`timescale 1ns / 1ps
// -----------------------------------------------------------------------
// address_decoder
//
// Address map:
//   0x0000_0000 - 0x0000_FFFF : BOOT ROM (64KB window, read-only)
//   0x1000_0000 - 0x1000_FFFF : SRAM     (64KB window, read/write BRAM)
//   0x2000_0000 - 0x2000_FFFF : CLINT    (64KB window, msip/mtime/mtimecmp)
//   0x2001_0000 - 0x2001_0FFF : GPIO     (reserved)
//   anything else              : DECERR (2'b11)
// -----------------------------------------------------------------------
module address_decoder(
    input  logic [31:0] addr,
    output logic        rom_sel,
    output logic        sram_sel,
    output logic        clint_sel,
    output logic        gpio_sel
);

always_comb begin
    // default
    rom_sel   = 1'b0;
    sram_sel  = 1'b0;
    clint_sel = 1'b0;
    gpio_sel  = 1'b0;

    // BOOT ROM
    if (addr >= 32'h0000_0000 && addr <= 32'h0000_FFFF) begin
        rom_sel = 1'b1;
    end
    // SRAM
    else if (addr >= 32'h1000_0000 && addr <= 32'h1000_FFFF) begin
        sram_sel = 1'b1;
    end
    // CLINT
    else if (addr >= 32'h2000_0000 && addr <= 32'h2000_FFFF) begin
        clint_sel = 1'b1;
    end
    // GPIO (reserved)
    else if (addr >= 32'h2001_0000 && addr <= 32'h2001_0FFF) begin
        gpio_sel = 1'b1;
    end
end

endmodule
