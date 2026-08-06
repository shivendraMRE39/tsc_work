//`timescale 1ns / 1ps

//module decode_stage(
//    input  logic        clk,
//    input  logic        rst,

//    input  logic        RegWriteW,

//    input  logic [31:0] InstrD,
//    input  logic [31:0] PCD,
//    input  logic [31:0] PcPlus4D,

//    input  logic [31:0] ResultW,
//    input  logic [4:0]  RdW,

//    input  logic        StallE, 
//    input  logic        FlushE, 

//    output logic        RegWriteE,
//    output logic [1:0]  ResultSrcE,
//    output logic        MemWriteE,
//    output logic        jumpE,
//    output logic        BranchE,
//    output logic [3:0]  ALUControlE,
//    output logic        ALUSrcE,

//    output logic [31:0] RD1E,
//    output logic [31:0] RD2E,
//    output logic [31:0] PCE,

//    output logic [4:0]  RdE,
//    output logic [4:0]  RS1E,
//    output logic [4:0]  RS2E,

//    output logic [31:0] ImmExtendE,
//    output logic [31:0] PcPlus4E,

//    output logic [4:0]  RS1D,
//    output logic [4:0]  RS2D,

//    output logic [2:0]  funct3E,

//    output logic        MemReadE,
//    output logic        csr_enE,
//    output logic [1:0]  csr_opE,
//    output logic [11:0] csr_addrE,
//    output logic        mretE,
//    output logic        illegal_instrE,
//    output logic        ecallE,
//    output logic        ebreakE,

//    // CSR immediate connections
//    output logic        csr_immE,
//    output logic [4:0]  zimmE
//);

//    logic        csr_enD;
//    logic [1:0]  csr_opD;
//    logic        mretD;
//    logic        RegWriteD;
//    logic        MemWriteD;
//    logic        MemReadD;
//    logic        jumpD;
//    logic        BranchD;
//    logic        ALUSrcD;
//    logic        illegal_instrD;
//    logic        ecallD;
//    logic        ebreakD;

//    logic [1:0]  ResultSrcD;
//    logic [3:0]  ALUControlD;
//    logic [2:0]  ImmSrcD;

//    logic [31:0] RD1D;
//    logic [31:0] RD2D;
//    logic [31:0] ImmExtendD;

//    logic [4:0]  RdD;
//    logic [11:0] csr_addrD;

//    logic        csr_immD;
//    logic [4:0]  zimmD;

//    //////////////////////////////////////////////////////
//    // Instruction Decoded Fields
//    //////////////////////////////////////////////////////
//    assign zimmD     = InstrD[19:15];
//    assign csr_addrD = InstrD[31:20];
//    assign RdD       = InstrD[11:7];
//    assign RS1D      = InstrD[19:15];
//    assign RS2D      = InstrD[24:20];

//    control_unit_top control (
//        .op           (InstrD[6:0]),
//        .funct3       (InstrD[14:12]),
//        .funct7       (InstrD[31:25]),
//        .RegWriteD    (RegWriteD),
//        .ResultSrcD   (ResultSrcD),
//        .MemWriteD    (MemWriteD),
//        .jumpD        (jumpD),
//        .BranchD      (BranchD),
//        .ALUControlD  (ALUControlD),
//        .ALUSrcD      (ALUSrcD),
//        .ImmSrcD      (ImmSrcD),
//        .MemReadD     (MemReadD),
//        .csr_enD      (csr_enD),
//        .csr_opD      (csr_opD),
//        .mretD        (mretD),
//        .illegal_instr(illegal_instrD),
//        .ecall        (ecallD),
//        .ebreak       (ebreakD),
//        .InstrD       (InstrD),
//        .csr_immD     (csr_immD)
//    );

//    registerfile register_file (
//        .clk(clk),
//        .rst(rst),
//        .A1 (InstrD[19:15]),
//        .A2 (InstrD[24:20]),
//        .A3 (RdW),
//        .WD3(ResultW),
//        .WE3(RegWriteW),
//        .RD1(RD1D),
//        .RD2(RD2D)
//    );

//    sign_extend extend (
//        .Instr    (InstrD),
//        .ImmSrc   (ImmSrcD),
//        .ImmExtend(ImmExtendD)
//    );

