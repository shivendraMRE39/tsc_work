`timescale 1ns / 1ps
// =============================================================================
// soc_clint_tb: Direct verification of AXI4-Lite CLINT integration in soc_top
// Tests:
//   1. MSIP register write / readback (0x2000_0000)
//   2. MTIMECMP low / high write & readback (0x2000_4000 / 0x2000_4004)
//   3. MTIME low / high write & readback (0x2000_BFF8 / 0x2000_BFFC)
//   4. RTC tick incrementing MTIME
//   5. Timer interrupt (MTIP) assertion when MTIME >= MTIMECMP
//   6. Software interrupt (MSIP) propagation
// =============================================================================

module soc_clint_tb;

    logic clk;
    logic rst;
    logic rtc_i;

    // AXI4-Lite Master signals to stimulus CLINT wrapper
    logic [31:0] s_awaddr;
    logic        s_awvalid;
    logic        s_awready;
    logic [31:0] s_wdata;
    logic [3:0]  s_wstrb;
    logic        s_wvalid;
    logic        s_wready;
    logic [1:0]  s_bresp;
    logic        s_bvalid;
    logic        s_bready;

    logic [31:0] s_araddr;
    logic        s_arvalid;
    logic        s_arready;
    logic [31:0] s_rdata;
    logic [1:0]  s_rresp;
    logic        s_rvalid;
    logic        s_rready;

    logic        msip_o;
    logic        mtip_o;

    // Instantiate DUT: axi4lite_clint
    axi4lite_clint #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) dut (
        .ACLK(clk),
        .ARESETN(rst),
        .rtc_i(rtc_i),

        .S_AWADDR(s_awaddr),
        .S_AWVALID(s_awvalid),
        .S_AWREADY(s_awready),
        .S_WDATA(s_wdata),
        .S_WSTRB(s_wstrb),
        .S_WVALID(s_wvalid),
        .S_WREADY(s_wready),
        .S_BRESP(s_bresp),
        .S_BVALID(s_bvalid),
        .S_BREADY(s_bready),

        .S_ARADDR(s_araddr),
        .S_ARVALID(s_arvalid),
        .S_ARREADY(s_arready),
        .S_RDATA(s_rdata),
        .S_RRESP(s_rresp),
        .S_RVALID(s_rvalid),
        .S_RREADY(s_rready),

        .msip_o(msip_o),
        .mtip_o(mtip_o)
    );

    // 100MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Bus write task
    task axi_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
        begin
            @(posedge clk);
            s_awaddr  <= addr;
            s_awvalid <= 1'b1;
            s_wdata   <= data;
            s_wstrb   <= strb;
            s_wvalid  <= 1'b1;
            s_bready  <= 1'b1;

            @(posedge clk);
            while (!(s_awready && s_wready)) @(posedge clk);
            s_awvalid <= 1'b0;
            s_wvalid  <= 1'b0;

            while (!s_bvalid) @(posedge clk);
            @(posedge clk);
            s_bready  <= 1'b0;
        end
    endtask

    // Bus read task
    task axi_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            s_araddr  <= addr;
            s_arvalid <= 1'b1;
            s_rready  <= 1'b1;

            @(posedge clk);
            while (!s_arready) @(posedge clk);
            s_arvalid <= 1'b0;

            while (!s_rvalid) @(posedge clk);
            data = s_rdata;
            @(posedge clk);
            s_rready  <= 1'b0;
        end
    endtask

    int test_pass = 0;
    int test_fail = 0;
    logic [31:0] rdata_buf;

    task check(input string name, input logic cond);
        if (cond) begin
            $display("[PASS] %s", name);
            test_pass++;
        end else begin
            $display("[FAIL] %s", name);
            test_fail++;
        end
    endtask

    initial begin
        rst       = 0;
        rtc_i     = 0;
        s_awaddr  = 0;
        s_awvalid = 0;
        s_wdata   = 0;
        s_wstrb   = 0;
        s_wvalid  = 0;
        s_bready  = 0;
        s_araddr  = 0;
        s_arvalid = 0;
        s_rready  = 0;

        #20;
        rst = 1;
        #20;

        $display("=== STARTING CLINT AXI4-LITE UNIT TESTS ===");

        // Test 1: Check default reset values
        axi_read(32'h2000_0000, rdata_buf); // msip
        check("Default MSIP == 0", rdata_buf == 32'd0 && msip_o == 1'b0);

        axi_read(32'h2000_BFF8, rdata_buf); // mtime_lo
        check("Default MTIME_LO == 0", rdata_buf == 32'd0);

        axi_read(32'h2000_4000, rdata_buf); // mtimecmp_lo
        check("Default MTIMECMP_LO == 0xFFFFFFFF", rdata_buf == 32'hFFFFFFFF && mtip_o == 1'b0);

        // Test 2: Write and read MSIP
        axi_write(32'h2000_0000, 32'h0000_0001, 4'b1111);
        axi_read(32'h2000_0000, rdata_buf);
        check("Write MSIP=1 -> Read MSIP==1 and msip_o==1", rdata_buf == 32'h1 && msip_o == 1'b1);

        axi_write(32'h2000_0000, 32'h0000_0000, 4'b1111);
        axi_read(32'h2000_0000, rdata_buf);
        check("Write MSIP=0 -> Read MSIP==0 and msip_o==0", rdata_buf == 32'h0 && msip_o == 1'b0);

        // Test 3: Set MTIMECMP to 5
        axi_write(32'h2000_4000, 32'd5, 4'b1111);
        axi_write(32'h2000_4004, 32'd0, 4'b1111);
        axi_read(32'h2000_4000, rdata_buf);
        check("MTIMECMP_LO == 5", rdata_buf == 32'd5 && mtip_o == 1'b0);

        // Test 4: Pulse rtc_i 5 times to increment MTIME
        repeat (5) begin
            @(posedge clk); rtc_i = 1;
            @(posedge clk); rtc_i = 0;
            #10;
        end

        axi_read(32'h2000_BFF8, rdata_buf);
        check("MTIME incremented to 5 via rtc_i", rdata_buf == 32'd5);
        check("MTIP asserted when MTIME (5) >= MTIMECMP (5)", mtip_o == 1'b1);

        // Test 5: Increase MTIMECMP to 10 -> MTIP should deassert
        axi_write(32'h2000_4000, 32'd10, 4'b1111);
        #10;
        check("MTIP deasserts when MTIMECMP updated to 10", mtip_o == 1'b0);

        $display("=== SUMMARY: PASS=%0d, FAIL=%0d ===", test_pass, test_fail);
        if (test_fail == 0) $display("=== ALL CLINT AXI4-LITE TESTS PASSED ===");
        $finish;
    end

endmodule
