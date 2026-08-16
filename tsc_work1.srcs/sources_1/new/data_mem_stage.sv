//`timescale 1ns / 1ps

//module data_mem_stage(
//    input  logic        clk,
//    input  logic        rst,
//    input  logic        bus_stall,      
//    input  logic        RegWriteM,
//    input  logic [1:0]  ResultSrcM,
//    input  logic        MemWriteM,
//    input  logic [31:0] ALUResultM,
//    input  logic [31:0] WriteDataM,
//    input  logic [2:0]  funct3M,
//    input  logic [4:0]  RdM,
//    input  logic [31:0] PcPlus4M,
//    input  logic [31:0] ReadDataM,      // Raw data returning from memory bus
//    input  logic        MemReadM,
    
//    output logic [31:0] ReadDataW,      // Formatted data going to Writeback
//    output logic        RegWriteW,
//    output logic [1:0]  ResultSrcW,
//    output logic [31:0] ALUResultW,
//    output logic [4:0]  RdW,
//    output logic [31:0] PcPlus4W,
    
//    ////////// CSR PORTS //////////
//    input  logic        csr_enM,
//    input  logic [1:0]  csr_opM,
//    input  logic [11:0] csr_addrM,
//    input  logic [31:0] csr_rdataM,
//    output logic        csr_enW,
//    output logic [1:0]  csr_opW,
//    output logic [11:0] csr_addrW,
//    output logic [31:0] csr_rdataW,
//    input  logic        mretM,
    
//    output logic [31:0] ResultM_forward,
    
//    ////////// LSU EXPOSED OUTPUTS //////////
//    output logic [31:0] StoreDataM,     // Formatted write data to Memory
//    output logic [3:0]  ByteEnableM,    // Byte enables to Memory
//    output logic        LoadMisalignedM, // Exception flag to Trap Handler
//    output logic        StoreMisalignedM // Exception flag to Trap Handler
//);

//    // Internal wires to capture raw exception flags from LSU
//    logic [31:0] lsu_load_data;
//    logic        lsu_load_misaligned;
//    logic        lsu_store_misaligned;

//    // ===================================================================
//    // LOAD-STORE UNIT (LSU) INSTANTIATION
//    // ===================================================================
//    LSU lsu_inst (
//        .Addr            (ALUResultM),
//        .WriteData       (WriteDataM),
//        .ReadData        (ReadDataM),
//        .LoadType        (funct3M),        // RISC-V funct3 maps directly to LoadType
//        .StoreType       (funct3M),        // RISC-V funct3 maps directly to StoreType
//        .StoreData       (StoreDataM),
//        .LoadData        (lsu_load_data),
//        .ByteEnable      (ByteEnableM),
//        .LoadMisaligned  (lsu_load_misaligned),
//        .StoreMisaligned (lsu_store_misaligned)
//    );

//    // ===================================================================
//    // Qualification using clean un-looped internal signals
//    // ===================================================================
//    assign LoadMisalignedM  = lsu_load_misaligned  && MemReadM;
//    assign StoreMisalignedM = lsu_store_misaligned && MemWriteM;

//    // ===================================================================
//    // FORWARDING MULTIPLEXER
//    // ===================================================================
//    always_comb begin
//        case(ResultSrcM)
//            2'b00:   ResultM_forward = ALUResultM;
//            2'b01:   ResultM_forward = lsu_load_data; // Forward formatted data, not raw
//            2'b10:   ResultM_forward = PcPlus4M;
//            2'b11:   ResultM_forward = csr_rdataM;
//            default: ResultM_forward = 32'd0;
//        endcase
//    end

//    // ===================================================================
//    // MEMORY TO WRITEBACK REGISTER PIPELINE (M/W)
//    // ===================================================================
//    always_ff @(posedge clk or negedge rst) begin
//        if (!rst) begin
//            RegWriteW   <= 1'b0;
//            ResultSrcW  <= 2'b00;
//            ALUResultW  <= 32'd0;
//            ReadDataW   <= 32'd0;
//            RdW         <= 5'd0;
//            PcPlus4W    <= 32'd0;
//            /////// CSR ///////
//            csr_enW     <= 1'b0;
//            csr_opW     <= 2'b00;
//            csr_addrW   <= 12'd0;
//            csr_rdataW  <= 32'd0;
//        end
//        else if (!bus_stall) begin
//            RegWriteW   <= RegWriteM;
//            ResultSrcW  <= ResultSrcM;
//            ALUResultW  <= ALUResultM;
//            ReadDataW   <= lsu_load_data; // Latch formatted, sign/zero-extended data
//            RdW         <= RdM;
//            PcPlus4W    <= PcPlus4M;
//            /////////// CSR ///////////
//            csr_enW     <= csr_enM;
//            csr_opW     <= csr_opM;
//            csr_addrW   <= csr_addrM;
//            csr_rdataW  <= csr_rdataM;
//        end
//    end

//endmodule

