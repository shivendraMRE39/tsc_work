`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/23/2026 03:01:24 AM
// Design Name: 
// Module Name: mux_3_1
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


module mux_3_1#(
parameter WIDTH = 32)
(input logic [WIDTH-1 : 0] A,
input logic [WIDTH-1 : 0] B,
input logic [WIDTH-1 : 0] C,
input logic [1:0] sel,
output logic [WIDTH-1 : 0] Y
);

assign Y = (sel == 2'b00) ? A : 
           (sel == 2'b01) ? B :
           (sel == 2'b10) ? C : A;
endmodule
