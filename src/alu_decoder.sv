`timescale 1ns / 1ps


module alu_decoder(
input logic [2:0] funct3,
input logic [6:0] funct7,
input logic [6:0] Opcode,
input logic [1:0] ALUop,
output logic [3:0] ALUcontrol 
 );

always_comb
begin 

if(ALUop == 2'b00)  
begin 
ALUcontrol = 4'b0000; // add
end 

else if(ALUop == 2'b01)
begin 
ALUcontrol = 4'b0001; //substract 
end 


 else if(ALUop == 2'b10)
 begin 
 case(funct3)
 
 3'b000 : begin 
   if({Opcode[5], funct7[5]} == 2'b11)         
   ALUcontrol = 4'b0001; //substract        
    else 
    ALUcontrol = 4'b0000; //add
    end 
    
    3'b100 : ALUcontrol = 4'b0111;   // xor 
    3'b001 : ALUcontrol = 4'b1000;  // shift logical left 
    3'b010 : ALUcontrol = 4'b0101;   // slt  
    3'b101 : ALUcontrol = (funct7[5]) ? 4'b0100 : 4'b0110 ; // Sra/Srai or Srl/srli 
    3'b110 : ALUcontrol = 4'b0011;  //or 
    3'b111 : ALUcontrol = 4'b0010 ; //and
    3'b011 : ALUcontrol = 4'b1001; // sltu
           
             
             default : ALUcontrol = 4'b0111;
             
             endcase    
  end 
  
  else 
  begin 
  ALUcontrol = 4'b0111;
  end 
  
end 
 
    
 
 
 
endmodule
