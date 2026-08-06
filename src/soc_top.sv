`timescale 1ns / 1ps
 
module soc_top(
    input  logic clk,
    input  logic rst,          // Asynchronous reset input

    input  logic [31:0] gpio_in,
    output logic [31:0] gpio_out,
    output logic [31:0] gpio_oe
);

logic rst_sync0;
logic rst_sync_final;

//--------------------------------------------------
// Reset Synchronizer
// Asynchronous assertion
// Synchronous de-assertion
//--------------------------------------------------

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        rst_sync0      <= 1'b1;
        rst_sync_final <= 1'b1;
    end
    else begin
        rst_sync0      <= 1'b0;
        rst_sync_final <= rst_sync0;
    end
end

//--------------------------------------------------
// Internal Signals
//--------------------------------------------------

logic [31:0] instr_addr;
logic [31:0] instr_rdata;

logic [31:0] data_addr;
logic [31:0] data_wdata;
logic [31:0] data_rdata;
logic        data_we;
logic [3:0]  data_be;

// SRAM Signals
logic [31:0] sram_addr;
logic [31:0] sram_wdata;
logic [31:0] sram_rdata;
logic        sram_we;

// GPIO Signals
logic [31:0] gpio_addr;
logic [31:0] gpio_wdata;
logic [31:0] gpio_rdata;
logic        gpio_we;

logic [31:0] rom_rdata;

//--------------------------------------------------
// CPU
//--------------------------------------------------

top_module_pipeline cpu_core(
    .clk(clk),
    .rst(rst_sync_final),          // <-- Use synchronized reset

    .instr_addr(instr_addr),
    .instr_rdata(instr_rdata),

    .data_addr(data_addr),
    .data_wdata(data_wdata),
    .data_rdata(data_rdata),
    .data_we(data_we),
    .data_be(data_be)
);

//--------------------------------------------------
// Instruction Memory
//--------------------------------------------------

instruction_memory imem(
    .A(instr_addr),
    .rd(instr_rdata)
);

//--------------------------------------------------
// SRAM
//--------------------------------------------------

data_memory sram(
    .clk(clk),
    .A(sram_addr),
    .WD(sram_wdata),
    .WE(sram_we),
    .RD(sram_rdata),
    .BE(data_be)
);

//--------------------------------------------------
// GPIO
//--------------------------------------------------

gpio gpio_instantiation(
    .clk(clk),
    .reset(rst_sync_final),        // <-- Use synchronized reset

    .addr(gpio_addr),
    .wdata(gpio_wdata),
    .we(gpio_we),
    .rdata(gpio_rdata),

    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_oe(gpio_oe)
);

//--------------------------------------------------
// Interconnect
//--------------------------------------------------

interconnect_01 bus(

    // CPU
    .cpu_addr(data_addr),
    .cpu_wdata(data_wdata),
    .cpu_we(data_we),
    .cpu_rdata(data_rdata),

    .rom_rdata(rom_rdata),

    // SRAM
    .sram_addr(sram_addr),
    .sram_wdata(sram_wdata),
    .sram_we(sram_we),
    .sram_rdata(sram_rdata),

    // GPIO
    .gpio_addr(gpio_addr),
    .gpio_wdata(gpio_wdata),
    .gpio_we(gpio_we),
    .gpio_rdata(gpio_rdata)
);

endmodule