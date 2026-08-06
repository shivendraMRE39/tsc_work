//`timescale 1ns / 1ps

//module pipline_top (
//    input  logic        clk,
//    input  logic        rst,
//    input  logic        pready,
//    output logic [31:0] ALUResultM,      
//    output logic [31:0] WriteDataM,      
//    output logic [3:0]  byte_strobeM,    
//    output logic        MemWriteM,       // Dynamic clean output pin to memory bus
//    output logic [2:0]  funct3M,
//    output logic        MemReadM,        // Dynamic clean output pin to memory bus
//    input  logic [31:0] ReadDataM,       
//    input  logic        mem_done,
//    input  logic [1:0]  timer_irq,
//    input  logic        sw_irq,
//    input  logic        ext_irq,
//    output logic        trap_taken
//);

//    // ====================================================================
//    // PIPELINE INTERCONNECT WIRES
//    // ====================================================================
//    // IF / ID Stage
//    logic [31:0] InstrD, PcD, PcPlus4D;
//    logic [4:0]  Rs1D, Rs2D;

//    // ID / EX Stage
//    logic [31:0] InstrE; 
//    logic        RegWriteE;
//    logic [1:0]  ResultSrcE;
//    logic        MemWriteE, MemReadE;
//    logic        jumpE, BranchE;
//    logic [3:0]  ALUControlE;
//    logic        ALUSrcE;
//    logic [31:0] RD1E, RD2E, PCE;
//    logic [4:0]  RdE, RS1E, RS2E;
//    logic [31:0] ImmExtendE, PcPlus4E;
//    logic [2:0]  funct3E;
//    logic        csr_immE;
//    logic [4:0]  zimmE;
//    logic        csr_enE;
//    logic [1:0]  csr_opE;
//    logic [11:0] csr_addrE;
//    logic        mretE, illegal_instrE, ecallE, ebreakE;

//    // EX / MEM Stage
//    logic        RegWriteM;
//    logic [1:0]  ResultSrcM;
//    logic [4:0]  RdM;
//    logic [31:0] PCM, PcPlus4M;
//    logic [31:0] PcTargetE;
//    logic        PcSrcE;
//    logic        csr_enM;
//    logic [1:0]  csr_opM;
//    logic [11:0] csr_addrM;
//    logic [31:0] csr_wdataM;
//    logic        mretM; // FIX: Added missing wire declaration
//    logic        illegal_instrM, ecallM, ebreakM;
//    logic        LoadAddrMisalignedM, StoreAddrMisalignedM;
//    logic [31:0] WriteDataM_internal, ResultM_forward;
//    logic        MemWriteM_internal, MemReadM_internal;

//    // MEM / WB Stage
//    logic        RegWriteW;
//    logic [1:0]  ResultSrcW;
//    logic [31:0] ALUResultW, ReadDataW;
//    logic [4:0]  RdW;
//    logic [31:0] PcPlus4W;
//    logic [31:0] ResultW;
//    logic        csr_enW;
//    logic [1:0]  csr_opW;
//    logic [11:0] csr_addrW;
//    logic [31:0] csr_rdataW;
// logic [31:0] csr_operand;
//    // Hazard & Stall Controls
//    logic [1:0]  ForwardAE, ForwardBE;
//    logic        lw_stall, bus_stall;
//    logic        StallF_hz, StallD_hz, StallE_hz, StallM_hz;   
//    logic        FlushD_hz, FlushE_hz, FlushM_hz;   
//    logic        StallF_final, StallD_final, StallE_final, StallM_final;
//    logic        FlushD_final, FlushE_final, FlushM_final;

//    // CSR & Trap Specific Wires
//    logic [31:0] csr_rdata_o;
//    logic [31:0] trap_pc_target;
//    logic        trap_pc_en;
//    logic        csr_illegal_instruction;

//    // ====================================================================
//    // TRAP-GATING LOGIC (External Bus Request Protection)
//    // ====================================================================
//    assign MemWriteM = MemWriteM_internal & ~trap_taken;
//    assign MemReadM  = MemReadM_internal  & ~trap_taken;

