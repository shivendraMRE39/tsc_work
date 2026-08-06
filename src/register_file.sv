`timescale 1ns / 1ps



module register_file(
input logic clk, rst,
input logic WE3,
input logic [4:0] A1,
input logic [4:0] A2,
input logic [4:0] A3,
input logic [31:0] WD3,
output logic [31:0] RD1,
output logic [31:0] RD2 
 );
 
 // register memory
 logic signed [31:0] reg_mem [0:31];

 integer i;
 
  
  //zero register is hard wire register 
  
//  assign  RD1 = (A1 == 5'd0 ? 32'b0 : reg_mem[A1]);
//  assign  RD2 = (A2 == 5'd0 ? 32'b0 : reg_mem[A2]);
assign RD1 = (A1 == 5'd0) ? 32'b0 :
             (WE3 && (A3 == A1)) ? WD3 : reg_mem[A1];

assign RD2 = (A2 == 5'd0) ? 32'b0 :
             (WE3 && (A3 == A2)) ? WD3 : reg_mem[A2];
 

always_ff @(posedge clk)
begin
    if (rst)
    begin
        integer i;
        for(i=0;i<32;i=i+1)
            reg_mem[i] <= 32'b0;
    end
    else if(WE3 && (A3 != 5'd0))
        reg_mem[A3] <= WD3;
end
                                                 
endmodule
