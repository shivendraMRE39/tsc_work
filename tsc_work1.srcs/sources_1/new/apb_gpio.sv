`timescale 1ns / 1ps

module apb_gpio(

input  logic       pclk,
input  logic       presetn,

input  logic       psel,
input  logic       penable,
input  logic       pwrite,

input  logic [7:0] paddr,
input  logic [7:0] pwdata,

output logic [7:0] prdata,
output logic       pready,

output logic [7:0] gpio_out,
input  logic [7:0] gpio_in

);

//////////////////////////////////////////////////////
// GPIO REGISTER
//////////////////////////////////////////////////////

logic [7:0] gpio_reg;

//////////////////////////////////////////////////////
// WRITE + READ
//////////////////////////////////////////////////////

always_ff @(posedge pclk or negedge presetn)
begin

    if(!presetn)
    begin
        gpio_reg <= 8'd0;
    end

    else if(psel && penable && pwrite)
    begin

        case(paddr)

        8'h00:
            gpio_reg <= pwdata;

        default:
            gpio_reg <= gpio_reg;

        endcase

    end

end

//////////////////////////////////////////////////////
// READ LOGIC
//////////////////////////////////////////////////////

always_comb
begin

    case(paddr)

    8'h00:
        prdata = gpio_reg;

    8'h04:
        prdata = gpio_in;

    default:
        prdata = 8'd0;

    endcase

end

//////////////////////////////////////////////////////
// READY
//////////////////////////////////////////////////////

assign pready = 1'b1;

//////////////////////////////////////////////////////
// OUTPUT
//////////////////////////////////////////////////////

assign gpio_out = gpio_reg;

endmodule