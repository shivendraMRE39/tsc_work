`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.05.2026 22:09:46
// Design Name: 
// Module Name: sign_extend
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


module sign_extend(

input  logic [31:0] Instr,
input  logic [2:0]  ImmSrc,
output logic [31:0] ImmExtend

);

always_comb
begin

    case(ImmSrc)

        //////////////////////////////////////////////////
        // I-Type
        //////////////////////////////////////////////////
        3'b000:
            ImmExtend = {{20{Instr[31]}}, Instr[31:20]};

        //////////////////////////////////////////////////
        // S-Type
        //////////////////////////////////////////////////
        3'b001:
            ImmExtend = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};

        //////////////////////////////////////////////////
        // B-Type
        //////////////////////////////////////////////////
        3'b010:
            ImmExtend = {{19{Instr[31]}},
                          Instr[31],
                          Instr[7],
                          Instr[30:25],
                          Instr[11:8],
                          1'b0};

        //////////////////////////////////////////////////
        // J-Type
        //////////////////////////////////////////////////
        3'b011:
            ImmExtend = {{11{Instr[31]}},
                          Instr[31],
                          Instr[19:12],
                          Instr[20],
                          Instr[30:21],
                          1'b0};

        //////////////////////////////////////////////////
        // U-Type (LUI/AUIPC)
        //////////////////////////////////////////////////
        3'b100:
            ImmExtend = {Instr[31:12],12'b0};

        default:
            ImmExtend = 32'd0;

    endcase

end

endmodule