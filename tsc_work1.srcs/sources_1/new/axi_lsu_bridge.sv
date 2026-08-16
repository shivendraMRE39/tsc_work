`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : axi_lsu_bridge
// Description : Protocol adapter between the CPU's level-held LSU bus
//               (memread/memwrite stay asserted, unchanged, for as many
//               cycles as the pipeline is stalled) and axi4lite_bus_top's
//               control interface (START_READ/START_WRITE must be a clean
//               EDGE -- axi_master only launches a transaction on a 0->1
//               transition and will not refire while one is in flight).
//
// WHY THIS IS NEEDED (root-cause of a real hazard, not a style choice):
//   pipline_top computes:
//       bus_stall = (MemReadM | MemWriteM) & ~mem_done & ~trap_taken;
//   and bus_stall freezes the EX/M pipeline register, so MemReadM/MemWriteM/
//   ALUResultM hold their value for the whole multi-cycle transaction.
//   That's fine for one transaction. The hazard is BACK-TO-BACK memory ops:
//   on the exact cycle mem_done pulses, bus_stall drops to 0 combinationally,
//   so the pipeline register can latch a brand-new load/store on that same
//   clock edge -- if the new instruction is ALSO a memory op, MemReadM or
//   MemWriteM never dips to 0 between transaction N and N+1. A naive
//   `assign START_READ = is_axi_read;` would then present a permanently-high
//   signal across two different transactions, and axi_master's internal
//   edge-detector would never see a second rising edge -> transaction N+1
//   would silently never launch (CPU hangs stalled forever).
//
// FIX: an explicit sticky "request already issued" flop, cleared by DONE,
//   guarantees exactly one clean 1-cycle START pulse per transaction
//   regardless of how the CPU-side level signal behaves across cycles.
//////////////////////////////////////////////////////////////////////////////////

module axi_lsu_bridge #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input  logic                        clk,
    input  logic                        rst,          // active-low, async (matches core)

    // ---------------- CPU / LSU side (from data_mem_stage / pipline_top) --
    input  logic [ADDR_WIDTH-1:0]       addr,          // ALUResultM
    input  logic [DATA_WIDTH-1:0]       wdata,         // WriteDataM (already
                                                         // byte-shifted by the
                                                         // LSU -- StoreDataM)
    input  logic                        memwrite,      // MemWriteM
    input  logic                        memread,       // MemReadM
    input  logic [(DATA_WIDTH/8)-1:0]   byte_strobeM,  // ByteEnableM
    output logic [DATA_WIDTH-1:0]       rdata,         // -> ReadDataM
    output logic                        pready,        // vestigial: pipline_top
                                                         // declares this input but
                                                         // never reads it (only
                                                         // mem_done drives
                                                         // bus_stall). Tied equal
                                                         // to mem_done here purely
                                                         // for port compatibility.
    output logic                        mem_done,      // -> bus_stall generation

    // ---------------- AXI4-Lite bus_top control interface -----------------
    output logic                        START_READ,
    output logic                        START_WRITE,
    output logic [ADDR_WIDTH-1:0]       address,
    output logic [DATA_WIDTH-1:0]       W_data,
    output logic [(DATA_WIDTH/8)-1:0]   W_strb,
    input  logic                        BUSY,
    input  logic                        DONE,
    input  logic [DATA_WIDTH-1:0]       RD_DATA,
    input  logic [1:0]                  RRESP_O,       // observation only --
    input  logic [1:0]                  BRESP_O        // not currently wired
                                                         // into any trap path.
                                                         // Extend here if/when
                                                         // bus-error faults are
                                                         // added.
);

    // ---------------------------------------------------------------
    // Direct combinational passthrough of address/data -- these are
    // already held stable by the frozen EX/M pipeline register for the
    // full duration of any given transaction, so no extra latching is
    // needed here.
    // ---------------------------------------------------------------
    assign address = addr;
    assign W_data  = wdata;
    assign W_strb  = byte_strobeM;

    // ---------------------------------------------------------------
    // Sticky "request already issued" flag -- the actual fix. Set the
    // cycle a NEW request is launched, cleared the cycle DONE returns.
    // ---------------------------------------------------------------
    logic is_req;
    assign is_req = memread | memwrite;

    logic req_issued_q;
    logic new_req;
    assign new_req = is_req & ~req_issued_q;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)            req_issued_q <= 1'b0;
        else if (new_req)    req_issued_q <= 1'b1;
        else if (DONE)       req_issued_q <= 1'b0;
    end

    // Exactly one clean cycle of START_x per transaction. memwrite is given
    // priority in the (illegal, defensive-only) case both are asserted at
    // once -- decode logic upstream should guarantee mutual exclusivity.
    assign START_WRITE = new_req & memwrite;
    assign START_READ  = new_req & memread & ~memwrite;

    // ---------------------------------------------------------------
    // Completion / data return.
    // DONE is axi_master's registered 1-cycle completion pulse -- on the
    // cycle DONE==1, RD_DATA/RRESP_O/BRESP_O already hold the new,
    // captured values (see axi_master.sv header notes #4/#5). That is
    // exactly the single-cycle mem_done pulse pipline_top's bus_stall
    // logic expects.
    // ---------------------------------------------------------------
    assign mem_done = DONE;
    assign pready   = DONE;
    assign rdata    = RD_DATA;

endmodule