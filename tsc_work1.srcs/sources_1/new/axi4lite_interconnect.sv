`timescale 1ns / 1ps
// =============================================================================
// axi4lite_interconnect (3 Slaves: ROM, SRAM, CLINT)
//
// Routes 1 AXI4-Lite Master (MST_*) to 3 AXI4-Lite Slaves:
//   - ROM   (0x0000_0000 - 0x0000_FFFF)
//   - SRAM  (0x1000_0000 - 0x1000_FFFF)
//   - CLINT (0x2000_0000 - 0x2000_FFFF)
//   - Any other address returns DECERR (2'b11).
// =============================================================================
module axi4lite_interconnect #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input  logic                        ACLK,
    input  logic                        ARESETN,

    // ---------------- Upstream: connects to axi_master's M_* ports --------
    input  logic [ADDR_WIDTH-1:0]       MST_AWADDR,
    input  logic                        MST_AWVALID,
    output logic                        MST_AWREADY,

    input  logic [DATA_WIDTH-1:0]       MST_WDATA,
    input  logic [(DATA_WIDTH/8)-1:0]   MST_WSTRB,
    input  logic                        MST_WVALID,
    output logic                        MST_WREADY,

    output logic [1:0]                  MST_BRESP,
    output logic                        MST_BVALID,
    input  logic                        MST_BREADY,

    input  logic [ADDR_WIDTH-1:0]       MST_ARADDR,
    input  logic                        MST_ARVALID,
    output logic                        MST_ARREADY,

    output logic [DATA_WIDTH-1:0]       MST_RDATA,
    output logic [1:0]                  MST_RRESP,
    output logic                        MST_RVALID,
    input  logic                        MST_RREADY,

    // ---------------- Downstream: ROM slave port (read-only) -------------
    output logic [ADDR_WIDTH-1:0]       ROM_AWADDR,
    output logic                        ROM_AWVALID,
    input  logic                        ROM_AWREADY,
    output logic [DATA_WIDTH-1:0]       ROM_WDATA,
    output logic [(DATA_WIDTH/8)-1:0]   ROM_WSTRB,
    output logic                        ROM_WVALID,
    input  logic                        ROM_WREADY,
    input  logic [1:0]                  ROM_BRESP,
    input  logic                        ROM_BVALID,
    output logic                        ROM_BREADY,
    output logic [ADDR_WIDTH-1:0]       ROM_ARADDR,
    output logic                        ROM_ARVALID,
    input  logic                        ROM_ARREADY,
    input  logic [DATA_WIDTH-1:0]       ROM_RDATA,
    input  logic [1:0]                  ROM_RRESP,
    input  logic                        ROM_RVALID,
    output logic                        ROM_RREADY,

    // ---------------- Downstream: SRAM slave port ------------------------
    output logic [ADDR_WIDTH-1:0]       SRAM_AWADDR,
    output logic                        SRAM_AWVALID,
    input  logic                        SRAM_AWREADY,
    output logic [DATA_WIDTH-1:0]       SRAM_WDATA,
    output logic [(DATA_WIDTH/8)-1:0]   SRAM_WSTRB,
    output logic                        SRAM_WVALID,
    input  logic                        SRAM_WREADY,
    input  logic [1:0]                  SRAM_BRESP,
    input  logic                        SRAM_BVALID,
    output logic                        SRAM_BREADY,
    output logic [ADDR_WIDTH-1:0]       SRAM_ARADDR,
    output logic                        SRAM_ARVALID,
    input  logic                        SRAM_ARREADY,
    input  logic [DATA_WIDTH-1:0]       SRAM_RDATA,
    input  logic [1:0]                  SRAM_RRESP,
    input  logic                        SRAM_RVALID,
    output logic                        SRAM_RREADY,

    // ---------------- Downstream: CLINT slave port -----------------------
    output logic [ADDR_WIDTH-1:0]       CLINT_AWADDR,
    output logic                        CLINT_AWVALID,
    input  logic                        CLINT_AWREADY,
    output logic [DATA_WIDTH-1:0]       CLINT_WDATA,
    output logic [(DATA_WIDTH/8)-1:0]   CLINT_WSTRB,
    output logic                        CLINT_WVALID,
    input  logic                        CLINT_WREADY,
    input  logic [1:0]                  CLINT_BRESP,
    input  logic                        CLINT_BVALID,
    output logic                        CLINT_BREADY,
    output logic [ADDR_WIDTH-1:0]       CLINT_ARADDR,
    output logic                        CLINT_ARVALID,
    input  logic                        CLINT_ARREADY,
    input  logic [DATA_WIDTH-1:0]       CLINT_RDATA,
    input  logic [1:0]                  CLINT_RRESP,
    input  logic                        CLINT_RVALID,
    output logic                        CLINT_RREADY
);

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_DECERR = 2'b11;

    // =========================================================================
    // WRITE PATH
    // =========================================================================
    typedef enum logic [1:0] {WIDLE, WFWD, WRESP} wstate_e;
    wstate_e wstate, wstate_n;

    logic aw_lat_valid, w_lat_valid;
    logic [ADDR_WIDTH-1:0]     awaddr_lat;
    logic [DATA_WIDTH-1:0]     wdata_lat;
    logic [(DATA_WIDTH/8)-1:0] wstrb_lat;

    logic wsel_rom_r, wsel_sram_r, wsel_clint_r, werr_r;
    logic wsel_rom_n, wsel_sram_n, wsel_clint_n, werr_n;

    logic w_rom_sel, w_sram_sel, w_clint_sel, w_gpio_sel;
    wire  w_match = w_rom_sel | w_sram_sel | w_clint_sel;

    address_decoder u_wdecode (
        .addr      (MST_AWADDR),
        .rom_sel   (w_rom_sel),
        .sram_sel  (w_sram_sel),
        .clint_sel (w_clint_sel),
        .gpio_sel  (w_gpio_sel)
    );

    assign MST_AWREADY = (wstate == WIDLE) && !aw_lat_valid;
    assign MST_WREADY  = (wstate == WIDLE) && !w_lat_valid;

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            aw_lat_valid <= 1'b0;
            w_lat_valid  <= 1'b0;
            awaddr_lat   <= '0;
            wdata_lat    <= '0;
            wstrb_lat    <= '0;
        end else begin
            if (wstate == WIDLE) begin
                if (MST_AWVALID && !aw_lat_valid) begin
                    aw_lat_valid <= 1'b1;
                    awaddr_lat   <= MST_AWADDR;
                end
                if (MST_WVALID && !w_lat_valid) begin
                    w_lat_valid <= 1'b1;
                    wdata_lat   <= MST_WDATA;
                    wstrb_lat   <= MST_WSTRB;
                end
            end
            if (wstate == WRESP && wstate_n == WIDLE) begin
                aw_lat_valid <= 1'b0;
                w_lat_valid  <= 1'b0;
            end
        end
    end

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            wstate       <= WIDLE;
            wsel_rom_r   <= 1'b0;
            wsel_sram_r  <= 1'b0;
            wsel_clint_r <= 1'b0;
            werr_r       <= 1'b0;
        end else begin
            wstate       <= wstate_n;
            wsel_rom_r   <= wsel_rom_n;
            wsel_sram_r  <= wsel_sram_n;
            wsel_clint_r <= wsel_clint_n;
            werr_r       <= werr_n;
        end
    end

    always_comb begin
        wstate_n     = wstate;
        wsel_rom_n   = wsel_rom_r;
        wsel_sram_n  = wsel_sram_r;
        wsel_clint_n = wsel_clint_r;
        werr_n       = werr_r;

        MST_BVALID = 1'b0;
        MST_BRESP  = RESP_OKAY;

        ROM_AWADDR   = awaddr_lat; ROM_AWVALID   = 1'b0;
        SRAM_AWADDR  = awaddr_lat; SRAM_AWVALID  = 1'b0;
        CLINT_AWADDR = awaddr_lat; CLINT_AWVALID = 1'b0;

        ROM_WDATA   = wdata_lat; ROM_WSTRB   = wstrb_lat; ROM_WVALID   = 1'b0;
        SRAM_WDATA  = wdata_lat; SRAM_WSTRB  = wstrb_lat; SRAM_WVALID  = 1'b0;
        CLINT_WDATA = wdata_lat; CLINT_WSTRB = wstrb_lat; CLINT_WVALID = 1'b0;

        ROM_BREADY   = 1'b0;
        SRAM_BREADY  = 1'b0;
        CLINT_BREADY = 1'b0;

        unique case (wstate)
            WIDLE: begin
                if ((aw_lat_valid || MST_AWVALID) && (w_lat_valid || MST_WVALID)) begin
                    wsel_rom_n   = w_rom_sel;
                    wsel_sram_n  = w_sram_sel;
                    wsel_clint_n = w_clint_sel;
                    werr_n       = ~w_match;
                    wstate_n     = WFWD;
                end
            end

            WFWD: begin
                if (werr_r) begin
                    wstate_n = WRESP;
                end else if (wsel_rom_r) begin
                    ROM_AWVALID = 1'b1; ROM_WVALID = 1'b1;
                    if (ROM_AWREADY && ROM_WREADY) wstate_n = WRESP;
                end else if (wsel_sram_r) begin
                    SRAM_AWVALID = 1'b1; SRAM_WVALID = 1'b1;
                    if (SRAM_AWREADY && SRAM_WREADY) wstate_n = WRESP;
                end else if (wsel_clint_r) begin
                    CLINT_AWVALID = 1'b1; CLINT_WVALID = 1'b1;
                    if (CLINT_AWREADY && CLINT_WREADY) wstate_n = WRESP;
                end
            end

            WRESP: begin
                if (werr_r) begin
                    MST_BVALID = 1'b1;
                    MST_BRESP  = RESP_DECERR;
                    if (MST_BREADY) wstate_n = WIDLE;
                end else if (wsel_rom_r) begin
                    ROM_BREADY = MST_BREADY;
                    MST_BVALID = ROM_BVALID;
                    MST_BRESP  = ROM_BRESP;
                    if (ROM_BVALID && MST_BREADY) wstate_n = WIDLE;
                end else if (wsel_sram_r) begin
                    SRAM_BREADY = MST_BREADY;
                    MST_BVALID  = SRAM_BVALID;
                    MST_BRESP   = SRAM_BRESP;
                    if (SRAM_BVALID && MST_BREADY) wstate_n = WIDLE;
                end else if (wsel_clint_r) begin
                    CLINT_BREADY = MST_BREADY;
                    MST_BVALID   = CLINT_BVALID;
                    MST_BRESP    = CLINT_BRESP;
                    if (CLINT_BVALID && MST_BREADY) wstate_n = WIDLE;
                end
            end

            default: wstate_n = WIDLE;
        endcase
    end

    // =========================================================================
    // READ PATH
    // =========================================================================
    typedef enum logic [1:0] {RIDLE, RFWD, RDATA} rstate_e;
    rstate_e rstate, rstate_n;

    logic [ADDR_WIDTH-1:0] araddr_lat;
    logic rsel_rom_r, rsel_sram_r, rsel_clint_r, rerr_r;
    logic rsel_rom_n, rsel_sram_n, rsel_clint_n, rerr_n;

    logic r_rom_sel, r_sram_sel, r_clint_sel, r_gpio_sel;
    wire  r_match = r_rom_sel | r_sram_sel | r_clint_sel;

    address_decoder u_rdecode (
        .addr      (MST_ARADDR),
        .rom_sel   (r_rom_sel),
        .sram_sel  (r_sram_sel),
        .clint_sel (r_clint_sel),
        .gpio_sel  (r_gpio_sel)
    );

    assign MST_ARREADY = (rstate == RIDLE);

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) araddr_lat <= '0;
        else if (rstate == RIDLE && MST_ARVALID) araddr_lat <= MST_ARADDR;
    end

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            rstate       <= RIDLE;
            rsel_rom_r   <= 1'b0;
            rsel_sram_r  <= 1'b0;
            rsel_clint_r <= 1'b0;
            rerr_r       <= 1'b0;
        end else begin
            rstate       <= rstate_n;
            rsel_rom_r   <= rsel_rom_n;
            rsel_sram_r  <= rsel_sram_n;
            rsel_clint_r <= rsel_clint_n;
            rerr_r       <= rerr_n;
        end
    end

    always_comb begin
        rstate_n     = rstate;
        rsel_rom_n   = rsel_rom_r;
        rsel_sram_n  = rsel_sram_r;
        rsel_clint_n = rsel_clint_r;
        rerr_n       = rerr_r;

        MST_RVALID  = 1'b0;
        MST_RRESP   = RESP_OKAY;
        MST_RDATA   = '0;

        ROM_ARADDR   = araddr_lat; ROM_ARVALID   = 1'b0; ROM_RREADY   = 1'b0;
        SRAM_ARADDR  = araddr_lat; SRAM_ARVALID  = 1'b0; SRAM_RREADY  = 1'b0;
        CLINT_ARADDR = araddr_lat; CLINT_ARVALID = 1'b0; CLINT_RREADY = 1'b0;

        unique case (rstate)
            RIDLE: begin
                if (MST_ARVALID) begin
                    rsel_rom_n   = r_rom_sel;
                    rsel_sram_n  = r_sram_sel;
                    rsel_clint_n = r_clint_sel;
                    rerr_n       = ~r_match;
                    rstate_n     = RFWD;
                end
            end

            RFWD: begin
                if (rerr_r) begin
                    rstate_n = RDATA;
                end else if (rsel_rom_r) begin
                    ROM_ARVALID = 1'b1;
                    if (ROM_ARREADY) rstate_n = RDATA;
                end else if (rsel_sram_r) begin
                    SRAM_ARVALID = 1'b1;
                    if (SRAM_ARREADY) rstate_n = RDATA;
                end else if (rsel_clint_r) begin
                    CLINT_ARVALID = 1'b1;
                    if (CLINT_ARREADY) rstate_n = RDATA;
                end
            end

            RDATA: begin
                if (rerr_r) begin
                    MST_RVALID = 1'b1;
                    MST_RRESP  = RESP_DECERR;
                    MST_RDATA  = '0;
                    if (MST_RREADY) rstate_n = RIDLE;
                end else if (rsel_rom_r) begin
                    ROM_RREADY = MST_RREADY;
                    MST_RVALID = ROM_RVALID;
                    MST_RRESP  = ROM_RRESP;
                    MST_RDATA  = ROM_RDATA;
                    if (ROM_RVALID && MST_RREADY) rstate_n = RIDLE;
                end else if (rsel_sram_r) begin
                    SRAM_RREADY = MST_RREADY;
                    MST_RVALID  = SRAM_RVALID;
                    MST_RRESP   = SRAM_RRESP;
                    MST_RDATA   = SRAM_RDATA;
                    if (SRAM_RVALID && MST_RREADY) rstate_n = RIDLE;
                end else if (rsel_clint_r) begin
                    CLINT_RREADY = MST_RREADY;
                    MST_RVALID   = CLINT_RVALID;
                    MST_RRESP    = CLINT_RRESP;
                    MST_RDATA    = CLINT_RDATA;
                    if (CLINT_RVALID && MST_RREADY) rstate_n = RIDLE;
                end
            end

            default: rstate_n = RIDLE;
        endcase
    end

endmodule
