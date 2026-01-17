//==============================================================================
// File: synchronizer.v
// Description: Multi-Stage Synchronizer for Clock Domain Crossing (CDC)
//
// This module implements a parameterized multi-stage flip-flop chain for
// safely transferring signals between clock domains.
//
//==============================================================================
// METASTABILITY EXPLAINED
//==============================================================================
//
// When a flip-flop samples a signal that changes too close to the clock edge
// (violating setup or hold time), the output can enter a metastable state.
//
// Metastability Timeline:
//
//         Setup   Hold
//         Time    Time
//         |<-->|<-->|
// Data: __|------|______   (Data changes near clock edge)
//              ^
// Clock: _____|‾‾|______   (Sampling edge)
//
// If data changes within the setup/hold window:
//
// Output States:
//
// Normal:     _______|‾‾‾‾‾‾‾   (Clean transition to 1)
//
// Metastable: _______|≈≈≈|‾‾‾   (Uncertain state, then resolves)
//                    ^   ^
//                    |   |
//            Metastable  Resolution
//            region      point
//
// The metastable state can persist for a "resolution time" before settling
// to either 0 or 1. If this unresolved state propagates to downstream logic,
// it can cause system failures.
//
//==============================================================================
// SYNCHRONIZER DESIGN
//==============================================================================
//
// Solution: Multi-stage flip-flop chain
//
//     +-------+     +-------+     +-------+
//     |  FF1  |     |  FF2  |     |  FF3  |
// --->|D    Q|---->|D    Q|---->|D    Q|---> sync_out
//     |       |     |       |     |       |
//     +---^---+     +---^---+     +---^---+
//         |             |             |
//     ----+-------------+-------------+----- clk (destination domain)
//
// How it works:
// 1. FF1 may go metastable if async_in changes near clk edge
// 2. FF1 has one full clock period to resolve before FF2 samples
// 3. If FF1 resolves in time, FF2 gets a clean signal
// 4. FF2 output is almost certainly stable (but add FF3 for extra safety)
//
// MTBF (Mean Time Between Failures):
//
//            exp(Tr / Tw)
// MTBF = -------------------
//          Fc × Fd × Tw
//
// Where:
// - Tr  = Resolution time constant (~100-300 ps for modern FPGAs)
// - Tw  = Metastability window (~20-50 ps for modern FPGAs)
// - Fc  = Capturing clock frequency (Hz)
// - Fd  = Data toggle frequency (Hz)
//
// Example calculation for 100 MHz clock, 50 MHz data rate:
// - Tr = 200 ps, Tw = 30 ps
// - MTBF_1_stage = exp(200ps/30ps) / (100M × 50M × 30ps)
//                = exp(6.67) / (1.5e17 × 30e-12)
//                = 788 / 4.5e6
//                = 0.000175 seconds (way too short!)
//
// With 2 stages (each additional stage adds one clock period = 10ns):
// - Tr_effective = 200ps + 10ns = 10.2ns
// - MTBF_2_stage = exp(10.2ns/30ps) / (100M × 50M × 30ps)
//                = exp(340) / 4.5e6
//                ≈ 10^140 seconds (practically infinite!)
//
// Guidelines:
// - 2 stages: Generally sufficient for most designs
// - 3 stages: Recommended for high-reliability or high-speed designs
// - 4+ stages: Rarely needed, may impact timing
//
//==============================================================================
// SYNTHESIS ATTRIBUTES
//==============================================================================
//
// The (* ASYNC_REG = "TRUE" *) attribute tells synthesis tools:
// 1. Place these flip-flops close together (minimize routing delay)
// 2. Don't optimize them away or merge them
// 3. Apply special timing constraints
//
// This is critical for reliability!
//
//==============================================================================

