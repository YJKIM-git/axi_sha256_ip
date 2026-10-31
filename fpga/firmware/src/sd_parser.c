#include "sd_parser.h"
#include <string.h>
#include "xil_printf.h"

static FATFS g_fatfs;

int sd_mount(void)
{
    FRESULT res = f_mount(&g_fatfs, "0:/", 1);
    if (res != FR_OK) {
        xil_printf("[ERROR] SD Card Mount Failed. Code: %d\r\n", res);
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

void sd_unmount(void)
{
    f_mount(NULL, "0:/", 0);
}

int sd_open_file(FIL *fil, const char *filepath)
{
    FRESULT res = f_open(fil, filepath, FA_READ);
    if (res != FR_OK) {
        xil_printf("[ERROR] Failed to open %s (FRESULT=%d)\r\n", filepath, res);
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

void sd_close_file(FIL *fil)
{
    f_close(fil);
}

int sd_read_next_vector(FIL *fil, SHA256_TestVector_t *vec)
{
    SHA256_VecHeader_t hdr;
    UINT br = 0U;

    FRESULT res = f_read(fil, &hdr, sizeof(SHA256_VecHeader_t), &br);
    if (res != FR_OK || br < sizeof(SHA256_VecHeader_t)) {
        return 0;
    }

    if (hdr.byte_len > SD_MAX_MSG_BYTES) {
        xil_printf("[ERROR] Vector byte_len (%u) exceeds buffer size\r\n", hdr.byte_len);
        return -1;
    }

    vec->bit_len  = hdr.bit_len;
    vec->byte_len = hdr.byte_len;
    memcpy(vec->golden_md, hdr.golden_md, sizeof(hdr.golden_md));

    if (hdr.byte_len > 0U) {
        res = f_read(fil, vec->msg, hdr.byte_len, &br);
        if (res != FR_OK || br != hdr.byte_len) {
            return -1;
        }
    }

    return 1;
}