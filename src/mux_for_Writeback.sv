//`timescale 1ns / 1ps


//module mux_for_Writeback(
//input logic clk,rst,
//input logic RegWriteW,
//input logic [4:0] RdW,
//input logic [1:0] ResultSrcW,
//input logic [31:0] ALUResultW,
//input logic [31:0] ReadDataW,
//input logic [31:0] PCPlus4W,
//output logic [31:0] ResultW,
//output logic RegWriteW_out,
//output logic [4:0] RdW_out,
//input logic [31:0] PCTargetW,        // NEW
// );
  
//  mux_3_1 mux4_1 (
//   .A(ALUResultW),
//   .B(ReadDataW),
//   .C(PCPlus4W),
//   .sel(ResultSrcW),
//   .Y(ResultW));
   

//assign RdW_out = (rst) ? 5'b0 : RdW;
//assign RegWriteW_out = (rst) ? 1'b0 : RegWriteW;

//endmodule

`timescale 1ns / 1ps

module mux_for_Writeback(
input logic clk,rst,
input logic RegWriteW,
input logic [4:0] RdW,
input logic [1:0] ResultSrcW,
input logic [31:0] ALUResultW,
input logic [31:0] ReadDataW,
input logic [31:0] PCPlus4W,
input logic [31:0] PCTargetW,     // NEW: AUIPC result (PC + imm_U)
output logic [31:0] ResultW,
output logic RegWriteW_out,
output logic [4:0] RdW_out
 );

  always_comb begin
    case(ResultSrcW)
      2'b00  : ResultW = ALUResultW;   // R-type / I-type / LUI
      2'b01  : ResultW = ReadDataW;    // loads
      2'b10  : ResultW = PCPlus4W;     // JAL / JALR link
      2'b11  : ResultW = PCTargetW;    // AUIPC (PC + imm_U)
      default: ResultW = ALUResultW;
    endcase
  end

assign RdW_out = (rst) ? 5'b0 : RdW;
assign RegWriteW_out = (rst) ? 1'b0 : RegWriteW;

endmodule