`timescale 1ns / 1ps

module data_mem_stage(
    input  logic        clk,
    input  logic        rst,
    input  logic        bus_stall,      // Connects to StallM from Hazard Unit
    input  logic        FlushM,         // Connects to FlushM from Hazard Unit (for traps)
    
    input  logic        RegWriteM,
    input  logic [1:0]  ResultSrcM,
    input  logic        MemWriteM,
    input  logic [31:0] ALUResultM,
    input  logic [31:0] WriteDataM,
    input  logic [2:0]  funct3M,
    input  logic [4:0]  RdM,
    input  logic [31:0] PcPlus4M,
    input  logic [31:0] ReadDataM,      // Raw data returning from memory bus
    input  logic        MemReadM,
    
    output logic [31:0] ReadDataW,      // Formatted data going to Writeback
    output logic        RegWriteW,
    output logic [1:0]  ResultSrcW,
    output logic [31:0] ALUResultW,
    output logic [4:0]  RdW,
    output logic [31:0] PcPlus4W,
    
    ////////// CSR PORTS //////////
    input  logic        csr_enM,
    input  logic [1:0]  csr_opM,
    input  logic [11:0] csr_addrM,
    input  logic [31:0] csr_rdataM,
    output logic        csr_enW,
    output logic [1:0]  csr_opW,
    output logic [11:0] csr_addrW,
    output logic [31:0] csr_rdataW,
    input  logic        mretM,
    
    output logic [31:0] ResultM_forward,
    
    ////////// LSU EXPOSED OUTPUTS //////////
    output logic [31:0] StoreDataM,     // Formatted write data to Memory
    output logic [3:0]  ByteEnableM,    // Byte enables to Memory
    output logic        LoadMisalignedM, // Exception flag to Trap Handler
    output logic        StoreMisalignedM // Exception flag to Trap Handler
);

    // Internal wires to capture raw exception flags from LSU
    logic [31:0] lsu_load_data;
    logic        lsu_load_misaligned;
    logic        lsu_store_misaligned;

    // ===================================================================
    // LOAD-STORE UNIT (LSU) INSTANTIATION
    // ===================================================================
    LSU lsu_inst (
        .Addr            (ALUResultM),
        .WriteData       (WriteDataM),
        .ReadData        (ReadDataM),
        .LoadType        (funct3M),        // RISC-V funct3 maps directly to LoadType
        .StoreType       (funct3M),        // RISC-V funct3 maps directly to StoreType
        .StoreData       (StoreDataM),
        .LoadData        (lsu_load_data),
        .ByteEnable      (ByteEnableM),
        .LoadMisaligned  (lsu_load_misaligned),
        .StoreMisaligned (lsu_store_misaligned)
    );

    // ===================================================================
    // Exception Qualification
    // Only trigger misaligned faults if we are actively reading or writing
    // ===================================================================
    assign LoadMisalignedM  = lsu_load_misaligned  && MemReadM;
    assign StoreMisalignedM = lsu_store_misaligned && MemWriteM;

    // ===================================================================
    // FORWARDING MULTIPLEXER
    // ===================================================================
    always_comb begin
        case(ResultSrcM)
            2'b00:   ResultM_forward = ALUResultM;
            2'b01:   ResultM_forward = lsu_load_data; // Forward formatted data, not raw
            2'b10:   ResultM_forward = PcPlus4M;
            2'b11:   ResultM_forward = csr_rdataM;
            default: ResultM_forward = 32'd0;
        endcase
    end

    // ===================================================================
    // MEMORY TO WRITEBACK REGISTER PIPELINE (M/W)
    // ===================================================================
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            RegWriteW   <= 1'b0;
            ResultSrcW  <= 2'b00;
            ALUResultW  <= 32'd0;
            ReadDataW   <= 32'd0;
            RdW         <= 5'd0;
            PcPlus4W    <= 32'd0;
            /////// CSR ///////
            csr_enW     <= 1'b0;
            csr_opW     <= 2'b00;
            csr_addrW   <= 12'd0;
            csr_rdataW  <= 32'd0;
        end
        // If a trap happens or an alignment exception triggers, wipe the Writeback stage!
        else if (FlushM || LoadMisalignedM || StoreMisalignedM) begin
            RegWriteW   <= 1'b0; // Prevent bad instruction from modifying register file
            ResultSrcW  <= 2'b00;
            ALUResultW  <= 32'd0;
            ReadDataW   <= 32'd0;
            RdW         <= 5'd0;
            PcPlus4W    <= 32'd0;
            /////// CSR ///////
            csr_enW     <= 1'b0; // Prevent bad instruction from modifying CSRs
            csr_opW     <= 2'b00;
            csr_addrW   <= 12'd0;
            csr_rdataW  <= 32'd0;
        end
        // Normal Pipeline Advance (Freeze if memory bus is stalling)
        else if (!bus_stall) begin
//         if (RegWriteM && csr_enM)

            RegWriteW   <= RegWriteM;
            ResultSrcW  <= ResultSrcM;
            ALUResultW  <= ALUResultM;
            ReadDataW   <= lsu_load_data; // Latch formatted, sign/zero-extended data
            RdW         <= RdM;
            PcPlus4W    <= PcPlus4M;
            /////////// CSR ///////////
            csr_enW     <= csr_enM;
            csr_opW     <= csr_opM;
            csr_addrW   <= csr_addrM;
            csr_rdataW  <= csr_rdataM;
        end
    end

endmodule