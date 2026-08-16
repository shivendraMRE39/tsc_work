`timescale 1ns / 1ps

module data_memory(
    input  logic        clk,
    input  logic        rst,

    // Address from LSU
    input  logic [31:0] A,

    // Write data already formatted by LSU
    input  logic [31:0] WD,

    // Write enable
    input  logic        WE,

    // Byte enables from LSU
    input  logic [3:0]  ByteEnable,

    // Raw 32-bit word returned to LSU
    output logic [31:0] RD
);

    //------------------------------------------------------------
    // 4KB RAM
    //------------------------------------------------------------
    logic [31:0] Mem [0:1023];

    //------------------------------------------------------------
    // Word Address
    //------------------------------------------------------------
    wire [9:0] word_addr;

    assign word_addr = A[11:2];

    //------------------------------------------------------------
    // Reset + Synchronous Write
    //------------------------------------------------------------
    integer i;

    always_ff @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            for(i=0;i<1024;i=i+1)
                Mem[i] <= 32'h00000000;
        end
        else if(WE)
        begin
            if(ByteEnable[0])
                Mem[word_addr][7:0] <= WD[7:0];

            if(ByteEnable[1])
                Mem[word_addr][15:8] <= WD[15:8];

            if(ByteEnable[2])
                Mem[word_addr][23:16] <= WD[23:16];

            if(ByteEnable[3])
                Mem[word_addr][31:24] <= WD[31:24];
        end
    end

    //------------------------------------------------------------
    // Asynchronous Read
    //------------------------------------------------------------
    always_comb
    begin
        RD = Mem[word_addr];
    end

endmodule