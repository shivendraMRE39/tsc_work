`timescale 1ns / 1ps


module mux_2_input(
input logic [31:0] A,
input logic [31:0] B,
input logic sel,
output logic [31:0] C
    );
    
   assign C = ((!sel) ? A : B);
   
endmodule
