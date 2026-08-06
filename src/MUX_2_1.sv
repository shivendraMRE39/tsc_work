`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.05.2026 17:16:40
// Design Name: 
// Module Name: MUX_2_1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module MUX_2_1(
input logic [31:0] a,b,
  input logic sel,
  output logic [31:0] c
    );
    assign c = (sel)?b:a;
endmodule
