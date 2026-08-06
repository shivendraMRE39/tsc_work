`timescale 1ns / 1ps


module address_decoder(

input  logic [31:0] addr,

output logic rom_sel,
output logic sram_sel,
output logic gpio_sel
);

always_comb begin

    // default
    rom_sel  = 1'b0;
    sram_sel = 1'b0;
    gpio_sel = 1'b0;

    // BOOT ROM
   
    if(addr >= 32'h0000_0000 &&
       addr <= 32'h0000_FFFF)
    begin
        rom_sel = 1'b1;
    end

    // SRAM
  
    else if(addr >= 32'h1000_0000 &&
            addr <= 32'h1000_FFFF)
    begin
        sram_sel = 1'b1;
    end
  
    // GPIO
   
    else if(addr >= 32'h2000_0000 &&
            addr <= 32'h2000_0FFF)
    begin
        gpio_sel = 1'b1;
    end

end

endmodule