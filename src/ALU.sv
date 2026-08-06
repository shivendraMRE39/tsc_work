`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////



module ALU #(
parameter WIDTH = 32)(
input logic signed [WIDTH-1 : 0] SrcAE,
input logic signed [WIDTH-1 : 0] SrcBE,
input logic [3:0] ALUcontrol,
output logic [WIDTH-1 : 0] ALUout
//output logic  ZeroE
    );
    
 always_comb 
    begin 
    ALUout = 32'b0;
    case(ALUcontrol)
   
    4'b0000 : ALUout = (SrcAE) + (SrcBE);    //add
    4'b0001 : ALUout = SrcAE - SrcBE ;  //substract 
    4'b0010 : ALUout = SrcAE & SrcBE ;      // and
    4'b0011 : ALUout = SrcAE | SrcBE ;       // or
    4'b0100 : ALUout = (SrcAE >>> SrcBE[4:0]);     //  sra 
    4'b0101 : ALUout = {{WIDTH-1{1'b0}}, ((SrcAE) < (SrcBE))} ;   // slt 
    4'b0110 : ALUout = (SrcAE >> SrcBE[4:0]);   //srl
    4'b0111 : ALUout = SrcAE ^ SrcBE ;     //xor
    4'b1000 : ALUout = SrcAE << SrcBE[4:0] ;  //sll 
    4'b1001 : ALUout = {{WIDTH-1{1'b0}}, ($unsigned(SrcAE) < $unsigned(SrcBE))};    // sltu 
    default : ALUout = 32'h0;
    endcase
   
//    ZeroE = (!ALUout) ? 1'b1 : 1'b0;
    
    end
    
  
endmodule
