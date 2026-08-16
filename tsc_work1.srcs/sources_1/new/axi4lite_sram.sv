`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : axi4lite_sram
// Description : Synthesizable AXI4-Lite SRAM slave, backed by a real inferred
//               block RAM (logic [DATA_WIDTH-1:0] mem [DEPTH-1:0]) instead of
//               the flip-flop register array used by axi4_lite_slave.sv. This
//               is the drop-in replacement for the SRAM slot in
//               axi4lite_bus_top -- same AXI4-Lite port list, same handshake
//               semantics, so the interconnect and address_decoder do not
//               change at all.
//
// Protocol structure deliberately mirrors axi4_lite_slave.sv 1:1:
//   - AW / W are captured independently (spec-legal: they may arrive on
//     different cycles) and accepted JOINTLY on wr_accept, gated by
//     !S_BVALID so exactly one write is ever outstanding (no ID tag in
//     AXI4-Lite to track more than one).
//   - AR / R: address is registered on acceptance, R data follows one cycle
//     later. This one-wait-state read is what lets the array read
//     (mem[rd_index]) land directly in a clocked always_ff -- the standard,
//     synthesis-tool-recognized idiom for inferring a synchronous-read block
//     RAM (as opposed to combinational array read + separate output flop,
//     which many tools will NOT map to a BRAM primitive).
//
// Address decode:
//   The interconnect's address_decoder routes a 64KB window
//   (0x1000_0000-0x1000_FFFF) to this slave. DEPTH is independently
//   parameterized (default 4096 words = 16KB) -- if DEPTH*4 is smaller than
//   the decoded window, the extra high address bits are simply ignored
//   (same aliasing note as axi4_lite_slave.sv's NUM_REGS: harmless, since
//   the interconnect has already range-checked the address before this
//   slave ever sees it). Raise DEPTH to 16384 to use the full 64KB window.
//////////////////////////////////////////////////////////////////////////////////

module axi4lite_sram #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 4096          // words; must be a power of 2
)(
    input  logic                       ACLK,
    input  logic                       ARESETN,

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
    input  logic                       S_RREADY
);

    localparam int ADDR_LSB     = $clog2(DATA_WIDTH/8);  // = 2 for 32-bit bus
    localparam int IDX_BITS     = $clog2(DEPTH);
    localparam int STRB_WIDTH   = DATA_WIDTH/8;

    // ---------------------------------------------------------------
    // The actual memory array. This is the ONLY thing that differs
    // structurally from axi4_lite_slave.sv -- everything else below is
    // the same, well-tested handshake skeleton.
    // ---------------------------------------------------------------
    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Zero-init at time 0 -- without this, any word that only ever
    // receives a PARTIAL byte-write (e.g. a lone SB touching 1 of 4
    // bytes) keeps its other 3 bytes permanently 'X' in simulation,
    // since nothing else ever writes them. A later word-granular bus
    // read of that same address (the AXI bus always returns the full
    // word -- byte selection happens downstream in lsu.sv) then shows
    // those undefined bytes in the waveform. Harmless functionally
    // (lsu.sv only ever uses the 1 real byte it asked for), but noisy
    // to look at. Matches axi4lite_rom.sv's existing zero-init.
    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
    end

    wire [IDX_BITS-1:0] wr_index = S_AWADDR[ADDR_LSB +: IDX_BITS];

    // ---------------------------------------------------------------
    // Write Address / Write Data handshake (decoupled, joint-accept)
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

    // Byte-strobed memory write, applied only on the accept cycle, indexed
    // by the LIVE S_AWADDR (see axi4_lite_slave.sv header note: a registered
    // copy would still hold the previous transaction's address on this same
    // edge due to nonblocking-assignment ordering).
    integer bi;
    always_ff @(posedge ACLK) begin
        if (wr_accept) begin
            for (bi = 0; bi < STRB_WIDTH; bi++) begin
                if (S_WSTRB[bi])
                    mem[wr_index][bi*8 +: 8] <= S_WDATA[bi*8 +: 8];
            end
        end
    end

    // Write response
    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            S_BVALID <= 1'b0;
            S_BRESP  <= 2'b00;
        end else if (wr_accept) begin
            S_BVALID <= 1'b1;
            S_BRESP  <= 2'b00;          // OKAY
        end else if (S_BVALID && S_BREADY) begin
            S_BVALID <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Read Address / Read Data -- one-wait-state synchronous BRAM read.
    // S_RDATA is registered directly from the mem[] read on the accept
    // cycle: this is the idiom synthesis tools map onto a block RAM's
    // own output register, rather than inferring extra LUT-RAM/flops.
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