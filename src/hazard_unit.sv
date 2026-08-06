`timescale 1ns / 1ps

module hazard_unit(
    input logic rst,

    // Writeback & Memory Stage Register Writing Control
    input logic RegWriteM,
    input logic RegWriteW,

    // Destination Register Addresses
    input logic [4:0] RdM,
    input logic [4:0] RdW,

    // Execute Stage Source Register Addresses
    input logic [4:0] Rs1E,
    input logic [4:0] Rs2E,

    // Decode Stage Source Register Addresses (for Load-Use detection)
    input logic [4:0] Rs1D,
    input logic [4:0] Rs2D,

    // Execute Stage Destination Register Address
    input logic [4:0] RdE,

    // Execute Stage Result Source (2'b01 indicates a Load instruction)
    input logic [1:0] ResultSrcE,

    // Branch/Jump Control
    input logic PcSrcE,
    input logic MemReadM,

    // Pipeline Stage Stalls
    output logic StallF,
    output logic StallD,
    output logic StallE,
    output logic StallM,

    // Pipeline Stage Flushes
    output logic FlushD,
    output logic FlushE,
    output logic FlushM,

    // ALU Forwarding Selectors
    output logic [1:0] ForwardAE,
    output logic [1:0] ForwardBE,

    // Hazard Status Output
    output logic lw_stall,
    
    // Exception/Trap Inputs
    input logic trap_taken,
    input logic mret_i
);

//////////////////////////////////////////////////////
// FORWARDING LOGIC (EX->EX and MEM->EX)
//////////////////////////////////////////////////////
// Hardwired register x0 (address 0) is never forwarded.
// Priority: MEM stage (2'b10) > WB stage (2'b01) > No forwarding (2'b00)

assign ForwardAE =
    (!rst) ? 2'b00 :
    ((RegWriteM) && (RdM != 5'd0) && (RdM == Rs1E)) ? 2'b10 : // MEM -> EX Forwarding
    ((RegWriteW) && (RdW != 5'd0) && (RdW == Rs1E)) ? 2'b01 : // WB  -> EX Forwarding
    2'b00;                                                    // No Forwarding

/* 
 * FIX: Removed syntax typo '2 mepc_d'b10' and redundant condition check.
 * OLD CODE: ((RegWriteM) && (RdM != 5'd0) && (RdM == Rs2E)) ? 2 mepc_d'b10 : 
 * WHY: Syntax error caused synthesis/simulation crash due to accidental typo string insertion.
 */
assign ForwardBE =
    (!rst) ? 2'b00 :
    ((RegWriteM) && (RdM != 5'd0) && (RdM == Rs2E)) ? 2'b10 : // MEM -> EX Forwarding
    ((RegWriteW) && (RdW != 5'd0) && (RdW == Rs2E)) ? 2'b01 : // WB  -> EX Forwarding
    2'b00;                                                    // No Forwarding

//////////////////////////////////////////////////////
// LOAD-USE HAZARD DETECTION
//////////////////////////////////////////////////////
assign lw_stall = (ResultSrcE == 2'b01) && (RdE != 5'd0) && ((RdE == Rs1D) || (RdE == Rs2D));

//////////////////////////////////////////////////////
// PIPELINE STALLS & FLUSHES (TRAP-OVERRIDE PRIORITY)
//////////////////////////////////////////////////////
/*
 * OLD CODE:
 * assign StallF = lw_stall;
 * assign StallD = lw_stall;
 * 
 * NEW CODE:
 * assign StallF = lw_stall & ~(trap_taken | mret_i);
 * assign StallD = lw_stall & ~(trap_taken | mret_i);
 *
 * WHY:
 * If an asynchronous interrupt or trap hits while a Load-Use hazard is stalling the pipeline, 
 * the old code held StallF/StallD high, causing the processor to freeze and delay handling 
 * the trap. Adding `& ~(trap_taken | mret_i)` allows traps/returns to immediately unfreeze 
 * Fetch and Decode so the processor can redirect execution to the handler without deadlocking.
 */
assign StallF = lw_stall & ~(trap_taken | mret_i);
assign StallD = lw_stall & ~(trap_taken | mret_i);
assign StallE = 1'b0; 
assign StallM = 1'b0; 

// Flushes
assign FlushD = PcSrcE | trap_taken | mret_i;
assign FlushE = lw_stall | PcSrcE | trap_taken | mret_i;
assign FlushM = trap_taken | mret_i;

endmodule