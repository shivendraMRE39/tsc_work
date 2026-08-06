`timescale 1ns / 1ps


module IF_stage (
input logic StallF,StallD,
input logic clk, rst, PCSrcE,
input logic [31:0] PCTargetE,
input logic FlushD,
output logic  [31:0] InstrD,
output logic [31:0] PCD,
output logic [31:0] PCPlus4D,
//new add for making instruction memory out to the pipeline core 
input  logic [31:0] instr_rdata,
output logic [31:0] instr_addr
  );
   
    logic [31:0] PCF_f, PCF, rd, PCPlus4F;
    
    
    assign instr_addr = PCF;
    assign rd = instr_rdata;

    // instantiating pc_mux
    mux_2_input pcmux (
    .A(PCPlus4F),
    .B(PCTargetE),
    .sel(PCSrcE),
    .C(PCF_f));
    
    // instantiating floppr_pc
    floppr_pc flip_flop_pc (
    .clk(clk),
    .rst(rst),
    .PCF_i(PCF_f),
    .PCF(PCF),
    .StallF(StallF));
    
//    //instantiating instruction memory 
//    instruction_memory instruction_memory(
//    .A(PCF),
//    .rd(rd));
    
    //instantiating pc_adder
    pc_adder pc_adder(
    .PCF(PCF),
    .PCPlus4F(PCPlus4F));
    
    always_ff@(posedge clk)
    begin
//    InstrD <= 32'h00000013;
    if(rst || FlushD) begin 
    InstrD <= 32'h00000013; // NOP (ADDI x0,x0,0)
    PCD <= 0;
    PCPlus4D <= 0;
    end 
    
    else if(!StallD)
    begin 
    InstrD <= rd;
    PCD <= PCF;
    PCPlus4D <= PCPlus4F;
    end 
    // else = hold the value
    end 
    
endmodule
