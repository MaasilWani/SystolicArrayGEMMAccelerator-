#include "xil_io.h"
#include "xparameters.h"
#include "xuartlite.h"
#include "xil_printf.h"

//Multiple test cases are included in this file. Comment out the ones you don't want to run. The main function is defined in each test case, so only one test case can be active at a time.

// Basic test for 4x4 matmul accelerator with debug prints. Writes two 4x4 matrices to BRAM, starts accelerator, polls for done, and reads back result.
#define DMEM_EXT   XPAR_AXI_BRAM_0_BASEADDRESS
#define CTRL_BASE  XPAR_CTRL_REGS_FSM_0_BASEADDR

#define A_BASE 0x00000000   //Address of Matrix A in Dual Port
#define B_BASE 0x00000040   //Address of Matrix B in Dual Port
#define C_BASE 0x00000100   //Address of Result Matrix C in Dual Port

int main() {
    XUartLite uart;   //Initializing UART
    XUartLite_Initialize(&uart, XPAR_AXI_UARTLITE_0_BASEADDR);

    xil_printf("Starting accelerator test...\r\n");

    // Clear output region first
    for (int i = 0; i < 16; i++) {
        Xil_Out32(DMEM_EXT + C_BASE + 4*i, 0x99999999);
    }

    // A = all ones, packed as four 8-bit values per 32-bit word
    // Each row = [1, 1, 1, 1]
    // A =
    // [ 1   2   3   4
    //   5   6   7   8
    //   9  10  11  12
    //  13  14  15  16 ]

    Xil_Out32(DMEM_EXT + A_BASE + 0x00, 0x01020304);  //Sending A matrix from CPU to BRAM
    Xil_Out32(DMEM_EXT + A_BASE + 0x04, 0x05060708);
    Xil_Out32(DMEM_EXT + A_BASE + 0x08, 0x090A0B0C);
    Xil_Out32(DMEM_EXT + A_BASE + 0x0C, 0x0D0E0F10);

    // B =
    // [ 1   2   3   4
    //   5   6   7   8
    //   9  10  11  12
    //  13  14  15  16 ]

   // B column 0 = [1, 5, 9, 13]
    Xil_Out32(DMEM_EXT + B_BASE + 0x00, 0x0105090D);  //Sending B matrix from CPU to BRAM

    // B column 1 = [2, 6, 10, 14]
    Xil_Out32(DMEM_EXT + B_BASE + 0x04, 0x02060A0E);

    // B column 2 = [3, 7, 11, 15]
    Xil_Out32(DMEM_EXT + B_BASE + 0x08, 0x03070B0F);

    // B column 3 = [4, 8, 12, 16]
    Xil_Out32(DMEM_EXT + B_BASE + 0x0C, 0x04080C10);

    // Read back A/B to verify BRAM writes
    xil_printf("A words:\r\n");
    for (int i = 0; i < 4; i++) {
        xil_printf("A[%d] = 0x%08X\r\n", i, Xil_In32(DMEM_EXT + A_BASE + 4*i));
    }

    xil_printf("B words:\r\n");
    for (int i = 0; i < 4; i++) {
        xil_printf("B[%d] = 0x%08X\r\n", i, Xil_In32(DMEM_EXT + B_BASE + 4*i));
    }

    xil_printf("C output words Before:\r\n");
    for (int i = 0; i < 4; i++) {
        u32 c = Xil_In32(DMEM_EXT + C_BASE + 4*i);
        xil_printf("C[%02d] = 0x%08X (%d)\r\n", i, c, c);
    }

    // Program control registers
    Xil_Out32(CTRL_BASE + 0x00, A_BASE); // src_a_addr
    Xil_Out32(CTRL_BASE + 0x04, B_BASE); // src_b_addr
    Xil_Out32(CTRL_BASE + 0x08, C_BASE); // dst_addr

    // Start accelerator
    Xil_Out32(CTRL_BASE + 0x10, 0x00000001); // go

    // Poll done with timeout
    volatile u32 done = 0;
    volatile u32 busy = 0;
    volatile int timeout = 1000000;

    while ((done == 0) && (timeout > 0)) {
        done = Xil_In32(CTRL_BASE + 0x1C);
        busy = Xil_In32(CTRL_BASE + 0x18);
        timeout--;
    }

    xil_printf("done = %d, busy = %d, timeout = %d\r\n", done, busy, timeout);

    // Read result matrix C
    xil_printf("C output words:\r\n");
    for (int i = 0; i < 16; i++) {
        u32 c = Xil_In32(DMEM_EXT + C_BASE + 4*i);
        xil_printf("C[%02d] = 0x%08X (%d)\r\n", i, c, c);
    }

    return 0;
}

