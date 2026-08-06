//`timescale 1ns/1ps
////==============================================================================
//// RISC-V Verification Suite v5: ext_irq coverage (+ store misalign / nested trap)
//// Instruction Memory (Read-Only, Word-Addressed)
//// Byte Address = Array Index * 4
////
//// Same 3-phase structure as v4, with one change: mie now enables MSIE+MTIE+MEIE
//// (not just MSIE+MTIE), via a second CSRRS since MEIE's bit (11) can't be
//// represented as a positive ADDI immediate (would be sign-extended). This lets
//// the SAME program test either sw_irq or ext_irq -- whichever pin the
//// testbench actually pulses is what fires, since both are now enabled.
////==============================================================================

//module inst_memory(
//    input  logic [31:0] A,
//    output logic [31:0] RD
//);

//always_comb begin
//    case (A[11:2])

//    //===============================================================
//    // PHASE 1: Store misalignment
//    //===============================================================
//    0  : RD = 32'h10000093;   // addi  x1, x0, 0x100
//    1  : RD = 32'h30509073;   // csrrw x0, mtvec, x1
//    2  : RD = 32'h20000113;   // addi  x2, x0, 0x200
//    3  : RD = 32'h02a00193;   // addi  x3, x0, 42
//    4  : RD = 32'h003120a3;   // sw    x3, 1(x2)          ; misaligned -> trap, mcause=6

//    //===============================================================
//    // PHASE 2: Interrupt setup (gap #2 / ext_irq coverage)
//    //===============================================================
//    5  : RD = 32'h08800213;   // addi  x4, x0, 0x88       ; MSIE|MTIE
//    6  : RD = 32'h30421073;   // csrrw x0, mie, x4        ; mie = 0x88
//    7  : RD = 32'h80000213;   // addi  x4, x0, 0x800      ; sign-extends to 0xFFFFF800, bit11 (MEIE) set
//    8  : RD = 32'h30422073;   // csrrs x0, mie, x4        ; mie |= ...800 -> MEIE now also enabled
//    9  : RD = 32'h30046073;   // csrrsi x0, mstatus, 8    ; mstatus.MIE = 1
//    10 : RD = 32'h20000293;   // addi  x5, x0, 0x200
//    11 : RD = 32'h30529073;   // csrrw x0, mtvec, x5      ; mtvec = interrupt handler

//    // filler window -- ext_irq (or sw_irq) should pulse somewhere in here
//    12 : RD = 32'h01100313;   // addi x6,  x0, 0x11
//    13 : RD = 32'h02200393;   // addi x7,  x0, 0x22
//    14 : RD = 32'h03300413;   // addi x8,  x0, 0x33
//    15 : RD = 32'h04400493;   // addi x9,  x0, 0x44
//    16 : RD = 32'h05500513;   // addi x10, x0, 0x55
//    17 : RD = 32'h06600593;   // addi x11, x0, 0x66
//    18 : RD = 32'h07700613;   // addi x12, x0, 0x77
//    19 : RD = 32'h09800693;   // addi x13, x0, 0x98
//    20 : RD = 32'h09900713;   // addi x14, x0, 0x99
//    21 : RD = 32'h0aa00793;   // addi x15, x0, 0xAA

//    22 : RD = 32'h0bb00813;   // addi x16, x0, 0xBB       ; post-interrupt marker

//    //===============================================================
//    // PHASE 3: Nested trap (unchanged from v4)
//    //===============================================================
//    23 : RD = 32'h30000893;   // addi  x17, x0, 0x300
//    24 : RD = 32'h30589073;   // csrrw x0, mtvec, x17
//    25 : RD = 32'h00000073;   // ecall

//    197: RD = 32'h0dd00913;   // addi x18, x0, 0xDD       ; survived-nesting marker
//    198: RD = 32'h0000006f;   // jal x0, 0

//    //===============================================================
//    // Phase 1 handler @ 0x100 (word 64)
//    //===============================================================
//    64 : RD = 32'h34202a73;   // csrrs x20, mcause, x0
//    65 : RD = 32'h34102af3;   // csrrs x21, mepc, x0
//    66 : RD = 32'h004a8a93;   // addi  x21, x21, 4
//    67 : RD = 32'h341a9073;   // csrrw x0, mepc, x21
//    68 : RD = 32'h30200073;   // mret

//    //===============================================================
//    // Phase 2 interrupt-only handler @ 0x200 (word 128)
//    //===============================================================
//    128: RD = 32'h34202b73;   // csrrs x22, mcause, x0    ; expect 0x8000000B for ext_irq
//    129: RD = 32'h34102bf3;   // csrrs x23, mepc, x0
//    130: RD = 32'h0cc00993;   // addi  x19, x0, 0xCC
//    131: RD = 32'h30200073;   // mret

//    //===============================================================
//    // Phase 3 OUTER handler @ 0x300 (word 192)
//    //===============================================================
//    192: RD = 32'h34202c73;   // csrrs x24, mcause, x0
//    193: RD = 32'h34102cf3;   // csrrs x25, mepc, x0
//    194: RD = 32'h40000593;   // addi  x11, x0, 0x400
//    195: RD = 32'h30559073;   // csrrw x0, mtvec, x11
//    196: RD = 32'hf1101073;   // csrrw x0, mvendorid, x0  ; deliberate inner fault

