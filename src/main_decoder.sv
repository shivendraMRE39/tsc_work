`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////


module main_decoder(
input logic [6:0] Opcode,
input logic [2:0] funct3,
output logic RegWrite, 
output logic ALUSrc, 
output logic MemWrite,
output logic Branch,
output logic Jump,
output logic JalrType,              // NEW
output logic [2:0] ImmSrc, 
output logic [1:0]ResultSrc,
output logic [1:0] ALUop,
output logic [2:0] LoadType,
output logic [2:0] StoreType,
output logic [2:0] BranchType
    );
    


always_comb begin
    //  DEFAULT SAFE VALUES
    RegWrite = 0;
    ALUSrc   = 0;
    MemWrite = 0;
    Branch   = 0;
    Jump     = 0;
    ImmSrc   = 3'b000;
    ResultSrc= 2'b00;
    ALUop    = 2'b00;
    LoadType = 3'b010;    // default LW
    StoreType = 3'b010;   //default Sw
    BranchType = 3'b000;  //default beq
    JalrType = 0;                       // NEW default
case (Opcode)

    7'b0110011: begin // R-type
        RegWrite = 1;
        ALUop    = 2'b10;
    end

    7'b0010011: begin // I-type
        RegWrite = 1;
        ALUSrc   = 1;
        ALUop    = 2'b10;
        ImmSrc   = 3'b000;
    end

    7'b0000011: begin // load
        RegWrite = 1;
        ALUSrc   = 1;
        ResultSrc= 2'b01;
        ImmSrc   = 3'b000;

        case(funct3)
            3'b000 : LoadType = 3'b000;  // LB
            3'b001 : LoadType = 3'b001;  // LH
            3'b010 : LoadType = 3'b010;  // LW
            3'b100 : LoadType = 3'b011;  // LBU
            3'b101 : LoadType = 3'b100;  // LHU
            default: LoadType = 3'b010;
        endcase
    end

    7'b0100011: begin // store
        ALUSrc   = 1;
        MemWrite = 1;
        ImmSrc   = 3'b001;

        case(funct3)
            3'b000 : StoreType = 3'b000; // SB
            3'b001 : StoreType = 3'b001; // SH
            3'b010 : StoreType = 3'b010; // SW
            default: StoreType = 3'b010;
        endcase
    end

    7'b1100011: begin // branch
        Branch = 1;
        ALUop  = 2'b01;
        ImmSrc = 3'b010;

        case(funct3)
            3'b000 : BranchType = 3'b000; // BEQ
            3'b001 : BranchType = 3'b001; // BNE
            3'b100 : BranchType = 3'b010; // BLT
            3'b101 : BranchType = 3'b011; // BGE
            3'b110 : BranchType = 3'b100; // BLTU
            3'b111 : BranchType = 3'b101; // BGEU
            default: BranchType = 3'b000;
        endcase
    end

    7'b1101111: begin // JAL
        RegWrite = 1;
        Jump     = 1;
        ResultSrc= 2'b10;
        ImmSrc   = 3'b011;
    end
    
    7'b1100111: begin // JALR
    RegWrite  = 1;
    Jump      = 1;
    ALUSrc    = 1;
    ResultSrc = 2'b10;   // PC+4 link, same as JAL
    JalrType  = 1;      // NEW: target = rs1 + imm, not PC + imm
    ImmSrc    = 3'b000;  // I-type immediate
end

    7'b0110111: begin // LUI
        RegWrite = 1;
        ALUSrc   = 1;
        ImmSrc   = 3'b100;
        ALUop    = 2'b00;
    end

7'b0010111: begin // AUIPC
    RegWrite = 1;
    ALUSrc   = 1;        // don't-care functionally, kept consistent w/ LUI
    ImmSrc   = 3'b100;   // same U-type immediate as LUI
    ALUop    = 2'b00;    // don't-care, ALU result unused for this instr
    ResultSrc= 2'b11;    // NEW: select PC-target adder output for writeback
end

endcase 
end    
endmodule
