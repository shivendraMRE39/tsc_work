`timescale 1ns / 1ps



module floppr_pc(
input StallF,
input logic clk, rst,
input logic [31:0] PCF_i,
output logic [31:0] PCF
    );
    
    always_ff@(posedge clk)
    begin 
    if(rst)
    PCF <= 0;
//    else if (enb)
//    PCF <= 0;
    
    else if(!StallF) 
    PCF <= PCF_i;
    end 
    // else → stall (hold value)
endmodule
