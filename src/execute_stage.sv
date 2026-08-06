`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
module execute_stage(
input logic clk, rst,
input logic RegWriteE,
input logic [1:0] ResultSrcE,
input logic MemWriteE,
input logic JumpE,
input logic JalrE,
input logic BranchE,
input logic [3:0] ALUcontrolE,
input logic ALUSrcE,
input logic [31:0] RD1E,
input logic [31:0] RD2E,
input logic [31:0] PCE,
input logic [4:0] RdE,
input logic [31:0] ImmExtE,
input logic [31:0] PCPlus4E,
input logic [1:0] ForwardAE, 
input logic [1:0] ForwardBE,
input logic [4:0] Rs1E,
input logic [4:0] Rs2E,
input  logic [31:0] ResultW,
input logic [2:0] LoadTypeE,
input logic [2:0] StoreTypeE,
input logic [2:0] BranchTypeE,

output logic RegWriteM,
output logic [1:0] ResultSrcM,
output logic MemWriteM, 
output logic [31:0] ALUResultM,
output logic [31:0] WriteDataM,
output logic [4:0] RdM,
output logic [31:0] PCPlus4M,
output logic PCSrcE,
output logic [31:0] PCTargetE,
//output logic [4:0] Rs1E_out,
//output logic [4:0] Rs2E_out,
//output logic [4:0] RdE_H,
//output logic [1:0]  ResultSrcE_H,
output logic [2:0] LoadTypeM,
output logic [2:0] StoreTypeM,
output logic [31:0] PCTargetM
);
    
    
    logic [31:0] ALUout;
//    logic ZeroE;
    logic [31:0] SrcBE;
    
//    logic Isq;
    logic [31:0] WriteDataE;
    logic [31:0] SrcAE;

    logic take_branch;
    logic [31:0] adderA, PCTargetE_raw;  // NEW



branch_unit branch_unit_inst(

    .BranchE(BranchE),
    .BranchTypeE(BranchTypeE),

    .Rs1Data(SrcAE),
    .Rs2Data(WriteDataE),

    .TakeBranch(take_branch)

    );

assign PCSrcE = (BranchE & take_branch) || JumpE;



//always_comb begin
//ResultSrcE_H = 0;
//RdE_H = 0; 

//ResultSrcE_H = ResultSrcE;
//RdE_H = RdE;
//end 


//assign Rs1E_out = (rst) ? 5'b0 : Rs1E;
//assign Rs2E_out = (rst) ? 5'b0 : Rs2E;

// mux_forwardAE 
mux_3_1 muxforwardAE(
.A(RD1E),
.B(ResultW),
.C(ALUResultM),
.sel(ForwardAE),
.Y(SrcAE));

// mux_forwardBE
mux_3_1 muxforwardBE(
.A(RD2E),
.B(ResultW),
.C(ALUResultM),
.sel(ForwardBE),
.Y(WriteDataE));


    //2*1 mux instantiatioin 
    mux_2_input mux(
    .A(WriteDataE),
    .B(ImmExtE),
    .sel(ALUSrcE),
    .C(SrcBE));
    
   //ALU Instantiation 
   ALU alu(
//   .ZeroE(ZeroE),
   .SrcAE(SrcAE),
   .SrcBE(SrcBE),
   .ALUcontrol(ALUcontrolE),
   .ALUout(ALUout));
   
   
    assign adderA = JalrE ? SrcAE : PCE;   
      
   // adder instantiati8on 
   adder adder(
   .A(adderA),          
   .B(ImmExtE),
   .Sum(PCTargetE_raw)
   );  
   

    // NEW: per spec, JALR must clear bit 0 of the computed target
    assign PCTargetE = {PCTargetE_raw[31:1], 1'b0};
   
    
   always_ff@(posedge clk)
   begin 
   if(rst) 
   begin 
   {RegWriteM , ResultSrcM, MemWriteM} <= 0;
   { ALUResultM, WriteDataM, RdM, PCPlus4M} <= 0;
   LoadTypeM  <= 3'b010;
   StoreTypeM <= 3'b010;
   PCTargetM <= 0;   // NEW
   end 
   
//   // synthesis translate_off
//  else if (^InstrD === 1'bX) begin
//      RegWriteE <= 0; 
//      MemWriteE <= 0;
////      BranchE <= 0; 
//      JumpE <= 0;
//  end
  // synthesis translate_on
  
   else begin 
   RegWriteM  <= RegWriteE;
   ResultSrcM <= ResultSrcE;
   MemWriteM  <= MemWriteE;
   ALUResultM <= ALUout;
   WriteDataM <= WriteDataE;
   RdM        <= RdE;
   PCPlus4M   <= PCPlus4E;
   LoadTypeM  <= LoadTypeE;
   StoreTypeM <= StoreTypeE;
   PCTargetM  <= PCTargetE;   // NEW
   end 
   end
   
  
   
   
   
endmodule