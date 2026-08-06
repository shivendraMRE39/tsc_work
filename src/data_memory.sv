`timescale 1ns / 1ps

module data_memory #(
    parameter WIDTH = 32,
    parameter DEPTH = 1024
)(
    input  logic clk,
    input  logic WE,
    input logic [3:0] BE,    //new
    input  logic [31:0] A,
    input  logic [31:0] WD,
    output logic [31:0] RD
);

    // Memory declaration
    logic [WIDTH-1:0] datamem [0:DEPTH-1];

    
    assign RD = datamem[A[11:2]];

always_ff @(posedge clk) begin

    if (WE) begin

        if (BE[0])
            datamem[A[11:2]][7:0] <= WD[7:0];

        if (BE[1])
            datamem[A[11:2]][15:8] <= WD[15:8];

        if (BE[2])
            datamem[A[11:2]][23:16] <= WD[23:16];

        if (BE[3])
            datamem[A[11:2]][31:24] <= WD[31:24];

    end

end
   
    integer i;

    initial begin

        // Default all memory to zero
        for (i = 0; i < DEPTH; i = i + 1)
            datamem[i] = 32'd0;
    end

endmodule