`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: clint
// Description: Core-Local Interruptor -- provides MSIP (software interrupt)
//              and MTIP (timer interrupt) for a single-hart system, using the
//              standard SiFive/de-facto CLINT relative register offsets:
//                  0x0000        msip        (32-bit, bit 0 meaningful)
//                  0x4000/0x4004 mtimecmp_lo/hi (64-bit, split into two words)
//                  0xBFF8/0xBFFC mtime_lo/hi    (64-bit, split into two words)
//              mtime is free-running, incrementing every clock cycle (not
//              scaled to any real-time reference -- for cycle-accurate
//              simulation/timing, compute mtimecmp offsets in clock cycles).
//
// Bus interface matches the simple synchronous-write/combinational-read style
// already used by data_memory.sv in this SoC, so it plugs into
// memory_interface.sv the same way the local RAM does.
//////////////////////////////////////////////////////////////////////////////////

module clint(
    input  logic        clk,
    input  logic        rst,          // active-low async reset (matches rest of design)

    // Bus side -- addr is RELATIVE to CLINT_BASE (memory_interface.sv subtracts
    // the base before presenting it here)
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        we,
    input  logic [3:0]  byte_enable,
    output logic [31:0] rdata,

    // Interrupt outputs
    output logic         msip_o,      // -> software_irq
    output logic         mtip_o       // -> timer_irq[1]
);

    //------------------------------------------------------------
    // Internal Registers
    //------------------------------------------------------------
    logic        msip_q;
    logic [63:0] mtimecmp_q;
    logic [63:0] mtime_q;

    //------------------------------------------------------------
    // Register Offsets (relative to CLINT_BASE)
    //------------------------------------------------------------
    localparam MSIP_OFFSET        = 16'h0000;
    localparam MTIMECMP_LO_OFFSET = 16'h4000;
    localparam MTIMECMP_HI_OFFSET = 16'h4004;
    localparam MTIME_LO_OFFSET    = 16'hBFF8;
    localparam MTIME_HI_OFFSET    = 16'hBFFC;

    //------------------------------------------------------------
    // mtime: free-running counter, increments every clock cycle,
    // never stops except on reset.
    //------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            mtime_q <= 64'd0;
        else if (we && addr[15:0] == MTIME_LO_OFFSET)
            mtime_q[31:0] <= apply_be(mtime_q[31:0], wdata, byte_enable);
        else if (we && addr[15:0] == MTIME_HI_OFFSET)
            mtime_q[63:32] <= apply_be(mtime_q[63:32], wdata, byte_enable);
        else
            mtime_q <= mtime_q + 64'd1;
    end

    //------------------------------------------------------------
    // mtimecmp: software-programmed deadline. Reset to all-1s so
    // MTIP cannot spuriously assert before software configures a
    // real deadline (common convention, not spec-mandated).
    //------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            mtimecmp_q <= 64'hFFFFFFFF_FFFFFFFF;
        end else begin
            if (we && addr[15:0] == MTIMECMP_LO_OFFSET)
                mtimecmp_q[31:0] <= apply_be(mtimecmp_q[31:0], wdata, byte_enable);
            if (we && addr[15:0] == MTIMECMP_HI_OFFSET)
                mtimecmp_q[63:32] <= apply_be(mtimecmp_q[63:32], wdata, byte_enable);
        end
    end

    //------------------------------------------------------------
    // msip: software-controlled software-interrupt request. Only
    // bit 0 is architecturally meaningful; the rest of the word is
    // reserved (read back as 0).
    //------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            msip_q <= 1'b0;
        else if (we && addr[15:0] == MSIP_OFFSET && byte_enable[0])
            msip_q <= wdata[0];
    end

    //------------------------------------------------------------
    // Byte-enable-aware write helper (matches data_memory.sv's
    // per-byte write style)
    //------------------------------------------------------------
    function automatic logic [31:0] apply_be(
        input logic [31:0] old_val,
        input logic [31:0] new_val,
        input logic [3:0]  be
    );
        logic [31:0] result;
        begin
            result = old_val;
            if (be[0]) result[7:0]   = new_val[7:0];
            if (be[1]) result[15:8]  = new_val[15:8];
            if (be[2]) result[23:16] = new_val[23:16];
            if (be[3]) result[31:24] = new_val[31:24];
            apply_be = result;
        end
    endfunction

    //------------------------------------------------------------
    // Read Mux (combinational, matches data_memory.sv's async-read style)
    //------------------------------------------------------------
    always_comb begin
        case (addr[15:0])
            MSIP_OFFSET:        rdata = {31'b0, msip_q};
            MTIMECMP_LO_OFFSET: rdata = mtimecmp_q[31:0];
            MTIMECMP_HI_OFFSET: rdata = mtimecmp_q[63:32];
            MTIME_LO_OFFSET:    rdata = mtime_q[31:0];
            MTIME_HI_OFFSET:    rdata = mtime_q[63:32];
            default:             rdata = 32'd0;
        endcase
    end

    //------------------------------------------------------------
    // Interrupt Outputs
    //------------------------------------------------------------
    assign msip_o = msip_q;
    assign mtip_o = (mtime_q >= mtimecmp_q);

endmodule