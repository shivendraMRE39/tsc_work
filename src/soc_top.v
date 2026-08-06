//`timescale 1ns / 1ps

//module soc_top(
//    input          clk,
//    input          rst,
//    input   [7:0]  gpio_in,
//    output  [31:0] gpio_out,
//    input          sw_irq,
//    input          ext_irq
//);

//    // ====================================================
//    // INTERCONNECT WIRES
//    // ====================================================
//    wire [31:0] ALUResultM;
//    wire [31:0] WriteDataM;
//    wire        MemWriteM;
//    wire [2:0]  funct3M;
//    wire [31:0] ReadDataM;
//    wire        MemReadM;
//    wire [3:0]  byte_strobeM;

//    wire        pready;
//    wire        mem_done;
//    wire [1:0]  timer_irq;

//    wire [11:0] apb_addr;
//    wire [31:0] apb_wdata;
//    wire [31:0] apb_rdata;
//    wire        apb_write;
//    wire        apb_read;
//    wire        transfer;
//    wire        apb_pready_out;
//    wire        apb_mem_done_out;

//    wire [31:0] ram_addr;
//    wire [31:0] ram_wdata;
//    wire        ram_we;
//    wire [3:0]  ram_be;
//    wire [31:0] ram_rdata;

//    // ====================================================
//    // CPU PIPELINE CORE
//    // ====================================================
//    pipline_top cpu (
//        .clk(clk),
//        .rst(rst),
//        .pready(pready),
//        .ALUResultM(ALUResultM),
//        .WriteDataM(WriteDataM),
//        .byte_strobeM(byte_strobeM),
//        .MemWriteM(MemWriteM),
//        .funct3M(funct3M),
//        .ReadDataM(ReadDataM),
//        .MemReadM(MemReadM),
//        .mem_done(mem_done),
//        .timer_irq(timer_irq),
//        .sw_irq(sw_irq),
//        .ext_irq(ext_irq),
//        .trap_taken()
//    );

//    // ====================================================
//    // SYSTEM MEMORY INTERFACE (GLUE)
//    // ====================================================
//    memory_interface mem_if (
//        .clk(clk),
//        .rst(rst),
//        .addr(ALUResultM),
//        .wdata(WriteDataM),
//        .memwrite(MemWriteM),
//        .memread(MemReadM),
//        .byte_strobeM(byte_strobeM),
//        .rdata(ReadDataM),
//        .pready(pready),
//        .mem_done(mem_done),
//        .apb_addr(apb_addr),
//        .apb_wdata(apb_wdata),
//        .apb_write(apb_write),
//        .apb_read(apb_read),
//        .transfer(transfer),
//        .apb_rdata(apb_rdata),
//        .apb_pready(apb_pready_out),
//        .apb_mem_done(apb_mem_done_out),
//        .ram_addr(ram_addr),
//        .ram_wdata(ram_wdata),
//        .ram_we(ram_we),
//        .ram_be(ram_be),
//        .ram_rdata(ram_rdata)
//    );

//    // ====================================================
//    // APB SYSTEM BUS TOP
//    // ====================================================
//    apb_top apb_sys (
//        .pclk(clk),
//        .presetn(rst),
//        .transfer(transfer),
//        .read(apb_read),
//        .write(apb_write),
//        .apb_write_paddr(apb_addr),
//        .apb_read_paddr(apb_addr),
//        .apb_write_data(apb_wdata),
//        .pslverr(), 
//        .pready_out(apb_pready_out),
//        .apb_read_data_out(apb_rdata),
//        .gpio_out(gpio_out),
//        .gpio_in(gpio_in),
//        .mem_done(apb_mem_done_out),
//        .timer_irq(timer_irq)
//    );

//    // ====================================================
//    // PARALLEL HIGH-SPEED DATA RAM
//    // ====================================================
//    data_memory u_local_ram (
//        .clk(clk),
//        .rst(rst),
//        .A(ram_addr),
//        .WD(ram_wdata),
//        .WE(ram_we),
//        .ByteEnable(ram_be),
//        .RD(ram_rdata)
//    );

