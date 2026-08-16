//////////////////////////////////////////////////////////////////////////////////
// Module Name : axi4_lite_master
// Description : Single-outstanding AXI4-Lite master FSM.
//
// Fixes vs. original code:
//   1) next_state has a default assignment -> no latch inference (was a
//      synthesis-safety bug in the original always_comb block)
//   2) AW and W channel handshakes are tracked with independent sticky
//      flags (aw_done / w_done) so a slave that accepts address and data
//      on DIFFERENT cycles does not hang the FSM or cause AWVALID to be
//      re-presented after that channel's handshake already completed
//   3) RREADY is asserted only during the data phase (RDATA_CHANNEL), not
//      during the address phase -- prevents a missed/early handshake on
//      fast (combinational) slaves
//   4) Read data and write response are captured into registered outputs
//      (RD_DATA, RRESP_O, BRESP_O) -- the original module discarded them
//   5) BUSY / DONE status outputs added. DONE is REGISTERED (pulses one
//      cycle after the bus handshake) so that on the cycle DONE==1:
//        - BUSY has already dropped to 0
//        - RD_DATA / RRESP_O / BRESP_O already hold the new, valid value
//      (a purely combinational DONE would pulse one cycle EARLY relative
//      to the registered result data -- a real off-by-one bug caught
//      during review of the previous version)
//   6) START_READ / START_WRITE are edge-detected; caller must wait for
//      BUSY==0 before pulsing START again
//   7) WSTRB and address-bus widths are fully parameterized
//////////////////////////////////////////////////////////////////////////////////

