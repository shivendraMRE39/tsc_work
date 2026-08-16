`timescale 1ns / 1ps
// =============================================================================
// axi4lite_bus_top
//
// Wires: pipline_top's LSU signals  -->  [sticky edge-detect adapter]
//        -->  axi_master  --> axi4lite_interconnect  -->
//        { axi4lite_rom, axi4lite_sram, axi4lite_clint }
//
// Address map:
//   0x0000_0000 - 0x0000_FFFF : ROM   (64KB window, read-only data)
//   0x1000_0000 - 0x1000_FFFF : SRAM  (64KB window, read/write BRAM)
//   0x2000_0000 - 0x2000_FFFF : CLINT (64KB window, msip/mtime/mtimecmp)
//   anything else              : DECERR (2'b11)
// =============================================================================
module axi4lite_bus_top #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input  logic                      ACLK,
    input  logic                      ARESETN,
    input  logic                      rtc_i,

    // CPU LSU side
    input  logic [ADDR_WIDTH-1:0]     addr,
    input  logic [DATA_WIDTH-1:0]     wdata,
    input  logic                      memwrite,
    input  logic                      memread,
    input  logic [(DATA_WIDTH/8)-1:0] byte_strobe,
    output logic [DATA_WIDTH-1:0]     rdata,
    output logic                      pready,
    output logic                      mem_done,

    // Interrupt outputs from CLINT
    output logic                      msip_o,
    output logic                      mtip_o
);

    // =====================================================================
    // CPU-SIDE ADAPTER (Sticky edge-detect for back-to-back operations)
    // =====================================================================
    logic                        START_READ, START_WRITE;
    logic [ADDR_WIDTH-1:0]       axi_address;
    logic [DATA_WIDTH-1:0]       axi_wdata;
    logic [(DATA_WIDTH/8)-1:0]   axi_wstrb;
    logic                        axi_busy, axi_done;
    logic [DATA_WIDTH-1:0]       axi_rdata;
    logic [1:0]                  axi_rresp, axi_bresp;

    assign axi_address = addr;
    assign axi_wdata   = wdata;
    assign axi_wstrb   = byte_strobe;

    logic is_req;
    assign is_req = memread | memwrite;

    logic req_issued_q;
    logic new_req;
    assign new_req = is_req & ~req_issued_q;

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN)          req_issued_q <= 1'b0;
        else if (new_req)      req_issued_q <= 1'b1;
        else if (axi_done)     req_issued_q <= 1'b0;
    end

    assign START_WRITE = new_req & memwrite;
    assign START_READ  = new_req & memread & ~memwrite;

    assign mem_done = axi_done;
    assign pready   = axi_done;
    assign rdata    = axi_rdata;

    // =====================================================================
    // axi_master
    // =====================================================================
    logic [ADDR_WIDTH-1:0]     m_awaddr, m_araddr;
    logic                      m_awvalid, m_awready;
    logic [DATA_WIDTH-1:0]     m_wdata;
    logic [(DATA_WIDTH/8)-1:0] m_wstrb;
    logic                      m_wvalid, m_wready;
    logic [1:0]                m_bresp;
    logic                      m_bvalid, m_bready;
    logic                      m_arvalid, m_arready;
    logic [DATA_WIDTH-1:0]     m_rdata;
    logic [1:0]                m_rresp;
    logic                      m_rvalid, m_rready;

    axi_master #(
        .ADDRESS    (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_master (
        .ACLK        (ACLK),
        .ARESETN     (ARESETN),
        .START_READ  (START_READ),
        .START_WRITE (START_WRITE),
        .address     (axi_address),
        .W_data      (axi_wdata),
        .W_strb      (axi_wstrb),
        .BUSY        (axi_busy),
        .DONE        (axi_done),
        .RD_DATA     (axi_rdata),
        .RRESP_O     (axi_rresp),
        .BRESP_O     (axi_bresp),

        .M_ARADDR  (m_araddr),  .M_ARVALID (m_arvalid), .M_ARREADY (m_arready),
        .M_RDATA   (m_rdata),   .M_RRESP   (m_rresp),   .M_RVALID  (m_rvalid),  .M_RREADY (m_rready),
        .M_AWADDR  (m_awaddr),  .M_AWVALID (m_awvalid), .M_AWREADY (m_awready),
        .M_WDATA   (m_wdata),   .M_WSTRB   (m_wstrb),   .M_WVALID  (m_wvalid),  .M_WREADY (m_wready),
        .M_BRESP   (m_bresp),   .M_BVALID  (m_bvalid),  .M_BREADY  (m_bready)
    );

    // =====================================================================
    // axi4lite_interconnect Wires
    // =====================================================================
    logic [ADDR_WIDTH-1:0]     rom_awaddr, rom_araddr;
    logic                      rom_awvalid, rom_awready;
    logic [DATA_WIDTH-1:0]     rom_wdata;
    logic [(DATA_WIDTH/8)-1:0] rom_wstrb;
    logic                      rom_wvalid, rom_wready;
    logic [1:0]                rom_bresp;
    logic                      rom_bvalid, rom_bready;
    logic                      rom_arvalid, rom_arready;
    logic [DATA_WIDTH-1:0]     rom_rdata;
    logic [1:0]                rom_rresp;
    logic                      rom_rvalid, rom_rready;

    logic [ADDR_WIDTH-1:0]     sram_awaddr, sram_araddr;
    logic                      sram_awvalid, sram_awready;
    logic [DATA_WIDTH-1:0]     sram_wdata;
    logic [(DATA_WIDTH/8)-1:0] sram_wstrb;
    logic                      sram_wvalid, sram_wready;
    logic [1:0]                sram_bresp;
    logic                      sram_bvalid, sram_bready;
    logic                      sram_arvalid, sram_arready;
    logic [DATA_WIDTH-1:0]     sram_rdata;
    logic [1:0]                sram_rresp;
    logic                      sram_rvalid, sram_rready;

    logic [ADDR_WIDTH-1:0]     clint_awaddr, clint_araddr;
    logic                      clint_awvalid, clint_awready;
    logic [DATA_WIDTH-1:0]     clint_wdata;
    logic [(DATA_WIDTH/8)-1:0] clint_wstrb;
    logic                      clint_wvalid, clint_wready;
    logic [1:0]                clint_bresp;
    logic                      clint_bvalid, clint_bready;
    logic                      clint_arvalid, clint_arready;
    logic [DATA_WIDTH-1:0]     clint_rdata;
    logic [1:0]                clint_rresp;
    logic                      clint_rvalid, clint_rready;

    axi4lite_interconnect #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) u_interconnect (
        .ACLK (ACLK), .ARESETN (ARESETN),

        .MST_AWADDR(m_awaddr), .MST_AWVALID(m_awvalid), .MST_AWREADY(m_awready),
        .MST_WDATA (m_wdata),  .MST_WSTRB(m_wstrb),      .MST_WVALID(m_wvalid),  .MST_WREADY(m_wready),
        .MST_BRESP (m_bresp),  .MST_BVALID(m_bvalid),    .MST_BREADY(m_bready),
        .MST_ARADDR(m_araddr), .MST_ARVALID(m_arvalid),  .MST_ARREADY(m_arready),
        .MST_RDATA (m_rdata),  .MST_RRESP(m_rresp),      .MST_RVALID(m_rvalid),  .MST_RREADY(m_rready),

        .ROM_AWADDR(rom_awaddr), .ROM_AWVALID(rom_awvalid), .ROM_AWREADY(rom_awready),
        .ROM_WDATA (rom_wdata),  .ROM_WSTRB(rom_wstrb),     .ROM_WVALID(rom_wvalid), .ROM_WREADY(rom_wready),
        .ROM_BRESP (rom_bresp),  .ROM_BVALID(rom_bvalid),   .ROM_BREADY(rom_bready),
        .ROM_ARADDR(rom_araddr), .ROM_ARVALID(rom_arvalid), .ROM_ARREADY(rom_arready),
        .ROM_RDATA (rom_rdata),  .ROM_RRESP(rom_rresp),     .ROM_RVALID(rom_rvalid), .ROM_RREADY(rom_rready),

        .SRAM_AWADDR(sram_awaddr), .SRAM_AWVALID(sram_awvalid), .SRAM_AWREADY(sram_awready),
        .SRAM_WDATA (sram_wdata),  .SRAM_WSTRB(sram_wstrb),     .SRAM_WVALID(sram_wvalid), .SRAM_WREADY(sram_wready),
        .SRAM_BRESP (sram_bresp),  .SRAM_BVALID(sram_bvalid),   .SRAM_BREADY(sram_bready),
        .SRAM_ARADDR(sram_araddr), .SRAM_ARVALID(sram_arvalid), .SRAM_ARREADY(sram_arready),
        .SRAM_RDATA (sram_rdata),  .SRAM_RRESP(sram_rresp),     .SRAM_RVALID(sram_rvalid), .SRAM_RREADY(sram_rready),

        .CLINT_AWADDR(clint_awaddr), .CLINT_AWVALID(clint_awvalid), .CLINT_AWREADY(clint_awready),
        .CLINT_WDATA (clint_wdata),  .CLINT_WSTRB(clint_wstrb),     .CLINT_WVALID(clint_wvalid), .CLINT_WREADY(clint_wready),
        .CLINT_BRESP (clint_bresp),  .CLINT_BVALID(clint_bvalid),   .CLINT_BREADY(clint_bready),
        .CLINT_ARADDR(clint_araddr), .CLINT_ARVALID(clint_arvalid), .CLINT_ARREADY(clint_arready),
        .CLINT_RDATA (clint_rdata),  .CLINT_RRESP(clint_rresp),     .CLINT_RVALID(clint_rvalid), .CLINT_RREADY(clint_rready)
    );

    // =====================================================================
    // Slaves: SRAM, ROM, CLINT
    // =====================================================================
    axi4lite_sram #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(4096)) u_sram (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(sram_awaddr), .S_AWVALID(sram_awvalid), .S_AWREADY(sram_awready),
        .S_WDATA(sram_wdata),   .S_WSTRB(sram_wstrb),     .S_WVALID(sram_wvalid),   .S_WREADY(sram_wready),
        .S_BRESP(sram_bresp),   .S_BVALID(sram_bvalid),   .S_BREADY(sram_bready),
        .S_ARADDR(sram_araddr), .S_ARVALID(sram_arvalid), .S_ARREADY(sram_arready),
        .S_RDATA(sram_rdata),   .S_RRESP(sram_rresp),     .S_RVALID(sram_rvalid),   .S_RREADY(sram_rready)
    );

    axi4lite_rom #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(4096), .HEXFILE("boot_rom.hex")) u_rom (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(rom_awaddr), .S_AWVALID(rom_awvalid), .S_AWREADY(rom_awready),
        .S_WDATA(rom_wdata),   .S_WSTRB(rom_wstrb),     .S_WVALID(rom_wvalid),   .S_WREADY(rom_wready),
        .S_BRESP(rom_bresp),   .S_BVALID(rom_bvalid),   .S_BREADY(rom_bready),
        .S_ARADDR(rom_araddr), .S_ARVALID(rom_arvalid), .S_ARREADY(rom_arready),
        .S_RDATA(rom_rdata),   .S_RRESP(rom_rresp),     .S_RVALID(rom_rvalid),   .S_RREADY(rom_rready)
    );

    axi4lite_clint #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) u_clint (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .rtc_i(rtc_i),
        .S_AWADDR(clint_awaddr), .S_AWVALID(clint_awvalid), .S_AWREADY(clint_awready),
        .S_WDATA(clint_wdata),   .S_WSTRB(clint_wstrb),     .S_WVALID(clint_wvalid),   .S_WREADY(clint_wready),
        .S_BRESP(clint_bresp),   .S_BVALID(clint_bvalid),   .S_BREADY(clint_bready),
        .S_ARADDR(clint_araddr), .S_ARVALID(clint_arvalid), .S_ARREADY(clint_arready),
        .S_RDATA(clint_rdata),   .S_RRESP(clint_rresp),     .S_RVALID(clint_rvalid),   .S_RREADY(clint_rready),
        .msip_o(msip_o),
        .mtip_o(mtip_o)
    );

endmodule