//    //////////////////////////////////////////////////////
//    // ID/EX Pipeline Register Synchronizer
//    //////////////////////////////////////////////////////
//    always_ff @(posedge clk or negedge rst) begin
//        if (!rst) begin
//            RegWriteE      <= 1'b0;
//            ResultSrcE     <= 2'b0;
//            MemWriteE      <= 1'b0;
//            jumpE          <= 1'b0;
            
//            /*
//             * FIX: Removed line 'BranchE <= 1 mepc_d'b0;' 
//             * WHY: '1 mepc_d'b0' is an invalid literal expression causing a syntax error.
//             * The clean assignment 'BranchE <= 1'b0;' directly below handles reset properly.
//             */
//            BranchE        <= 1'b0;
            
//            ALUControlE    <= 4'b0;
//            ALUSrcE        <= 1'b0;
//            RD1E           <= 32'b0;
//            RD2E           <= 32'b0;
//            PCE            <= 32'b0;
//            RdE            <= 5'b0;
//            RS1E           <= 5'b0;
//            RS2E           <= 5'b0;
//            ImmExtendE     <= 32'b0;
//            PcPlus4E       <= 32'b0;
//            funct3E        <= 3'b0;
//            MemReadE       <= 1'b0;
//            csr_enE        <= 1'b0;
//            csr_opE        <= 2'b0;
//            csr_addrE      <= 12'b0;
//            mretE          <= 1'b0;
//            illegal_instrE <= 1'b0;
//            ecallE         <= 1'b0;
//            ebreakE        <= 1'b0;
//            csr_immE       <= 1'b0;
//            zimmE          <= 5'b0;
//        end
//        else if (FlushE) begin
//            RegWriteE      <= 1'b0;
//            ResultSrcE     <= 2'b00;
//            MemWriteE      <= 1'b0;
//            jumpE          <= 1'b0;
//            BranchE        <= 1'b0;
//            ALUControlE    <= 4'b0;
//            ALUSrcE        <= 1'b0;
//            RD1E           <= 32'b0;
//            RD2E           <= 32'b0;
//            PCE            <= 32'b0;
//            RdE            <= 5'd0;
//            RS1E           <= 5'b0;
//            RS2E           <= 5'b0;
//            ImmExtendE     <= 32'b0;
//            PcPlus4E       <= 32'b0;
//            funct3E        <= 3'b0;
//            MemReadE       <= 1'b0;
//            csr_enE        <= 1'b0;
//            csr_opE        <= 2'b0;
//            csr_addrE      <= 12'b0;
//            mretE          <= 1'b0;
//            illegal_instrE <= 1'b0;
//            ecallE         <= 1'b0;
//            ebreakE        <= 1'b0;
//            csr_immE       <= 1'b0;
//            zimmE          <= 5'b0;
//        end
//        else if (!StallE) begin
//            RegWriteE      <= RegWriteD;
//            ResultSrcE     <= ResultSrcD;
//            MemWriteE      <= MemWriteD;
//            MemReadE       <= MemReadD;
//            jumpE          <= jumpD;
//            BranchE        <= BranchD;
//            ALUControlE    <= ALUControlD;
//            ALUSrcE        <= ALUSrcD;
//            RD1E           <= RD1D;
//            RD2E           <= RD2D;
//            PCE            <= PCD;
//            RdE            <= RdD;
//            RS1E           <= RS1D;
//            RS2E           <= RS2D;
//            ImmExtendE     <= ImmExtendD;
//            PcPlus4E       <= PcPlus4D;
//            funct3E        <= InstrD[14:12];
//            csr_enE        <= csr_enD;
//            csr_opE        <= csr_opD;
//            csr_addrE      <= csr_addrD;
//            mretE          <= mretD; 
//            illegal_instrE <= illegal_instrD;
//            ecallE         <= ecallD;
//            ebreakE        <= ebreakD;
//            csr_immE       <= csr_immD;
//            zimmE          <= zimmD;
//        end
//    end

