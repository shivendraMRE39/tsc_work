`timescale 1ns / 1ps

module decode_stage( 
input logic clk,rst,

input logic [31:0] InstrD,
input logic [31:0] PCPlus4D,
input logic [31:0] ResultW,
input logic  RegWriteW_out,
input logic [31:0] PCD,
input logic [4:0] RdW_out,
input logic FlushE,
output logic RegWriteE,
output logic [1:0] ResultSrcE,
output logic MemWriteE,
output logic JumpE,
output logic BranchE,
output logic JalrE,                 // NEW
output logic [3:0] ALUcontrolE,
output logic ALUSrcE,
output logic [31:0] RD1E,
output logic [31:0] RD2E,
output logic [31:0] PCE,
output logic [4:0] RdE,
output logic [31:0] ImmExtE,
output logic [31:0] PCPlus4E,
output logic [4:0] Rs1E,
output logic [4:0] Rs2E,
output logic [4:0] Rs1DH,
output logic [4:0] Rs2DH,
output logic [2:0] LoadTypeE,
output logic [2:0] StoreTypeE,
output logic [2:0] BranchTypeE
    );
   
   logic RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD, JalrD;
  
   logic [1:0] ResultSrcD;
   logic [2:0] ImmSrcD;
   logic [3:0] ALUcontrolD;
   logic [31:0] RD1, RD2;
   logic [31:0] ImmExtD;
//   logic [31:0] WD3;
   logic [4:0] RdD;
   logic [4:0] Rs1D;
   logic [4:0] Rs2D;
   logic [2:0] LoadType;
   logic [2:0] StoreType;
   logic [2:0] BranchType;
   

   
   
   // instantiating the controller 
   controller_pipeline controller(
   .Opcode(InstrD[6:0]),
   .funct7(InstrD[31:25]),
   .funct3(InstrD[14:12]),
   .RegWrite(RegWriteD),
   .ResultSrc(ResultSrcD),
   .MemWrite(MemWriteD),
   .Jump(JumpD),
   .JalrType(JalrD),         
   .Branch(BranchD),
   .ALUcontrol(ALUcontrolD),
   .ALUSrc(ALUSrcD),
   .ImmSrc(ImmSrcD),
   .LoadType(LoadType),
   .StoreType(StoreType),
   .BranchType(BranchType));
   
   // instantiating the register_file
   register_file register_file_inst(
   .clk(clk),
   .rst(rst),
   .WE3(RegWriteW_out),
   .A1(InstrD[19:15]),
   .A2(InstrD[24:20]),
   .WD3(ResultW),
   .RD1(RD1),
   .A3(RdW_out),
   .RD2(RD2));
   
   //instantiating the sign extended unit
   sign_extended sign_extension_inst (
   .InstrD(InstrD[31:7]),
   .ImmSrcD(ImmSrcD),
   .ImmExtD(ImmExtD));
   
   always_comb 
   begin
   Rs2DH = Rs2D;
   Rs1DH = Rs1D;
   end
  
 
 
 // decode stage flopper   
  always_ff@(posedge clk)
   begin 
   if(rst || FlushE ) begin   
        RegWriteE  <= 0;
        ResultSrcE <= 0;
        MemWriteE  <= 0;
        JumpE      <= 0;
        BranchE    <= 0;
        ALUcontrolE <= 0;
        ALUSrcE    <= 0;
        RD1E       <= 0;
        RD2E       <= 0;
        PCE        <= 0;
        RdE        <= 0;
        ImmExtE    <= 0;
        PCPlus4E   <= 0;
        Rs1E       <= 0;
        Rs2E       <= 0;
        LoadTypeE  <= 3'b010;
        StoreTypeE <= 3'b010;
        BranchTypeE <= 3'b000;
        JalrE    <= 0;
       
    end
     //handle invalid instruction 
    
    else if (^InstrD === 1'bX) begin
    // treat as NOP
    RegWriteE  <= 0;
    MemWriteE  <= 0;
    BranchE    <= 0;
    JumpE      <= 0;
    JalrE      <= 0;
end
    
    else
     begin 
   RegWriteE  <= RegWriteD;
   ResultSrcE <= ResultSrcD;
   MemWriteE  <= MemWriteD;
   JumpE      <= JumpD;
   BranchE    <= BranchD;
   ALUcontrolE <= ALUcontrolD;
   ALUSrcE    <= ALUSrcD;
   RD1E       <= RD1;
   RD2E       <= RD2;
   PCE        <= PCD;
   RdE        <= RdD;
   ImmExtE    <= ImmExtD; 
   PCPlus4E   <= PCPlus4D;
   Rs1E       <= Rs1D;
   Rs2E       <= Rs2D;
   LoadTypeE <= LoadType; 
   StoreTypeE <= StoreType;
   BranchTypeE <= BranchType;
   JalrE <= JalrD;             // NEW
   end
  
   
   end 
 
   
   assign RdD = InstrD[11:7];
   assign Rs1D = InstrD[19:15];
   assign Rs2D = InstrD[24:20];
   
endmodule
