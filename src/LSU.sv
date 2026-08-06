`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/14/2026 06:07:52 PM
// Design Name: 
// Module Name: LSU
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

module LSU(

    input  logic [31:0] Addr,
    input  logic [31:0] WriteData,
    input  logic [31:0] ReadData,

    input  logic [2:0] LoadType,
    input  logic [2:0] StoreType,

    output logic [31:0] StoreData,
    output logic [31:0] LoadData,
    output logic [3:0]  ByteEnable,

    output logic LoadMisaligned,
    output logic StoreMisaligned

);

logic [7:0]  byte_data;
logic [15:0] half_data;

logic [31:0] lb_result;
logic [31:0] lh_result;
logic [31:0] lbu_result;
logic [31:0] lhu_result;


// BYTE ENABLE GENERATION

always_comb begin

    ByteEnable = 4'b0000;

    case(StoreType)

        // SB
        3'b000: begin
            case(Addr[1:0])
                2'b00: ByteEnable = 4'b0001;
                2'b01: ByteEnable = 4'b0010;
                2'b10: ByteEnable = 4'b0100;
                2'b11: ByteEnable = 4'b1000;
            endcase
        end

        // SH
        3'b001: begin
            if(Addr[1] == 1'b0)
                ByteEnable = 4'b0011;
            else
                ByteEnable = 4'b1100;
        end

        // SW
        3'b010: begin
            ByteEnable = 4'b1111;
        end

        default: begin
            ByteEnable = 4'b0000;
        end

    endcase

end

// STORE DATA GENERATION

always_comb begin

    StoreData = 32'b0;

    case(StoreType)

        // SB

        3'b000: begin

            case(Addr[1:0])

                2'b00:
                    StoreData = {24'b0, WriteData[7:0]};

                2'b01:
                    StoreData = {16'b0,WriteData[7:0],8'b0};
                                 
                2'b10:
                    StoreData = {8'b0, WriteData[7:0], 16'b0};                             
                                
                2'b11:
                    StoreData = {WriteData[7:0], 24'b0};
                                
            endcase

        end

        // SH

        3'b001: begin

            if(Addr[1] == 1'b0)
                StoreData = {16'b0, WriteData[15:0]};
            else
                StoreData = {WriteData[15:0], 16'b0};

        end

        // SW

        3'b010: begin

            StoreData = WriteData;

        end

        default: begin

            StoreData = 32'b0;

        end

    endcase

end

// BYTE EXTRACTION

always_comb begin

    byte_data = 8'b0;

    case(Addr[1:0])

        2'b00: byte_data = ReadData[7:0];
        2'b01: byte_data = ReadData[15:8];
        2'b10: byte_data = ReadData[23:16];
        2'b11: byte_data = ReadData[31:24];

    endcase

end

// HALFWORD EXTRACTION

always_comb begin

    half_data = 16'b0;

    case(Addr[1])

        1'b0: half_data = ReadData[15:0];
        1'b1: half_data = ReadData[31:16];

    endcase

end

// SIGN / ZERO EXTENSION

assign lb_result  = {{24{byte_data[7]}}, byte_data};

assign lh_result  = {{16{half_data[15]}}, half_data};

assign lbu_result = {24'b0, byte_data};

assign lhu_result = {16'b0, half_data};

// LOAD FORMATTER

always_comb begin

    case(LoadType)

        3'b000: LoadData = lb_result;    // LB

        3'b001: LoadData = lh_result;    // LH

        3'b010: LoadData = ReadData;     // LW

        3'b011: LoadData = lbu_result;   // LBU

        3'b100: LoadData = lhu_result;   // LHU

        default:
            LoadData = ReadData;

    endcase

end

// MISALIGNMENT CHECKS

always_comb begin

    LoadMisaligned = 1'b0;

    case(LoadType)

        // LH
        3'b001:
            LoadMisaligned = Addr[0];

        // LW
        3'b010:
            LoadMisaligned = |Addr[1:0];

        default:
            LoadMisaligned = 1'b0;

    endcase

end

always_comb begin

    StoreMisaligned = 1'b0;

    case(StoreType)

        // SH
        3'b001:
            StoreMisaligned = Addr[0];

        // SW
        3'b010:
            StoreMisaligned = |Addr[1:0];

        default:
            StoreMisaligned = 1'b0;

    endcase

end

endmodule
