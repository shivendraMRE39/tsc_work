`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 



module hazard_unit(
input logic [4:0] Rs1E ,
input logic [4:0] Rs2E,
input logic [4:0] RdM,
input logic [4:0] RdW,
input logic RegWriteM,
input logic RegWriteW,
input logic [4:0] Rs1DH,
input logic [4:0] Rs2DH,
input logic [4:0] RdE,
input logic [1:0] ResultSrcE,
input logic  PCSrcE,
output logic [1:0] ForwardAE,
output logic [1:0] ForwardBE,
output logic StallF,
output logic StallD,
output logic FlushE,
output logic FlushD

    );
    
    logic lwStall;
    
    always_comb
    begin 
    ForwardAE = 2'b00;
    if((Rs1E == RdM) && RegWriteM && (Rs1E != 0)) 
    //forward from memory stage 
       ForwardAE = 2'b10;
      else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 0))
       // Forward from Writeback stage
       ForwardAE = 2'b01;
       else 
       ForwardAE = 2'b00;
       // No forwarding (use RF output)
       end 
       
       always_comb
       begin 
       ForwardBE = 2'b00;
        if((Rs2E == RdM) && RegWriteM && (Rs2E != 0))
        // Forward from Memory stage 
          ForwardBE = 2'b10;
          else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 0))
       // Forward from Writeback stage 
           ForwardBE = 2'b01;
           else 
             ForwardBE = 2'b00;
       // No forwarding (use RF output)    
          end
       
//       always_comb 
//       begin 
//       lwStall = (ResultSrcE) && (RdE != 5'b0) && ((Rs1DH == RdE) || (Rs2DH == RdE));
//       StallF = lwStall ; 
//       StallD = lwStall ;
////       FlushE = lwStall ;
       
       always_comb begin
    lwStall = (ResultSrcE == 2'b01) && (RdE != 5'b0) &&
              ((Rs1DH == RdE) || (Rs2DH == RdE));
    StallF = lwStall;
    StallD = lwStall;
end
       
       
       always_comb 
       begin 
       FlushD = PCSrcE;
       FlushE = lwStall | PCSrcE ; // | PCSrcE;
end 
endmodule