//    //===============================================================
//    // Phase 3 INNER handler @ 0x400 (word 256)
//    //===============================================================
//    256: RD = 32'h34202d73;   // csrrs x26, mcause, x0
//    257: RD = 32'h34102df3;   // csrrs x27, mepc, x0
//    258: RD = 32'h004d8d93;   // addi  x27, x27, 4
//    259: RD = 32'h341d9073;   // csrrw x0, mepc, x27
//    260: RD = 32'h30200073;   // mret

//    default:
//        RD = 32'h00000013;    // nop

//    endcase
//end

//endmodule
`timescale 1ns/1ps
//==============================================================================
// RISC-V Verification Suite v7: CLINT (MSIP + MTIP) test
// Instruction Memory (Read-Only, Word-Addressed)
// Byte Address = Array Index * 4
//
// Tests the CLINT integration: software interrupt via msip register write,
// and timer interrupt via mtimecmp register write. First instruction is an
// isolated LUI sanity check (needed because CLINT's registers -- especially
// mtime at CLINT_BASE+0xBFF8 -- live at addresses too large for a plain ADDI
// immediate; this is the first use of LUI in this test suite).
//
// The handler is deliberately branch-free: it unconditionally clears BOTH
// possible interrupt sources every time it runs (msip=0, mtimecmp=all-1s),
// which is safe and idempotent regardless of which one actually fired, and
// avoids needing branch instructions (still unvalidated) to distinguish
// MSIP from MTIP via mcause.
//
// MTIP is triggered by writing mtimecmp=0 (guaranteed <= mtime, which is
// already nonzero by the time this runs), rather than computing a future
// target and waiting -- simpler and fully deterministic.
//==============================================================================

module inst_memory(
    input  logic [31:0] A,
    output logic [31:0] RD
);

always_comb begin
    case (A[11:2])

    //===============================================================
    // Setup
    //===============================================================
    0  : RD = 32'h000010b7;   // lui   x1, 0x1            ; SANITY CHECK: x1 should = 0x1000
    1  : RD = 32'h10000113;   // addi  x2, x0, 0x100
    2  : RD = 32'h30511073;   // csrrw x0, mtvec, x2
    3  : RD = 32'h08800193;   // addi  x3, x0, 0x88       ; MSIE|MTIE
    4  : RD = 32'h30419073;   // csrrw x0, mie, x3
    5  : RD = 32'h30046073;   // csrrsi x0, mstatus, 8    ; mstatus.MIE = 1

    //===============================================================
    // MSIP test (CLINT software interrupt)
    //===============================================================
    6  : RD = 32'h00002237;   // lui   x4, 0x2            ; x4 = 0x2000 (CLINT_BASE / msip addr)
    7  : RD = 32'h00100293;   // addi  x5, x0, 1
    8  : RD = 32'h00522023;   // sw    x5, 0(x4)          ; msip = 1 -> triggers MSIP (mcause=0x80000003)
    9  : RD = 32'h0aa00413;   // addi  x8, x0, 0xAA       ; post-MSIP marker

    //===============================================================
    // MTIP test (CLINT timer interrupt)
    //===============================================================
    10 : RD = 32'h00006337;   // lui   x6, 0x6            ; x6 = 0x6000 (mtimecmp_lo addr)
    11 : RD = 32'h00032023;   // sw    x0, 0(x6)          ; mtimecmp_lo = 0
    12 : RD = 32'h00430393;   // addi  x7, x6, 4          ; x7 = 0x6004 (mtimecmp_hi addr)
    13 : RD = 32'h0003a023;   // sw    x0, 0(x7)          ; mtimecmp_hi = 0 -> triggers MTIP (mcause=0x80000007)
    14 : RD = 32'h0bb00493;   // addi  x9, x0, 0xBB       ; post-MTIP marker

    15 : RD = 32'h0000006f;   // jal x0, 0                ; terminal spin loop

    //===============================================================
    // Handler @ 0x100 (word 64) -- branch-free, clears both sources always
    //===============================================================
    64 : RD = 32'h34202a73;   // csrrs x20, mcause, x0
    65 : RD = 32'h34102af3;   // csrrs x21, mepc, x0
    66 : RD = 32'h00002b37;   // lui   x22, 0x2           ; x22 = 0x2000 (msip addr)
    67 : RD = 32'h000b2023;   // sw    x0, 0(x22)         ; msip = 0 (clear -- harmless if already 0)
    68 : RD = 32'h00006bb7;   // lui   x23, 0x6           ; x23 = 0x6000 (mtimecmp_lo addr)
    69 : RD = 32'hfff00c13;   // addi  x24, x0, -1        ; x24 = 0xFFFFFFFF
    70 : RD = 32'h018ba023;   // sw    x24, 0(x23)        ; mtimecmp_lo = 0xFFFFFFFF (disable future MTIP)
    71 : RD = 32'h004b8c93;   // addi  x25, x23, 4        ; x25 = 0x6004 (mtimecmp_hi addr)
    72 : RD = 32'h018ca023;   // sw    x24, 0(x25)        ; mtimecmp_hi = 0xFFFFFFFF
    73 : RD = 32'h30200073;   // mret                     ; mepc unchanged -> retries preempted instr

    default:
        RD = 32'h00000013;    // nop

    endcase
end

endmodule