//    // Calculate bus stalls based on clean, gated signals
//    assign bus_stall = (MemReadM | MemWriteM) & ~(mem_done) & ~trap_taken;

//    // Combine hazard unit stalls with external memory bus stalls
//    assign StallF_final = StallF_hz | bus_stall;
//    assign StallD_final = StallD_hz | bus_stall;
//    assign StallE_final = StallE_hz | bus_stall; 
//    assign StallM_final = StallM_hz | bus_stall; 
    
//    // Flush pipeline entries during hazards, traps, or returns
//    // FIX: Updated mret check to include both mretE and mretM stages
//    assign FlushD_final = FlushD_hz | trap_taken | mretE | mretM;
//    assign FlushE_final = (FlushE_hz & ~bus_stall) | trap_taken | mretE | mretM;  
//    assign FlushM_final = (FlushM_hz & ~bus_stall) | trap_taken | mretM; 

//    // Aggregate Trap Signal
//    assign trap_taken = trap_pc_en | ecallM | ebreakM | illegal_instrM | LoadAddrMisalignedM | StoreAddrMisalignedM;

//    // ====================================================================
//    // UNIFIED CSR REGISTER FILE INSTANTIATION
//    // ====================================================================
//    CSR_Register_File #(
//        .DATA_BUS_WIDTH(32)
//    ) CSR (
//        .clk                 (clk),
//        .reset               (rst),
//        .csr_en              (csr_enE),
//        .stall_E_int         (StallE_final),
//        .valid_E             (1'b1),
//        .funct3              (funct3E),
//        .csr_addr            (csr_addrE),
//        .csr_data            (csr_operand),
//        .PC                  (PCE),
        
//        // External Interrupt Lines
//        .timer_irq           (timer_irq[1]),
//        .software_irq        (sw_irq),
//        .external_irq        (ext_irq),
        
//        // Memory Bus Fault inputs
//        .bus_fault_M         (LoadAddrMisalignedM | StoreAddrMisalignedM),
//        .is_store_M          (StoreAddrMisalignedM),
        
//        // Control & Vector Outputs
//        .illegal_instruction (csr_illegal_instruction),
//        .pc_en               (trap_pc_en),
//        .RD                  (csr_rdata_o),
//        .PC_Next             (trap_pc_target),
        
        
//        .ecall(ecallE),
//        .ebreak(ebreakE),
//        .mret(mretE)
//    );

//    // ====================================================================
//    // PIPELINE STAGES INSTANTIATION
//    // ====================================================================
//    IF fetch (
//        .clk          (clk),
//        .rst          (rst),
//        .StallF       (StallF_final),
//        .StallD       (StallD_final),   
//        .FlushD       (FlushD_final),   
//        .PcSrcE       (PcSrcE),
//        .PcTargetE    (PcTargetE),
//        .mtvec_i      (trap_pc_target),
//        .mret_i       (mretE),
//        .mepc_i       (trap_pc_target),
//        .trap_taken_i (trap_taken),
//        .InstrD       (InstrD),
//        .PcD          (PcD),
//        .PcPlus4D     (PcPlus4D)
//    );

