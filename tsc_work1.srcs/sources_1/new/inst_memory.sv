`timescale 1ns/1ps
// =============================================================================
// inst_memory (Read-Only, Word-Addressed, Combinational Read)
//
// REWRITTEN this revision: was a hardcoded `case (A[11:2])` statement with
// test programs baked directly into the RTL (each new test = editing and
// re-elaborating this file). Now loads from a plain hex text file via
// $readmemh at time 0 -- same pattern already used by axi4lite_sram.sv /
// axi4lite_rom.sv elsewhere in this project. Edit instruction_memory.hex,
// re-run simulation -- no RTL changes needed for a new test program.
//
// Read is still purely COMBINATIONAL (assign, not always_ff) -- this is
// required: IF.sv's IF/ID pipeline register latches InstrF on the very
// same clock edge PCF is valid, so inst_memory must return RD with zero
// added latency relative to A, exactly like the original case-statement
// version did.
//
// DEPTH default 4096 words (16KB) -- matches the sizing convention already
// used by axi4lite_sram.sv/axi4lite_rom.sv elsewhere in this project (the
// original case-statement version only implicitly supported 1024 words,
// A[11:2] -- 4096 gives headroom for larger test programs without needing
// another RTL edit later).
//
// The v7 CLINT test program that was hardcoded here previously has been
// preserved byte-for-byte as the DEFAULT instruction_memory.hex content
// (see that file) -- swapping to file-based loading doesn't lose it,
// it's just editable now instead of compiled-in.
// =============================================================================
module inst_memory #(
    parameter int   DEPTH   = 4096,
    parameter       HEXFILE = "instruction_memory.hex"
)(
    input  logic [31:0] A,
    output logic [31:0] RD
);

    localparam int IDX_BITS = $clog2(DEPTH);   // 12 for DEPTH=4096
    localparam int ADDR_LSB = 2;

    logic [31:0] mem [0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = 32'h00000013;  // NOP fill
        $readmemh(HEXFILE, mem);
    end

    assign RD = mem[A[ADDR_LSB +: IDX_BITS]];

endmodule