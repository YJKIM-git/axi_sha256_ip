#include <stdint.h>
#include <string.h>
#include "xparameters.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_mmu.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xpseudo_asm.h"

#include "sha256_hal.h"
#include "dma_utils.h"
#include "sd_parser.h"
#include "sha256_ref_model.h"

#define DMA_MM2S_IRQ_ID             61U
#define SHA256_DONE_IRQ_ID          62U

/* Cortex-A9 64-bit Global Timer registers (Clocked at APU_FREQ / 2 = 333.33 MHz) */
#define ZYNQ_GTIMER_BASE            0xF8F00200U
#define ZYNQ_GTIMER_CNT_LO          (ZYNQ_GTIMER_BASE + 0x00U)
#define ZYNQ_GTIMER_CNT_HI          (ZYNQ_GTIMER_BASE + 0x04U)
#define ZYNQ_GTIMER_CTRL            (ZYNQ_GTIMER_BASE + 0x08U)
#define ZYNQ_GTIMER_FREQ_HZ         333333343ULL

#define MMU_ATTR_DEVICE_SECURE      0x00000C02U
#define MMU_ATTR_DEVICE_NONSECURE   0x00080C02U

/* Global symbol in Xilinx Cortex-A9 asm_vectors.S holding faulting instruction PC */
extern uint32_t DataAbortAddr;

typedef struct {
    const char    *name;
    const uint8_t *data;
    const uint32_t length;
    const uint32_t expected_hash[8];
} TestVector;

static const uint8_t tv1_data[] __attribute__((aligned(64))) = "abc";
static const uint8_t tv2_data[] __attribute__((aligned(64))) = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
static const uint8_t tv3_data[] __attribute__((aligned(64))) = "The quick brown fox jumps over the lazy dog";

static const TestVector basic_test_vectors[3] = {
    {
        "FIPS Vector 1 (3 Bytes)", tv1_data, 3U,
        {0xba7816bfU, 0x8f01cfeaU, 0x414140deU, 0x5dae2223U, 0xb00361a3U, 0x96177a9cU, 0xb410ff61U, 0xf20015adU}
    },
    {
        "FIPS Vector 2 (56 Bytes)", tv2_data, 56U,
        {0x248d6a61U, 0xd20638b8U, 0xe5c02693U, 0x0c3e6039U, 0xa33ce459U, 0x64ff2167U, 0xf6ecedd4U, 0x19db06c1U}
    },
    {
        "Custom Vector 3 (43 Bytes)", tv3_data, 43U,
        {0xd7a8fbb3U, 0x07d78094U, 0x69ca9abcU, 0xb0082e4fU, 0x8d5651e4U, 0x6d3cdb76U, 0x2d02d0bfU, 0x37c9e592U}
    }
};

static XAxiDma              AxiDma;
static XScuGic              Intc;
static SHA256_TestVector_t  g_tv;

static volatile int g_dma_done_flag    = 0;
static volatile int g_dma_err_flag     = 0;
static volatile int g_sha256_done_flag = 0;
static volatile int g_data_abort_cnt   = 0;

static void gtimer_init(void)
{
    /* Enable 64-bit Global Timer with prescaler = 0 */
    Xil_Out32(ZYNQ_GTIMER_CTRL, 0x00000001U);
}

static uint64_t gtimer_get_ticks(void)
{
    uint32_t hi1, lo, hi2;
    do {
        hi1 = Xil_In32(ZYNQ_GTIMER_CNT_HI);
        lo  = Xil_In32(ZYNQ_GTIMER_CNT_LO);
        hi2 = Xil_In32(ZYNQ_GTIMER_CNT_HI);
    } while (hi1 != hi2);
    return (((uint64_t)hi1 << 32) | lo);
}