//    decode_stage decode (
//        .clk            (clk), 
//        .rst            (rst), 
//        .RegWriteW      (RegWriteW), 
//        .InstrD         (InstrD), 
//        .PCD            (PcD), 
//        .PcPlus4D       (PcPlus4D),
//        .ResultW        (ResultW), 
//        .RdW            (RdW), 
//        .StallE         (StallE_final), 
//        .FlushE         (FlushE_final), 
//        .RegWriteE      (RegWriteE), 
//        .ResultSrcE     (ResultSrcE),
//        .MemWriteE      (MemWriteE), 
//        .jumpE          (jumpE), 
//        .BranchE        (BranchE), 
//        .ALUControlE    (ALUControlE), 
//        .ALUSrcE        (ALUSrcE), 
//        .RD1E           (RD1E), 
//        .RD2E           (RD2E),
//        .PCE            (PCE), 
//        .RdE            (RdE), 
//        .RS1E           (RS1E), 
//        .RS2E           (RS2E), 
//        .ImmExtendE     (ImmExtendE), 
//        .PcPlus4E       (PcPlus4E), 
//        .RS1D           (Rs1D), 
//        .RS2D           (Rs2D),
//        .funct3E        (funct3E), 
//        .MemReadE       (MemReadE), 
//        .csr_enE        (csr_enE), 
//        .csr_opE        (csr_opE), 
//        .csr_addrE      (csr_addrE), 
//        .mretE          (mretE),
//        .illegal_instrE (illegal_instrE), 
//        .ecallE         (ecallE), 
//        .ebreakE        (ebreakE),
//        .csr_immE       (csr_immE),
//        .zimmE          (zimmE)
//    );

//    // ID/EX Pipeline Register for Raw Instruction
//    always_ff @(posedge clk or negedge rst) begin
//        if (!rst) begin
//            InstrE <= 32'h00000013; // Default to NOP
//        end else if (FlushE_final) begin
//            InstrE <= 32'h00000013; // Flush to NOP
//        end else if (!StallE_final) begin
//            InstrE <= InstrD;       // Latch active Decode instruction
//        end
//    end

//    Execute_stage execute (
//        .clk             (clk), 
//        .rst             (rst), 
//        .RegWriteE       (RegWriteE), 
//        .ResultSrcE      (ResultSrcE), 
//        .MemWriteE       (MemWriteE),
//        .jumpE           (jumpE), 
//        .BranchE         (BranchE), 
//        .ALUControlE     (ALUControlE), 
//        .ALUSrcE         (ALUSrcE), 
//        .RD1E            (RD1E), 
//        .RD2E            (RD2E), 
//        .PCE             (PCE),
//        .RdE             (RdE), 
//        .RS1E            (RS1E), 
//        .RS2E            (RS2E), 
//        .ImmExtendE      (ImmExtendE), 
//        .PcPlus4E        (PcPlus4E), 
//        .ResultW         (ResultW), 
//        .ForwardAE       (ForwardAE),
//        .ForwardBE       (ForwardBE), 
//        .FlushM          (FlushM_final), 
//        .StallM          (StallM_final), 
//        .funct3E         (funct3E), 
//        .RegWriteM       (RegWriteM), 
//        .ResultSrcM      (ResultSrcM),
//        .MemWriteM       (MemWriteM_internal), 
//        .ALUResultM      (ALUResultM), 
//        .WriteDataM      (WriteDataM_internal), 
//        .RdM             (RdM), 
//        .PcPlus4M        (PcPlus4M),
//        .PcTargetE       (PcTargetE), 
//        .PcSrcE          (PcSrcE), 
//        .ResultM_forward (ResultM_forward), 
//        .funct3M         (funct3M), 
//        .MemReadM        (MemReadM_internal), 
//        .MemReadE        (MemReadE),
//        .csr_enE         (csr_enE), 
//        .csr_opE         (csr_opE), 
//        .csr_addrE       (csr_addrE), 
//        .csr_enM         (csr_enM), 
//        .csr_opM         (csr_opM), 
//        .csr_addrM       (csr_addrM),
//        .csr_wdataM      (csr_wdataM), 
//        .mretM           (mretM), 
//        .mretE           (mretE), 
//        .illegal_instrE  (illegal_instrE | csr_illegal_instruction), 
//        .ecallE          (ecallE), 
//        .ebreakE         (ebreakE),
//        .illegal_instrM  (illegal_instrM), 
//        .ecallM          (ecallM), 
//        .ebreakM         (ebreakM), 
//        .PCM             (PCM),
//        .InstrE          (InstrE),
//        .csr_immE        (csr_immE),
//        .zimmE           (zimmE),
//        .csr_operand  (csr_operand)
//    );