// Basic cycle count test. Measures cycles taken to execute an empty loop of 1000 iterations.
// #include "xil_printf.h"

// static inline uint32_t get_cycle() {
//     uint32_t c;
//     __asm__ volatile ("rdcycle %0" : "=r"(c));
//     return c;
// }

// int main() {
//     uint32_t t0 = get_cycle();
//     for (volatile int i = 0; i < 1000; i++);
//     uint32_t t1 = get_cycle();

//     xil_printf("delta: %u\r\n", t1 - t0);

//     while(1);
//     return 0;
// }


// 4x4 matmul software reference. Measures cycles taken by software to compute 4x4 matrix multiplication on CPU. Compare with hardware accelerator result.

// #include "xil_printf.h"

// static inline uint32_t get_cycle() {
//     uint32_t c;
//     __asm__ volatile ("rdcycle %0" : "=r"(c));
//     return c;
// }

// void sw_matmul(int8_t A[4][4], int8_t B[4][4], int32_t C[4][4]) {
//     for (int i = 0; i < 4; i++)
//         for (int j = 0; j < 4; j++) {
//             C[i][j] = 0;
//             for (int k = 0; k < 4; k++)
//                 C[i][j] += A[i][k] * B[k][j];
//         }
// }

// int main() {

//     int8_t A[4][4] = {
//         { 1,  2,  3,  4},
//         { 5,  6,  7,  8},
//         { 9, 10, 11, 12},
//         {13, 14, 15, 16}
//     };
//     int8_t B[4][4] = {
//         { 1,  2,  3,  4},
//         { 5,  6,  7,  8},
//         { 9, 10, 11, 12},
//         {13, 14, 15, 16}
//     };

//     int32_t C[4][4];

//     uint32_t t0 = get_cycle();
//     sw_matmul(A, B, C);
//     uint32_t sw_cycles = get_cycle() - t0;

//     xil_printf("Result:\r\n");
//     for (int i = 0; i < 4; i++) {
//         for (int j = 0; j < 4; j++)
//             xil_printf("%6d ", C[i][j]);
//         xil_printf("\r\n");
//     }

//     xil_printf("\r\nSW cycles: %u\r\n", sw_cycles);

//     return 0;
// }

// 4x4 matmul hardware accelerator test. Writes two 4x4 matrices to BRAM, starts accelerator, polls for done, and reads back result. Measures hardware cycles taken by accelerator.

// #include "xil_io.h"
// #include "xparameters.h"
// #include "xil_printf.h"

// #define DMEM_EXT  XPAR_AXI_BRAM_0_BASEADDRESS
// #define CTRL_BASE XPAR_CTRL_REGS_FSM_0_BASEADDR

// #define A_BASE 0x00000000
// #define B_BASE 0x00000040
// #define C_BASE 0x00000100

// static inline uint32_t get_cycle() {
//     uint32_t c;
//     __asm__ volatile ("rdcycle %0" : "=r"(c));
//     return c;
// }

// int main() {

//     // Write A to BRAM (row-major)
//     Xil_Out32(DMEM_EXT + A_BASE + 0x00, 0x01020304);
//     Xil_Out32(DMEM_EXT + A_BASE + 0x04, 0x05060708);
//     Xil_Out32(DMEM_EXT + A_BASE + 0x08, 0x090A0B0C);
//     Xil_Out32(DMEM_EXT + A_BASE + 0x0C, 0x0D0E0F10);

//     // Write B to BRAM (column-major)
//     Xil_Out32(DMEM_EXT + B_BASE + 0x00, 0x0105090D);
//     Xil_Out32(DMEM_EXT + B_BASE + 0x04, 0x02060A0E);
//     Xil_Out32(DMEM_EXT + B_BASE + 0x08, 0x03070B0F);
//     Xil_Out32(DMEM_EXT + B_BASE + 0x0C, 0x04080C10);

//     Xil_Out32(CTRL_BASE + 0x00, A_BASE);
//     Xil_Out32(CTRL_BASE + 0x04, B_BASE);
//     Xil_Out32(CTRL_BASE + 0x08, C_BASE);

