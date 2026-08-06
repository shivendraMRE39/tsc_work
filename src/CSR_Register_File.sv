`timescale 1ns / 1ps

module CSR_Register_File #(
    parameter DATA_BUS_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         csr_en,
    input  wire                         stall_E_int, // Stall signal
    input  wire                         valid_E,
    
    // funct3[2]:   0 = Register operand, 1 = Immediate operand (uimm)
    // funct3[1:0]: 00 = SYSTEM/PRIV, 01 = WRITE, 10 = SET, 11 = CLEAR
    input  wire [2:0]                   funct3,   
    
    input  wire [11:0]                  csr_addr,
    input  wire [DATA_BUS_WIDTH-1:0]    csr_data,
    input  wire [DATA_BUS_WIDTH-1:0]    PC,
    // PCM: the M-stage instruction's own PC. Needed specifically for
    // bus_fault_M below, since that fault is inherently M-stage-native --
    // by the time it's detected, PC (=PCE, the Execute stage's *current*
    // PC) already belongs to a younger instruction that has since moved
    // into E-stage, not the actual faulting one. Using PC/PCE for that
    // branch causes mepc to be captured one instruction too late, which
    // makes the trap handler's "mepc+4, return" skip the WRONG
    // instruction (the innocent younger one, not the actual fault).
    input  wire [DATA_BUS_WIDTH-1:0]    PCM,
    
    // =======================================================================
    // === HARDWARE INTERRUPT PINS ===
    // =======================================================================
    input  wire                         timer_irq,    // MTIP (Bit 7)
    input  wire                         software_irq, // MSIP (Bit 3)
    input  wire                         external_irq, // MEIP (Bit 11)
    
    // =======================================================================
    // === FAULT PINS ===
    // =======================================================================
    input  wire                         bus_fault_M,
    input  wire                         is_store_M,

    output wire                         illegal_instruction,
    output reg                          pc_en,
    output reg  [DATA_BUS_WIDTH-1:0]    RD,
    output reg  [DATA_BUS_WIDTH-1:0]    PC_Next,
    
    input  wire                         ecall,
    input  wire                         ebreak,
    input  wire                         mret
);

    reg illeg_instr_r, illeg_instr_w;
    assign illegal_instruction = illeg_instr_r | illeg_instr_w; 

    reg [1:0] priv_q = 2'b11, priv_d = 2'b11; // Default: Machine Mode (11)

    // Mask for writable bits in mstatus (MIE=Bit 3, MPIE=Bit 7, MPP=Bits 12:11)
    localparam MSTATUS_MASK = 32'h0000_1888;

    // Check if targeted CSR address is Read-Only (bits [11:10] == 2'b11)
    wire is_readonly_csr = (csr_addr[11:10] == 2'b11);

    // ============================ CSR ADDRESS DEFINITIONS ================================== //
    localparam MVENDORID = 12'hF11, MARCHID   = 12'hF12, MIMPID    = 12'hF13, MHARTID   = 12'hF14; 
    localparam MSTATUS   = 12'h300, MISA      = 12'h301, MTVEC     = 12'h305; 
    localparam MSCRATCH  = 12'h340, MEPC      = 12'h341, MCAUSE    = 12'h342, MTVAL     = 12'h343; 
    localparam MIE       = 12'h304, MIP       = 12'h344;
    localparam MCYCLE    = 12'hB00, MCYCLEH   = 12'hB80, MINSTRET  = 12'hB02, MINSTRETH = 12'hB82;

    // ========================= PHYSICAL REGISTER FLIP-FLOPS ================================= //
    reg [DATA_BUS_WIDTH-1:0] mvendorid = 32'b0;  
    reg [DATA_BUS_WIDTH-1:0] marchid   = 32'b0;    
    reg [DATA_BUS_WIDTH-1:0] mimpid    = 32'b0;     
    reg [DATA_BUS_WIDTH-1:0] mhartid   = 32'b0;    

    reg [DATA_BUS_WIDTH-1:0] misa      = 32'h4000_1101;       
    reg [DATA_BUS_WIDTH-1:0] mstatus_q,  mstatus_d;    
    reg [DATA_BUS_WIDTH-1:0] mtvec_q,    mtvec_d;     
    reg [DATA_BUS_WIDTH-1:0] mie_q,      mie_d;          

    wire [DATA_BUS_WIDTH-1:0] mip_wire = {20'b0, external_irq, 3'b0, timer_irq, 3'b0, software_irq, 3'b0};

    reg [DATA_BUS_WIDTH-1:0] mscratch_q, mscratch_d;   
    reg [DATA_BUS_WIDTH-1:0] mepc_q,     mepc_d;        
    reg [DATA_BUS_WIDTH-1:0] mcause_q,   mcause_d;      
    reg [DATA_BUS_WIDTH-1:0] mtval_q,    mtval_d;      

    // Hardware Counters
    reg [63:0] mcycle_q, minstret_q;
    
    // Recovery register for pipelined PC tracking during stalls/flushes
    // NOTE: assumes PC == 0 is never a legitimate valid instruction address.
    // Verify this holds for your reset vector before relying on it.
    reg [DATA_BUS_WIDTH-1:0] recovery_pc;
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) 
            recovery_pc <= 32'b0;
        else if (PC != 32'b0) 
            recovery_pc <= PC; 
    end

    // Use current PC if valid, otherwise rely on recovery_pc
    wire [DATA_BUS_WIDTH-1:0] current_pc = (PC != 32'b0) ? PC : recovery_pc;

    // Determine incoming write operand (Register vs Zero-Extended 5-bit Immediate)
    wire [DATA_BUS_WIDTH-1:0] wdata_operand = funct3[2] ? {27'b0, csr_data[4:0]} : csr_data;

    // CSRRW/CSRRWI (funct3[1:0]==2'b01) always writes, regardless of operand value.
    // CSRRS/CSRRC/CSRRSI/CSRRCI only write when the operand is nonzero -- per the
    // RISC-V spec, e.g. "csrrs rd, csr, x0" must be treated as a pure read and must
    // NOT be illegal even on a read-only CSR. This wire distinguishes the two so the
    // illegal-write checks below only fire on a genuine write attempt.
    wire attempting_write = (funct3[1:0] == 2'b01) || (wdata_operand != 0);

    // ==================================== Reading =========================================== //
    always_comb begin
        illeg_instr_r = 1'b0; 
        RD            = 32'd0;

        if (csr_en && valid_E) begin
            if (priv_q < csr_addr[9:8]) begin
                illeg_instr_r = 1'b1;
            end else if (funct3[1:0] != 2'b00) begin
                case (csr_addr)
                    MVENDORID : RD = mvendorid;
                    MARCHID   : RD = marchid;
                    MIMPID    : RD = mimpid;
                    MHARTID   : RD = mhartid;
                    MISA      : RD = misa;
                    MSTATUS   : RD = mstatus_q;
                    MTVEC     : RD = mtvec_q;
                    MSCRATCH  : RD = mscratch_q;
                    MEPC      : RD = mepc_q;
                    MCAUSE    : RD = mcause_q;
                    MTVAL     : RD = mtval_q;
                    MIE       : RD = mie_q;
                    MIP       : RD = mip_wire; 
                    MCYCLE    : RD = mcycle_q[31:0];
                    MCYCLEH   : RD = mcycle_q[63:32];
                    MINSTRET  : RD = minstret_q[31:0];
                    MINSTRETH : RD = minstret_q[63:32];
                    default   : begin
                        illeg_instr_r = 1'b1;
                        RD            = 32'd0;
                    end
                endcase
            end
        end
    end

    // ==================================== Writing & Traps =========================================== //
    always_comb begin
        illeg_instr_w = 1'b0;
        pc_en         = 1'b0;
        priv_d        = priv_q;
        mstatus_d     = mstatus_q;
        mtvec_d       = mtvec_q;
        mscratch_d    = mscratch_q;
        mepc_d        = mepc_q;
        mcause_d      = mcause_q;
        mtval_d       = mtval_q;
        mie_d         = mie_q;
        PC_Next       = PC;

        // ---------------------------------------------------------------------------------------------
        // 1. SYNCHRONOUS BUS FAULT (Highest Priority)
        // NOTE: bus_fault_M is not gated by an M-stage valid signal here.
        // If it can glitch/assert when the M-stage instruction is not valid,
        // AND it with your pipeline's valid_M before use.
        // ---------------------------------------------------------------------------------------------
        if (bus_fault_M) begin
            mepc_d           = PCM; // M-native fault: capture the M-stage instruction's OWN PC, not PCE
            mcause_d         = is_store_M ? 32'd6 : 32'd4; // 6=Store/AMO addr misaligned, 4=Load addr misaligned (standard RISC-V codes)
            mtval_d          = 32'd0;
            mstatus_d[7]     = mstatus_q[3];
            mstatus_d[3]     = 1'b0;                      
            mstatus_d[12:11] = priv_q;
            priv_d           = 2'b11;
            PC_Next          = {mtvec_q[31:2], 2'b00};
            pc_en            = 1'b1;
        end

        // ---------------------------------------------------------------------------------------------
        // 2. ASYNCHRONOUS HARDWARE INTERRUPTS (Takes precedence over normal instruction execution)
        // ---------------------------------------------------------------------------------------------
        else if (mstatus_q[3] && valid_E && !stall_E_int && (| (mie_q & mip_wire))) begin
            mepc_d           = current_pc;                      
            mstatus_d[7]     = mstatus_q[3];
            mstatus_d[3]     = 1'b0;                      
            mstatus_d[12:11] = priv_q;
            priv_d           = 2'b11;
            PC_Next          = {mtvec_q[31:2], 2'b00};
            pc_en            = 1'b1;

            if (mie_q[11] && mip_wire[11])       mcause_d = 32'h8000_000B; // External Interrupt
            else if (mie_q[3] && mip_wire[3])   mcause_d = 32'h8000_0003; // Software Interrupt
            else if (mie_q[7] && mip_wire[7])   mcause_d = 32'h8000_0007; // Timer Interrupt
        end

        // ---------------------------------------------------------------------------------------------
        // 3. SYNCHRONOUS EXCEPTIONS & CSR INSTRUCTIONS
        // ---------------------------------------------------------------------------------------------
        else if (valid_E) begin

            if (ecall) begin
                mepc_d           = current_pc;
                mcause_d         = (priv_q == 2'b11) ? 32'd11 : 32'd8;
                mtval_d          = 32'd0;
                mstatus_d[7]     = mstatus_q[3];
                mstatus_d[3]     = 1'b0;
                mstatus_d[12:11] = priv_q;
                priv_d           = 2'b11;
                PC_Next          = {mtvec_q[31:2], 2'b00};
                pc_en            = 1'b1;
            end
            
            else if (ebreak) begin
                mepc_d           = current_pc;
                mcause_d         = 32'd3;
                mtval_d          = current_pc;
                mstatus_d[7]     = mstatus_q[3];
                mstatus_d[3]     = 1'b0;
                mstatus_d[12:11] = priv_q;
                priv_d           = 2'b11;
                PC_Next          = {mtvec_q[31:2], 2'b00};
                pc_en            = 1'b1;
            end

            else if (mret) begin
                if (priv_q == 2'b11) begin
                    PC_Next          = mepc_q;
                    pc_en            = 1'b1;
                    priv_d           = mstatus_q[12:11];
                    // MPP is set to 2'b11 (M-mode), the least-privileged supported
                    // mode per the RISC-V priv spec (3.1.6.1), since this core
                    // implements no other privilege level anywhere else.
                    mstatus_d[12:11] = 2'b11;
                    mstatus_d[3]     = mstatus_q[7];
                    mstatus_d[7]     = 1'b1;
                end else begin
                    illeg_instr_w = 1'b1;
                end
            end

            else if (csr_en) begin
                // Trap only genuine write attempts to Read-Only CSRs, or lower privilege access.
                // A CSRRS/CSRRC-family instruction with a zero operand is a pure read and must
                // remain legal even on a read-only CSR (RISC-V spec, Zicsr).
                if ((is_readonly_csr && attempting_write) || (priv_q < csr_addr[9:8])) begin
                    illeg_instr_w = 1'b1;
                end else begin
                    case (funct3[1:0])
                        2'b01: begin // CSRRW / CSRRWI
                            case (csr_addr)
                                MSTATUS  : mstatus_d  = (mstatus_q & ~MSTATUS_MASK) | (wdata_operand & MSTATUS_MASK);
                                MTVEC    : mtvec_d    = wdata_operand;
                                MSCRATCH : mscratch_d = wdata_operand;
                                MEPC     : mepc_d     = wdata_operand;
                                MCAUSE   : mcause_d   = wdata_operand;
                                MTVAL    : mtval_d    = wdata_operand;
                                MIE      : mie_d      = wdata_operand;
                                default  : illeg_instr_w = 1'b1;
                            endcase
                        end   

                        2'b10: begin // CSRRS / CSRRSI
                            case (csr_addr)
                                MSTATUS  : if (wdata_operand != 0) mstatus_d  = mstatus_q | (wdata_operand & MSTATUS_MASK);
                                MTVEC    : if (wdata_operand != 0) mtvec_d    = mtvec_q    | wdata_operand;
                                MSCRATCH : if (wdata_operand != 0) mscratch_d = mscratch_q | wdata_operand;
                                MEPC     : if (wdata_operand != 0) mepc_d     = mepc_q     | wdata_operand;
                                MCAUSE   : if (wdata_operand != 0) mcause_d   = mcause_q   | wdata_operand;
                                MTVAL    : if (wdata_operand != 0) mtval_d    = mtval_q    | wdata_operand;
                                MIE      : if (wdata_operand != 0) mie_d      = mie_q      | wdata_operand;
                                // Addresses not in this write table (e.g. misa, mip, mcycle,
                                // minstret, ...) are legal to READ via CSRRS/CSRRSI with a zero
                                // operand -- only flag illegal if an actual write was attempted.
                                default  : if (wdata_operand != 0) illeg_instr_w = 1'b1;
                            endcase
                        end 

                        2'b11: begin // CSRRC / CSRRCI 
                            case (csr_addr)
                                MSTATUS  : if (wdata_operand != 0) mstatus_d  = mstatus_q & ~(wdata_operand & MSTATUS_MASK);
                                MTVEC    : if (wdata_operand != 0) mtvec_d    = mtvec_q    & ~wdata_operand;
                                MSCRATCH : if (wdata_operand != 0) mscratch_d = mscratch_q & ~wdata_operand;
                                MEPC     : if (wdata_operand != 0) mepc_d     = mepc_q     & ~wdata_operand;
                                MCAUSE   : if (wdata_operand != 0) mcause_d   = mcause_q   & ~wdata_operand;
                                MTVAL    : if (wdata_operand != 0) mtval_d    = mtval_q    & ~wdata_operand;
                                MIE      : if (wdata_operand != 0) mie_d      = mie_q      & ~wdata_operand;
                                // Same reasoning as the CSRRS default above.
                                default  : if (wdata_operand != 0) illeg_instr_w = 1'b1;
                            endcase
                        end

                        default: ;
                    endcase
                end
            end

            // Handle Illegal Instruction Trap
            if (illeg_instr_r || illeg_instr_w) begin
                mepc_d           = current_pc;
                mcause_d         = 32'd2; // Illegal instruction trap
                mtval_d          = 32'd0;  
                mstatus_d[7]     = mstatus_q[3];     
                mstatus_d[3]     = 1'b0;             
                mstatus_d[12:11] = priv_q;           
                priv_d           = 2'b11;            
                PC_Next          = {mtvec_q[31:2], 2'b00};
                pc_en            = 1'b1;
            end
        end
    end

    // =================================== FF Update ========================================== //
    // NOTE: asynchronous, active-LOW reset (negedge reset, if (!reset)).
    // Confirm this matches your top-level reset convention before integrating.
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            priv_q     <= 2'b11; // Reset to Machine mode
            mstatus_q  <= 32'b0;
            mtvec_q    <= 32'b0; 
            mscratch_q <= 32'b0;
            mepc_q     <= 32'b0;
            mcause_q   <= 32'b0;
            mtval_q    <= 32'b0;
            mie_q      <= 32'b0;
            mcycle_q   <= 64'b0;
            minstret_q <= 64'b0;
        end else begin
            // Free-running hardware cycle counter
            mcycle_q <= mcycle_q + 1'b1;

            if (!stall_E_int) begin   
                priv_q     <= priv_d;
                mstatus_q  <= mstatus_d;
                mtvec_q    <= mtvec_d;
                mscratch_q <= mscratch_d;
                mepc_q     <= mepc_d;
                mcause_q   <= mcause_d;
                mtval_q    <= mtval_d;
                mie_q      <= mie_d;
                
                if (valid_E) begin
                    minstret_q <= minstret_q + 1'b1;
                end
            end
        end
    end

endmodule