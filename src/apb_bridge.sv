`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: apb_bridge
// Description:
//   Bridges the RISC-V pipeline's data-memory interface to an APB master.
//   The processor side presents:
//     - A (32-bit address), WD (32-bit write data), WE (write enable)
//     - funct3M for byte/halfword/word granularity
//     - RD (32-bit read data) returned to the pipeline
//   The APB side drives the standard master_apb control signals.
//
//   Width mismatch: the APB bus here is 8-bit data / 8-bit address.
//   For a WORD (funct3=010) access four sequential APB transfers are issued.
//   For a HALFWORD (funct3=001) two transfers, for BYTE (funct3=000) one.
//
//   stall_out is asserted while APB transfers are in progress so the
//   pipeline's hazard unit can stall the processor.
////////////////////////////////////////////////////////////////////////////////

module apb_bridge (
    input  logic        clk,
    input  logic        rst,        // active-low, matching pipeline convention

    //------------------------------------------------------------------
    // Processor (data-memory stage) interface
    //------------------------------------------------------------------
    input  logic [31:0] A,          // byte address from ALU
    input  logic [31:0] WD,         // write data
    input  logic        WE,         // write enable (store)
    input  logic        RE,         // read  enable (load)
    input  logic [2:0]  funct3M,    // sb/sh/sw / lb/lh/lw/lbu/lhu
    output logic [31:0] RD,         // read data back to pipeline
    output logic        stall_out,  // stall pipeline while APB busy

    //------------------------------------------------------------------
    // APB master control outputs  (connect to master_apb inputs)
    //------------------------------------------------------------------
    output logic        transfer,
    output logic        read,
    output logic        write,
    output logic [7:0]  apb_write_paddr,
    output logic [7:0]  apb_read_paddr,
    output logic [7:0]  apb_write_data,

    //------------------------------------------------------------------
    // APB master status inputs  (from master_apb outputs)
    //------------------------------------------------------------------
    input  logic [7:0]  apb_read_data_out,
    input  logic        pready,
    input  logic        pslverr
);

    //------------------------------------------------------------------
    // Number of APB beats required per access
    //------------------------------------------------------------------
    // funct3[1:0]: 00=byte(1), 01=half(2), 10=word(4)
    logic [2:0] num_beats;
    always_comb begin
        case (funct3M[1:0])
            2'b00:   num_beats = 3'd1;
            2'b01:   num_beats = 3'd2;
            2'b10:   num_beats = 3'd4;
            default: num_beats = 3'd1;
        endcase
    end

    //------------------------------------------------------------------
    // FSM
    //------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        BUSY    = 2'b01,
        WAIT    = 2'b10,
        DONE    = 2'b11
    } state_t;

    state_t state, next_state;

    logic [2:0] beat_cnt;       // current beat index (0-based)
    logic [7:0] rd_bytes [0:3]; // accumulated read bytes

    //------------------------------------------------------------------
    // State register
    //------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state    <= IDLE;
            beat_cnt <= 3'd0;
        end else begin
            state <= next_state;
            if (state == IDLE && (WE || RE))
                beat_cnt <= 3'd0;
            else if (state == WAIT && pready)
                beat_cnt <= beat_cnt + 3'd1;
        end
    end

    //------------------------------------------------------------------
    // Read-byte accumulator
    //------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            rd_bytes[0] <= 8'd0;
            rd_bytes[1] <= 8'd0;
            rd_bytes[2] <= 8'd0;
            rd_bytes[3] <= 8'd0;
        end else if (state == WAIT && pready && !WE) begin
            rd_bytes[beat_cnt[1:0]] <= apb_read_data_out;
        end
    end

    //------------------------------------------------------------------
    // Next-state logic
    //------------------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (WE || RE)
                    next_state = BUSY;
            end
            BUSY: begin
                // one cycle to latch address/data before APB setup phase
                next_state = WAIT;
            end
            WAIT: begin
                if (pready) begin
                    if (beat_cnt == num_beats - 1)
                        next_state = DONE;
                    else
                        next_state = BUSY;  // next beat
                end
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    //------------------------------------------------------------------
    // APB master drive signals
    //------------------------------------------------------------------
    always_comb begin
        transfer         = 1'b0;
        read             = 1'b0;
        write            = 1'b0;
        apb_write_paddr  = 8'd0;
        apb_read_paddr   = 8'd0;
        apb_write_data   = 8'd0;

        if (state == BUSY || state == WAIT) begin
            transfer = 1'b1;

            if (WE) begin
                // STORE
                write            = 1'b1;
                apb_write_paddr  = A[7:0] + {5'd0, beat_cnt};
                case (beat_cnt[1:0])
                    2'b00: apb_write_data = WD[7:0];
                    2'b01: apb_write_data = WD[15:8];
                    2'b10: apb_write_data = WD[23:16];
                    2'b11: apb_write_data = WD[31:24];
                    default: apb_write_data = 8'd0;
                endcase
            end else begin
                // LOAD
                read           = 1'b1;
                apb_read_paddr = A[7:0] + {5'd0, beat_cnt};
            end
        end
    end

    //------------------------------------------------------------------
    // Read-data reconstruction (sign/zero extension matching funct3M)
    //------------------------------------------------------------------
    always_comb begin
        case (funct3M)
            3'b000:  RD = {{24{rd_bytes[0][7]}}, rd_bytes[0]};          // lb
            3'b001:  RD = {{16{rd_bytes[1][7]}}, rd_bytes[1], rd_bytes[0]}; // lh
            3'b010:  RD = {rd_bytes[3], rd_bytes[2], rd_bytes[1], rd_bytes[0]}; // lw
            3'b100:  RD = {24'd0, rd_bytes[0]};                         // lbu
            3'b101:  RD = {16'd0, rd_bytes[1], rd_bytes[0]};            // lhu
            default: RD = 32'd0;
        endcase
    end

    //------------------------------------------------------------------
    // Stall: asserted whenever a transaction is in progress
    //------------------------------------------------------------------
    assign stall_out = (state == BUSY) || (state == WAIT);

endmodule
