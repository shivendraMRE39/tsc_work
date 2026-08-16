`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Execute_stage
// Description: Pipeline execution stage containing forwarding logic, ALU, 
//              branch unit, and the EX/MEM pipeline registers. Fully updated
//              with an internal bypass for AUIPC (routes PCE to ALU SrcAE).
//////////////////////////////////////////////////////////////////////////////////

module Execute_stage(
    input logic clk,
    input logic rst,

    input logic RegWriteE,
    input logic [1:0] ResultSrcE,
    input logic MemWriteE,
    input logic jumpE,
    input logic BranchE,
    input logic [3:0] ALUControlE,
    input logic ALUSrcE,
    input logic mretE,
    output logic mretM,
    
    input logic [31:0] RD1E,
    input logic [31:0] RD2E,
    input logic [31:0] PCE,

    input logic [4:0] RdE,
    input logic [4:0] RS1E,
    input logic [4:0] RS2E,

    input logic [31:0] ImmExtendE,
    input logic [31:0] PcPlus4E,

    input logic [31:0] ResultW,
    input logic [1:0] ForwardAE,
    input logic [1:0] ForwardBE,
    input logic [31:0] ResultM_forward,
    
    input logic FlushM, 
    input logic StallM,            

    input logic [2:0] funct3E,
    
    input logic        csr_enE,
    input logic [1:0]  csr_opE,
    input logic [11:0] csr_addrE,

    output logic RegWriteM,
    output logic [1:0] ResultSrcM,
    output logic MemWriteM,
    output logic [31:0] ALUResultM,
    output logic [31:0] WriteDataM,
    output logic [4:0] RdM,
    output logic [31:0] PcPlus4M,
    output logic [2:0] funct3M,

    output logic [31:0] PcTargetE,
    output logic PcSrcE,

    input logic MemReadE,
    output logic MemReadM,
    
    output logic        csr_enM,
    output logic [1:0]  csr_opM,
    output logic [11:0] csr_addrM,
    input  logic [31:0] csr_rdataE,
    output logic [31:0] csr_rdataM,

    input logic illegal_instrE,
    input logic ecallE,
    input logic ebreakE,
    output logic illegal_instrM,
    output logic ecallM,
    output logic ebreakM,
    
    output logic [31:0] PCM,
    input  logic [31:0] InstrE,  // Required for internal opcode checking
    
    input logic        csr_immE,
    input logic [4:0]  zimmE,
    output logic [31:0] csr_operand
);

    //////////////////////////////////////////////////////
    // Internal Signals
    //////////////////////////////////////////////////////
    logic [31:0] PcPlusImm;
    logic [31:0] ForwardedSrcAE;
    logic [31:0] SrcAE;
    logic [31:0] SrcBE;
    logic [31:0] ForwardBData;
    logic [31:0] ALUOut;
    logic BranchTaken;
    logic zeroE;
//logic [31:0] csr_operand;



assign csr_operand =
        csr_immE ?
        {27'd0, zimmE} :
        SrcAE;
    //////////////////////////////////////////////////////
    // Forwarding MUX A & B
    //////////////////////////////////////////////////////
    mux_3_1 mux_hazard_1 (
        .a(RD1E),
        .b(ResultW),
        .c(ResultM_forward),
        .s(ForwardAE),
        .muxout(ForwardedSrcAE)
    );

    mux_3_1 mux_hazard_3 (
        .a(RD2E),
        .b(ResultW),
        .c(ResultM_forward),
        .s(ForwardBE),
        .muxout(ForwardBData)
    );

    //////////////////////////////////////////////////////
    // AUIPC Architectural Bypass Logic
    //////////////////////////////////////////////////////
    // If instruction is AUIPC (opcode 7'b0010111), bypass register data and route PCE!
    assign SrcAE = (InstrE[6:0] == 7'b0010111) ? PCE : ForwardedSrcAE;

    //////////////////////////////////////////////////////
    // ALU Source MUX
    //////////////////////////////////////////////////////
    MUX_2_1 alu_src_mux (
        .a(ForwardBData),
        .b(ImmExtendE),
        .sel(ALUSrcE),
        .c(SrcBE)
    );

    //////////////////////////////////////////////////////
    // ALU
    //////////////////////////////////////////////////////
    ALU alu (
        .SrcAE(SrcAE),
        .SrcBE(SrcBE),
        .ALUControlE(ALUControlE),
        .ALUResult(ALUOut),
        .zeroE(zeroE)
    );

    //////////////////////////////////////////////////////
    // Branch Decision Unit
    //////////////////////////////////////////////////////
    branch_unit branch_dec_inst (
        .SrcAE(SrcAE),
        .SrcBE(ForwardBData), 
        .BranchE(BranchE),
        .funct3E(funct3E),
        .BranchTaken(BranchTaken)
    );

    //////////////////////////////////////////////////////
    // PC Target Adder
    //////////////////////////////////////////////////////
    Adder pc_adder (
        .PCE(PCE),
        .ImmExtendE(ImmExtendE),
        .PcTargetE(PcPlusImm)
    );

    assign PcTargetE = (jumpE && ALUSrcE)
                       ? (ALUOut & 32'hFFFFFFFE)
                       : PcPlusImm;

    assign PcSrcE = BranchTaken | jumpE;

    //////////////////////////////////////////////////////
    // Pipeline Register (EX/MEM Register Stage)
    //////////////////////////////////////////////////////
    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            RegWriteM       <= 1'b0;
            ResultSrcM      <= 2'b00;
            MemWriteM       <= 1'b0;
            MemReadM        <= 1'b0;
            ALUResultM      <= 32'd0;
            WriteDataM      <= 32'd0;
            RdM             <= 5'd0;
            PcPlus4M        <= 32'd0;
            funct3M         <= 3'd0;
            csr_enM         <= 1'b0;
            csr_opM         <= 2'b00;
            csr_addrM       <= 12'd0;
            csr_rdataM      <= 32'd0;
            mretM           <= 1'b0;
            illegal_instrM  <= 1'b0;
            ecallM          <= 1'b0;
            ebreakM         <= 1'b0;
            PCM             <= 32'b0;
        end
        else if(FlushM) begin
            RegWriteM       <= 1'b0;
            ResultSrcM      <= 2'b00;
            MemWriteM       <= 1'b0;
            MemReadM        <= 1'b0;
            ALUResultM      <= 32'd0;
            WriteDataM      <= 32'd0;
            RdM             <= 5'd0;
            PcPlus4M        <= 32'd0;
            funct3M         <= 3'd0;
            csr_enM         <= 1'b0;
            csr_opM         <= 2'b00;
            csr_addrM       <= 12'd0; 
            csr_rdataM      <= 32'd0;
            mretM           <= 1'b0;
            illegal_instrM  <= 1'b0;
            ecallM          <= 1'b0;
            ebreakM         <= 1'b0;
            PCM             <= 32'b0;
        end
        else if(StallM) begin
            RegWriteM       <= RegWriteM;
            ResultSrcM      <= ResultSrcM;
            MemWriteM       <= MemWriteM;
            MemReadM        <= MemReadM;
            ALUResultM      <= ALUResultM;
            WriteDataM      <= WriteDataM;
            RdM             <= RdM;
            PcPlus4M        <= PcPlus4M;
            funct3M         <= funct3M;
            csr_enM         <= csr_enM;
            csr_opM         <= csr_opM;
            csr_addrM       <= csr_addrM;
            csr_rdataM      <= csr_rdataM;
            mretM           <= mretM;
            illegal_instrM  <= illegal_instrM;
            ecallM          <= ecallM;
            ebreakM         <= ebreakM;
            PCM             <= PCM;
        end
        else begin
            RegWriteM       <= RegWriteE;
            ResultSrcM      <= ResultSrcE;
            MemWriteM       <= MemWriteE;
            MemReadM        <= MemReadE;
            ALUResultM      <= ALUOut;
            WriteDataM      <= ForwardBData;  
            RdM             <= RdE;
            PcPlus4M        <= PcPlus4E;
            funct3M         <= funct3E;
            csr_enM         <= csr_enE;
            csr_opM         <= csr_opE;
            csr_addrM       <= csr_addrE;
            csr_rdataM      <= csr_rdataE; // Latch CSR read result so it stays aligned with RdM/ResultSrcM
            mretM           <= mretE;
            illegal_instrM  <= illegal_instrE;
            ecallM          <= ecallE;
            ebreakM         <= ebreakE;
            PCM             <= PCE;
        end
    end

endmodule