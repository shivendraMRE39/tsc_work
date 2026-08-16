`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: axi4lite_clint
// Description: AXI4-Lite Slave wrapper for the Core-Local Interruptor (clint.sv).
//              Maps the standard RISC-V CLINT registers onto the AXI4-Lite bus:
//                - 0x2000_0000        : msip (Software Interrupt Pending)
//                - 0x2000_4000/0x4004 : mtimecmp_lo / mtimecmp_hi (Timer comparator)
//                - 0x2000_BFF8/0xBFFC : mtime_lo / mtime_hi (Real-time counter)
//
//              Exposes hardware interrupt outputs:
//                - msip_o : Software interrupt -> CPU MSIP (MIP bit 3)
//                - mtip_o : Timer interrupt    -> CPU MTIP (MIP bit 7)
//////////////////////////////////////////////////////////////////////////////////

module axi4lite_clint #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input  logic                       ACLK,
    input  logic                       ARESETN,
    input  logic                       rtc_i,

    // Write Address Channel
    input  logic [ADDR_WIDTH-1:0]      S_AWADDR,
    input  logic                       S_AWVALID,
    output logic                       S_AWREADY,

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0]      S_WDATA,
    input  logic [(DATA_WIDTH/8)-1:0]  S_WSTRB,
    input  logic                       S_WVALID,
    output logic                       S_WREADY,

    // Write Response Channel
    output logic [1:0]                 S_BRESP,
    output logic                       S_BVALID,
    input  logic                       S_BREADY,

    // Read Address Channel
    input  logic [ADDR_WIDTH-1:0]      S_ARADDR,
    input  logic                       S_ARVALID,
    output logic                       S_ARREADY,

    // Read Data Channel
    output logic [DATA_WIDTH-1:0]      S_RDATA,
    output logic [1:0]                 S_RRESP,
    output logic                       S_RVALID,
    input  logic                       S_RREADY,

    // Interrupt Outputs
    output logic                       msip_o,
    output logic                       mtip_o
);

    // ---------------------------------------------------------------
    // CLINT core signals
    // ---------------------------------------------------------------
    logic [31:0] clint_addr;
    logic [31:0] clint_wdata;
    logic        clint_we;
    logic [3:0]  clint_byte_enable;
    logic [31:0] clint_rdata;

    // ---------------------------------------------------------------
    // Write Channel Handshake
    // ---------------------------------------------------------------
    wire wr_accept = S_AWVALID && S_WVALID && !S_BVALID;

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            S_AWREADY <= 1'b0;
            S_WREADY  <= 1'b0;
        end else begin
            S_AWREADY <= wr_accept;
            S_WREADY  <= wr_accept;
        end
    end

    // Write Response
    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            S_BVALID <= 1'b0;
            S_BRESP  <= 2'b00;
        end else if (wr_accept) begin
            S_BVALID <= 1'b1;
            S_BRESP  <= 2'b00; // OKAY
        end else if (S_BVALID && S_BREADY) begin
            S_BVALID <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Read Channel Handshake (1-wait-state registered return)
    // ---------------------------------------------------------------
    wire rd_accept = S_ARVALID && !S_ARREADY && !S_RVALID;

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            S_ARREADY <= 1'b0;
            S_RVALID  <= 1'b0;
            S_RRESP   <= 2'b00;
            S_RDATA   <= '0;
        end else begin
            S_ARREADY <= rd_accept;
            if (rd_accept) begin
                S_RVALID <= 1'b1;
                S_RRESP  <= 2'b00; // OKAY
                S_RDATA  <= clint_rdata;
            end else if (S_RVALID && S_RREADY) begin
                S_RVALID <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------------
    // Bus multiplexing into CLINT core
    // ---------------------------------------------------------------
    assign clint_we          = wr_accept;
    assign clint_wdata       = S_WDATA;
    assign clint_byte_enable = S_WSTRB;
    assign clint_addr        = wr_accept ? S_AWADDR : S_ARADDR;

    // ---------------------------------------------------------------
    // CLINT core instantiation
    // ---------------------------------------------------------------
    clint u_clint_core (
        .clk         (ACLK),
        .rst         (ARESETN),
        .rtc_i       (rtc_i),
        .addr        (clint_addr),
        .wdata       (clint_wdata),
        .we          (clint_we),
        .byte_enable (clint_byte_enable),
        .rdata       (clint_rdata),
        .msip_o      (msip_o),
        .mtip_o      (mtip_o)
    );

endmodule
