`timescale 1ns / 1ps

module IF(
    input  logic        clk,
    input  logic        rst,

    // Hazard & Pipeline Control Signals
    input  logic        StallF,       // Stalls Fetch Stage (Program Counter)
    input  logic        StallD,       // Stalls Decode Stage (IF/ID Pipeline Register)
    input  logic        FlushD,       // Flushes Decode Stage (Inserts NOP bubble)

    // Branch/Jump Control
    input  logic        PcSrcE,
    input  logic [31:0] PcTargetE,

    // Exception & Trap Control
    input  logic [31:0] mtvec_i,
    input  logic        mret_i,
    input  logic [31:0] mepc_i,
    input  logic        trap_taken_i,

    // Pipeline Outputs to Decode Stage
    output logic [31:0] InstrD,
    output logic [31:0] PcD,
    output logic [31:0] PcPlus4D
);

    logic [31:0] PCF;
    logic [31:0] InstrF;
    logic [31:0] PcPlus4F;

    logic [31:0] PC_BranchNext;
    logic [31:0] PC_Next;
    
    /*
     * OLD CODE:
     * logic pc_stall_gate;
     * assign pc_stall_gate = StallF && !trap_taken_i && !mret_i;
     * MUX_2_1 branch_mux(...);
     * MUX_2_1 trap_mux(...);
     * MUX_2_1 mret_mux(...);
     *
     * NEW CODE:
     * Simplified target assignments + explicit pc_stall_gate.
     *
     * WHY:
     * Replacing explicit MUX_2_1 instantiations with ternary operators (`? :`) keeps the module 
     * clean, easy to read, and allows the synthesizer to optimize the multiplexer tree. 
     * `pc_stall_gate` ensures PC updating is NOT stalled when jumping to `mtvec` or `mepc`.
     */
    logic pc_stall_gate;
    assign pc_stall_gate = StallF && !trap_taken_i && !mret_i;

    //////////////////////////////////////////////////////
    // Next Program Counter Selection Tree
    //////////////////////////////////////////////////////
    // Priority: Trap Vector > MRET Return Target > Branch/Jump Target > PC + 4
    assign PC_BranchNext = PcSrcE        ? PcTargetE : PcPlus4F;
    assign PC_Next       = trap_taken_i  ? mtvec_i   : 
                           mret_i        ? mepc_i    : 
                                           PC_BranchNext;

    //////////////////////////////////////////////////////
    // Program Counter Module
    //////////////////////////////////////////////////////
    Pc_Module Pc(
        .clk    (clk),
        .rst    (rst),
        .Pc_next(PC_Next),
        .Pc     (PCF),
        .StallF (pc_stall_gate) 
    );

    //////////////////////////////////////////////////////
    // Instruction Memory & PC Increment Adder
    //////////////////////////////////////////////////////
    inst_memory inst_mem(
        .A (PCF),
        .RD(InstrF)
    );

    Pc_adder pc_adder(
        .PcF  (PCF),
        .PcF_4(PcPlus4F)
    );

    //////////////////////////////////////////////////////
    // IF/ID Pipeline Register
    //////////////////////////////////////////////////////
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            InstrD   <= 32'h00000013; // Reset to NOP (addi x0, x0, 0)
            PcD      <= 32'd0;
            PcPlus4D <= 32'd0;
        end
        else if (FlushD) begin
            InstrD   <= 32'h00000013; // Inject NOP bubble on branches/traps
            PcD      <= 32'd0;
            PcPlus4D <= 32'd0;
        end
        else if (!StallD) begin
            InstrD   <= InstrF;
            PcD      <= PCF;
            PcPlus4D <= PcPlus4F;
        end
    end

endmodule