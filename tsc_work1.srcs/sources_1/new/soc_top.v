`timescale 1ns / 1ps
// =============================================================================
// soc_top
//
// CPU data-memory path:
//     pipline_top  -->  axi4lite_bus_top (adapter absorbed internally)
//                        (axi_master --> axi4lite_interconnect -->
//                         { axi4lite_rom, axi4lite_sram, axi4lite_clint })
//
// Address map (decoded by address_decoder.sv inside the interconnect):
//     0x0000_0000 - 0x0000_FFFF : ROM   (64KB window, DEPTH=4096 words, read-only)
//     0x1000_0000 - 0x1000_FFFF : SRAM  (64KB window, DEPTH=4096 words, block RAM)
//     0x2000_0000 - 0x2000_FFFF : CLINT (64KB window, msip/mtime/mtimecmp)
//     anything else              : DECERR (2'b11)
//
// Interrupt Architecture:
//     - clint_msip -> pipline_top.sw_irq (MSIP: Machine Software Interrupt)
//     - clint_mtip -> pipline_top.timer_irq[1] (MTIP: Machine Timer Interrupt)
//     - ext_irq    -> pipline_top.ext_irq (MEIP: Machine External Interrupt)
// =============================================================================
module soc_top #(
    parameter integer RTC_DIVIDER = 100    // Clock divider to generate rtc_tick from clk
)(
    input          clk,
    input          rst,
    input   [7:0]  gpio_in,     // kept for pin-constraint compat
    output  [31:0] gpio_out,    // kept for pin-constraint compat -- tied to 0
    input          ext_irq
);

    // ====================================================
    // RTC (Real-Time Clock) Reference Tick Generator
    // ====================================================
    reg [31:0] rtc_cnt;
    reg        rtc_tick;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            rtc_cnt  <= 32'd0;
            rtc_tick <= 1'b0;
        end else if (RTC_DIVIDER <= 1) begin
            rtc_cnt  <= 32'd0;
            rtc_tick <= 1'b1;
        end else if (rtc_cnt >= (RTC_DIVIDER - 1)) begin
            rtc_cnt  <= 32'd0;
            rtc_tick <= 1'b1;
        end else begin
            rtc_cnt  <= rtc_cnt + 32'd1;
            rtc_tick <= 1'b0;
        end
    end

    // ====================================================
    // CPU <-> MEMORY INTERCONNECT WIRES
    // ====================================================
    wire [31:0] ALUResultM;
    wire [31:0] WriteDataM;      // formatted StoreDataM from the LSU (lsu.sv)
    wire        MemWriteM;
    wire [2:0]  funct3M;
    wire [31:0] ReadDataM;
    wire        MemReadM;
    wire [3:0]  byte_strobeM;    // formatted ByteEnableM from the LSU
    wire        pready;
    wire        mem_done;

    // ====================================================
    // Interrupt Lines from CLINT
    // ====================================================
    wire        clint_msip;
    wire        clint_mtip;
    wire [1:0]  timer_irq_vec = {clint_mtip, 1'b0};

    // ====================================================
    // CPU PIPELINE CORE
    // ====================================================
    pipline_top cpu (
        .clk(clk),
        .rst(rst),
        .pready(pready),
        .ALUResultM(ALUResultM),
        .WriteDataM(WriteDataM),
        .byte_strobeM(byte_strobeM),
        .MemWriteM(MemWriteM),
        .funct3M(funct3M),
        .ReadDataM(ReadDataM),
        .MemReadM(MemReadM),
        .mem_done(mem_done),
        .timer_irq(timer_irq_vec),
        .sw_irq(clint_msip),
        .ext_irq(ext_irq),
        .trap_taken()
    );

    // ====================================================
    // AXI4-LITE BUS: CPU-side adapter
    //                + master + interconnect + ROM/SRAM/CLINT slaves
    // ====================================================
    axi4lite_bus_top #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) u_axi_bus (
        .ACLK         (clk),
        .ARESETN      (rst),
        .rtc_i        (rtc_tick),

        .addr         (ALUResultM),
        .wdata        (WriteDataM),
        .memwrite     (MemWriteM),
        .memread      (MemReadM),
        .byte_strobe  (byte_strobeM),
        .rdata        (ReadDataM),
        .pready       (pready),
        .mem_done     (mem_done),

        .msip_o       (clint_msip),
        .mtip_o       (clint_mtip)
    );

    // gpio_in is intentionally unused, gpio_out tied to 0
    assign gpio_out = 32'h0000_0000;
    wire _unused_gpio_in = &gpio_in;   // silences "unused input" lint warnings

endmodule
