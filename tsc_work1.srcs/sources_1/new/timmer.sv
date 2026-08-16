`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.06.2026 02:18:56
// Design Name: 
// Module Name: timmer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////




module timer
#(
    parameter APB_ADDR_WIDTH = 12
)
(
    input  logic                     HCLK,
    input  logic                     HRESETn,

    input  logic [APB_ADDR_WIDTH-1:0] PADDR,
    input  logic [31:0]               PWDATA,
    input  logic                      PWRITE,
    input  logic                      PSEL,
    input  logic                      PENABLE,

    output logic [31:0]               PRDATA,
    output logic                      PREADY,
    output logic                      PSLVERR,

    output logic [1:0]                irq_o
);

//////////////////////////////////////////////////
// REGISTER ADDRESSES
//////////////////////////////////////////////////

localparam REG_TIMER      = 2'd0;
localparam REG_CTRL       = 2'd1;
localparam REG_COMPARE    = 2'd2;

//////////////////////////////////////////////////
// REGISTERS
//////////////////////////////////////////////////

logic [31:0] timer_reg;
logic [31:0] ctrl_reg;
logic [31:0] compare_reg;

logic [1:0] reg_addr;
logic timer_irq_pending;

assign reg_addr = PADDR[3:2];

//////////////////////////////////////////////////
// APB CONSTANTS
//////////////////////////////////////////////////

assign PREADY  = 1'b1;
assign PSLVERR = 1'b0;

//////////////////////////////////////////////////
// TIMER COUNTING
//////////////////////////////////////////////////

always_ff @(posedge HCLK or negedge HRESETn)
begin

    if(!HRESETn)
    begin
        timer_reg   <= 32'd0;
        ctrl_reg    <= 32'd0;
        compare_reg <= 32'd0;
    end
    else
    begin

        //////////////////////////////////////////
        // APB WRITES
        //////////////////////////////////////////

        if(PSEL && PENABLE && PWRITE)
        begin

            case(reg_addr)

                REG_TIMER:
                    timer_reg <= PWDATA;

                REG_CTRL:
                    ctrl_reg <= PWDATA;

                REG_COMPARE:
                begin
                    compare_reg <= PWDATA;
                    timer_reg   <= 32'd0;
                end

            endcase

        end

        //////////////////////////////////////////
        // TIMER ENABLE
        //////////////////////////////////////////

        else if(ctrl_reg[0])
        begin
            timer_reg <= timer_reg + 1;
        end

    end

end


always_ff @(posedge HCLK or negedge HRESETn)
begin
    if(!HRESETn)
        timer_irq_pending <= 1'b0;

    else if(compare_reg != 32'd0 &&
            timer_reg >= compare_reg)
        timer_irq_pending <= 1'b1;

    // no clear yet
end
//////////////////////////////////////////////////
// APB READS
//////////////////////////////////////////////////

always_comb
begin

    PRDATA = 32'd0;

    if(PSEL && PENABLE && !PWRITE)
    begin

        case(reg_addr)

            REG_TIMER:
                PRDATA = timer_reg;

            REG_CTRL:
                PRDATA = ctrl_reg;

            REG_COMPARE:
                PRDATA = compare_reg;

            default:
                PRDATA = 32'd0;

        endcase

    end

end

//////////////////////////////////////////////////
// INTERRUPTS
//////////////////////////////////////////////////

always_comb
begin

    irq_o = 2'b00;

    //////////////////////////////////////////////
    // OVERFLOW IRQ
    //////////////////////////////////////////////

    if(timer_reg == 32'hFFFF_FFFF)
        irq_o[0] = 1'b1;

    //////////////////////////////////////////////
    // COMPARE IRQ
    //////////////////////////////////////////////

//    if(compare_reg != 32'd0 &&
//       timer_reg == compare_reg)
//        irq_o[1] = 1'b1;
irq_o[1] = timer_irq_pending;
end

endmodule