//     uint32_t t0 = get_cycle();

//     Xil_Out32(CTRL_BASE + 0x10, 0x1);
//     while (!Xil_In32(CTRL_BASE + 0x1C));

//     uint32_t hw_cycles = get_cycle() - t0;

//     // Read result (reversed output)
//     // int32_t C[4][4];
//     // for (int idx = 0; idx < 16; idx++) {
//     //     int k = 15 - idx;
//     //     C[k/4][k%4] = (int32_t)Xil_In32(DMEM_EXT + C_BASE + 4*idx);
//     // }

//     int32_t C[4][4];
//     for (int idx = 0; idx < 16; idx++) {
//         int k = 15 - idx;
//         C[k%4][k/4] = (int32_t)Xil_In32(DMEM_EXT + C_BASE + 4*idx);
//     }

//     xil_printf("Result:\r\n");
//     for (int i = 0; i < 4; i++) {
//         for (int j = 0; j < 4; j++)
//             xil_printf("%6d ", C[i][j]);
//         xil_printf("\r\n");
//     }

//     xil_printf("\r\nHW cycles: %u\r\n", hw_cycles);

//     return 0;
// }



// 16x16 matmul software reference. Measures cycles taken by software to compute 16x16 matrix multiplication on CPU. Compare with hardware accelerator result.
// #include "xil_printf.h"

// static inline uint32_t get_cycle() {
//     uint32_t c;
//     __asm__ volatile ("rdcycle %0" : "=r"(c));
//     return c;
// }

// void sw_matmul_16(int8_t A[16][16], int8_t B[16][16], int32_t C[16][16]) {
//     for (int i = 0; i < 16; i++)
//         for (int j = 0; j < 16; j++) {
//             C[i][j] = 0;
//             for (int k = 0; k < 16; k++)
//                 C[i][j] += A[i][k] * B[k][j];
//         }
// }

// int main() {

//     // A and B filled 1..256 row-major
//     int8_t A[16][16], B[16][16];
//     int32_t C[16][16];

//     for (int i = 0; i < 16; i++)
//         for (int j = 0; j < 16; j++) {
//             A[i][j] = (int8_t)(i + j + 1);   // values 1..31, safely fits in int8
//             B[i][j] = (int8_t)(i + j + 1);
//         }

//     uint32_t t0 = get_cycle();
//     sw_matmul_16(A, B, C);
//     uint32_t sw_cycles = get_cycle() - t0;

//     xil_printf("C[0][0]   = %d\r\n", C[0][0]);
//     xil_printf("C[0][15]  = %d\r\n", C[0][15]);
//     xil_printf("C[15][0]  = %d\r\n", C[15][0]);
//     xil_printf("C[15][15] = %d\r\n", C[15][15]);

//     xil_printf("\r\nSW 16x16 cycles: %u\r\n", sw_cycles);

//     return 0;
// }

// 16x16 matmul hardware accelerator test. Writes two 16x16 matrices to BRAM, starts accelerator, polls for done, and reads back result. Measures hardware cycles taken by accelerator.

// #include <stdint.h>
// #include "xil_io.h"
// #include "xparameters.h"
// #include "xil_printf.h"

// #define DMEM_EXT  XPAR_AXI_BRAM_0_BASEADDRESS
// #define CTRL_BASE XPAR_CTRL_REGS_FSM_0_BASEADDR

// #define A_BASE 0x00000000
// #define B_BASE 0x00000040
// #define C_BASE 0x00000100

// static inline uint32_t get_cycle(void) {
//     uint32_t c;
//     __asm__ volatile ("rdcycle %0" : "=r"(c));
//     return c;
// }

// static uint32_t pack4_u8(int8_t x0, int8_t x1, int8_t x2, int8_t x3) {
//     return ((uint32_t)((uint8_t)x0) << 24) |
//            ((uint32_t)((uint8_t)x1) << 16) |
//            ((uint32_t)((uint8_t)x2) <<  8) |
//            ((uint32_t)((uint8_t)x3) <<  0);
// }

// static void run_accelerator(void) {
//     Xil_Out32(CTRL_BASE + 0x00, A_BASE);
//     Xil_Out32(CTRL_BASE + 0x04, B_BASE);
//     Xil_Out32(CTRL_BASE + 0x08, C_BASE);

