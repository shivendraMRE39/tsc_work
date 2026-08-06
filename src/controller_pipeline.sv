`timescale 1ns / 1ps




module controller_pipeline(
input logic [6:0] Opcode,
input logic [6:0] funct7,
input logic [2:0] funct3,
output logic MemWrite, ALUSrc, RegWrite, Jump, Branch,
output logic JalrType,              // NEW
output logic [3:0] ALUcontrol, 
output logic [2:0] ImmSrc,
output logic [1:0] ResultSrc,
output logic [2:0] LoadType,
output logic [2:0] StoreType,
output logic [2:0] BranchType
    );
    
    
    logic [1:0] ALUop;
    
    //instantiating main decoder
    main_decoder main_decoder_inst(
    .Opcode(Opcode),
    .funct3(funct3),
    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .ALUSrc(ALUSrc),
    .ImmSrc(ImmSrc),
    .ResultSrc(ResultSrc),
    .Jump(Jump),
    .JalrType(JalrType),            // NEW
    .ALUop(ALUop),
    .Branch(Branch),
    .LoadType(LoadType),
    .StoreType(StoreType),
    .BranchType(BranchType));
    
    //instantiating ALUDecoder
    alu_decoder alu_decoder_inst(
    .funct3(funct3),
    .funct7(funct7),
    .Opcode(Opcode),
    .ALUcontrol(ALUcontrol),
    .ALUop(ALUop));
    
    
    
endmodule
