`timescale 1ns / 1ps



module instruction_memory#(
parameter WIDTH = 32, 
parameter DEPTH = 1024)(
input logic [31 : 0] A,
output logic [WIDTH-1 : 0] rd
    );
    
    //creating instruction memory
    logic [WIDTH-1 : 0] instr_mem [DEPTH-1 : 0] ;
    
    // reads data from the correspondence address addr
    assign rd = instr_mem[A[11 : 2]];

    initial begin
    integer i;

    // Step 1: Initialize all memory with NOP
    for (i = 0; i < DEPTH; i = i + 1)
        instr_mem[i] = 32'h00000013; // NOP

    // Step 2: Load actual instructions
    $readmemh("instruction_hexfile.hex", instr_mem);
end
endmodule
