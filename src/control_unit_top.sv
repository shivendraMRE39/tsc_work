//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Module Name: control_unit_top
//// Description: Top-level Control Unit for 5-stage RISC-V RV32I Processor.
////              Instantiates ALU Decoder and Main Decoder (including CSR/System
////              and CSR Immediate instructions CSRRWI, CSRRSI, CSRRCI support).
////////////////////////////////////////////////////////////////////////////////////

//module control_unit_top(
//    // Instruction Decode Inputs
//    input  logic [6:0]  op,
//    input  logic [2:0]  funct3,
//    input  logic [6:0]  funct7,
//    input  logic [31:0] InstrD,

//    // Register File & Memory Control
//    output logic        RegWriteD,
//    output logic [1:0]  ResultSrcD,
//    output logic        MemWriteD,
//    output logic        MemReadD,

//    // Jump & Branch Control
//    output logic        jumpD,
//    output logic        BranchD,

//    // Execution / ALU Control
//    output logic [3:0]  ALUControlD,
//    output logic        ALUSrcD,
//    output logic [2:0]  ImmSrcD,

//    // CSR System & Exception Signals
//    output logic        csr_enD,
//    output logic [1:0]  csr_opD,
//    output logic        mretD,
//    output logic        illegal_instr,
//    output logic        ecall,
//    output logic        ebreak
//);

//    // Internal interconnect for ALUOp code between Main Decoder & ALU Decoder
//    logic [1:0] ALUOpConnec;

//    //////////////////////////////////////////////////////
//    // Main Control Decoder Instantiation
//    //////////////////////////////////////////////////////
//    main_decoder decoder (
//        .op            (op),
//        .funct3        (funct3),
//        .InstrD        (InstrD),
//        .ResultSrc     (ResultSrcD),
//        .MemWrite      (MemWriteD),
//        .MemRead       (MemReadD),
//        .ALUSrc        (ALUSrcD),
//        .ImmSrc        (ImmSrcD),
//        .RegWrite      (RegWriteD),
//        .jump          (jumpD),
//        .Branch        (BranchD),
//        .ALUOp         (ALUOpConnec),
//        .csr_en        (csr_enD),
//        .csr_op        (csr_opD),
//        .mret          (mretD),
//        .illegal_instr (illegal_instr),
//        .ecall         (ecall),
//        .ebreak        (ebreak)
//    );

//    //////////////////////////////////////////////////////
//    // ALU Control Decoder Instantiation
//    //////////////////////////////////////////////////////
//    ALU_Decoder alu (
//        .op         (op),
//        .funct3     (funct3),
//        .funct7     (funct7),
//        .ALUOp      (ALUOpConnec),
//        .ALUControl (ALUControlD)
//    );

//endmodule

`timescale 1ns / 1ps

module control_unit_top(

input  logic [6:0] op,
input  logic [2:0] funct3,
input  logic [6:0] funct7,

output logic RegWriteD,
output logic [1:0] ResultSrcD,
output logic MemWriteD,
output logic MemReadD,
output logic jumpD,
output logic BranchD,
output logic [3:0] ALUControlD,
output logic ALUSrcD,
output logic [2:0] ImmSrcD,

// CSR
output logic        csr_enD,
output logic [1:0]  csr_opD,
output logic        csr_immD,      // <-- NEW

output logic mretD,
output logic illegal_instr,
output logic ecall,
output logic ebreak,

input logic [31:0] InstrD

);

logic [1:0] ALUOpConnec;

//////////////////////////////////////////////////////////
// ALU Decoder
//////////////////////////////////////////////////////////

ALU_Decoder alu (

    .op(op),
    .funct3(funct3),
    .funct7(funct7),

    .ALUOp(ALUOpConnec),
    .ALUControl(ALUControlD)

);

//////////////////////////////////////////////////////////
// Main Decoder
//////////////////////////////////////////////////////////

main_decoder decoder (

    .op(op),

    .ResultSrc(ResultSrcD),
    .MemWrite(MemWriteD),
    .ALUSrc(ALUSrcD),
    .ImmSrc(ImmSrcD),
    .RegWrite(RegWriteD),
    .jump(jumpD),
    .Branch(BranchD),

    .ALUOp(ALUOpConnec),

    .MemRead(MemReadD),

    .funct3(funct3),

    // CSR
    .csr_en(csr_enD),
    .csr_op(csr_opD),
    .csr_imm(csr_immD),      // <-- NEW

    .mret(mretD),
    .illegal_instr(illegal_instr),
    .ecall(ecall),
    .ebreak(ebreak),

    .InstrD(InstrD)

);

endmodule