//     // Start accelerator
//     Xil_Out32(CTRL_BASE + 0x10, 0x1);

//     /*
//      * done is sticky from previous run.
//      * For repeated calls:
//      * 1. wait for old done to clear
//      * 2. wait for new done to become 1
//      */
//     while (Xil_In32(CTRL_BASE + 0x1C) & 0x1);

//     while (!(Xil_In32(CTRL_BASE + 0x1C) & 0x1));
// }

// static void print_corners(int32_t C[16][16]) {
//     xil_printf("C[0][0]   = %d\r\n", C[0][0]);
//     xil_printf("C[0][15]  = %d\r\n", C[0][15]);
//     xil_printf("C[15][0]  = %d\r\n", C[15][0]);
//     xil_printf("C[15][15] = %d\r\n", C[15][15]);
// }

// static void print_matrix_16x16(int32_t C[16][16]) {
//     xil_printf("\r\nFull 16x16 C matrix:\r\n");

//     for (int i = 0; i < 16; i++) {
//         for (int j = 0; j < 16; j++) {
//             xil_printf("%6d ", C[i][j]);
//         }
//         xil_printf("\r\n");
//     }
// }

// int main(void) {

//     int8_t  A[16][16];
//     int8_t  B[16][16];
//     int32_t C_acc[16][16];

//     /*
//      * Test matrix:
//      * A[i][j] = i + j + 1
//      * B[i][j] = i + j + 1
//      */
//     for (int i = 0; i < 16; i++) {
//         for (int j = 0; j < 16; j++) {
//             A[i][j] = (int8_t)(i + j + 1);
//             B[i][j] = (int8_t)(i + j + 1);
//             C_acc[i][j] = 0;
//         }
//     }

//     uint32_t t0 = get_cycle();

//     /*
//      * 16x16 GEMM using 4x4 accelerator.
//      *
//      * C[bi][bj] += A[bi][bk] x B[bk][bj]
//      *
//      * bi, bj, bk are tile indices.
//      * Each tile is 4x4.
//      */
//     for (int bi = 0; bi < 4; bi++) {
//         for (int bj = 0; bj < 4; bj++) {
//             for (int bk = 0; bk < 4; bk++) {

//                 /*
//                  * Pack A tile row-major.
//                  *
//                  * A word 0 = A row 0 of tile
//                  * A word 1 = A row 1 of tile
//                  * A word 2 = A row 2 of tile
//                  * A word 3 = A row 3 of tile
//                  */
//                 for (int r = 0; r < 4; r++) {
//                     uint32_t word = pack4_u8(
//                         A[bi*4 + r][bk*4 + 0],
//                         A[bi*4 + r][bk*4 + 1],
//                         A[bi*4 + r][bk*4 + 2],
//                         A[bi*4 + r][bk*4 + 3]
//                     );

//                     Xil_Out32(DMEM_EXT + A_BASE + 4*r, word);
//                 }

//                 /*
//                  * Pack B tile column-major.
//                  *
//                  * B word 0 = B column 0 of tile
//                  * B word 1 = B column 1 of tile
//                  * B word 2 = B column 2 of tile
//                  * B word 3 = B column 3 of tile
//                  */
//                 for (int c = 0; c < 4; c++) {
//                     uint32_t word = pack4_u8(
//                         B[bk*4 + 0][bj*4 + c],
//                         B[bk*4 + 1][bj*4 + c],
//                         B[bk*4 + 2][bj*4 + c],
//                         B[bk*4 + 3][bj*4 + c]
//                     );

//                     Xil_Out32(DMEM_EXT + B_BASE + 4*c, word);
//                 }

//                 run_accelerator();

//                 /*
//                  * Debug: print raw output for first tile multiply only.
//                  *
//                  * For bi=0,bj=0,bk=0, expected local 4x4 result is:
//                  *
//                  *  30   40   50   60
//                  *  40   54   68   82
//                  *  50   68   86  104
//                  *  60   82  104  126
//                  *
//                  * Expected raw HW order:
//                  *
//                  * idx 00 = 126
//                  * idx 01 = 104
//                  * idx 02 = 82
//                  * idx 03 = 60
//                  * idx 04 = 104
//                  * idx 05 = 86
//                  * idx 06 = 68
//                  * idx 07 = 50
//                  * idx 08 = 82
//                  * idx 09 = 68
//                  * idx 10 = 54
//                  * idx 11 = 40
//                  * idx 12 = 60
//                  * idx 13 = 50
//                  * idx 14 = 40
//                  * idx 15 = 30
//                  */
//                 if (bi == 0 && bj == 0 && bk == 0) {
//                     xil_printf("\r\nRaw first 4x4 partial tile output:\r\n");

