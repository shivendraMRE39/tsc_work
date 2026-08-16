`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// RV32I ALU
// ALUControlE encoding:
// 0000 : ADD
// 0001 : SUB
// 0010 : AND
// 0011 : OR
// 0100 : XOR
// 0101 : SLL
// 0110 : SRL
// 0111 : SRA
// 1000 : SLT   (signed compare)
// 1001 : SLTU  (unsigned compare)
//////////////////////////////////////////////////////////////////////////////////
module ALU(
    input  logic [31:0] SrcAE,
    input  logic [31:0] SrcBE,
    input  logic [3:0]  ALUControlE,
    output logic [31:0] ALUResult,
    output logic        zeroE
);

    always_comb begin
        case(ALUControlE)
            4'b0000 : ALUResult = SrcAE + SrcBE;                                   // ADD
            4'b0001 : ALUResult = SrcAE - SrcBE;                                   // SUB
            4'b0010 : ALUResult = SrcAE & SrcBE;                                   // AND
            4'b0011 : ALUResult = SrcAE | SrcBE;                                   // OR
            4'b0100 : ALUResult = SrcAE ^ SrcBE;                                   // XOR
            4'b0101 : ALUResult = SrcAE << SrcBE[4:0];                             // SLL
            4'b0110 : ALUResult = SrcAE >> SrcBE[4:0];                             // SRL (logical)
            4'b0111 : ALUResult = $signed(SrcAE) >>> SrcBE[4:0];                   // SRA (arithmetic)
            4'b1000 : ALUResult = ($signed(SrcAE) < $signed(SrcBE)) ? 32'd1 : 32'd0; // SLT  (FIXED: signed)
            4'b1001 : ALUResult = (SrcAE < SrcBE) ? 32'd1 : 32'd0;                    // SLTU (FIXED: unsigned)
            default : ALUResult = 32'h00000000;
        endcase

        zeroE = (ALUResult == 32'd0);
    end

endmodule