//    data_mem_stage memory_stage (
//        .clk             (clk), 
//        .rst             (rst), 
//        .bus_stall       (bus_stall), 
//        .FlushM          (FlushM_final), 
//        .RegWriteM       (RegWriteM), 
//        .ResultSrcM      (ResultSrcM),
//        .MemWriteM       (MemWriteM_internal), 
//        .MemReadM        (MemReadM_internal),   
//        .ALUResultM      (ALUResultM), 
//        .WriteDataM      (WriteDataM_internal), 
//        .funct3M         (funct3M), 
//        .RdM             (RdM), 
//        .PcPlus4M        (PcPlus4M), 
//        .ReadDataM       (ReadDataM),
//        .StoreDataM      (WriteDataM),        
//        .ByteEnableM     (byte_strobeM),     
//        .LoadMisalignedM (LoadAddrMisalignedM), 
//        .StoreMisalignedM(StoreAddrMisalignedM),
//        .ReadDataW       (ReadDataW), 
//        .RegWriteW       (RegWriteW), 
//        .ResultSrcW      (ResultSrcW), 
//        .ALUResultW      (ALUResultW), 
//        .RdW             (RdW), 
//        .PcPlus4W        (PcPlus4W),
//        .csr_enM         (csr_enM), 
//        .csr_opM         (csr_opM), 
//        .csr_addrM       (csr_addrM), 
//        .csr_rdataM      (csr_rdata_o),
//        .csr_enW         (csr_enW), 
//        .csr_opW         (csr_opW), 
//        .csr_addrW       (csr_addrW), 
//        .csr_rdataW      (csr_rdataW),
//        .mretM           (mretM), 
//        .ResultM_forward (ResultM_forward)
//    );

//    write_back_stage wb (
//        .RegWriteW  (RegWriteW), 
//        .ResultSrcW (ResultSrcW), 
//        .ALUResultW (ALUResultW), 
//        .ReadDataW  (ReadDataW),
//        .RdW        (RdW), 
//        .PcPlus4W   (PcPlus4W), 
//        .ResultW    (ResultW), 
//        .csr_rdataW (csr_rdataW)
//    );

//    hazard_unit ha (
//        .rst        (rst), 
//        .RegWriteM  (RegWriteM), 
//        .RegWriteW  (RegWriteW), 
//        .RdM        (RdM), 
//        .RdW        (RdW), 
//        .Rs1E       (RS1E), 
//        .Rs2E       (RS2E),
//        .Rs1D       (Rs1D), 
//        .Rs2D       (Rs2D), 
//        .ResultSrcE (ResultSrcE), 
//        .RdE        (RdE), 
//        .PcSrcE     (PcSrcE), 
//        .ForwardAE  (ForwardAE), 
//        .ForwardBE  (ForwardBE),
//        .StallF     (StallF_hz), 
//        .StallD     (StallD_hz), 
//        .StallE     (StallE_hz), 
//        .StallM     (StallM_hz),
//        .FlushD     (FlushD_hz), 
//        .FlushE     (FlushE_hz), 
//        .FlushM     (FlushM_hz), 
//        .lw_stall   (lw_stall), 
//        .MemReadM   (MemReadM_internal),
//        .trap_taken (trap_taken), 
//        .mret_i     (mretE)
//    );