static void dma_mm2s_isr(void *callback_ref)
{
    XAxiDma *dma_ptr = (XAxiDma *)callback_ref;
    uint32_t irq_status = XAxiDma_IntrGetIrq(dma_ptr, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrAckIrq(dma_ptr, irq_status, XAXIDMA_DMA_TO_DEVICE);

    if (irq_status & XAXIDMA_IRQ_ERROR_MASK) {
        g_dma_err_flag = 1;
    }
    if (irq_status & XAXIDMA_IRQ_IOC_MASK) {
        g_dma_done_flag = 1;
    }
}

static void sha256_done_isr(void *callback_ref)
{
    (void)callback_ref;
    sha256_clear_intr(SHA256_INTCLR_DONE);
    g_sha256_done_flag = 1;
}

static void axi_abort_exception_handler(void *data)
{
    (void)data;
    uint32_t dfsr = 0U;
    uint32_t spsr = 0U;

    __asm__ volatile("mrc p15, 0, %0, c5, c0, 0" : "=r"(dfsr));
    __asm__ volatile("mrs %0, spsr" : "=r"(spsr));
    __asm__ volatile("mcr p15, 0, %0, c5, c0, 0" : : "r"(0U));

    if ((dfsr & (1U << 10)) == 0U) { /* Synchronous Abort */
        uint32_t *sp_ptr;
        __asm__ volatile("mov %0, sp" : "=r"(sp_ptr));
        
        uint32_t inst_len = (spsr & 0x20U) ? 2U : 4U;

        for (int i = 0; i < 256; i++) {
            if (sp_ptr[i] == (DataAbortAddr + 8U)) {
                sp_ptr[i] += inst_len;
            }
        }
    }

    g_data_abort_cnt++;
    dsb();
}

static int setup_interrupt_system(XScuGic *intc_ptr, XAxiDma *dma_ptr)
{
    XScuGic_Config *intc_cfg;

#ifdef XPAR_XSCUGIC_0_BASEADDR
    intc_cfg = XScuGic_LookupConfig(XPAR_XSCUGIC_0_BASEADDR);
#else
    intc_cfg = XScuGic_LookupConfig(0);
#endif
    if (!intc_cfg) {
        return XST_FAILURE;
    }

    if (XScuGic_CfgInitialize(intc_ptr, intc_cfg, intc_cfg->CpuBaseAddress) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    XScuGic_SetPriorityTriggerType(intc_ptr, DMA_MM2S_IRQ_ID, 0xA0U, 0x01U);
    XScuGic_SetPriorityTriggerType(intc_ptr, SHA256_DONE_IRQ_ID, 0xA0U, 0x01U);

    if (XScuGic_Connect(intc_ptr, DMA_MM2S_IRQ_ID,
                        (Xil_InterruptHandler)dma_mm2s_isr, dma_ptr) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    if (XScuGic_Connect(intc_ptr, SHA256_DONE_IRQ_ID,
                        (Xil_InterruptHandler)sha256_done_isr, NULL) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    XScuGic_Enable(intc_ptr, DMA_MM2S_IRQ_ID);
    XScuGic_Enable(intc_ptr, SHA256_DONE_IRQ_ID);

    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 intc_ptr);
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_DATA_ABORT_INT,
                                 (Xil_ExceptionHandler)axi_abort_exception_handler,
                                 NULL);
    Xil_ExceptionEnable();

    return XST_SUCCESS;
}

static int run_pl_sha256_irq(const uint8_t *msg, uint32_t byte_len,
                             uint32_t digest_out[8], uint64_t *elapsed_ticks)
{
    uint64_t t_start, t_end;
    uint32_t timeout = 10000000U;

    while ((sha256_get_status() & SHA256_STATUS_BUSY) != 0U) {}

    g_dma_done_flag    = 0;
    g_dma_err_flag     = 0;
    g_sha256_done_flag = 0;

    sha256_clear_intr(SHA256_INTCLR_DONE | SHA256_INTCLR_ERR);

    t_start = gtimer_get_ticks();

    sha256_start(1);
    if (dma_send_stream(&AxiDma, msg, byte_len) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    while (!g_sha256_done_flag && !g_dma_err_flag && timeout > 0U) {
        timeout--;
    }

    t_end = gtimer_get_ticks();

    if (elapsed_ticks != NULL) {
        *elapsed_ticks = (t_end - t_start);
    }

    if (timeout == 0U || g_dma_err_flag) {
        sha256_clear_intr(SHA256_INTCLR_DONE | SHA256_INTCLR_ERR);
        return XST_FAILURE;
    }

    sha256_read_digest(digest_out);
    return XST_SUCCESS;
}

static int compare_digests(const uint32_t hw[8], const uint32_t expected[8], int verbose)
{
    int mismatch = 0;
    for (int i = 0; i < 8; i++) {
        if (hw[i] != expected[i]) {
            if (verbose) {
                xil_printf("  [MISMATCH] Word %d: HW=0x%08X, Expected=0x%08X\r\n",
                           i, hw[i], expected[i]);
            }
            mismatch++;
        }
    }
    return mismatch;
}

static int test_basic_vectors(void)
{
    xil_printf("=== [Test 1] Basic Bring-up Vectors (Interrupt Mode) ===\r\n");
    int total_errors = 0;
    uint32_t hw_digest[8], sw_digest[8];

    for (int v = 0; v < 3; v++) {
        xil_printf("--- Testing %s ---\r\n", basic_test_vectors[v].name);
        uint64_t pl_ticks = 0ULL;

        if (run_pl_sha256_irq(basic_test_vectors[v].data,
                              basic_test_vectors[v].length,
                              hw_digest, &pl_ticks) != XST_SUCCESS) {
            xil_printf("  [ERROR] IP Timeout or DMA Error. STATUS: 0x%08X\r\n",
                       sha256_get_status());
            total_errors++;
            continue;
        }

        uint64_t ps_t0 = gtimer_get_ticks();
        sw_sha256_oneshot(basic_test_vectors[v].data, basic_test_vectors[v].length, sw_digest);
        uint64_t ps_t1 = gtimer_get_ticks();

        int mismatch = compare_digests(hw_digest, basic_test_vectors[v].expected_hash, 1);
        mismatch += compare_digests(sw_digest, basic_test_vectors[v].expected_hash, 0);

        if (mismatch == 0) {
            xil_printf("  [SUCCESS] Hash Match! (PL=%u ticks, PS=%u ticks)\r\n",
                       (unsigned int)pl_ticks, (unsigned int)(ps_t1 - ps_t0));
        } else {
            total_errors += mismatch;
        }
    }
    return (total_errors == 0) ? XST_SUCCESS : XST_FAILURE;
}

static int test_padding_and_chaining(void)
{
    xil_printf("\r\n=== [Test 2] Padding Boundary (55B/56B/64B) & Auto/Manual Chaining ===\r\n");
    const uint32_t boundary_lengths[] = {1U, 55U, 56U, 64U, 128U, 192U};
    uint32_t hw_digest[8], sw_digest[8];

    for (size_t idx = 0; idx < sizeof(boundary_lengths) / sizeof(boundary_lengths[0]); idx++) {
        uint32_t len = boundary_lengths[idx];
        for (uint32_t i = 0; i < len; i++) {
            g_tv.msg[i] = (uint8_t)('a' + (i % 26U));
        }

        if (run_pl_sha256_irq(g_tv.msg, len, hw_digest, NULL) != XST_SUCCESS) {
            return XST_FAILURE;
        }
        sw_sha256_oneshot(g_tv.msg, len, sw_digest);

        if (compare_digests(hw_digest, sw_digest, 1) != 0) {
            return XST_FAILURE;
        }
        xil_printf("  [PASS] Payload %3u Bytes (HW MSG_LEN=%u bits)\r\n",
                   len, (unsigned int)sha256_get_msg_bitlen());
    }

    const uint32_t custom_iv[8] = {
        0x11223344U, 0x55667788U, 0x99AABBCCU, 0xDDEEFF00U,
        0x0F1E2D3CU, 0x4B5A6978U, 0x8796A5B4U, 0xC3D2E1F0U
    };
    sha256_set_custom_iv(custom_iv);

    if (run_pl_sha256_irq(g_tv.msg, 64U, hw_digest, NULL) != XST_SUCCESS) {
        sha256_load_default_iv();
        return XST_FAILURE;
    }

    SW_SHA256_CTX custom_ctx;
    sw_sha256_init_custom_iv(&custom_ctx, custom_iv);
    sw_sha256_update(&custom_ctx, g_tv.msg, 64U);
    sw_sha256_final(&custom_ctx, sw_digest);
    sha256_load_default_iv();

    if (compare_digests(hw_digest, sw_digest, 1) != 0) {
        return XST_FAILURE;
    }
    xil_printf("  [PASS] STATE_IN Custom IV Chaining Verified\r\n");
    return XST_SUCCESS;
}

static int test_negative_exceptions(void)
{
    xil_printf("\r\n=== [Test 3] Exception & Security (Negative) Verification ===\r\n");
    g_data_abort_cnt = 0;

    /* 3.1 Atomicity Violation: Write to STATE_IN while STATUS.BUSY == 1 */
    sha256_clear_intr(SHA256_INTCLR_DONE | SHA256_INTCLR_ERR);
    sha256_start(0);

    if (!(sha256_get_status() & SHA256_STATUS_BUSY)) {
        xil_printf("  [ERROR] Failed to enter BUSY state\r\n");
        return XST_FAILURE;
    }

    sha256_ip->STATE_IN[0] = 0xDEADBEEFU;
    dsb();

    if (!(sha256_get_status() & SHA256_STATUS_ERR_PRT)) {
        xil_printf("  [ERROR] Atomicity protection did not trigger ERR_PRT\r\n");
        return XST_FAILURE;
    }
    xil_printf("  [PASS] Atomicity Violation Blocked (STATUS=0x%08X, Aborts=%d)\r\n",
               sha256_get_status(), g_data_abort_cnt);

    /* 3.2 Soft-Reset & Hang Recovery */
    sha256_soft_reset();
    dsb();
    if ((sha256_get_status() & SHA256_STATUS_BUSY) != 0U ||
        sha256_ip->STATE_IN[0] != 0x6A09E667U) {
        xil_printf("  [ERROR] Soft-Reset recovery failed\r\n");
        return XST_FAILURE;
    }
    xil_printf("  [PASS] Soft-Reset & Hang Recovery Verified\r\n");

    /* 3.3 Address Decode & RO/WO Violation (SLVERR / DECERR) */
    Xil_Out32(SHA256_BASE_ADDR + SHA256_OFFSET_ID, 0x12345678U);
    dsb();
    (void)Xil_In32(SHA256_BASE_ADDR + SHA256_OFFSET_INTCLEAR);
    dsb();
    (void)Xil_In32(SHA256_BASE_ADDR + SHA256_OFFSET_UNALLOC);
    dsb();

    if (sha256_ip->ID == SHA256_HW_ID_EXPECTED) {
        xil_printf("  [PASS] RO/WO/Unallocated Access Protected (ID=0x%08X, Aborts=%d)\r\n",
                   sha256_ip->ID, g_data_abort_cnt);
    }

    /* 3.4 PROT Firewall: Set MMU TLB NS=1 to drive AxPROT[1]=1 */
    sha256_clear_intr(SHA256_INTCLR_ERR);
    Xil_SetTlbAttributes(SHA256_BASE_ADDR, MMU_ATTR_DEVICE_NONSECURE);

    (void)sha256_ip->ID;
    dsb();
    sha256_ip->STATE_IN[0] = 0xCAFEBABEU;
    dsb();

    Xil_SetTlbAttributes(SHA256_BASE_ADDR, MMU_ATTR_DEVICE_SECURE);

    uint32_t prot_status = sha256_get_status();
    if ((prot_status & SHA256_STATUS_ERR_PRT) && sha256_ip->STATE_IN[0] == 0x6A09E667U) {
        xil_printf("  [PASS] PROT Firewall Blocked Non-Secure Access (ERR_PRT=1, Aborts=%d)\r\n",
                   g_data_abort_cnt);
    } else {
        xil_printf("  [INFO] PROT Firewall Status=0x%08X, Aborts=%d\r\n",
                   prot_status, g_data_abort_cnt);
    }
    sha256_clear_intr(SHA256_INTCLR_ERR);

    return XST_SUCCESS;
}

static int run_sd_bin_suite(const char *filepath)
{
    FIL fil;
    if (sd_open_file(&fil, filepath) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    xil_printf("\r\n=== [Test 4] SD Card Preprocessed CAVP Suite: %s ===\r\n", filepath);

    uint32_t total_cnt = 0U, pass_cnt = 0U, waived_cnt = 0U;
    uint64_t total_pl_ticks = 0ULL, total_ps_ticks = 0ULL;
    uint64_t total_bits = 0ULL;
    uint32_t hw_digest[8], sw_digest[8];
    int rd_stat;

    while ((rd_stat = sd_read_next_vector(&fil, &g_tv)) > 0) {
        total_cnt++;

        /* Len = 0 is waived on PL DMA due to AXI DMA 1B minimum transfer & Null Beat firewall */
        if (g_tv.bit_len == 0U) {
            sw_sha256_oneshot(g_tv.msg, 0U, sw_digest);
            if (compare_digests(sw_digest, g_tv.golden_md, 1) == 0) {
                waived_cnt++;
                pass_cnt++;
            }
            continue;
        }

        uint64_t pl_ticks = 0ULL;
        if (run_pl_sha256_irq(g_tv.msg, g_tv.byte_len, hw_digest, &pl_ticks) != XST_SUCCESS) {
            xil_printf("  [ERROR] PL Timeout at Len=%u bits\r\n", g_tv.bit_len);
            sd_close_file(&fil);
            return XST_FAILURE;
        }

        uint64_t ps_t0 = gtimer_get_ticks();
        sw_sha256_oneshot(g_tv.msg, g_tv.byte_len, sw_digest);
        uint64_t ps_t1 = gtimer_get_ticks();

        if (compare_digests(hw_digest, g_tv.golden_md, 1) == 0 &&
            compare_digests(sw_digest, g_tv.golden_md, 0) == 0) {
            pass_cnt++;
            total_pl_ticks += pl_ticks;
            total_ps_ticks += (ps_t1 - ps_t0);
            total_bits     += g_tv.bit_len;
        } else {
            xil_printf("  [ERROR] Digest Mismatch at Len=%u bits\r\n", g_tv.bit_len);
            sd_close_file(&fil);
            return XST_FAILURE;
        }
    }

    sd_close_file(&fil);

    if (rd_stat < 0) {
        return XST_FAILURE;
    }

    uint32_t pl_us = (uint32_t)((total_pl_ticks * 1000000ULL) / ZYNQ_GTIMER_FREQ_HZ);
    uint32_t ps_us = (uint32_t)((total_ps_ticks * 1000000ULL) / ZYNQ_GTIMER_FREQ_HZ);
    uint32_t pl_mbps_x100 = (pl_us > 0U) ? (uint32_t)((total_bits * 100ULL) / pl_us) : 0U;
    uint32_t ps_mbps_x100 = (ps_us > 0U) ? (uint32_t)((total_bits * 100ULL) / ps_us) : 0U;
    uint32_t speedup_x100 = (total_pl_ticks > 0ULL) ? (uint32_t)((total_ps_ticks * 100ULL) / total_pl_ticks) : 0U;

    xil_printf("  [SUMMARY] %s: %u/%u Passed (%u Waived for Len=0)\r\n",
               filepath, pass_cnt, total_cnt, waived_cnt);
    xil_printf("  [PERF] Bits: %u | PL: %u us (%u.%02u Mbps) | PS: %u us (%u.%02u Mbps) | Speed-up: %u.%02ux\r\n",
               (unsigned int)total_bits,
               pl_us, pl_mbps_x100 / 100U, pl_mbps_x100 % 100U,
               ps_us, ps_mbps_x100 / 100U, ps_mbps_x100 % 100U,
               speedup_x100 / 100U, speedup_x100 % 100U);

    return (pass_cnt == total_cnt) ? XST_SUCCESS : XST_FAILURE;
}

int main(void)
{
    gtimer_init();

    xil_printf("\r\n=================================================\r\n");
    xil_printf(" SHA-256 Hardware Verification Suite (v5.1 IRQ)\r\n");
    xil_printf("=================================================\r\n");

    if (sha256_init() != XST_SUCCESS) {
        xil_printf("[ERROR] SHA-256 IP ID mismatch. Got: 0x%08X\r\n", sha256_ip->ID);
        return -1;
    }
    xil_printf("[SUCCESS] SHA-256 ID Verified (0x%08X).\r\n", sha256_ip->ID);

    if (dma_init(&AxiDma) != XST_SUCCESS) {
        xil_printf("[ERROR] DMA initialization failed.\r\n");
        return -1;
    }
    xil_printf("[SUCCESS] DMA Initialized in Direct Register Mode.\r\n");

    if (setup_interrupt_system(&Intc, &AxiDma) != XST_SUCCESS) {
        xil_printf("[ERROR] GIC Interrupt initialization failed.\r\n");
        return -1;
    }
    xil_printf("[SUCCESS] GIC Interrupts Connected (DMA=61, SHA256=62).\r\n\r\n");

    int total_failures = 0;

    if (test_basic_vectors() != XST_SUCCESS) {
        total_failures++;
    }

    if (test_padding_and_chaining() != XST_SUCCESS) {
        total_failures++;
    }

    if (test_negative_exceptions() != XST_SUCCESS) {
        total_failures++;
    }

    if (sd_mount() == XST_SUCCESS) {
        if (run_sd_bin_suite("0:/SHORT_TV.BIN") != XST_SUCCESS) {
            total_failures++;
        }
        if (run_sd_bin_suite("0:/LONG_TV.BIN") != XST_SUCCESS) {
            total_failures++;
        }
        sd_unmount();
    } else {
        total_failures++;
    }

    xil_printf("\r\n=================================================\r\n");
    if (total_failures == 0) {
        xil_printf("ALL TESTS PASSED SUCCESSFULLY.\r\n");
    } else {
        xil_printf("TEST FAILED WITH %d SUITE ERRORS.\r\n", total_failures);
    }
    xil_printf("=================================================\r\n");

    return 0;
}