`timescale 1ns / 1ps

module synchronizer #(
    parameter WIDTH  = 5,    // Width of the signal to synchronize
    parameter STAGES = 2     // Number of synchronizer stages (minimum 2)
) (
    //==========================================================================
    // Clock and Reset
    //==========================================================================
    input  wire             clk,       // Destination clock domain
    input  wire             rst_n,     // Active-low asynchronous reset

    //==========================================================================
    // Data Interface
    //==========================================================================
    input  wire [WIDTH-1:0] async_in,  // Asynchronous input (from source domain)
    output wire [WIDTH-1:0] sync_out   // Synchronized output (in dest domain)
);

    //==========================================================================
    // SYNCHRONIZER FLIP-FLOP CHAIN
    //==========================================================================
    // Use a 2D array to implement the multi-stage chain
    // sync_chain[0] = first stage (directly sampling async_in)
    // sync_chain[STAGES-1] = last stage (output)

    // Synthesis attribute to keep flip-flops together and prevent optimization
    (* ASYNC_REG = "TRUE" *)
    reg [WIDTH-1:0] sync_chain [0:STAGES-1];

    // Generate index variable
    integer stage_idx;

    //==========================================================================
    // SYNCHRONIZER LOGIC
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all stages to 0
            // Using a loop for flexibility with parameterized STAGES
            for (stage_idx = 0; stage_idx < STAGES; stage_idx = stage_idx + 1) begin
                sync_chain[stage_idx] <= {WIDTH{1'b0}};
            end
        end
        else begin
            // First stage samples the asynchronous input
            sync_chain[0] <= async_in;

            // Subsequent stages form a shift register
            // Each stage samples the previous stage's output
            for (stage_idx = 1; stage_idx < STAGES; stage_idx = stage_idx + 1) begin
                sync_chain[stage_idx] <= sync_chain[stage_idx - 1];
            end
        end
    end

    //==========================================================================
    // OUTPUT ASSIGNMENT
    //==========================================================================
    // The synchronized output is the last stage of the chain
    assign sync_out = sync_chain[STAGES-1];

    //==========================================================================
    // PARAMETER VALIDATION
    //==========================================================================
    // synthesis translate_off
    initial begin
        if (STAGES < 2) begin
            $display("ERROR: synchronizer requires at least 2 stages!");
            $display("       STAGES = %0d is insufficient for safe CDC", STAGES);
            $finish;
        end
        if (WIDTH < 1) begin
            $display("ERROR: synchronizer WIDTH must be at least 1!");
            $finish;
        end
    end
    // synthesis translate_on

endmodule

//==============================================================================
// SINGLE-BIT SYNCHRONIZER (Optimized version)
//==============================================================================
// For single-bit signals, this simpler version may synthesize more efficiently

module sync_1bit #(
    parameter STAGES = 2
) (
    input  wire clk,
    input  wire rst_n,
    input  wire async_in,
    output wire sync_out
);

    // Synthesis attribute for proper placement
    (* ASYNC_REG = "TRUE" *)
    reg [STAGES-1:0] sync_chain;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_chain <= {STAGES{1'b0}};
        end
        else begin
            // Shift register: input goes to LSB, output from MSB
            sync_chain <= {sync_chain[STAGES-2:0], async_in};
        end
    end

    assign sync_out = sync_chain[STAGES-1];

endmodule

//==============================================================================
// RESET SYNCHRONIZER
//==============================================================================
// Special synchronizer for reset signals
// Implements async assert, sync de-assert pattern

module reset_synchronizer #(
    parameter STAGES = 2
) (
    input  wire clk,           // Destination clock
    input  wire async_rst_n,   // Asynchronous reset input (active low)
    output wire sync_rst_n     // Synchronized reset output (active low)
);

    // Synthesis attribute for proper placement
    (* ASYNC_REG = "TRUE" *)
    reg [STAGES-1:0] sync_chain;

    // Key feature: Asynchronous ASSERT, Synchronous DE-ASSERT
    //
    // When async_rst_n goes LOW:
    //   - All flip-flops immediately reset to 0 (async assert)
    //   - sync_rst_n immediately goes LOW
    //
    // When async_rst_n goes HIGH:
    //   - 1s start shifting through the chain (sync de-assert)
    //   - sync_rst_n goes HIGH only after all stages have 1s
    //   - This ensures clean de-assertion synchronized to clk

    always @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) begin
            // Asynchronous reset assertion
            sync_chain <= {STAGES{1'b0}};
        end
        else begin
            // Synchronous de-assertion
            sync_chain <= {sync_chain[STAGES-2:0], 1'b1};
        end
    end

    assign sync_rst_n = sync_chain[STAGES-1];

endmodule