module axi_master #(
    parameter int ADDRESS    = 32,
    parameter int DATA_WIDTH = 32
)(
    // Global signals
    input  logic                       ACLK,
    input  logic                       ARESETN,      // active-low, asynchronous assert

    // Simple control interface to this master
    input  logic                       START_READ,
    input  logic                       START_WRITE,
    input  logic  [ADDRESS-1:0]        address,
    input  logic  [DATA_WIDTH-1:0]     W_data,
    input  logic  [(DATA_WIDTH/8)-1:0] W_strb,        // NEW: caller-supplied byte
                                                       // strobes (e.g. LSU's
                                                       // ByteEnableM) for SB/SH
                                                       // correctness. Was
                                                       // previously hardwired to
                                                       // all-ones -- corrupted
                                                       // adjacent bytes on any
                                                       // sub-word store.

    output logic                       BUSY,          // 1 = transaction in flight
    output logic                       DONE,          // registered 1-cycle pulse on completion
    output logic  [DATA_WIDTH-1:0]     RD_DATA,       // captured read data, valid when DONE==1
    output logic  [1:0]                RRESP_O,       // latched read response, valid when DONE==1
    output logic  [1:0]                BRESP_O,       // latched write response, valid when DONE==1

    // Read Address Channel
    output logic  [ADDRESS-1:0]        M_ARADDR,
    output logic                       M_ARVALID,
    input  logic                       M_ARREADY,

    // Read Data Channel
    input  logic  [DATA_WIDTH-1:0]     M_RDATA,
    input  logic  [1:0]                M_RRESP,
    input  logic                       M_RVALID,
    output logic                       M_RREADY,

    // Write Address Channel
    output logic  [ADDRESS-1:0]        M_AWADDR,
    output logic                       M_AWVALID,
    input  logic                       M_AWREADY,

    // Write Data Channel
    output logic  [DATA_WIDTH-1:0]     M_WDATA,
    output logic  [(DATA_WIDTH/8)-1:0] M_WSTRB,
    output logic                       M_WVALID,
    input  logic                       M_WREADY,

    // Write Response Channel
    input  logic  [1:0]                M_BRESP,
    input  logic                       M_BVALID,
    output logic                       M_BREADY
);

    localparam int STRB_WIDTH = DATA_WIDTH/8;

    typedef enum logic [2:0] {
        IDLE,
        WRITE_CHANNEL,
        WRESP_CHANNEL,
        RADDR_CHANNEL,
        RDATA_CHANNEL
    } state_type;

    state_type state, next_state;

    // ---------------------------------------------------------------
    // Edge detection on START_READ / START_WRITE.
    // Caller must only pulse START_x while BUSY==0; the FSM will not
    // accept a new START while a transaction is already in flight
    // (guaranteed structurally: read_pulse/write_pulse are only acted
    // on from the IDLE state).
    // ---------------------------------------------------------------
    logic start_read_q, start_write_q;
    logic read_pulse, write_pulse;

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            start_read_q  <= 1'b0;
            start_write_q <= 1'b0;
        end else begin
            start_read_q  <= START_READ;
            start_write_q <= START_WRITE;
        end
    end

    assign read_pulse  = START_READ  & ~start_read_q;
    assign write_pulse = START_WRITE & ~start_write_q;

    // ---------------------------------------------------------------
    // Sticky "handshake completed" flags for the write channel.
    // Let AWREADY and WREADY arrive on independent cycles without
    // hanging the FSM or re-asserting VALID after that channel's
    // handshake has already completed.
    // ---------------------------------------------------------------
    logic aw_done, w_done;

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            aw_done <= 1'b0;
            w_done  <= 1'b0;
        end else if (state == WRITE_CHANNEL) begin
            if (M_AWVALID && M_AWREADY) aw_done <= 1'b1;
            if (M_WVALID  && M_WREADY ) w_done  <= 1'b1;
        end else begin
            // cleared whenever not in WRITE_CHANNEL so the flags are
            // fresh for the next write transaction
            aw_done <= 1'b0;
            w_done  <= 1'b0;
        end
    end

    // Combinational "channel complete" terms used by the FSM. Declared
    // as module-level continuous assigns (not locals inside a case
    // branch) for maximum synthesis-tool portability.
    logic aw_complete, w_complete;
    assign aw_complete = aw_done || (M_AWVALID && M_AWREADY);
    assign w_complete  = w_done  || (M_WVALID  && M_WREADY);

    // ---------------------------------------------------------------
    // Read Address Channel
    // ---------------------------------------------------------------
    assign M_ARADDR  = (state == RADDR_CHANNEL) ? address : '0;
    assign M_ARVALID = (state == RADDR_CHANNEL);

    // ---------------------------------------------------------------
    // Read Data Channel -- RREADY only in the data phase
    // ---------------------------------------------------------------
    assign M_RREADY = (state == RDATA_CHANNEL);

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            RD_DATA <= '0;
            RRESP_O <= 2'b00;
        end else if (state == RDATA_CHANNEL && M_RVALID && M_RREADY) begin
            RD_DATA <= M_RDATA;
            RRESP_O <= M_RRESP;
        end
    end

    // ---------------------------------------------------------------
    // Write Address Channel -- deasserts as soon as its own handshake
    // completes, independent of the W channel
    // ---------------------------------------------------------------
    assign M_AWVALID = (state == WRITE_CHANNEL) && !aw_done;
    assign M_AWADDR  = (state == WRITE_CHANNEL) ? address : '0;

    // ---------------------------------------------------------------
    // Write Data Channel -- deasserts as soon as its own handshake
    // completes, independent of the AW channel
    // ---------------------------------------------------------------
    assign M_WVALID = (state == WRITE_CHANNEL) && !w_done;
    assign M_WDATA  = (state == WRITE_CHANNEL) ? W_data : '0;
    assign M_WSTRB  = (state == WRITE_CHANNEL) ? W_strb : '0;

    // ---------------------------------------------------------------
    // Write Response Channel
    // ---------------------------------------------------------------
    assign M_BREADY = (state == WRESP_CHANNEL);

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            BRESP_O <= 2'b00;
        end else if (state == WRESP_CHANNEL && M_BVALID && M_BREADY) begin
            BRESP_O <= M_BRESP;
        end
    end

    // ---------------------------------------------------------------
    // BUSY (combinational, tracks state directly) and DONE (registered,
    // pulses the cycle AFTER the handshake -- see header comment #5 for
    // why this must be registered rather than combinational).
    // ---------------------------------------------------------------
    assign BUSY = (state != IDLE);

    logic done_d;
    assign done_d = ((state == RDATA_CHANNEL) && M_RVALID && M_RREADY) ||
                     ((state == WRESP_CHANNEL) && M_BVALID && M_BREADY);

    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) DONE <= 1'b0;
        else          DONE <= done_d;
    end

    // ---------------------------------------------------------------
    // State register
    // ---------------------------------------------------------------
    always_ff @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) state <= IDLE;
        else          state <= next_state;
    end

    // ---------------------------------------------------------------
    // Next-state logic -- default assignment prevents latch inference
    // ---------------------------------------------------------------
    always_comb begin
        next_state = state;   // default: fixes the original latch bug
        case (state)
            IDLE: begin
                if (write_pulse)      next_state = WRITE_CHANNEL;
                else if (read_pulse)  next_state = RADDR_CHANNEL;
                else                  next_state = IDLE;
            end

            RADDR_CHANNEL: begin
                if (M_ARVALID && M_ARREADY) next_state = RDATA_CHANNEL;
            end

            RDATA_CHANNEL: begin
                if (M_RVALID && M_RREADY) next_state = IDLE;
            end

            WRITE_CHANNEL: begin
                if (aw_complete && w_complete) next_state = WRESP_CHANNEL;
            end

            WRESP_CHANNEL: begin
                if (M_BVALID && M_BREADY) next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule