`timescale 1ns / 1ps
// =============================================================================
// axi4lite_rom
//
// Real, functional AXI4-Lite BOOT ROM slave -- didn't exist before (the
// rom_sel decoded range was reserved-but-unrouted since no real ROM RTL
// existed). Read-only: standard AR/R handshake identical in shape to
// axi4lite_sram.sv's read path. Writes are accepted at the AXI protocol
// level (so a misbehaving master doesn't hang waiting on AWREADY/WREADY
// that never comes) but return SLVERR (2'b10) instead of OKAY, since
// writing to ROM is a real error condition worth surfacing to software
// -- unlike an unmapped address (DECERR from the interconnect), this IS
// a real slave, it just refuses the write.
//
// Contents are loaded from a hex file via $readmemh at time 0 (simulation
// only -- for real FPGA synthesis this infers a ROM initialized from the
// same .hex via the standard Vivado initial-block-on-a-reg-array flow).
//
// NOTE: instruction fetch is NOT on this bus (IF.sv's inst_memory is
// separate) -- this ROM is for memory-mapped read-only DATA (lookup
// tables, constants, etc.) reachable by LOAD instructions through
// data_mem_stage/lsu.sv, at the 0x0000_0000-0x0000_FFFF range.
//
// IMPORTANT: boot_rom.hex is not provided -- this defaults to
// all-zeros if the file doesn't exist (most simulators warn but don't
// error on a missing $readmemh file). Supply a real boot_rom.hex (or
// tell me what should be in it) to give this real content.
// =============================================================================
module axi4lite_rom #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 4096,             // words -> 16KB default
    parameter      HEXFILE   = "boot_rom.hex"
)(
    input  logic                       ACLK,
    input  logic                       ARESETN,

    // Write Address / Data / Response -- accepted but always SLVERR (see header)
    input  logic [ADDR_WIDTH-1:0]      S_AWADDR,
    input  logic                       S_AWVALID,
    output logic                       S_AWREADY,

    input  logic [DATA_WIDTH-1:0]      S_WDATA,
    input  logic [(DATA_WIDTH/8)-1:0]  S_WSTRB,
    input  logic                       S_WVALID,
    output logic                       S_WREADY,

    output logic [1:0]                 S_BRESP,
    output logic                       S_BVALID,
    input  logic                       S_BREADY,

    // Read Address / Data -- real, one-wait-state (same idiom as axi4lite_sram.sv)
    input  logic [ADDR_WIDTH-1:0]      S_ARADDR,
    input  logic                       S_ARVALID,
    output logic                       S_ARREADY,

    output logic [DATA_WIDTH-1:0]      S_RDATA,
    output logic [1:0]                 S_RRESP,
    output logic                       S_RVALID,
    input  logic                       S_RREADY
);

    localparam int IDX_BITS = $clog2(DEPTH);
    localparam int ADDR_LSB = 2;

    (* rom_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
        $readmemh(HEXFILE, mem);
    end

    // ---------------------------------------------------------------
    // Write path -- accepted, but always SLVERR (read-only memory)
    // ---------------------------------------------------------------
    wire wr_accept = S_AWVALID && S_WVALID && !S_BVALID;

    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AWREADY <= 1'b0;
            S_WREADY  <= 1'b0;
        end else begin
            S_AWREADY <= wr_accept;
            S_WREADY  <= wr_accept;
        end
    end

    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            S_BVALID <= 1'b0;
            S_BRESP  <= 2'b00;
        end else if (wr_accept) begin
            S_BVALID <= 1'b1;
            S_BRESP  <= 2'b10;          // SLVERR -- ROM refuses writes
        end else if (S_BVALID && S_BREADY) begin
            S_BVALID <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Read path -- one-wait-state, identical idiom to axi4lite_sram.sv
    // ---------------------------------------------------------------
    wire rd_accept = S_ARVALID && !S_ARREADY && !S_RVALID;

    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            S_ARREADY <= 1'b0;
            S_RVALID  <= 1'b0;
            S_RRESP   <= 2'b00;
            S_RDATA   <= '0;
        end else begin
            S_ARREADY <= rd_accept;
            if (rd_accept) begin
                S_RVALID <= 1'b1;
                S_RRESP  <= 2'b00;      // OKAY
                S_RDATA  <= mem[S_ARADDR[ADDR_LSB +: IDX_BITS]];
            end else if (S_RVALID && S_RREADY) begin
                S_RVALID <= 1'b0;
            end
        end
    end

endmodule