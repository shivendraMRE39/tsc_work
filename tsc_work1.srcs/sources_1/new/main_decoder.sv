`timescale 1ns / 1ps

module main_decoder(
    input  logic [6:0]  op,
    input  logic [2:0]  funct3,
    input  logic [31:0] InstrD,

    output logic [1:0] ResultSrc,
    output logic MemWrite,
    output logic ALUSrc,
    output logic [2:0] ImmSrc,
    output logic RegWrite,
    output logic jump,
    output logic Branch,
    output logic [1:0] ALUOp,
    output logic MemRead,

    // CSR
    output logic csr_en,
    output logic [1:0] csr_op,
    output logic csr_imm,

    output logic mret,
    output logic illegal_instr,
    output logic ecall,
    output logic ebreak
);

always_comb begin

    //-------------------------------------------------------
    // Default values
    //-------------------------------------------------------
    RegWrite      = 1'b0;
    MemWrite      = 1'b0;
    MemRead       = 1'b0;
    ALUSrc        = 1'b0;
    ResultSrc     = 2'b00;
    Branch        = 1'b0;
    jump          = 1'b0;
    ALUOp         = 2'b00;
    ImmSrc        = 3'b000;

    csr_en        = 1'b0;
    csr_op        = 2'b00;
    csr_imm       = 1'b0;

    mret          = 1'b0;
    illegal_instr = 1'b0;
    ecall         = 1'b0;
    ebreak        = 1'b0;

    //-------------------------------------------------------
    // Opcode Decode
    //-------------------------------------------------------

    case(op)

    //-------------------------------------------------------
    // R-Type
    //-------------------------------------------------------
    7'b0110011: begin
        RegWrite = 1'b1;
        ALUSrc   = 1'b0;
        ALUOp    = 2'b10;
    end

    //-------------------------------------------------------
    // I-Type ALU
    //-------------------------------------------------------
    7'b0010011: begin
        RegWrite = 1'b1;
        ALUSrc   = 1'b1;
        ALUOp    = 2'b10;
    end

    //-------------------------------------------------------
    // LOAD
    //-------------------------------------------------------
    7'b0000011: begin
        RegWrite = 1'b1;
        ALUSrc   = 1'b1;
        ResultSrc= 2'b01;
        ALUOp    = 2'b00;
        MemRead  = 1'b1;
    end

    //-------------------------------------------------------
    // STORE
    //-------------------------------------------------------
    7'b0100011: begin
        MemWrite = 1'b1;
        ALUSrc   = 1'b1;
        ImmSrc   = 3'b001;
        ALUOp    = 2'b00;
        RegWrite = 1'b0;
    end

    //-------------------------------------------------------
    // BRANCH
    //-------------------------------------------------------
    7'b1100011: begin
        Branch   = 1'b1;
        ALUOp    = 2'b01;
        ImmSrc   = 3'b010;
    end

    //-------------------------------------------------------
    // JAL
    //-------------------------------------------------------
    7'b1101111: begin
        RegWrite = 1'b1;
        ResultSrc= 2'b10;
        jump     = 1'b1;
        ImmSrc   = 3'b011;
    end

    //-------------------------------------------------------
    // JALR
    //-------------------------------------------------------
    7'b1100111: begin
        RegWrite = 1'b1;
        ALUSrc   = 1'b1;
        ResultSrc= 2'b10;
        jump     = 1'b1;
    end

    //-------------------------------------------------------
    // LUI
    //-------------------------------------------------------
    7'b0110111: begin
        RegWrite = 1'b1;
        ALUSrc   = 1'b1;
        ResultSrc= 2'b00;
        ALUOp    = 2'b11;
        ImmSrc   = 3'b100;
    end

    //-------------------------------------------------------
    // AUIPC
    //-------------------------------------------------------
    7'b0010111: begin
        RegWrite = 1'b1;
        ALUSrc   = 1'b1;
        ResultSrc= 2'b00;
        ALUOp    = 2'b11;
        ImmSrc   = 3'b100;
    end

    //-------------------------------------------------------
    // SYSTEM / CSR
    //-------------------------------------------------------
    7'b1110011: begin

        case(funct3)

        //-----------------------------------------------
        // ECALL / EBREAK / MRET
        //-----------------------------------------------
        3'b000: begin
            case(InstrD)

                32'h30200073:
                    mret = 1'b1;

                32'h00000073:
                    ecall = 1'b1;

                32'h00100073:
                    ebreak = 1'b1;

                default:
                    illegal_instr = 1'b1;

            endcase
        end

        //-----------------------------------------------
        // CSRRW
        //-----------------------------------------------
        3'b001: begin
            RegWrite = 1'b1;
            csr_en   = 1'b1;
            csr_op   = 2'b00;
            csr_imm  = 1'b0;
            ResultSrc= 2'b11;
        end

        //-----------------------------------------------
        // CSRRS
        //-----------------------------------------------
        3'b010: begin
            RegWrite = 1'b1;
            csr_en   = 1'b1;
            csr_op   = 2'b01;
            csr_imm  = 1'b0;
            ResultSrc= 2'b11;
        end

        //-----------------------------------------------
        // CSRRC
        //-----------------------------------------------
        3'b011: begin
            RegWrite = 1'b1;
            csr_en   = 1'b1;
            csr_op   = 2'b10;
            csr_imm  = 1'b0;
            ResultSrc= 2'b11;
        end

        //-----------------------------------------------
        // CSRRWI
        //-----------------------------------------------
        3'b101: begin
            RegWrite = 1'b1;
            csr_en   = 1'b1;
            csr_op   = 2'b00;
            csr_imm  = 1'b1;
            ResultSrc= 2'b11;
        end

        //-----------------------------------------------
        // CSRRSI
        //-----------------------------------------------
        3'b110: begin
            RegWrite = 1'b1;
            csr_en   = 1'b1;
            csr_op   = 2'b01;
            csr_imm  = 1'b1;
            ResultSrc= 2'b11;
        end

        //-----------------------------------------------
        // CSRRCI
        //-----------------------------------------------
        3'b111: begin
            RegWrite = 1'b1;
            csr_en   = 1'b1;
            csr_op   = 2'b10;
            csr_imm  = 1'b1;
            ResultSrc= 2'b11;
        end

        //-----------------------------------------------
        // Illegal funct3
        //-----------------------------------------------
        default: begin
            illegal_instr = 1'b1;
        end

        endcase
    end

    //-------------------------------------------------------
    // Illegal Opcode
    //-------------------------------------------------------
    default: begin
        illegal_instr = 1'b1;
    end

    endcase

end

endmodule