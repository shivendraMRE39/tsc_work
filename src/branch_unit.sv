`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/15/2026 05:36:19 AM
// Design Name: 
// Module Name: branch_unit
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

module branch_unit(

    input logic BranchE,
    input logic [2:0] BranchTypeE,

    input logic [31:0] Rs1Data,
    input logic [31:0] Rs2Data,

    output logic TakeBranch

);

always_comb begin

    TakeBranch = 1'b0;

    if(BranchE) begin

        case(BranchTypeE)

            3'b000: TakeBranch = (Rs1Data == Rs2Data); // BEQ

            3'b001: TakeBranch = (Rs1Data != Rs2Data); // BNE

            3'b010: TakeBranch =
                     ($signed(Rs1Data) < $signed(Rs2Data)); // BLT

            3'b011: TakeBranch =
                     ($signed(Rs1Data) >= $signed(Rs2Data)); // BGE

            3'b100: TakeBranch = (Rs1Data < Rs2Data); // BLTU

            3'b101: TakeBranch = (Rs1Data >= Rs2Data); // BGEU

            default: TakeBranch = 1'b0;

        endcase

    end

end

endmodule