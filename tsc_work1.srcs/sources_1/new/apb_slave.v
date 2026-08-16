//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 25.05.2026 22:20:29
//// Design Name: 
//// Module Name: apb_slave
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////


//module apb_slave(
//  input pclk,presetn,
//  input psel,penable,pwrite,
//  input [7:0] paddr,pwdata,
//  output [7:0] prdata,
//  output reg pready
//    );
    
//    reg [7:0] addr;
//    reg [7:0] mem[63:0];
    
//    assign prdata = mem[addr];
    
//    always@(*)
//     begin 
//     if (!presetn)
//      begin pready = 0;
//      end
//      else if (psel && !penable && !pwrite)
//      pready = 0;
//      else if (psel && penable && !pwrite)
//      begin 
//      pready = 1;
//      addr = paddr;
//      end
//      else if (psel && !penable && pwrite)
//      begin 
//      pready = 0;
//      end
//      else if (psel && penable && pwrite)
//      begin
//      pready = 1;
//      mem [addr] = pwdata;
//      end
//      else 
//      pready = 0;
      
//      end 
//endmodule


`timescale 1ns / 1ps

module apb_slave(

    input             pclk,
    input             presetn,

    input             psel,
    input             penable,
    input             pwrite,

    input      [8:0] paddr,
    input      [7:0] pwdata,

    output reg [7:0] prdata,
    output reg        pready

);

////////////////////////////////////////////////////////////
// MEMORY
////////////////////////////////////////////////////////////

reg [7:0] mem [63:0];

integer i;

////////////////////////////////////////////////////////////
// APB SLAVE LOGIC
////////////////////////////////////////////////////////////

always @(posedge pclk or negedge presetn)
begin

    ////////////////////////////////////////////////////////
    // RESET
    ////////////////////////////////////////////////////////

    if(!presetn)
    begin

        pready <= 1'b0;
        prdata <= 8'd0;

        ////////////////////////////////////////////////////
        // CLEAR MEMORY
        ////////////////////////////////////////////////////

        for(i=0;i<64;i=i+1)
            mem[i] <= 8'd0;

    end

    ////////////////////////////////////////////////////////
    // NORMAL OPERATION
    ////////////////////////////////////////////////////////

    else
    begin

        ////////////////////////////////////////////////////
        // DEFAULT
        ////////////////////////////////////////////////////

        pready <= 1'b0;

        ////////////////////////////////////////////////////
        // WRITE TRANSFER
        ////////////////////////////////////////////////////

        if(psel && penable && pwrite)
        begin

            pready <= 1'b1;

            mem[paddr[8:0]] <= pwdata;

        end

        ////////////////////////////////////////////////////
        // READ TRANSFER
        ////////////////////////////////////////////////////

        else if(psel && penable && !pwrite)
        begin

            pready <= 1'b1;

            prdata <= mem[paddr[8:0]];

        end

    end

end

endmodule