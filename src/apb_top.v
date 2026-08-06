`timescale 1ns / 1ps

module apb_top(
    input          pclk,
    input          presetn,
    input          transfer,
    input          read,
    input          write,
    input   [11:0] apb_write_paddr,
    input   [11:0] apb_read_paddr,
    input   [31:0] apb_write_data,
    output         pslverr,
    output         pready_out,
    output  [31:0] apb_read_data_out,
    output  [31:0] gpio_out,
    input   [7:0]  gpio_in,
    output         mem_done,
    output  [1:0]  timer_irq
);

    wire [31:0] pwdata;
    wire [31:0] gpio_prdata;
    wire [31:0] timer_prdata;
    wire [31:0] prdata;
    wire [11:0] paddr;
    wire        pready;
    wire        penable;
    wire        pwrite;
    wire        psel1;
    wire        psel2;
    wire        timer_pready;
    wire        timer_pslverr;

    assign pready_out = pready;
    assign mem_done   = penable & pready;

    master_apb dut_master(
        .pclk(pclk),
        .presetn(presetn),
        .transfer(transfer),
        .read(read),
        .write(write),
        .apb_write_paddr(apb_write_paddr),
        .apb_read_paddr(apb_read_paddr),
        .apb_write_data(apb_write_data),
        .prdata(prdata),
        .pready(pready),
        .penable(penable),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .apb_read_data_out(apb_read_data_out),
        .psel1(psel1),
        .psel2(psel2),
        .pslverr(pslverr)
    );

    apb_gpio gpio(
        .pclk(pclk),
        .presetn(presetn),
        .psel(psel1),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(gpio_prdata),
        .pready(pready),
        .gpio_out(gpio_out),
        .gpio_in(gpio_in)
    );

    timer timmer(
        .HCLK(pclk),
        .HRESETn(presetn),
        .PADDR(paddr),
        .PWDATA(pwdata),
        .PWRITE(pwrite),
        .PSEL(psel2),
        .PENABLE(penable),
        .PRDATA(timer_prdata),
        .PREADY(timer_pready),
        .PSLVERR(timer_pslverr),
        .irq_o(timer_irq)
    );

    // Read Data Multiplexer Multiplexing
    assign prdata = (psel1) ? gpio_prdata :
                    (psel2) ? timer_prdata : 32'h00000000;

endmodule