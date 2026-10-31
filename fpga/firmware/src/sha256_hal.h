#ifndef SHA256_HAL_H
#define SHA256_HAL_H

#include <stdint.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xstatus.h"

#define SHA256_BASE_ADDR            0x40000000U
#define SHA256_HW_ID_EXPECTED       0x41749591U

#define SHA256_OFFSET_ID            0x00U
#define SHA256_OFFSET_CTRL          0x04U
#define SHA256_OFFSET_STATUS        0x08U
#define SHA256_OFFSET_INTCLEAR      0x0CU
#define SHA256_OFFSET_MSG_LEN_LO    0x10U
#define SHA256_OFFSET_MSG_LEN_HI    0x14U
#define SHA256_OFFSET_DIGEST_BASE   0x20U
#define SHA256_OFFSET_UNALLOC       0x40U
#define SHA256_OFFSET_STATE_IN_BASE 0x80U

#define SHA256_CTRL_EN              (1U << 0)
#define SHA256_CTRL_IRQ_EN          (1U << 1)
#define SHA256_CTRL_START           (1U << 2)
#define SHA256_CTRL_SOFT_RST        (1U << 3)

#define SHA256_STATUS_BUSY          (1U << 0)
#define SHA256_STATUS_DONE          (1U << 1)
#define SHA256_STATUS_ERR_PRT       (1U << 2)

#define SHA256_INTCLR_DONE          (1U << 1)
#define SHA256_INTCLR_ERR           (1U << 2)

typedef struct {
    volatile const uint32_t ID;
    volatile       uint32_t CTRL;
    volatile const uint32_t STATUS;
    volatile       uint32_t INTCLEAR;
    volatile const uint32_t MSG_LEN_LO;
    volatile const uint32_t MSG_LEN_HI;
    uint32_t _reserved0[2];
    volatile const uint32_t DIGEST[8];
    uint32_t _reserved1[16];
    volatile       uint32_t STATE_IN[8];
} SHA256_RegMap;

#define sha256_ip ((SHA256_RegMap *)SHA256_BASE_ADDR)

int      sha256_init(void);
void     sha256_soft_reset(void);
void     sha256_load_default_iv(void);
void     sha256_set_custom_iv(const uint32_t iv[8]);
void     sha256_start(int irq_enable);
void     sha256_clear_intr(uint32_t clr_mask);
uint32_t sha256_get_status(void);
uint64_t sha256_get_msg_bitlen(void);
void     sha256_read_digest(uint32_t digest[8]);

#endif /* SHA256_HAL_H */