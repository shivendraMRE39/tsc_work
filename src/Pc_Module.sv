`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.05.2026 15:58:29
// Design Name: 
// Module Name: Pc_Module
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


module Pc_Module(
input logic clk,rst,
input logic StallF,
input logic [31:0] Pc_next,
output logic [31:0] Pc
    );
    always_ff @(posedge clk or negedge rst)
    if(!rst)
    Pc <= 32'h00000000;
    else if (!StallF)
    Pc <= Pc_next;
       else Pc <= Pc;
endmodule
