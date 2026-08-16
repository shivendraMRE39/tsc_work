`timescale 1ns / 1ps

module master_apb(
    input             pclk,
    input             presetn,
    input             transfer,
    input             read,
    input             write,
    input      [11:0] apb_write_paddr,
    input      [11:0] apb_read_paddr,
    input      [31:0] apb_write_data,
    input      [31:0] prdata,
    input             pready,
    output reg        penable,
    output     [11:0] paddr,
    output            pwrite,
    output     [31:0] pwdata,
    output     [31:0] apb_read_data_out,
    output            psel1,
    output            psel2,
    output            pslverr
);

    localparam IDLE   = 2'b00;
    localparam SETUP  = 2'b01;
    localparam ENABLE = 2'b10;

    reg [1:0] present_state;
    reg [1:0] next_state;

    reg        write_reg_in;
    reg        read_reg_in;
    reg [11:0] addr_reg_in;
    reg [31:0] wdata_reg_in;

    reg [11:0] paddr_reg;
    reg [31:0] pwdata_reg;
    reg        pwrite_reg;

    assign paddr  = paddr_reg;
    assign pwdata = pwdata_reg;
    assign pwrite = pwrite_reg;

    reg setup_error;
    reg invalid_read_paddr;
    reg invalid_write_paddr;
    reg invalid_write_data;

    always @(posedge pclk or negedge presetn) begin
        if(!presetn) present_state <= IDLE;
        else         present_state <= next_state;
    end

    // Latching Requests
    always @(posedge pclk or negedge presetn) begin
        if(!presetn) begin
            write_reg_in <= 1'b0;
            read_reg_in  <= 1'b0;
            addr_reg_in  <= 12'd0;
            wdata_reg_in <= 32'd0;
        end 
        else if(transfer && ((present_state == IDLE) || (present_state == ENABLE && pready))) begin
            write_reg_in <= write;
            read_reg_in  <= read;
            if(write && !read) begin
                addr_reg_in  <= apb_write_paddr;
                wdata_reg_in <= apb_write_data;
            end 
            else if(read && !write) begin
                addr_reg_in <= apb_read_paddr;
            end
        end
    end

    // Driving Output Registers during SETUP
    always @(posedge pclk or negedge presetn) begin
        if(!presetn) begin
            paddr_reg  <= 12'd0;
            pwdata_reg <= 32'd0;
            pwrite_reg <= 1'b0;
        end 
        else if(present_state == SETUP) begin
            paddr_reg  <= addr_reg_in;
            pwdata_reg <= wdata_reg_in;
            pwrite_reg <= write_reg_in;
        end
    end

    // FSM Combinational Logic
    always @(*) begin
        next_state = present_state;
        penable    = 1'b0;

        case(present_state)
            IDLE: begin
                if(transfer) next_state = SETUP;
                else         next_state = IDLE;
            end
            SETUP: begin
                penable    = 1'b0;
                next_state = ENABLE;
            end
            ENABLE: begin
                penable = 1'b1;
                if (!pready)          next_state = ENABLE; 
                else if (transfer)    next_state = SETUP;  
                else                  next_state = IDLE;   
            end
            default: next_state = IDLE;
        endcase
    end

    // Combinational Read Return Mapping
    assign apb_read_data_out = (present_state == ENABLE && penable && !pwrite_reg && pready) ? prdata : 32'd0;

    // Address Decode Select Lines
    assign psel1 = (present_state != IDLE) && (paddr_reg[11:8] == 4'h1);
    assign psel2 = (present_state != IDLE) && (paddr_reg[11:8] == 4'h2);

    // Error Flag Processing
    always @(*) begin
        setup_error         = 1'b0;
        invalid_read_paddr  = 1'b0;
        invalid_write_paddr = 1'b0;
        invalid_write_data  = 1'b0;

        if((present_state == IDLE) && (next_state == ENABLE)) setup_error = 1'b1;
        if(write_reg_in) begin
            if(addr_reg_in  === 12'bxxxxxxxxx) invalid_write_paddr = 1'b1;
            if(wdata_reg_in === 32'bxxxxxxxx)  invalid_write_data  = 1'b1;
        end
        if(read_reg_in) begin
            if(addr_reg_in === 12'bxxxxxxxxx)  invalid_read_paddr = 1'b1;
        end
    end

    assign pslverr = setup_error | invalid_read_paddr | invalid_write_paddr | invalid_write_data;

endmodule