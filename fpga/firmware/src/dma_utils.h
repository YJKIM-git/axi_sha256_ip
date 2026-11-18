#ifndef DMA_UTILS_H
#define DMA_UTILS_H

#include <stdint.h>
#include "xparameters.h"
#include "xaxidma.h"
#include "xil_cache.h"
#include "xstatus.h"

#define AXI_DMA_BASE        0x40400000U

int  dma_init(XAxiDma *dma_inst_ptr);
int  dma_send_stream(XAxiDma *dma_inst_ptr, const uint8_t *tx_buf, uint32_t byte_len);
void dma_recover(XAxiDma *dma_inst_ptr);

#endif /* DMA_UTILS_H */