//endmodule
`timescale 1ns / 1ps
module soc_top(
    input          clk,
    input          rst,
    input   [7:0]  gpio_in,
    output  [31:0] gpio_out,
    input          ext_irq
    // NOTE: sw_irq removed. Real hardware has no external MSIP-bypass pin --
    // software interrupts are requested purely by writing CLINT's msip
    // register from software (a self-IPI). See clint.sv / CLINT_BASE below.
);
    // ====================================================
    // INTERCONNECT WIRES
    // ====================================================
    wire [31:0] ALUResultM;
    wire [31:0] WriteDataM;
    wire        MemWriteM;
    wire [2:0]  funct3M;
    wire [31:0] ReadDataM;
    wire        MemReadM;
    wire [3:0]  byte_strobeM;
    wire        pready;
    wire        mem_done;
    wire [1:0]  timer_irq_apb;      // apb_top's existing timer peripheral
                                    // output -- kept instantiated and
                                    // pollable over APB, but no longer wired
                                    // into the CPU's interrupt input (CLINT
                                    // is now authoritative for MTIP; see
                                    // integration notes)
    wire [1:0]  timer_irq_cpu;      // what actually feeds pipline_top
    wire [11:0] apb_addr;
    wire [31:0] apb_wdata;
    wire [31:0] apb_rdata;
    wire        apb_write;
    wire        apb_read;
    wire        transfer;
    wire        apb_pready_out;
    wire        apb_mem_done_out;
    wire [31:0] ram_addr;
    wire [31:0] ram_wdata;
    wire        ram_we;
    wire [3:0]  ram_be;
    wire [31:0] ram_rdata;

    // CLINT interconnect
    wire [31:0] clint_addr;
    wire [31:0] clint_wdata;
    wire        clint_we;
    wire [3:0]  clint_be;
    wire [31:0] clint_rdata;
    wire        clint_msip;
    wire        clint_mtip;

    // ====================================================
    // CPU PIPELINE CORE
    // ====================================================
    // timer_irq[1] (the only bit pipline_top's CSR module reads) is driven
    // solely by CLINT's mtip -- the standard, software-portable machine
    // timer interrupt source. timer_irq[0] carries the existing APB timer
    // peripheral's contribution through unchanged (still unused by the CSR
    // module today, preserved rather than dropped in case it's wired to
    // something later).
    assign timer_irq_cpu = {clint_mtip, timer_irq_apb[0]};

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
        .timer_irq(timer_irq_cpu),
        .sw_irq(clint_msip),        // CLINT is the sole software-interrupt source
        .ext_irq(ext_irq),
        .trap_taken()
    );

    // ====================================================
    // SYSTEM MEMORY INTERFACE (GLUE)
    // ====================================================
    memory_interface mem_if (
        .clk(clk),
        .rst(rst),
        .addr(ALUResultM),
        .wdata(WriteDataM),
        .memwrite(MemWriteM),
        .memread(MemReadM),
        .byte_strobeM(byte_strobeM),
        .rdata(ReadDataM),
        .pready(pready),
        .mem_done(mem_done),
        .apb_addr(apb_addr),
        .apb_wdata(apb_wdata),
        .apb_write(apb_write),
        .apb_read(apb_read),
        .transfer(transfer),
        .apb_rdata(apb_rdata),
        .apb_pready(apb_pready_out),
        .apb_mem_done(apb_mem_done_out),
        .ram_addr(ram_addr),
        .ram_wdata(ram_wdata),
        .ram_we(ram_we),
        .ram_be(ram_be),
        .ram_rdata(ram_rdata),
        .clint_addr(clint_addr),
        .clint_wdata(clint_wdata),
        .clint_we(clint_we),
        .clint_be(clint_be),
        .clint_rdata(clint_rdata)
    );

    // ====================================================
    // APB SYSTEM BUS TOP
    // ====================================================
    apb_top apb_sys (
        .pclk(clk),
        .presetn(rst),
        .transfer(transfer),
        .read(apb_read),
        .write(apb_write),
        .apb_write_paddr(apb_addr),
        .apb_read_paddr(apb_addr),
        .apb_write_data(apb_wdata),
        .pslverr(), 
        .pready_out(apb_pready_out),
        .apb_read_data_out(apb_rdata),
        .gpio_out(gpio_out),
        .gpio_in(gpio_in),
        .mem_done(apb_mem_done_out),
        .timer_irq(timer_irq_apb)
    );

    // ====================================================
    // PARALLEL HIGH-SPEED DATA RAM
    // ====================================================
    data_memory u_local_ram (
        .clk(clk),
        .rst(rst),
        .A(ram_addr),
        .WD(ram_wdata),
        .WE(ram_we),
        .ByteEnable(ram_be),
        .RD(ram_rdata)
    );

    // ====================================================
    // CLINT: software + timer interrupt controller
    // ====================================================
    clint u_clint (
        .clk(clk),
        .rst(rst),
        .addr(clint_addr),
        .wdata(clint_wdata),
        .we(clint_we),
        .byte_enable(clint_be),
        .rdata(clint_rdata),
        .msip_o(clint_msip),
        .mtip_o(clint_mtip)
    );

endmodule