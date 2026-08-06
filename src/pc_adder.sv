`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.05.2026 17:17:57
// Design Name: 
// Module Name: Pc_adder
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


module Pc_adder(
input logic [31:0] PcF,
 output logic [31:0] PcF_4
    );
    assign PcF_4 = (PcF + 32'h00000004);
endmodule
