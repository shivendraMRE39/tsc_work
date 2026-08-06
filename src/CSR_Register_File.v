`timescale 1ns / 1ps

module CSR_Register_File #(
    parameter DATA_BUS_WIDTH  = 32
) (
    input                                 clk, reset, csr_en,
    input                                 stall_E_int, // Stall signal
    input                                 valid_E,
    input  [1:0]                          funct3b21,   
    input  [11:0]                         csr_addr,
    input  [DATA_BUS_WIDTH-1 : 0]         csr_data, PC,
    
    // =======================================================================
    // === HARDWARE INTERRUPT PINS ===
    // =======================================================================
    input wire                            timer_irq,    // Connects to CLINT (MTIP - Bit 7)
    input wire                            software_irq, // Connects to CLINT (MSIP - Bit 3)
    input wire                            external_irq, // Connects to PLIC  (MEIP - Bit 11)
    // =======================================================================
    
    
    input wire                            bus_fault_M,
    input wire                            is_store_M,

    output                                illegal_instruction,
    output reg                            pc_en,
    output reg [DATA_BUS_WIDTH-1 : 0]     RD,
    output reg [DATA_BUS_WIDTH-1 : 0]     PC_Next
);
    reg illeg_instr_r, illeg_instr_w;
    assign illegal_instruction = illeg_instr_r | illeg_instr_w; 

    reg [1:0] priv_q = 2'b11, priv_d = 2'b11; // Default to Machine Mode (11)

// ============================ CSR ADDRESS DEFINITIONS  ================================== //
                                           
    localparam MVENDORID = 12'hF11, MARCHID = 12'hF12, MIMPID = 12'hF13, MHARTID = 12'hF14; 
    localparam MSTATUS = 12'h300, MISA = 12'h301, MTVEC = 12'h305; 
    localparam MSCRATCH = 12'h340, MEPC = 12'h341, MCAUSE = 12'h342, MTVAL = 12'h343; 
    localparam MIE = 12'h304, MIP = 12'h344;

// ========================= PHYSICAL REGISTER FLIP-FLOPS ================================= //

    // --- Machine Information Registers ---
    reg [DATA_BUS_WIDTH-1 : 0] mvendorid = 32'b0 ;  
    reg [DATA_BUS_WIDTH-1 : 0] marchid   = 32'b0 ;    
    reg [DATA_BUS_WIDTH-1 : 0] mimpid    = 32'h0 ;     
    reg [DATA_BUS_WIDTH-1 : 0] mhartid   = 32'b0 ;    

    // --- Machine Trap Setup ---
    reg [DATA_BUS_WIDTH-1 : 0] misa = 32'h4000_1101;       
    reg [DATA_BUS_WIDTH-1 : 0] mstatus_q, mstatus_d;    
    reg [DATA_BUS_WIDTH-1 : 0] mtvec_q, mtvec_d;      

    // --- Machine Interrupt Enable & Pending ---
    reg [DATA_BUS_WIDTH-1 : 0] mie_q, mie_d;          // Machine Interrupt Enable
    
    // Bit 11 = MEIP, Bit 7 = MTIP, Bit 3 = MSIP
    wire [DATA_BUS_WIDTH-1 : 0] mip_wire = {20'b0, external_irq, 3'b0, timer_irq, 3'b0, software_irq, 3'b0};

    // --- Machine Trap Handling ---
    reg [DATA_BUS_WIDTH-1 : 0] mscratch_q, mscratch_d;   
    reg [DATA_BUS_WIDTH-1 : 0] mepc_q, mepc_d;        
    reg [DATA_BUS_WIDTH-1 : 0] mcause_q, mcause_d;      
    reg [DATA_BUS_WIDTH-1 : 0] mtval_q, mtval_d;      
    
    // =======================================================================
    // === PIPELINE BUBBLE RECOVERY LATCH ===
    // Tracks the last valid PC to safely recover from traps during bubbles
    // =======================================================================
    reg [DATA_BUS_WIDTH-1 : 0] recovery_pc;
    always @(posedge clk or negedge reset) begin
        if (!reset) recovery_pc <= 32'b0;
        else if (PC != 32'b0) recovery_pc <= PC; 
    end
    
    

// ==================================== Reading =========================================== //
    always @(*) begin
        illeg_instr_r = 1'b0; 
        if (priv_q < csr_addr[9:8]) begin
            illeg_instr_r = 1'b1;
            RD = 32'd0; 
        end
        else if (csr_en && funct3b21 != 2'b00) begin
            case (csr_addr)
                MVENDORID  : RD = mvendorid  ;
                MARCHID    : RD = marchid    ;
                MIMPID     : RD = mimpid     ;
                MHARTID    : RD = mhartid    ;
                MISA       : RD = misa       ;
                MSTATUS    : RD = mstatus_q  ;
                MTVEC      : RD = mtvec_q    ;
                MSCRATCH   : RD = mscratch_q ;
                MEPC       : RD = mepc_q     ;
                MCAUSE     : RD = mcause_q   ;
                MTVAL      : RD = mtval_q    ;
                MIE        : RD = mie_q      ;
                MIP        : RD = mip_wire   ; // Software reads the physical pins
                default    : begin
                    illeg_instr_r = 1'b1;
                    RD = 32'd0;
                end
            endcase
        end else RD = 32'd0;
    end

// ==================================== Writing =========================================== //
    always @(*) begin
        illeg_instr_w = 1'b0;
        pc_en      = 1'b0;
        priv_d     = priv_q;
        mstatus_d  = mstatus_q;
        mtvec_d    = mtvec_q;
        mscratch_d = mscratch_q;
        mepc_d     = mepc_q;
        mcause_d   = mcause_q;
        mtval_d    = mtval_q;
        mie_d      = mie_q;
        PC_Next    = PC;
        
        
        // =======================================================================
        // === SYNCHRONOUS EXCEPTIONS (Highest Priority) ===
        // =======================================================================
        if (bus_fault_M) begin
            mepc_d           = (PC != 32'b0) ? PC : recovery_pc;
            mcause_d         = is_store_M ? 32'd7 : 32'd5; // 7 = Store Fault, 5 = Load Fault
            mtval_d          = 32'd0; // Can hold faulting address if desired
            mstatus_d[7]     = mstatus_q[3];
            mstatus_d[3]     = 1'b0;                     
            mstatus_d[12:11] = priv_q;
            priv_d           = 2'b11;
            PC_Next          = {mtvec_q[31:2], 2'b00};
            pc_en            = 1'b1;
        end
        
        
        // =======================================================================
        // === ASYNCHRONOUS HARDWARE INTERRUPT TRIGGER WITH RISC-V PRIORITY ===
        // =======================================================================
        
        // 1. Check External Interrupt (Highest Priority)
        if (mstatus_q[3] && mie_q[11] && mip_wire[11] && valid_E && !stall_E_int) begin
            mepc_d           = PC;                       
            mcause_d         = 32'h8000_000B;  
            mstatus_d[7]     = mstatus_q[3];
            mstatus_d[3]     = 1'b0;                     
            mstatus_d[12:11] = priv_q;
            priv_d           = 2'b11;
            PC_Next          = {mtvec_q[31:2], 2'b00};
            pc_en            = 1'b1;
        end
        // 2. Check Software Interrupt (Middle Priority)
        else if (mstatus_q[3] && mie_q[3] && mip_wire[3] && valid_E && !stall_E_int) begin
            mepc_d           = PC;                       
            mcause_d         = 32'h8000_0003;
            mstatus_d[7]     = mstatus_q[3];             
            mstatus_d[3]     = 1'b0;                     
            mstatus_d[12:11] = priv_q;
            priv_d           = 2'b11;
            PC_Next          = {mtvec_q[31:2], 2'b00};
            pc_en            = 1'b1;
        end
        // 3. Check Timer Interrupt (Lowest Priority)
        else if (mstatus_q[3] && mie_q[7] && mip_wire[7] && valid_E && !stall_E_int) begin
            mepc_d           = PC;                                              
            mcause_d         = 32'h8000_0007;
            mstatus_d[7]     = mstatus_q[3];             
            mstatus_d[3]     = 1'b0;                     
            mstatus_d[12:11] = priv_q;
            priv_d           = 2'b11;
            PC_Next          = {mtvec_q[31:2], 2'b00};
            pc_en            = 1'b1;
        end

        else if (csr_en) begin
            case (funct3b21)
                2'b00: begin  // privilege instructions
                    case (csr_addr) 
                        12'h000: begin             // ecall
                            mepc_d               = (PC != 32'b0) ? PC : mepc_q;                        
                            mstatus_d[7]         = mstatus_q[3];             
                            mstatus_d[3]         = 1'b0;                     
                            mstatus_d[12:11]     = priv_q;      
                            priv_d               = 2'b11;       
                            PC_Next              = {mtvec_q[31:2], 2'b00};     
                            pc_en                = 1'b1;
                            case (priv_q)
                                2'b00: mcause_d  = 32'd8;      
                                2'b01: mcause_d  = 32'd9;      
                                2'b11: mcause_d  = 32'd11;     
                            endcase 
                        end
                        12'h001: begin             // ebreak                     
                            mepc_d               = (PC != 32'b0) ? PC : mepc_q;                        
                            mstatus_d[7]         = mstatus_q[3];             
                            mstatus_d[3]         = 1'b0;                     
                            mstatus_d[12:11]     = priv_q;      
                            priv_d               = 2'b11;       
                            PC_Next              = {mtvec_q[31:2], 2'b00};     
                            pc_en                = 1'b1;
                            mcause_d             = 32'd3;                                         
                        end
                        12'h302: begin             // mret
                            if (priv_q == 2'b11) begin
                                PC_Next              = mepc_q;  
                                pc_en                = 1'b1;
                                priv_d               = mstatus_q[12:11];             
                                mstatus_d[12:11]     = 2'b00;                
                                mstatus_d[3]         = mstatus_q[7];    
                                mstatus_d[7]         = 1'b1; 
                            end
                            else illeg_instr_w = 1'b1;
                        end
                        default:  illeg_instr_w = 1'b1;
                    endcase            
                end

                2'b01: begin         //CSRRW
                    if (priv_q < csr_addr[9:8]) illeg_instr_w = 1'b1;
                    else begin
                        illeg_instr_w = 1'b0;
                        case (csr_addr)
                            MSTATUS    : mstatus_d  = csr_data ;
                            MTVEC      : mtvec_d    = csr_data ;
                            MSCRATCH   : mscratch_d = csr_data ;
                            MEPC       : mepc_d     = csr_data ;
                            MCAUSE     : mcause_d   = csr_data ;
                            MTVAL      : mtval_d    = csr_data ;
                            MIE        : mie_d      = csr_data ;
                            default    : illeg_instr_w = 1'b1;
                        endcase
                    end  
                end   

                2'b10: begin         //CSRRS
                    if (priv_q < csr_addr[9:8]) illeg_instr_w = 1'b1;
                    else if (csr_data == 0) begin
                        illeg_instr_w = 1'b0;
                    end
                    else begin
                        illeg_instr_w = 1'b0;
                        case (csr_addr)
                            MSTATUS  : mstatus_d  = mstatus_q  | csr_data ;
                            MTVEC    : mtvec_d    = mtvec_q    | csr_data ;
                            MSCRATCH : mscratch_d = mscratch_q | csr_data ;
                            MEPC     : mepc_d     = mepc_q     | csr_data ;
                            MCAUSE   : mcause_d   = mcause_q   | csr_data ;
                            MTVAL    : mtval_d    = mtval_q    | csr_data ;
                            MIE      : mie_d      = mie_q      | csr_data ;
                            default  : illeg_instr_w = 1'b1;
                        endcase
                    end
                end 

                2'b11:  begin        //CSRRC  
                    if (priv_q < csr_addr[9:8]) illeg_instr_w = 1'b1;
                    else if (csr_data == 0) begin
                        illeg_instr_w = 1'b0;
                    end
                    else begin
                        case (csr_addr)
                            MSTATUS  : mstatus_d  = mstatus_q  & ~csr_data ;
                            MTVEC    : mtvec_d    = mtvec_q    & ~csr_data ;
                            MSCRATCH : mscratch_d = mscratch_q & ~csr_data ;
                            MEPC     : mepc_d     = mepc_q     & ~csr_data ;
                            MCAUSE   : mcause_d   = mcause_q   & ~csr_data ;
                            MTVAL    : mtval_d    = mtval_q    & ~csr_data ;
                            MIE      : mie_d      = mie_q      & ~csr_data ;
                            default  : illeg_instr_w = 1'b1;
                        endcase
                    end
                end
            endcase
            if (illeg_instr_r || illeg_instr_w) begin
                mepc_d           = (PC != 32'b0) ? PC : mepc_q;
                mcause_d         = 32'd2;  // illegal instruction
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
    always @(posedge clk or negedge reset) begin
        if(!reset) begin
            priv_q     <= 2'b11; // Reset to Machine mode
            mstatus_q  <= 32'b0;
            mtvec_q    <= 32'b0; 
            mscratch_q <= 32'b0;
            mepc_q     <= 32'b0;
            mcause_q   <= 32'b0;
            mtval_q    <= 32'b0;
            mie_q      <= 32'b0;
       end else if (!stall_E_int) begin   
            priv_q     <= priv_d;
            mstatus_q  <= mstatus_d;
            mtvec_q    <= mtvec_d;
            mscratch_q <= mscratch_d;
            mepc_q     <= mepc_d;
            mcause_q   <= mcause_d;
            mtval_q    <= mtval_d;
            mie_q      <= mie_d;
        end
    end

endmodule