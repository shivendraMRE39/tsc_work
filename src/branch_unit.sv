
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: branch_unit
// Description: Fully combinational branch decision unit for the RISC-V Pipeline.
//////////////////////////////////////////////////////////////////////////////////

module branch_unit (
    input  logic [31:0] SrcAE,         // Operand A (from Hazard MUX A)
    input  logic [31:0] SrcBE,         // Operand B (from Hazard MUX B / Imm MUX)
    input  logic        BranchE,       // Branch Control signal from control unit
    input  logic [2:0]  funct3E,       // Funct3 field identifying branch types
    output logic        BranchTaken    // Asserted if branch condition evaluates true
);

    // Explicit signed and unsigned representation of input operands
    logic signed [31:0] sA;
    logic signed [31:0] sB;
    
    assign sA = SrcAE;
    assign sB = SrcBE;

    always_comb begin
        BranchTaken = 1'b0;
        if (BranchE) begin
            case (funct3E)
                3'b000:  BranchTaken = (SrcAE == SrcBE);       // BEQ (Equal)
                3'b001:  BranchTaken = (SrcAE != SrcBE);       // BNE (Not Equal)
                3'b100:  BranchTaken = (sA < sB);             // BLT (Less Than, Signed)
                3'b101:  BranchTaken = (sA >= sB);            // BGE (Greater Than or Equal, Signed)
                3'b110:  BranchTaken = (SrcAE < SrcBE);        // BLTU (Less Than, Unsigned)
                3'b111:  BranchTaken = (SrcAE >= SrcBE);       // BGEU (Greater Than or Equal, Unsigned)
                default: BranchTaken = 1'b0;
            endcase
        end
    end

endmodule