//`timescale 1ns / 1ps

//module memory_interface(
//    input  logic        clk,
//    input  logic        rst,

//    // CPU Side
//    input  logic [31:0] addr,
//    input  logic [31:0] wdata,
//    input  logic        memwrite,
//    input  logic        memread,
//    input  logic [3:0]  byte_strobeM,
//    output logic [31:0] rdata,
//    output logic        pready,
//    output logic        mem_done,

//    // APB Side
//    output logic [11:0] apb_addr,
//    output logic [31:0] apb_wdata,
//    output logic        apb_write,
//    output logic        apb_read,
//    output logic        transfer,
//    input  logic [31:0] apb_rdata,
//    input  logic        apb_pready,
//    input  logic        apb_mem_done,

//    // Direct RAM Side
//    output logic [31:0] ram_addr,
//    output logic [31:0] ram_wdata,
//    output logic        ram_we,
//    output logic [3:0]  ram_be,
//    input  logic [31:0] ram_rdata
//);

//    logic is_ram;
//    logic is_apb;

//    // Decode: 0x0000_1XXX is routed to APB. Everything below 0x1000 stays in local RAM.
//    assign is_ram = (memread | memwrite) && (addr[31:12] == 20'h0000_0);
//    assign is_apb = (memread | memwrite) && (addr[31:12] == 20'h0000_1);

//    // RAM Routing
//    assign ram_addr  = addr;
//    assign ram_wdata = wdata;
//    assign ram_we    = is_ram ? memwrite : 1'b0;
//    assign ram_be    = is_ram ? byte_strobeM : 4'b0000;

//    // APB Routing
//    assign apb_addr  = addr[11:0];
//    assign apb_wdata = wdata;
//    assign apb_write = is_apb ? memwrite : 1'b0;
//    assign apb_read  = is_apb ? memread  : 1'b0;
//    assign transfer  = is_apb;

//    // Read Multiplexer
//    always_comb begin
//        if (addr[31:12] == 20'h0000_1)
//            rdata = apb_rdata;
//        else
//            rdata = ram_rdata;
//    end

//    // Stall Handshake Generation
//    always_comb begin
//        if (is_ram) begin
//            pready   = 1'b1;
//            mem_done = 1'b1;
//        end else if (is_apb) begin
//            pready   = apb_pready;
//            mem_done = apb_mem_done;
//        end else begin
//            pready   = 1'b1;
//            mem_done = 1'b1;
//        end
//    end

//endmodule
`timescale 1ns / 1ps
module memory_interface(
    input  logic        clk,
    input  logic        rst,
    // CPU Side
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        memwrite,
    input  logic        memread,
    input  logic [3:0]  byte_strobeM,
    output logic [31:0] rdata,
    output logic        pready,
    output logic        mem_done,
    // APB Side
    output logic [11:0] apb_addr,
    output logic [31:0] apb_wdata,
    output logic        apb_write,
    output logic        apb_read,
    output logic        transfer,
    input  logic [31:0] apb_rdata,
    input  logic        apb_pready,
    input  logic        apb_mem_done,
    // Direct RAM Side
    output logic [31:0] ram_addr,
    output logic [31:0] ram_wdata,
    output logic        ram_we,
    output logic [3:0]  ram_be,
    input  logic [31:0] ram_rdata,
    // CLINT Side (NEW)
    output logic [31:0] clint_addr,   // relative to CLINT_BASE
    output logic [31:0] clint_wdata,
    output logic        clint_we,
    output logic [3:0]  clint_be,
    input  logic [31:0] clint_rdata
);
    // Address map:
    //   0x0000_0000 - 0x0000_0FFF : local RAM
    //   0x0000_1000 - 0x0000_1FFF : APB peripherals
    //   0x0000_2000 - 0x0000_DFFF : CLINT (needs a wider-than-4KB window to
    //                               preserve standard relative offsets up to
    //                               mtime @ +0xBFF8)
    localparam CLINT_BASE = 32'h0000_2000;
    localparam CLINT_TOP  = 32'h0000_E000; // exclusive upper bound

    logic is_ram;
    logic is_apb;
    logic is_clint;

    assign is_ram   = (memread | memwrite) && (addr[31:12] == 20'h0000_0);
    assign is_apb   = (memread | memwrite) && (addr[31:12] == 20'h0000_1);
    assign is_clint = (memread | memwrite) && (addr >= CLINT_BASE) && (addr < CLINT_TOP);

    // RAM Routing
    assign ram_addr  = addr;
    assign ram_wdata = wdata;
    assign ram_we    = is_ram ? memwrite : 1'b0;
    assign ram_be    = is_ram ? byte_strobeM : 4'b0000;

    // APB Routing
    assign apb_addr  = addr[11:0];
    assign apb_wdata = wdata;
    assign apb_write = is_apb ? memwrite : 1'b0;
    assign apb_read  = is_apb ? memread  : 1'b0;
    assign transfer  = is_apb;

    // CLINT Routing (NEW)
    assign clint_addr  = addr - CLINT_BASE;   // present a CLINT-relative offset
    assign clint_wdata = wdata;
    assign clint_we    = is_clint ? memwrite : 1'b0;
    assign clint_be    = is_clint ? byte_strobeM : 4'b0000;

    // Read Multiplexer
    always_comb begin
        if (is_clint)
            rdata = clint_rdata;
        else if (addr[31:12] == 20'h0000_1)
            rdata = apb_rdata;
        else
            rdata = ram_rdata;
    end

    // Stall Handshake Generation
    // CLINT is always single-cycle ready, same as local RAM -- no wait states.
    always_comb begin
        if (is_ram) begin
            pready   = 1'b1;
            mem_done = 1'b1;
        end else if (is_apb) begin
            pready   = apb_pready;
            mem_done = apb_mem_done;
        end else if (is_clint) begin
            pready   = 1'b1;
            mem_done = 1'b1;
        end else begin
            pready   = 1'b1;
            mem_done = 1'b1;
        end
    end
endmodule