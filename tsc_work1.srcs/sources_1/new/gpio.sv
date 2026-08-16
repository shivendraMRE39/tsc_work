`timescale 1ns/1ps

module gpio #(
    parameter int WIDTH = 32
)(
    input  logic              clk,
    input  logic              reset,

    // Bus Interface
    input  logic [31:0]       addr,
    input  logic [31:0]       wdata,
    input  logic              we,
    output logic [31:0]       rdata,

    // GPIO Interface
    input  logic [WIDTH-1:0]  gpio_in,
    output logic [WIDTH-1:0]  gpio_out,
    output logic [WIDTH-1:0]  gpio_oe
);

    // ------------------------------------------------------------
    // GPIO Registers
    // ------------------------------------------------------------

    logic [WIDTH-1:0] dir_reg;
    logic [WIDTH-1:0] out_reg;
    logic [WIDTH-1:0] in_reg;

    // Two-stage synchronizer registers
    logic [WIDTH-1:0] gpio_in_sync0;
    logic [WIDTH-1:0] gpio_in_sync1;

    // ------------------------------------------------------------
    // Write Logic
    // ------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (reset) begin
            dir_reg <= '0;
            out_reg <= '0;
        end
        else if (we) begin
            unique case (addr[7:0])

                8'h00:
                    dir_reg <= wdata;

                8'h04:
                    out_reg <= wdata;

                default:
                    ;

            endcase
        end
    end

    // ------------------------------------------------------------
    // 2-Flip-Flop Synchronizer
    // ------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (reset) begin
            gpio_in_sync0 <= '0;
            gpio_in_sync1 <= '0;
            in_reg        <= '0;
        end
        else begin
            gpio_in_sync0 <= gpio_in;
            gpio_in_sync1 <= gpio_in_sync0;
            in_reg        <= gpio_in_sync1;
        end
    end

    // ------------------------------------------------------------
    // Read Logic
    // ------------------------------------------------------------

    always_comb begin
        unique case (addr[7:0])

            8'h00:
                rdata = dir_reg;

            8'h04:
                rdata = out_reg;

            8'h08:
                rdata = in_reg;

            default:
                rdata = '0;

        endcase
    end

    // ------------------------------------------------------------
    // GPIO Outputs
    // ------------------------------------------------------------

    assign gpio_out = out_reg;
    assign gpio_oe  = dir_reg;

endmodule