#include "dma_utils.h"

int dma_init(XAxiDma *dma_inst_ptr)
{
    XAxiDma_Config *cfg_ptr = XAxiDma_LookupConfig(AXI_DMA_BASE);
    if (!cfg_ptr) {
        return XST_FAILURE;
    }

    if (XAxiDma_CfgInitialize(dma_inst_ptr, cfg_ptr) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    if (XAxiDma_HasSg(dma_inst_ptr)) {
        return XST_FAILURE;
    }

    XAxiDma_IntrDisable(dma_inst_ptr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrAckIrq(dma_inst_ptr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrEnable(dma_inst_ptr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    return XST_SUCCESS;
}

int dma_send_stream(XAxiDma *dma_inst_ptr, const uint8_t *tx_buf, uint32_t byte_len)
{
    if (byte_len == 0U) {
        return XST_INVALID_PARAM;
    }

    Xil_DCacheFlushRange((UINTPTR)tx_buf, byte_len);

    return XAxiDma_SimpleTransfer(
        dma_inst_ptr,
        (UINTPTR)tx_buf,
        byte_len,
        XAXIDMA_DMA_TO_DEVICE
    );
}

void dma_recover(XAxiDma *dma_inst_ptr)
{
    XAxiDma_Reset(dma_inst_ptr);
    int timeout = 1000000;
    while (timeout > 0 && !XAxiDma_ResetIsDone(dma_inst_ptr)) {
        timeout--;
    }
    XAxiDma_IntrAckIrq(dma_inst_ptr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrEnable(dma_inst_ptr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
}