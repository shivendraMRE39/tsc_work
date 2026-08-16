`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: clint
// Description: Single-hart Core-Local Interruptor, purpose-built for a
//              distress-signal / sensor-monitoring SoC:
//                - mtimecmp/mtime drive the periodic "time to sample the
//                  sensors" timer interrupt (MTIP) -- the primary use of
//                  this module in this system.
//                - msip provides a software-triggered interrupt, intended
//                  for fast-path/slow-path analysis handoff or self-test,
//                  not for inter-hart signaling (there is only one hart).
//
// Register map (relative to CLINT_BASE), standard RISC-V CLINT offsets:
//     0x0000        msip        (32-bit, bit 0 meaningful)
//     0x4000/0x4004 mtimecmp_lo/hi (64-bit, two words)
//     0xBFF8/0xBFFC mtime_lo/hi    (64-bit, two words)
//
// mtime increments on rtc_i rising edges (synchronized into this clock
// domain), NOT every system clock cycle -- this decouples the sensor
// sampling rate from CPU clock speed, same as real hardware.
//////////////////////////////////////////////////////////////////////////////////

module clint(
    input  logic        clk,
    input  logic         rst,          // active-low async reset (matches rest of design)
    input  logic         rtc_i,        // real-time reference tick (see soc_top.sv's divider)

    // Bus side -- addr is RELATIVE to CLINT_BASE (memory_interface.sv subtracts
    // the base before presenting it here)
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        we,
    input  logic [3:0]  byte_enable,
    output logic [31:0] rdata,

    // Interrupt outputs
    output logic        msip_o,       // -> software_irq (fast-path/slow-path handoff, self-test)
    output logic        mtip_o        // -> timer_irq[1] (periodic sensor-sampling tick)
);

    //------------------------------------------------------------
    // Register Offsets (relative to CLINT_BASE)
    //------------------------------------------------------------
    localparam MSIP_OFFSET        = 16'h0000;
    localparam MTIMECMP_LO_OFFSET = 16'h4000;
    localparam MTIMECMP_HI_OFFSET = 16'h4004;
    localparam MTIME_LO_OFFSET    = 16'hBFF8;
    localparam MTIME_HI_OFFSET    = 16'hBFFC;

    //------------------------------------------------------------
    // Internal Registers
    //------------------------------------------------------------
    logic        msip_q;
    logic [63:0] mtimecmp_q;
    logic [63:0] mtime_q;

    //------------------------------------------------------------
    // rtc_i synchronizer (2-stage) + rising-edge detector
    //------------------------------------------------------------
    logic [1:0] rtc_sync_q;
    logic       rtc_tick;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) rtc_sync_q <= 2'b00;
        else      rtc_sync_q <= {rtc_sync_q[0], rtc_i};
    end
    assign rtc_tick = rtc_sync_q[0] & ~rtc_sync_q[1];  // rising-edge pulse, 1 clk wide

    //------------------------------------------------------------
    // Byte-enable-aware write helper
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
    // mtime: increments once per rtc_tick -- this is the sensor-sampling
    // time base. Software can also write it directly (rare, spec-legal,
    // used for time sync).
    //------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            mtime_q <= 64'd0;
        end else if (we && addr[15:0] == MTIME_LO_OFFSET) begin
            mtime_q[31:0] <= apply_be(mtime_q[31:0], wdata, byte_enable);
        end else if (we && addr[15:0] == MTIME_HI_OFFSET) begin
            mtime_q[63:32] <= apply_be(mtime_q[63:32], wdata, byte_enable);
        end else if (rtc_tick) begin
            mtime_q <= mtime_q + 64'd1;
        end
    end

    //------------------------------------------------------------
    // mtimecmp: software-programmed "next sample time" deadline.
    // Resets to all-1s so MTIP cannot spuriously fire before the sensor
    // polling loop configures a real first deadline.
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
    // msip: software-triggered interrupt (fast-path/slow-path handoff,
    // self-test injection). Only bit 0 is architecturally meaningful.
    //------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            msip_q <= 1'b0;
        else if (we && addr[15:0] == MSIP_OFFSET && byte_enable[0])
            msip_q <= wdata[0];
    end

    //------------------------------------------------------------
    // Read Mux
    //------------------------------------------------------------
    always_comb begin
        case (addr[15:0])
            MSIP_OFFSET:        rdata = {31'b0, msip_q};
            MTIMECMP_LO_OFFSET: rdata = mtimecmp_q[31:0];
            MTIMECMP_HI_OFFSET: rdata = mtimecmp_q[63:32];
            MTIME_LO_OFFSET:    rdata = mtime_q[31:0];
            MTIME_HI_OFFSET:    rdata = mtime_q[63:32];
            default:            rdata = 32'd0;
        endcase
    end

    //------------------------------------------------------------
    // Interrupt Outputs
    //------------------------------------------------------------
    assign msip_o = msip_q;
    assign mtip_o = (mtime_q >= mtimecmp_q);

endmodule