#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "svdpi.h"

#define ROTRIGHT(a, b) (((a) >> (b)) | ((a) << (32 - (b))))
#define CH(x, y, z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTRIGHT(x, 2) ^ ROTRIGHT(x, 13) ^ ROTRIGHT(x, 22))
#define EP1(x) (ROTRIGHT(x, 6) ^ ROTRIGHT(x, 11) ^ ROTRIGHT(x, 25))
#define SIG0(x) (ROTRIGHT(x, 7) ^ ROTRIGHT(x, 18) ^ ((x) >> 3))
#define SIG1(x) (ROTRIGHT(x, 17) ^ ROTRIGHT(x, 19) ^ ((x) >> 10))

enum FSM_State
{
    STATE_IDLE,
    STATE_INIT,
    STATE_COMPRESS,
    STATE_UPDATE,
    STATE_DONE
};

class SHA256_Core
{
public:
    FSM_State state;
    uint32_t H[8];
    uint32_t W[64];
    uint32_t a, b, c, d, e, f, g, h;
    int round_idx;
    bool ready;

    static const uint32_t K[64];

    SHA256_Core()
    {
        reset();
    }

    void reset()
    {
        H[0] = 0x6a09e667;
        H[1] = 0xbb67ae85;
        H[2] = 0x3c6ef372;
        H[3] = 0xa54ff53a;
        H[4] = 0x510e527f;
        H[5] = 0x9b05688c;
        H[6] = 0x1f83d9ab;
        H[7] = 0x5be0cd19;
        state = STATE_IDLE;
        ready = true;
    }

    void load_block(const uint8_t *data)
    {
        for (int i = 0; i < 16; ++i)
        {
            W[i] = (data[i * 4] << 24) | (data[i * 4 + 1] << 16) | (data[i * 4 + 2] << 8) | (data[i * 4 + 3]);
        }
        state = STATE_INIT;
        ready = false;
    }

    void tick()
    {
        switch (state)
        {
        case STATE_IDLE:
            break;
        case STATE_INIT:
            a = H[0];
            b = H[1];
            c = H[2];
            d = H[3];
            e = H[4];
            f = H[5];
            g = H[6];
            h = H[7];
            round_idx = 0;
            state = STATE_COMPRESS;
            break;
        case STATE_COMPRESS:
            if (round_idx < 64)
            {
                uint32_t w_val;
                if (round_idx < 16)
                {
                    w_val = W[round_idx];
                }
                else
                {
                    w_val = SIG1(W[round_idx - 2]) + W[round_idx - 7] + SIG0(W[round_idx - 15]) + W[round_idx - 16];
                    W[round_idx] = w_val;
                }
                uint32_t t1 = h + EP1(e) + CH(e, f, g) + K[round_idx] + w_val;
                uint32_t t2 = EP0(a) + MAJ(a, b, c);
                h = g;
                g = f;
                f = e;
                e = d + t1;
                d = c;
                c = b;
                b = a;
                a = t1 + t2;
                round_idx++;
            }
            else
            {
                state = STATE_UPDATE;
            }
            break;
        case STATE_UPDATE:
            H[0] += a;
            H[1] += b;
            H[2] += c;
            H[3] += d;
            H[4] += e;
            H[5] += f;
            H[6] += g;
            H[7] += h;
            state = STATE_DONE;
            break;
        case STATE_DONE:
            ready = true;
            state = STATE_IDLE;
            break;
        }
    }
};

const uint32_t SHA256_Core::K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};

struct SHA256_CTX
{
    uint8_t data[64];
    uint32_t datalen;
    uint64_t bitlen;
    SHA256_Core core;
};

void sha256_init(SHA256_CTX *ctx)
{
    ctx->datalen = 0;
    ctx->bitlen = 0;
    ctx->core.reset();
}

void process_block(SHA256_CTX *ctx)
{
    ctx->core.load_block(ctx->data);
    while (!ctx->core.ready)
    {
        ctx->core.tick();
    }
}

void sha256_update(SHA256_CTX *ctx, const uint8_t data[], size_t len)
{
    for (size_t i = 0; i < len; ++i)
    {
        ctx->data[ctx->datalen] = data[i];
        ctx->datalen++;
        if (ctx->datalen == 64)
        {
            process_block(ctx);
            ctx->bitlen += 512;
            ctx->datalen = 0;
        }
    }
}

