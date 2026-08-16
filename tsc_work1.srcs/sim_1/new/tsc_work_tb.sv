`timescale 1ns / 1ps

module tsc_work_tb;

    // 1. Declare signals matching the soc_top ports
    logic        clk;
    logic        rst;
    logic [7:0]  gpio_in;
    logic [31:0] gpio_out;
    logic        ext_irq;

    // 2. Connect the Design Under Test (DUT)
    soc_top u_dut (
        .clk      (clk),
        .rst      (rst),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .ext_irq  (ext_irq)
    );

    // 3. Generate 100MHz clock (toggle every 5ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 4. Main test sequence
    initial begin
        // Step A: Initial state & hold reset
        rst     = 1;
        gpio_in = 8'h00;
        ext_irq = 0;

        // Step B: Release reset after 20ns
        #20;
        rst = 0;

        // Step C: Send a simple input value to the SoC
        #50;
        gpio_in = 8'hFF;

        // Step D: Let the system run, then stop
        #500;
        $finish;
    end

endmodule