//endmodule
`timescale 1ns / 1ps

module pipline_top (
    input  logic        clk,
    input  logic        rst,
    input  logic        pready,
    output logic [31:0] ALUResultM,      
    output logic [31:0] WriteDataM,      
    output logic [3:0]  byte_strobeM,    
    output logic        MemWriteM,       // Dynamic clean output pin to memory bus
    output logic [2:0]  funct3M,
    output logic        MemReadM,        // Dynamic clean output pin to memory bus
    input  logic [31:0] ReadDataM,       
    input  logic        mem_done,
    input  logic [1:0]  timer_irq,
    input  logic        sw_irq,
    input  logic        ext_irq,
    output logic        trap_taken
);

    // ====================================================================
    // PIPELINE INTERCONNECT WIRES
    // ====================================================================
    // IF / ID Stage
    logic [31:0] InstrD, PcD, PcPlus4D;
    logic [4:0]  Rs1D, Rs2D;

    // ID / EX Stage
    logic [31:0] InstrE; 
    logic        RegWriteE;
    logic [1:0]  ResultSrcE;
    logic        MemWriteE, MemReadE;
    logic        jumpE, BranchE;
    logic [3:0]  ALUControlE;
    logic        ALUSrcE;
    logic [31:0] RD1E, RD2E, PCE;
    logic [4:0]  RdE, RS1E, RS2E;
    logic [31:0] ImmExtendE, PcPlus4E;
    logic [2:0]  funct3E;
    logic        csr_immE;
    logic [4:0]  zimmE;
    logic        csr_enE;
    logic [1:0]  csr_opE;
    logic [11:0] csr_addrE;
    logic        mretE, illegal_instrE, ecallE, ebreakE;
    logic        InstrValidE; // FIX: real E-stage validity bit (replaces hardwired valid_E)

    // EX / MEM Stage
    logic        RegWriteM;
    logic [1:0]  ResultSrcM;
    logic [4:0]  RdM;
    logic [31:0] PCM, PcPlus4M;
    logic [31:0] PcTargetE;
    logic        PcSrcE;
    logic        csr_enM;
    logic [1:0]  csr_opM;
    logic [11:0] csr_addrM;
    logic [31:0] csr_wdataM;
    logic        mretM; // FIX: Added missing wire declaration
    logic        illegal_instrM, ecallM, ebreakM;
    logic        LoadAddrMisalignedM, StoreAddrMisalignedM;
    logic [31:0] WriteDataM_internal, ResultM_forward;
    logic        MemWriteM_internal, MemReadM_internal;

    // MEM / WB Stage
    logic        RegWriteW;
    logic [1:0]  ResultSrcW;
    logic [31:0] ALUResultW, ReadDataW;
    logic [4:0]  RdW;
    logic [31:0] PcPlus4W;
    logic [31:0] ResultW;
    logic        csr_enW;
    logic [1:0]  csr_opW;
    logic [11:0] csr_addrW;
    logic [31:0] csr_rdataW;
 logic [31:0] csr_operand;
    // Hazard & Stall Controls
    logic [1:0]  ForwardAE, ForwardBE;
    logic        lw_stall, bus_stall;
    logic        StallF_hz, StallD_hz, StallE_hz, StallM_hz;   
    logic        FlushD_hz, FlushE_hz, FlushM_hz;   
    logic        StallF_final, StallD_final, StallE_final, StallM_final;
    logic        FlushD_final, FlushE_final, FlushM_final;

    // CSR & Trap Specific Wires
    logic [31:0] csr_rdata_o;
    logic [31:0] trap_pc_target;
    logic        trap_pc_en;
    logic        csr_illegal_instruction;

    // ====================================================================
    // TRAP-GATING LOGIC (External Bus Request Protection)
    // ====================================================================
    assign MemWriteM = MemWriteM_internal & ~trap_taken;
    assign MemReadM  = MemReadM_internal  & ~trap_taken;

    // Calculate bus stalls based on clean, gated signals
    assign bus_stall = (MemReadM | MemWriteM) & ~(mem_done) & ~trap_taken;

    // Combine hazard unit stalls with external memory bus stalls
    assign StallF_final = StallF_hz | bus_stall;
    assign StallD_final = StallD_hz | bus_stall;
    assign StallE_final = StallE_hz | bus_stall; 
    assign StallM_final = StallM_hz | bus_stall; 
    
    // Flush pipeline entries during hazards, traps, or returns
    // FIX: Updated mret check to include both mretE and mretM stages
    assign FlushD_final = FlushD_hz | trap_taken | mretE | mretM;
    assign FlushE_final = (FlushE_hz & ~bus_stall) | trap_taken | mretE | mretM;  
    // Two DISTINCT flush conditions are needed here, not one shared signal:
    //
    // FlushM_EX  -> feeds Execute_stage's own E->M register. Must use the early/E-native
    //               trap signal (trap_taken, which includes trap_pc_en) so that ecall/ebreak/
    //               illegal_instr/mret correctly suppress THEIR OWN transfer into M-stage as
    //               they leave E-stage.
    //
    // FlushM_MW  -> feeds data_mem_stage's M->W register. Must ONLY respond to faults that are
    //               native to whatever instruction is CURRENTLY resident in M this cycle
    //               (i.e. LoadAddrMisalignedM/StoreAddrMisalignedM). It must NOT react to
    //               ecallM/ebreakM/illegal_instrM/trap_pc_en/mretM: those all belong to a
    //               different, younger instruction relative to M's current occupant, and
    //               using them here wrongly discards an unrelated, already-valid M-stage
    //               result before it can reach Writeback (this was the root cause of the
    //               x6 bug, and reusing a single M-timed-only signal for BOTH boundaries
    //               instead caused the opposite regression by no longer suppressing ecall's
    //               own E->M transfer, letting a stale ecallM leak forward and clobber the
    //               real trap-handler instructions in M one cycle later).
    // NOTE: mretM is deliberately excluded here (unlike FlushD_final/FlushE_final,
    // which harmlessly re-flush already-fresh fetch content). By the time mret
    // reaches M-stage, its own redirect already happened via mretE one cycle
    // earlier. The instruction sitting in E-stage when mretM asserts is the
    // fresh, already-correctly-redirected NEXT instruction -- flushing it here
    // wrongly discards its write (same failure mode as the earlier ecallM bug).
    wire FlushM_EX = trap_taken | mretE;
    wire FlushM_MW = LoadAddrMisalignedM | StoreAddrMisalignedM;

    // Aggregate Trap Signal
    assign trap_taken = trap_pc_en | ecallM | ebreakM | illegal_instrM | LoadAddrMisalignedM | StoreAddrMisalignedM;

    // ====================================================================
    // UNIFIED CSR REGISTER FILE INSTANTIATION
    // ====================================================================
    CSR_Register_File #(
        .DATA_BUS_WIDTH(32)
    ) CSR (
        .clk                 (clk),
        .reset               (rst),
        .csr_en              (csr_enE),
        .stall_E_int         (StallE_final),
        // FIX: was hardwired to 1'b1. That let mepc get captured with PCE == 0
        // whenever an interrupt landed on a flush-injected bubble cycle (PCE is
        // forced to 0 on FlushE), and let minstret count bubbles as retired
        // instructions. Now driven by the real, pipeline-tracked validity bit.
        .valid_E             (InstrValidE),
        .funct3              (funct3E),
        .csr_addr            (csr_addrE),
        .csr_data            (csr_operand),
        .PC                  (PCE),
        // PCM: the M-stage instruction's own PC, needed so bus_fault_M
        // (LoadAddrMisalignedM/StoreAddrMisalignedM) captures mepc for the
        // instruction that actually faulted, not whatever's currently in
        // E-stage a cycle later. PCM is already produced by Execute_stage;
        // it was simply never wired into the CSR module before.
        .PCM                 (PCM),
        
        // External Interrupt Lines
        .timer_irq           (timer_irq[1]),
        .software_irq        (sw_irq),
        .external_irq        (ext_irq),
        
        // Memory Bus Fault inputs
        .bus_fault_M         (LoadAddrMisalignedM | StoreAddrMisalignedM),
        .is_store_M          (StoreAddrMisalignedM),
        
        // Control & Vector Outputs
        .illegal_instruction (csr_illegal_instruction),
        .pc_en               (trap_pc_en),
        .RD                  (csr_rdata_o),
        .PC_Next             (trap_pc_target),
        
        
        .ecall(ecallE),
        .ebreak(ebreakE),
        .mret(mretE)
    );

    // ====================================================================
    // PIPELINE STAGES INSTANTIATION
    // ====================================================================
    IF fetch (
        .clk          (clk),
        .rst          (rst),
        .StallF       (StallF_final),
        .StallD       (StallD_final),   
        .FlushD       (FlushD_final),   
        .PcSrcE       (PcSrcE),
        .PcTargetE    (PcTargetE),
        .mtvec_i      (trap_pc_target),
        .mret_i       (mretE),
        .mepc_i       (trap_pc_target),
        .trap_taken_i (trap_taken),
        .InstrD       (InstrD),
        .PcD          (PcD),
        .PcPlus4D     (PcPlus4D)
    );

    decode_stage decode (
        .clk            (clk), 
        .rst            (rst), 
        .RegWriteW      (RegWriteW), 
        .InstrD         (InstrD), 
        .PCD            (PcD), 
        .PcPlus4D       (PcPlus4D),
        .ResultW        (ResultW), 
        .RdW            (RdW), 
        .StallE         (StallE_final), 
        .FlushE         (FlushE_final), 
        .RegWriteE      (RegWriteE), 
        .ResultSrcE     (ResultSrcE),
        .MemWriteE      (MemWriteE), 
        .jumpE          (jumpE), 
        .BranchE        (BranchE), 
        .ALUControlE    (ALUControlE), 
        .ALUSrcE        (ALUSrcE), 
        .RD1E           (RD1E), 
        .RD2E           (RD2E),
        .PCE            (PCE), 
        .RdE            (RdE), 
        .RS1E           (RS1E), 
        .RS2E           (RS2E), 
        .ImmExtendE     (ImmExtendE), 
        .PcPlus4E       (PcPlus4E), 
        .RS1D           (Rs1D), 
        .RS2D           (Rs2D),
        .funct3E        (funct3E), 
        .MemReadE       (MemReadE), 
        .csr_enE        (csr_enE), 
        .csr_opE        (csr_opE), 
        .csr_addrE      (csr_addrE), 
        .mretE          (mretE),
        .illegal_instrE (illegal_instrE), 
        .ecallE         (ecallE), 
        .ebreakE        (ebreakE),
        .csr_immE       (csr_immE),
        .zimmE          (zimmE),
        .InstrValidE    (InstrValidE)
    );

    // ID/EX Pipeline Register for Raw Instruction
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            InstrE <= 32'h00000013; // Default to NOP
        end else if (FlushE_final) begin
            InstrE <= 32'h00000013; // Flush to NOP
        end else if (!StallE_final) begin
            InstrE <= InstrD;       // Latch active Decode instruction
        end
    end

    Execute_stage execute (
        .clk             (clk), 
        .rst             (rst), 
        .RegWriteE       (RegWriteE), 
        .ResultSrcE      (ResultSrcE), 
        .MemWriteE       (MemWriteE),
        .jumpE           (jumpE), 
        .BranchE         (BranchE), 
        .ALUControlE     (ALUControlE), 
        .ALUSrcE         (ALUSrcE), 
        .RD1E            (RD1E), 
        .RD2E            (RD2E), 
        .PCE             (PCE),
        .RdE             (RdE), 
        .RS1E            (RS1E), 
        .RS2E            (RS2E), 
        .ImmExtendE      (ImmExtendE), 
        .PcPlus4E        (PcPlus4E), 
        .ResultW         (ResultW), 
        .ForwardAE       (ForwardAE),
        .ForwardBE       (ForwardBE), 
        .FlushM          (FlushM_EX), 
        .StallM          (StallM_final), 
        .funct3E         (funct3E), 
        .RegWriteM       (RegWriteM), 
        .ResultSrcM      (ResultSrcM),
        .MemWriteM       (MemWriteM_internal), 
        .ALUResultM      (ALUResultM), 
        .WriteDataM      (WriteDataM_internal), 
        .RdM             (RdM), 
        .PcPlus4M        (PcPlus4M),
        .PcTargetE       (PcTargetE), 
        .PcSrcE          (PcSrcE), 
        .ResultM_forward (ResultM_forward), 
        .funct3M         (funct3M), 
        .MemReadM        (MemReadM_internal), 
        .MemReadE        (MemReadE),
        .csr_enE         (csr_enE), 
        .csr_opE         (csr_opE), 
        .csr_addrE       (csr_addrE), 
        .csr_enM         (csr_enM), 
        .csr_opM         (csr_opM), 
        .csr_addrM       (csr_addrM),
        .mretM           (mretM), 
        .mretE           (mretE), 
        .illegal_instrE  (illegal_instrE | csr_illegal_instruction), 
        .ecallE          (ecallE), 
        .ebreakE         (ebreakE),
        .illegal_instrM  (illegal_instrM), 
        .ecallM          (ecallM), 
        .ebreakM         (ebreakM), 
        .PCM             (PCM),
        .InstrE          (InstrE),
        .csr_immE        (csr_immE),
        .zimmE           (zimmE),
        .csr_operand  (csr_operand),
        .csr_rdataE      (csr_rdata_o),
        .csr_rdataM      (csr_wdataM)
    );

    data_mem_stage memory_stage (
        .clk             (clk), 
        .rst             (rst), 
        .bus_stall       (bus_stall), 
        .FlushM          (FlushM_MW), 
        .RegWriteM       (RegWriteM), 
        .ResultSrcM      (ResultSrcM),
        .MemWriteM       (MemWriteM_internal), 
        .MemReadM        (MemReadM_internal),   
        .ALUResultM      (ALUResultM), 
        .WriteDataM      (WriteDataM_internal), 
        .funct3M         (funct3M), 
        .RdM             (RdM), 
        .PcPlus4M        (PcPlus4M), 
        .ReadDataM       (ReadDataM),
        .StoreDataM      (WriteDataM),        
        .ByteEnableM     (byte_strobeM),     
        .LoadMisalignedM (LoadAddrMisalignedM), 
        .StoreMisalignedM(StoreAddrMisalignedM),
        .ReadDataW       (ReadDataW), 
        .RegWriteW       (RegWriteW), 
        .ResultSrcW      (ResultSrcW), 
        .ALUResultW      (ALUResultW), 
        .RdW             (RdW), 
        .PcPlus4W        (PcPlus4W),
        .csr_enM         (csr_enM), 
        .csr_opM         (csr_opM), 
        .csr_addrM       (csr_addrM), 
        .csr_rdataM      (csr_wdataM),
        .csr_enW         (csr_enW), 
        .csr_opW         (csr_opW), 
        .csr_addrW       (csr_addrW), 
        .csr_rdataW      (csr_rdataW),
        .mretM           (mretM), 
        .ResultM_forward (ResultM_forward)
    );

    write_back_stage wb (
        .RegWriteW  (RegWriteW), 
        .ResultSrcW (ResultSrcW), 
        .ALUResultW (ALUResultW), 
        .ReadDataW  (ReadDataW),
        .RdW        (RdW), 
        .PcPlus4W   (PcPlus4W), 
        .ResultW    (ResultW), 
        .csr_rdataW (csr_rdataW)
    );

    hazard_unit ha (
        .rst        (rst), 
        .RegWriteM  (RegWriteM), 
        .RegWriteW  (RegWriteW), 
        .RdM        (RdM), 
        .RdW        (RdW), 
        .Rs1E       (RS1E), 
        .Rs2E       (RS2E),
        .Rs1D       (Rs1D), 
        .Rs2D       (Rs2D), 
        .ResultSrcE (ResultSrcE), 
        .RdE        (RdE), 
        .PcSrcE     (PcSrcE), 
        .ForwardAE  (ForwardAE), 
        .ForwardBE  (ForwardBE),
        .StallF     (StallF_hz), 
        .StallD     (StallD_hz), 
        .StallE     (StallE_hz), 
        .StallM     (StallM_hz),
        .FlushD     (FlushD_hz), 
        .FlushE     (FlushE_hz), 
        .FlushM     (FlushM_hz), 
        .lw_stall   (lw_stall), 
        .MemReadM   (MemReadM_internal),
        .trap_taken (trap_taken), 
        .mret_i     (mretE)
    );

endmodule