///*
// * FIX: Removed appended code 'BranchE <= 1 mepc_d'b0;' after endmodule.
// * WHY: Statements written outside of modules or procedural blocks are invalid Verilog.
// */
//endmodule
`timescale 1ns / 1ps

module decode_stage(
    input  logic        clk,
    input  logic        rst,

    input  logic        RegWriteW,

    input  logic [31:0] InstrD,
    input  logic [31:0] PCD,
    input  logic [31:0] PcPlus4D,

    input  logic [31:0] ResultW,
    input  logic [4:0]  RdW,

    input  logic        StallE, 
    input  logic        FlushE, 

    output logic        RegWriteE,
    output logic [1:0]  ResultSrcE,
    output logic        MemWriteE,
    output logic        jumpE,
    output logic        BranchE,
    output logic [3:0]  ALUControlE,
    output logic        ALUSrcE,

    output logic [31:0] RD1E,
    output logic [31:0] RD2E,
    output logic [31:0] PCE,

    output logic [4:0]  RdE,
    output logic [4:0]  RS1E,
    output logic [4:0]  RS2E,

    output logic [31:0] ImmExtendE,
    output logic [31:0] PcPlus4E,

    output logic [4:0]  RS1D,
    output logic [4:0]  RS2D,

    output logic [2:0]  funct3E,

    output logic        MemReadE,
    output logic        csr_enE,
    output logic [1:0]  csr_opE,
    output logic [11:0] csr_addrE,
    output logic        mretE,
    output logic        illegal_instrE,
    output logic        ecallE,
    output logic        ebreakE,

    // CSR immediate connections
    output logic        csr_immE,
    output logic [4:0]  zimmE,

    // FIX: Genuine E-stage validity bit. 0 whenever the E-stage holds a
    // flush-injected bubble (branch mispredict / trap / mret / load-use stall),
    // 1 whenever a real decoded instruction is latched in. This is what the
    // CSR file's valid_E port must be driven by -- NOT a constant 1.
    output logic         InstrValidE
);

    logic        csr_enD;
    logic [1:0]  csr_opD;
    logic        mretD;
    logic        RegWriteD;
    logic        MemWriteD;
    logic        MemReadD;
    logic        jumpD;
    logic        BranchD;
    logic        ALUSrcD;
    logic        illegal_instrD;
    logic        ecallD;
    logic        ebreakD;

    logic [1:0]  ResultSrcD;
    logic [3:0]  ALUControlD;
    logic [2:0]  ImmSrcD;

    logic [31:0] RD1D;
    logic [31:0] RD2D;
    logic [31:0] ImmExtendD;

    logic [4:0]  RdD;
    logic [11:0] csr_addrD;

    logic        csr_immD;
    logic [4:0]  zimmD;

    //////////////////////////////////////////////////////
    // Instruction Decoded Fields
    //////////////////////////////////////////////////////
    assign zimmD     = InstrD[19:15];
    assign csr_addrD = InstrD[31:20];
    assign RdD       = InstrD[11:7];
    assign RS1D      = InstrD[19:15];
    assign RS2D      = InstrD[24:20];

    control_unit_top control (
        .op           (InstrD[6:0]),
        .funct3       (InstrD[14:12]),
        .funct7       (InstrD[31:25]),
        .RegWriteD    (RegWriteD),
        .ResultSrcD   (ResultSrcD),
        .MemWriteD    (MemWriteD),
        .jumpD        (jumpD),
        .BranchD      (BranchD),
        .ALUControlD  (ALUControlD),
        .ALUSrcD      (ALUSrcD),
        .ImmSrcD      (ImmSrcD),
        .MemReadD     (MemReadD),
        .csr_enD      (csr_enD),
        .csr_opD      (csr_opD),
        .mretD        (mretD),
        .illegal_instr(illegal_instrD),
        .ecall        (ecallD),
        .ebreak       (ebreakD),
        .InstrD       (InstrD),
        .csr_immD     (csr_immD)
    );

    registerfile register_file (
        .clk(clk),
        .rst(rst),
        .A1 (InstrD[19:15]),
        .A2 (InstrD[24:20]),
        .A3 (RdW),
        .WD3(ResultW),
        .WE3(RegWriteW),
        .RD1(RD1D),
        .RD2(RD2D)
    );

    sign_extend extend (
        .Instr    (InstrD),
        .ImmSrc   (ImmSrcD),
        .ImmExtend(ImmExtendD)
    );

    //////////////////////////////////////////////////////
    // ID/EX Pipeline Register Synchronizer
    //////////////////////////////////////////////////////
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            RegWriteE      <= 1'b0;
            ResultSrcE     <= 2'b0;
            MemWriteE      <= 1'b0;
            jumpE          <= 1'b0;
            
            /*
             * FIX: Removed line 'BranchE <= 1 mepc_d'b0;' 
             * WHY: '1 mepc_d'b0' is an invalid literal expression causing a syntax error.
             * The clean assignment 'BranchE <= 1'b0;' directly below handles reset properly.
             */
            BranchE        <= 1'b0;
            
            ALUControlE    <= 4'b0;
            ALUSrcE        <= 1'b0;
            RD1E           <= 32'b0;
            RD2E           <= 32'b0;
            PCE            <= 32'b0;
            RdE            <= 5'b0;
            RS1E           <= 5'b0;
            RS2E           <= 5'b0;
            ImmExtendE     <= 32'b0;
            PcPlus4E       <= 32'b0;
            funct3E        <= 3'b0;
            MemReadE       <= 1'b0;
            csr_enE        <= 1'b0;
            csr_opE        <= 2'b0;
            csr_addrE      <= 12'b0;
            mretE          <= 1'b0;
            illegal_instrE <= 1'b0;
            ecallE         <= 1'b0;
            ebreakE        <= 1'b0;
            csr_immE       <= 1'b0;
            zimmE          <= 5'b0;
            InstrValidE    <= 1'b0;
        end
        else if (FlushE) begin
            RegWriteE      <= 1'b0;
            ResultSrcE     <= 2'b00;
            MemWriteE      <= 1'b0;
            jumpE          <= 1'b0;
            BranchE        <= 1'b0;
            ALUControlE    <= 4'b0;
            ALUSrcE        <= 1'b0;
            RD1E           <= 32'b0;
            RD2E           <= 32'b0;
            PCE            <= 32'b0;
            RdE            <= 5'd0;
            RS1E           <= 5'b0;
            RS2E           <= 5'b0;
            ImmExtendE     <= 32'b0;
            PcPlus4E       <= 32'b0;
            funct3E        <= 3'b0;
            MemReadE       <= 1'b0;
            csr_enE        <= 1'b0;
            csr_opE        <= 2'b0;
            csr_addrE      <= 12'b0;
            mretE          <= 1'b0;
            illegal_instrE <= 1'b0;
            ecallE         <= 1'b0;
            ebreakE        <= 1'b0;
            csr_immE       <= 1'b0;
            zimmE          <= 5'b0;
            InstrValidE    <= 1'b0;
        end
        else if (!StallE) begin
            RegWriteE      <= RegWriteD;
            ResultSrcE     <= ResultSrcD;
            MemWriteE      <= MemWriteD;
            MemReadE       <= MemReadD;
            jumpE          <= jumpD;
            BranchE        <= BranchD;
            ALUControlE    <= ALUControlD;
            ALUSrcE        <= ALUSrcD;
            RD1E           <= RD1D;
            RD2E           <= RD2D;
            PCE            <= PCD;
            RdE            <= RdD;
            RS1E           <= RS1D;
            RS2E           <= RS2D;
            ImmExtendE     <= ImmExtendD;
            PcPlus4E       <= PcPlus4D;
            funct3E        <= InstrD[14:12];
            csr_enE        <= csr_enD;
            csr_opE        <= csr_opD;
            csr_addrE      <= csr_addrD;
            mretE          <= mretD; 
            illegal_instrE <= illegal_instrD;
            ecallE         <= ecallD;
            ebreakE        <= ebreakD;
            csr_immE       <= csr_immD;
            zimmE          <= zimmD;
            InstrValidE    <= 1'b1;
        end
        // else (StallE, no flush): hold current values, including InstrValidE,
        // exactly like every other E-stage field above.
    end

/*
 * FIX: Removed appended code 'BranchE <= 1 mepc_d'b0;' after endmodule.
 * WHY: Statements written outside of modules or procedural blocks are invalid Verilog.
 */
endmodule