//`timescale 1ns / 1ps


//module interconnect_01(

//    // CPU SIDE

//    input  logic [31:0] cpu_addr,
//    input  logic [31:0] cpu_wdata,
//    input  logic        cpu_we,
//    output logic [31:0] cpu_rdata,
   
//    // SRAM SIDE
    
//    output logic [31:0] sram_addr,
//    output logic [31:0] sram_wdata,
//    output logic        sram_we,
//    input  logic [31:0] sram_rdata,

//    // GPIO SIDE

//    output logic [31:0] gpio_addr,
//    output logic [31:0] gpio_wdata,
//    output logic        gpio_we,
//    input  logic [31:0] gpio_rdata
//);

//logic rom_sel;
//logic sram_sel;
//logic gpio_sel;

//// ADDRESS DECODER

//address_decoder decoder(

//    .addr(cpu_addr),

//    .rom_sel(rom_sel),
//    .sram_sel(sram_sel),
//    .gpio_sel(gpio_sel)
//);

//// ROUTE TO SRAM

////assign sram_addr  = cpu_addr;
//assign sram_addr = (sram_sel) ? cpu_addr : 32'h10000000;

////assign sram_wdata = cpu_wdata;
//assign sram_wdata = (sram_sel) ? cpu_wdata : 32'b0;

//assign sram_we = cpu_we & sram_sel;


////Route GPIO Signals

//assign gpio_addr  = cpu_addr;

//assign gpio_wdata = cpu_wdata;

//assign gpio_we = cpu_we & gpio_sel;


//// RETURN READ DATA TO CPU

//always_comb begin

//    cpu_rdata = 32'h00000000;

//    // SRAM

//    if(sram_sel)
//        cpu_rdata = sram_rdata;

//    // GPIO

//    else if(gpio_sel)
//        cpu_rdata = gpio_rdata;

//end

//endmodule

`timescale 1ns / 1ps

module interconnect_01(

    //==================================================
    // CPU SIDE
    //==================================================
    input  logic [31:0] cpu_addr,
    input  logic [31:0] cpu_wdata,
    input  logic        cpu_we,
    output logic [31:0] cpu_rdata,

    //==================================================
    // ROM
    //==================================================
    input  logic [31:0] rom_rdata,

    //==================================================
    // SRAM
    //==================================================
    output logic [31:0] sram_addr,
    output logic [31:0] sram_wdata,
    output logic        sram_we,
    input  logic [31:0] sram_rdata,

    //==================================================
    // GPIO
    //==================================================
    output logic [31:0] gpio_addr,
    output logic [31:0] gpio_wdata,
    output logic        gpio_we,
    input  logic [31:0] gpio_rdata

    // Future IPs
    // output logic [31:0] uart_addr,
    // output logic [31:0] uart_wdata,
    // output logic        uart_we,
    // input  logic [31:0] uart_rdata
);

    //--------------------------------------------------
    // Select Signals
    //--------------------------------------------------
    logic rom_sel;
    logic sram_sel;
    logic gpio_sel;

    //--------------------------------------------------
    // Address Decoder
    //--------------------------------------------------
    address_decoder decoder (
        .addr     (cpu_addr),

        .rom_sel  (rom_sel),
        .sram_sel (sram_sel),
        .gpio_sel (gpio_sel)
    );

    //--------------------------------------------------
    // SRAM Routing
    //--------------------------------------------------
    assign sram_addr  = cpu_addr;
    assign sram_wdata = cpu_wdata;
    assign sram_we    = cpu_we & sram_sel;

    //--------------------------------------------------
    // GPIO Routing
    //--------------------------------------------------
    assign gpio_addr  = cpu_addr;
    assign gpio_wdata = cpu_wdata;
    assign gpio_we    = cpu_we & gpio_sel;

    //--------------------------------------------------
    // Read Data Mux
    //--------------------------------------------------
    always_comb begin

       
    cpu_rdata = 32'h00000000;

    if (sram_sel)
        cpu_rdata = sram_rdata;
    else if (gpio_sel)
        cpu_rdata = gpio_rdata;
end
        

   
endmodule