//                     for (int idx = 0; idx < 16; idx++) {
//                         int32_t value =
//                             (int32_t)Xil_In32(DMEM_EXT + C_BASE + 4*idx);

//                         xil_printf("idx %02d = %d\r\n", idx, value);
//                     }
//                 }

//                 /*
//                  * Read and accumulate result.
//                  *
//                  * Your accelerator output order is:
//                  *
//                  * idx 0  -> local C[3][3]
//                  * idx 1  -> local C[2][3]
//                  * idx 2  -> local C[1][3]
//                  * idx 3  -> local C[0][3]
//                  *
//                  * idx 4  -> local C[3][2]
//                  * idx 5  -> local C[2][2]
//                  * idx 6  -> local C[1][2]
//                  * idx 7  -> local C[0][2]
//                  *
//                  * idx 8  -> local C[3][1]
//                  * idx 9  -> local C[2][1]
//                  * idx 10 -> local C[1][1]
//                  * idx 11 -> local C[0][1]
//                  *
//                  * idx 12 -> local C[3][0]
//                  * idx 13 -> local C[2][0]
//                  * idx 14 -> local C[1][0]
//                  * idx 15 -> local C[0][0]
//                  *
//                  * Therefore:
//                  * local_row = 3 - (idx % 4)
//                  * local_col = 3 - (idx / 4)
//                  */
//                 for (int idx = 0; idx < 16; idx++) {
//                     int local_row = 3 - (idx % 4);
//                     int local_col = 3 - (idx / 4);

//                     int32_t value =
//                         (int32_t)Xil_In32(DMEM_EXT + C_BASE + 4*idx);

//                     C_acc[bi*4 + local_row][bj*4 + local_col] += value;
//                 }
//             }
//         }
//     }

//     uint32_t hw_cycles = get_cycle() - t0;

//     xil_printf("\r\nFinal corner values:\r\n");
//     print_corners(C_acc);

//     xil_printf("\r\nHW 16x16 cycles: %u\r\n", hw_cycles);

//     print_matrix_16x16(C_acc);

//     return 0;
// }

// 16x16 matmul hardware accelerator test. Writes two 16x16 matrices to BRAM, starts accelerator, polls for done, and reads back result. Measures hardware cycles taken by accelerator.

// #include <stdint.h>
// #include "xil_io.h"
// #include "xparameters.h"
// #include "xil_printf.h"

// #define DMEM_EXT  XPAR_AXI_BRAM_0_BASEADDRESS
// #define CTRL_BASE XPAR_CTRL_REGS_FSM_0_BASEADDR

// #define A_BASE 0x00000000
// #define B_BASE 0x00000040
// #define C_BASE 0x00000100

// static inline uint32_t get_cycle(void) {
//     uint32_t c;
//     __asm__ volatile ("rdcycle %0" : "=r"(c));
//     return c;
// }

// static uint32_t pack4_u8(int8_t x0, int8_t x1, int8_t x2, int8_t x3) {
//     return ((uint32_t)((uint8_t)x0) << 24) |
//            ((uint32_t)((uint8_t)x1) << 16) |
//            ((uint32_t)((uint8_t)x2) <<  8) |
//            ((uint32_t)((uint8_t)x3) <<  0);
// }

// static void run_accelerator(void) {
//     Xil_Out32(CTRL_BASE + 0x00, A_BASE);
//     Xil_Out32(CTRL_BASE + 0x04, B_BASE);
//     Xil_Out32(CTRL_BASE + 0x08, C_BASE);

//     // Start accelerator
//     Xil_Out32(CTRL_BASE + 0x10, 0x1);

//     // done is sticky, so wait for old done to clear first
//     while (Xil_In32(CTRL_BASE + 0x1C) & 0x1);

//     // wait for new done
//     while (!(Xil_In32(CTRL_BASE + 0x1C) & 0x1));
// }

// static void print_corners(int32_t C[16][16]) {
//     xil_printf("C[0][0]   = %d\r\n", C[0][0]);
//     xil_printf("C[0][15]  = %d\r\n", C[0][15]);
//     xil_printf("C[15][0]  = %d\r\n", C[15][0]);
//     xil_printf("C[15][15] = %d\r\n", C[15][15]);
// }