void sha256_final(SHA256_CTX *ctx, uint8_t hash[])
{
    uint32_t i = ctx->datalen;
    if (ctx->datalen < 56)
    {
        ctx->data[i++] = 0x80;
        while (i < 56)
            ctx->data[i++] = 0x00;
    }
    else
    {
        ctx->data[i++] = 0x80;
        while (i < 64)
            ctx->data[i++] = 0x00;
        process_block(ctx);
        memset(ctx->data, 0, 56);
    }

    ctx->bitlen += ctx->datalen * 8;
    ctx->data[63] = ctx->bitlen;
    ctx->data[62] = ctx->bitlen >> 8;
    ctx->data[61] = ctx->bitlen >> 16;
    ctx->data[60] = ctx->bitlen >> 24;
    ctx->data[59] = ctx->bitlen >> 32;
    ctx->data[58] = ctx->bitlen >> 40;
    ctx->data[57] = ctx->bitlen >> 48;
    ctx->data[56] = ctx->bitlen >> 56;
    process_block(ctx);

    for (i = 0; i < 4; ++i)
    {
        hash[i] = (ctx->core.H[0] >> (24 - i * 8)) & 0xff;
        hash[i + 4] = (ctx->core.H[1] >> (24 - i * 8)) & 0xff;
        hash[i + 8] = (ctx->core.H[2] >> (24 - i * 8)) & 0xff;
        hash[i + 12] = (ctx->core.H[3] >> (24 - i * 8)) & 0xff;
        hash[i + 16] = (ctx->core.H[4] >> (24 - i * 8)) & 0xff;
        hash[i + 20] = (ctx->core.H[5] >> (24 - i * 8)) & 0xff;
        hash[i + 24] = (ctx->core.H[6] >> (24 - i * 8)) & 0xff;
        hash[i + 28] = (ctx->core.H[7] >> (24 - i * 8)) & 0xff;
    }
}

int main()
{
    const char *test1 = "";
    uint8_t hash1[32];
    SHA256_CTX ctx1;
    sha256_init(&ctx1);
    sha256_update(&ctx1, (const uint8_t *)test1, strlen(test1));
    sha256_final(&ctx1, hash1);

    printf("Test Case 1: Empty String\n");
    printf("Input: \"%s\"\n", test1);
    printf("Output: ");
    for (int i = 0; i < 32; i++)
        printf("%02x", hash1[i]);
    printf("\n\n");

    const char *test2 = "abc";
    uint8_t hash2[32];
    SHA256_CTX ctx2;
    sha256_init(&ctx2);
    sha256_update(&ctx2, (const uint8_t *)test2, strlen(test2));
    sha256_final(&ctx2, hash2);

    printf("Test Case 2: Single-block Short String\n");
    printf("Input: \"%s\"\n", test2);
    printf("Output: ");
    for (int i = 0; i < 32; i++)
        printf("%02x", hash2[i]);
    printf("\n\n");

    const char *test3 = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
    uint8_t hash3[32];
    SHA256_CTX ctx3;
    sha256_init(&ctx3);
    sha256_update(&ctx3, (const uint8_t *)test3, strlen(test3));
    sha256_final(&ctx3, hash3);

    printf("Test Case 3: Single-block Long String (Exactly 56 bytes)\n");
    printf("Input: \"%s\"\n", test3);
    printf("Output: ");
    for (int i = 0; i < 32; i++)
        printf("%02x", hash3[i]);
    printf("\n\n");

    const char *test4 = "a";
    uint8_t hash4[32];
    SHA256_CTX ctx4;
    sha256_init(&ctx4);
    for (int i = 0; i < 1000000; i++)
        sha256_update(&ctx4, (const uint8_t *)test4, 1);
    sha256_final(&ctx4, hash4);

    printf("Test Case 4: Multi-block Million 'a's\n");
    printf("Input: \"a\" repeated 1,000,000 times\n");
    printf("Output: ");
    for (int i = 0; i < 32; i++)
        printf("%02x", hash4[i]);
    printf("\n");

    return 0;
}

extern "C"
{
    void c_sha256_digest(const svOpenArrayHandle msg_handle, int msg_len, uint32_t expected_hash[8])
    {
        SHA256_CTX ctx;
        uint8_t hash_bytes[32];

        sha256_init(&ctx);

        // svGetArrElemPtr1()을 사용하여 SV 동적 배열에서 한 바이트씩 안전하게 추출합니다.
        for (int i = 0; i < msg_len; i++)
        {
            uint8_t *byte_ptr = (uint8_t *)svGetArrElemPtr1(msg_handle, i);
            sha256_update(&ctx, byte_ptr, 1);
        }

        sha256_final(&ctx, hash_bytes);

        // SystemVerilog의 32-bit 배열(expected_hash)에 맞게 바이트 조합
        for (int i = 0; i < 8; ++i)
        {
            expected_hash[i] = (hash_bytes[i * 4] << 24) |
                               (hash_bytes[i * 4 + 1] << 16) |
                               (hash_bytes[i * 4 + 2] << 8) |
                               (hash_bytes[i * 4 + 3]);
        }
    }
}

/*
 * 1. Standard SHA-256 Test Vectors
 * ----------------------------------------------------------------------------
 * * Test Case 1: Empty String
 * Input:  "" (0 bytes)
 * Output: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
 * * Test Case 2: Single-block Short String
 * Input:  "abc"
 * Output: ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
 * * Test Case 3: Single-block Long String (Exactly 56 bytes)
 * Input:  "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
 * Output: 248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1
 * * Test Case 4: Multi-block Million 'a's
 * Input:  "a" repeated 1,000,000 times
 * Output: cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0
 */
