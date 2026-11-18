#ifndef SHA256_REF_MODEL_H
#define SHA256_REF_MODEL_H

#include <stdint.h>
#include <stddef.h>

typedef struct {
    uint8_t  data[64];
    uint32_t datalen;
    uint64_t bitlen;
    uint32_t H[8];
} SW_SHA256_CTX;

void sw_sha256_init(SW_SHA256_CTX *ctx);
void sw_sha256_init_custom_iv(SW_SHA256_CTX *ctx, const uint32_t iv[8]);
void sw_sha256_update(SW_SHA256_CTX *ctx, const uint8_t *data, size_t len);
void sw_sha256_final(SW_SHA256_CTX *ctx, uint32_t digest_out[8]);
void sw_sha256_oneshot(const uint8_t *data, size_t len, uint32_t digest_out[8]);

#endif /* SHA256_REF_MODEL_H */