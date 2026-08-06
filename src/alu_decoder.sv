`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ALU_Decoder
// ALUOp encoding (from Main Decoder):
//   00 : load/store  -> ADD
//   01 : branch      -> SUB (supports BEQ/BNE via zeroE only)
//   10 : R-type/I-type ALU -> decode via funct3/funct7
//////////////////////////////////////////////////////////////////////////////////
module ALU_Decoder(
    input  logic [6:0] op,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    input  logic [1:0] ALUOp,
    output logic [3:0] ALUControl
);

    always_comb begin
        case (ALUOp)
            2'b00 : ALUControl = 4'b0000; // load/store: ADD
            2'b01 : ALUControl = 4'b0001; // branch: SUB
            2'b10 : begin
                case (funct3)
                    3'b000: begin
                        if (op == 7'b0110011 && funct7[5])
                            ALUControl = 4'b0001; // SUB (R-type only)
                        else
                            ALUControl = 4'b0000; // ADD / ADDI
                    end
                    3'b111: ALUControl = 4'b0010; // AND
                    3'b110: ALUControl = 4'b0011; // OR
                    3'b100: ALUControl = 4'b0100; // XOR
                    3'b001: ALUControl = 4'b0101; // SLL
                    3'b010: ALUControl = 4'b1000; // SLT (signed)
                    3'b101: begin                  // FIXED: 3'B101 -> 3'b101
                        if (funct7[5])
                            ALUControl = 4'b0111; // SRA
                        else
                            ALUControl = 4'b0110; // SRL
                    end
                    3'b011: ALUControl = 4'b1001; // SLTU (unsigned)
                    default: ALUControl = 4'b0000;
                endcase
            end
            default: ALUControl = 4'b0000;
        endcase
    end

endmodule