// static void print_matrix_16x16(int32_t C[16][16]) {
//     xil_printf("\r\nFull 16x16 C matrix:\r\n");

//     for (int i = 0; i < 16; i++) {
//         for (int j = 0; j < 16; j++) {
//             xil_printf("%6d ", C[i][j]);
//         }
//         xil_printf("\r\n");
//     }
// }

// int main(void) {

//     int8_t  A[16][16];
//     int8_t  B[16][16];
//     int32_t C_acc[16][16];

//     /*
//      * Test matrix:
//      * A[i][j] = i + j + 1
//      * B[i][j] = i + j + 1
//      */
//     for (int i = 0; i < 16; i++) {
//         for (int j = 0; j < 16; j++) {
//             A[i][j] = (int8_t)(i + j + 1);
//             B[i][j] = (int8_t)(i + j + 1);
//             C_acc[i][j] = 0;
//         }
//     }

//     uint32_t t0 = get_cycle();

//     /*
//      * 16x16 GEMM using 4x4 accelerator tiles.
//      *
//      * C += A x B
//      *
//      * bi = A tile row
//      * bj = B tile column
//      * bk = reduction tile index
//      */
//     for (int bi = 0; bi < 4; bi++) {
//         for (int bj = 0; bj < 4; bj++) {
//             for (int bk = 0; bk < 4; bk++) {

//                 /*
//                  * Pack A tile row-major.
//                  *
//                  * A word 0 = A local row 0
//                  * A word 1 = A local row 1
//                  * A word 2 = A local row 2
//                  * A word 3 = A local row 3
//                  */
//                 for (int r = 0; r < 4; r++) {
//                     uint32_t word = pack4_u8(
//                         A[bi*4 + r][bk*4 + 0],
//                         A[bi*4 + r][bk*4 + 1],
//                         A[bi*4 + r][bk*4 + 2],
//                         A[bi*4 + r][bk*4 + 3]
//                     );

//                     Xil_Out32(DMEM_EXT + A_BASE + 4*r, word);
//                 }

//                 /*
//                  * Pack B tile column-major.
//                  *
//                  * B word 0 = B local column 0
//                  * B word 1 = B local column 1
//                  * B word 2 = B local column 2
//                  * B word 3 = B local column 3
//                  */
//                 for (int c = 0; c < 4; c++) {
//                     uint32_t word = pack4_u8(
//                         B[bk*4 + 0][bj*4 + c],
//                         B[bk*4 + 1][bj*4 + c],
//                         B[bk*4 + 2][bj*4 + c],
//                         B[bk*4 + 3][bj*4 + c]
//                     );

//                     Xil_Out32(DMEM_EXT + B_BASE + 4*c, word);
//                 }

//                 run_accelerator();

//                 /*
//                  * Hardware local output order:
//                  *
//                  * idx 0  -> local C[3][3]
//                  * idx 1  -> local C[2][3]
//                  * idx 2  -> local C[1][3]
//                  * idx 3  -> local C[0][3]
//                  *
//                  * idx 4  -> local C[3][2]
//                  * ...
//                  *
//                  * idx 15 -> local C[0][0]
//                  *
//                  * Therefore:
//                  * local_row = 3 - (idx % 4)
//                  * local_col = 3 - (idx / 4)
//                  *
//                  * IMPORTANT:
//                  * From the 16x16 debug result, tile placement is transposed.
//                  * So place the tile at [bj][bi], not [bi][bj].
//                  */
//                 for (int idx = 0; idx < 16; idx++) {
//                     int local_row = 3 - (idx % 4);
//                     int local_col = 3 - (idx / 4);

//                     int32_t value =
//                         (int32_t)Xil_In32(DMEM_EXT + C_BASE + 4*idx);

//                     C_acc[bj*4 + local_row][bi*4 + local_col] += value;
//                 }
//             }
//         }
//     }

//     uint32_t hw_cycles = get_cycle() - t0;

//     xil_printf("\r\nFinal corner values:\r\n");
//     print_corners(C_acc);

//     xil_printf("\r\nHW 16x16 cycles: %u\r\n", hw_cycles);

//     print_matrix_16x16(C_acc);

//     while (1);
//     return 0;
// }