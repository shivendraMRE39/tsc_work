`timescale 1ns / 1ps

module top_module_pipeline(
input clk, rst,

// instruction interface
output logic [31:0] instr_addr,
input  logic [31:0] instr_rdata,

// data interface
output logic [31:0] data_addr,
output logic [31:0] data_wdata,
input  logic [31:0] data_rdata,
output logic        data_we,
output logic [3:0] data_be
    );
    
    logic PCSrcE;
    logic [31:0] PCTargetE;
    logic [31:0] InstrD;
    logic [31:0] PCD;
    logic [31:0] PCPlus4D;
    
// logic [31:0] WD3;
// logic [4:0] RdD;
 logic RegWriteW;
 
 logic RegWriteE;
 logic [1:0] ResultSrcE;
 logic MemWriteE;
 logic JumpE;
 logic BranchE;
 logic [3:0] ALUcontrolE;
 logic ALUSrcE;
 logic [31:0] RD1E;
 logic [31:0] RD2E;
 logic [31:0] PCE;
 logic [4:0] RdE;
 logic [31:0] ImmExtE;
 logic [31:0] PCPlus4E;
    
logic RegWriteM;
logic [1:0] ResultSrcM;
logic MemWriteM;
logic [31:0] ALUResultM;
logic [31:0] WriteDataM;
logic [4:0] RdM;
logic [31:0] PCPlus4M;

logic [1:0] ResultSrcW;
logic [31:0] ReadDataW;
logic [31:0] ALUResultW;
logic [4:0] RdW;       
logic [31:0] PCPlus4W;  
    
logic [31:0] ResultW;
logic [4:0] RdW_out;
logic RegWriteW_out;
logic [1:0] ForwardBE;
logic [1:0] ForwardAE;
//logic [4:0] Rs1E_out;
//logic [4:0] Rs2E_out;
logic [4:0] Rs1E;
logic [4:0] Rs2E;
//logic enbF; 
//logic enbD;
logic StallF;
logic StallD;
logic [4:0] Rs1D;
logic [4:0] Rs2D;
//logic [4:0] RdE_H;
//logic [1:0] ResultSrcE_H;
logic FlushE;
logic FlushD;
logic [2:0] LoadTypeM;
logic [2:0] LoadTypeE;
logic [2:0] StoreTypeE;
logic [2:0] StoreTypeM;
logic [2:0] BranchTypeE;
logic [31:0] PCTargetM;
logic [31:0] PCTargetW;

//logic [4:0] Rs1DH;
//logic [4:0] Rs2DH;
logic JalrE;   // NEW

    
    
    // hazard unit
    hazard_unit hazard_unit(
//    .Rs1E(Rs1E_out),
//    .Rs2E(Rs2E_out),
    .Rs1E(Rs1E),      // CHANGED: was Rs1E_out
    .Rs2E(Rs2E),      // CHANGED: was Rs2E_out
    .RdM(RdM),
    .RdW(RdW_out),
    .RegWriteM(RegWriteM),
    .RegWriteW(RegWriteW_out),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .StallF(StallF),
    .StallD(StallD),
    .Rs1DH(Rs1D),
    .Rs2DH(Rs2D),
    .RdE(RdE),
    .ResultSrcE(ResultSrcE),
    .FlushE(FlushE),
    .PCSrcE(PCSrcE),
    .FlushD(FlushD));
    
    //IF stage
    IF_stage fetch(
    .clk(clk),
    .rst(rst),
    .PCSrcE(PCSrcE),
    .PCTargetE(PCTargetE),
    .InstrD(InstrD),
    .PCD(PCD),
    .PCPlus4D(PCPlus4D),
    .StallD(StallD),
    .StallF(StallF),
    .FlushD(FlushD),
    .instr_addr(instr_addr),
    .instr_rdata(instr_rdata) 
    );
//    logic enbD;
//    logic enbF;
//    assign enbD = StallD;
//    assign enbF = StallF;
    
    //Decode Stage
    decode_stage decode(
    .clk(clk),
    .rst(rst),
    .RegWriteW_out(RegWriteW_out),
    .ResultW(ResultW),
//    .RdW(RdW),
    .InstrD(InstrD),
    .PCD(PCD),
    .PCPlus4D(PCPlus4D),
    
    .ResultSrcE(ResultSrcE),
    .MemWriteE(MemWriteE),
    .JumpE(JumpE),
    .JalrE(JalrE),      // NEW
    .BranchE(BranchE),
    .ALUcontrolE(ALUcontrolE),
    .ALUSrcE(ALUSrcE),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .RdE(RdE),
    .ImmExtE(ImmExtE),
    .PCPlus4E(PCPlus4E),
    .RdW_out(RdW_out),
    .RegWriteE(RegWriteE),
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
    .Rs1DH(Rs1D),
    .Rs2DH(Rs2D),
    .FlushE(FlushE),
    .LoadTypeE(LoadTypeE),
    .StoreTypeE(StoreTypeE),
    .BranchTypeE(BranchTypeE)
);

       //Execute stage
       execute_stage execute (
    .clk(clk),
    .rst(rst),
    .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE),
    .MemWriteE(MemWriteE),
    .JumpE(JumpE),
    .JalrE(JalrE),      // NEW
    .BranchE(BranchE),
    .ALUcontrolE(ALUcontrolE),
    .ALUSrcE(ALUSrcE),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .RdE(RdE),
    .ImmExtE(ImmExtE),
    .PCPlus4E(PCPlus4E),
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .MemWriteM(MemWriteM),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .RdM(RdM),
    .PCPlus4M(PCPlus4M),
    .PCSrcE(PCSrcE),
    .PCTargetE(PCTargetE),
    .ResultW(ResultW),
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
//    .Rs2E_out(Rs2E_out),
//    .Rs1E_out(Rs1E_out),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
//    .RdE_H(RdE_H),
//    .ResultSrcE_H(ResultSrcE_H),
    .LoadTypeE(LoadTypeE),
    .LoadTypeM(LoadTypeM),
    .StoreTypeE(StoreTypeE),
    .StoreTypeM(StoreTypeM),
    .BranchTypeE(BranchTypeE),
    .PCTargetM(PCTargetM)     // NEW
   
);

      //Memory stage
       mem_stage memory(
    .clk(clk),
    .rst(rst),
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .MemWriteM(MemWriteM),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .RdM(RdM),
    .PCPlus4M(PCPlus4M),
    .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW),
    .ReadDataW(ReadDataW),
    .ALUResultW(ALUResultW),
    .RdW(RdW),
    .PCPlus4W(PCPlus4W),
    .LoadTypeM(LoadTypeM),
    .StoreTypeM(StoreTypeM),
    .data_addr(data_addr),
    .data_wdata(data_wdata),
    .data_rdata(data_rdata),
    .data_we(data_we),
    .data_be(data_be),
    .PCTargetM(PCTargetM),     // NEW (input to mem_stage)
    .PCTargetW(PCTargetW)    // NEW (output from mem_stage)
 
);

     //Writeback stage
     mux_for_Writeback writeback(
     .clk(clk),
     .rst(rst),
    .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW),
    .ALUResultW(ALUResultW),
    .ReadDataW(ReadDataW),
    .PCPlus4W(PCPlus4W),
    .ResultW(ResultW),
    .RdW_out(RdW_out),
    .RegWriteW_out(RegWriteW_out),
    .RdW(RdW),
    .PCTargetW(PCTargetW)   // NEW 
);
    
endmodule
