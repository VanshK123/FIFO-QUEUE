//==============================================================================
// File: gray_counter.v
// Description: Gray Code Counter for Asynchronous FIFO
//
// This module implements a counter that outputs values in Gray code format.
// Gray code is essential for safe clock domain crossing (CDC) because only
// ONE bit changes between consecutive values.
//
//==============================================================================
// GRAY CODE EXPLANATION
//==============================================================================
//
// In standard binary counting, multiple bits can change simultaneously:
//
//   Binary Count: 0111 -> 1000  (4 bits change!)
//
// This creates a problem for CDC because:
// 1. Different bits have different propagation delays
// 2. The receiving clock domain might sample during transition
// 3. This could read an invalid intermediate value (e.g., 0000, 1111, etc.)
//
// Gray code solves this by ensuring only ONE bit changes per increment:
//
//   Decimal | Binary | Gray
//   --------|--------|------
//      0    |  0000  | 0000
//      1    |  0001  | 0001
//      2    |  0010  | 0011  <- only 1 bit differs from previous
//      3    |  0011  | 0010
//      4    |  0100  | 0110
//      5    |  0101  | 0111
//      6    |  0110  | 0101
//      7    |  0111  | 0100
//      8    |  1000  | 1100  <- only 1 bit differs from 0100
//      9    |  1001  | 1101
//     10    |  1010  | 1111
//     11    |  1011  | 1110
//     12    |  1100  | 1010
//     13    |  1101  | 1011
//     14    |  1110  | 1001
//     15    |  1111  | 1000
//
// Benefits for CDC:
// - If the receiving domain samples during a transition, it gets either
//   the old value or the new value - never an invalid combination
// - The worst case is reading a "stale" value, which is safe for FIFOs
//   (leads to conservative full/empty detection)
//
//==============================================================================
// CONVERSION ALGORITHMS
//==============================================================================
//
// Binary to Gray:
//   gray[N-1] = binary[N-1]           (MSB stays the same)
//   gray[i]   = binary[i+1] ^ binary[i]  (for i = N-2 down to 0)
//
//   Simplified: gray = binary ^ (binary >> 1)
//
// Gray to Binary:
//   binary[N-1] = gray[N-1]           (MSB stays the same)
//   binary[i]   = binary[i+1] ^ gray[i]  (for i = N-2 down to 0)
//
//   This is an iterative XOR from MSB to LSB
//
//==============================================================================
// TIMING DIAGRAM
//==============================================================================
//
//         ___     ___     ___     ___     ___     ___
// clk  __|   |___|   |___|   |___|   |___|   |___|   |___
//                |       |       |       |       |
// enable ________|-------|-------|-------|-------|________
//                |       |       |       |       |
// binary    0000 | 0001  | 0010  | 0011  | 0100  | 0100
//                |       |       |       |       |
// gray      0000 | 0001  | 0011  | 0010  | 0110  | 0110
//                ^       ^       ^       ^       ^
//                |       |       |       |       |
//            only 1 bit changes each cycle!
//
//==============================================================================

`timescale 1ns / 1ps

module gray_counter #(
    parameter WIDTH = 5    // Counter width (default: 5 bits for DEPTH=16)
) (
    //==========================================================================
    // Clock and Reset
    //==========================================================================
    input  wire             clk,        // Clock input
    input  wire             rst_n,      // Active-low asynchronous reset

    //==========================================================================
    // Control
    //==========================================================================
    input  wire             enable,     // Count enable

    //==========================================================================
    // Outputs
    //==========================================================================
    output reg [WIDTH-1:0]  gray_count,    // Gray code output
    output reg [WIDTH-1:0]  binary_count   // Binary count output (for internal use)
);

    //==========================================================================
    // INTERNAL SIGNALS
    //==========================================================================
    wire [WIDTH-1:0] next_binary;
    wire [WIDTH-1:0] next_gray;

    //==========================================================================
    // BINARY COUNTER INCREMENT
    //==========================================================================
    // Standard binary counter - increments by 1 when enabled
    assign next_binary = binary_count + 1'b1;

    //==========================================================================
    // BINARY TO GRAY CONVERSION
    //==========================================================================
    // Gray code: gray = binary XOR (binary >> 1)
    //
    // Example (4-bit):
    //   binary = 0110
    //   binary >> 1 = 0011
    //   gray = 0110 ^ 0011 = 0101
    //
    // This works because:
    //   gray[3] = binary[3] ^ 0 = binary[3]
    //   gray[2] = binary[2] ^ binary[3]
    //   gray[1] = binary[1] ^ binary[2]
    //   gray[0] = binary[0] ^ binary[1]
    //
    assign next_gray = next_binary ^ (next_binary >> 1);

    //==========================================================================
    // REGISTERED OUTPUTS
    //==========================================================================
    // Both binary and Gray values are registered for clean outputs
    // This prevents glitches on the gray_count output

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset both counters to 0
            // Note: Gray code of 0 is 0, so both start at 0
            binary_count <= {WIDTH{1'b0}};
            gray_count   <= {WIDTH{1'b0}};
        end
        else if (enable) begin
            // Increment both counters
            binary_count <= next_binary;
            gray_count   <= next_gray;
        end
        // If not enabled, hold current values
    end

    //==========================================================================
    // VERIFICATION ASSERTIONS (simulation only)
    //==========================================================================
    // synthesis translate_off

    // Verify Gray code only changes by 1 bit per cycle
    reg [WIDTH-1:0] prev_gray;
    integer bit_changes;
    integer bit_idx;

    always @(posedge clk) begin
        if (rst_n && enable) begin
            prev_gray <= gray_count;

            // Count number of bits that changed
            bit_changes = 0;
            for (bit_idx = 0; bit_idx < WIDTH; bit_idx = bit_idx + 1) begin
                if (prev_gray[bit_idx] != gray_count[bit_idx]) begin
                    bit_changes = bit_changes + 1;
                end
            end

            // After first increment, should only be 1 bit change
            if (binary_count > 1 && bit_changes != 1) begin
                $display("[%0t] ERROR: Gray code changed by %0d bits (should be 1)",
                         $time, bit_changes);
                $display("       Previous: %b, Current: %b", prev_gray, gray_count);
            end
        end
    end

    // synthesis translate_on

endmodule

//==============================================================================
// GRAY TO BINARY CONVERTER (Combinational)
//==============================================================================
// This is a standalone module for converting Gray code back to binary.
// Useful in the receiving clock domain to calculate FIFO occupancy.

module gray_to_binary #(
    parameter WIDTH = 5
) (
    input  wire [WIDTH-1:0] gray,
    output wire [WIDTH-1:0] binary
);

    // Iterative conversion: binary[i] = XOR of all gray bits from i to MSB
    //
    // binary[N-1] = gray[N-1]
    // binary[N-2] = gray[N-1] ^ gray[N-2]
    // binary[N-3] = gray[N-1] ^ gray[N-2] ^ gray[N-3]
    // ...
    // binary[0]   = gray[N-1] ^ gray[N-2] ^ ... ^ gray[0]
    //
    // This can be computed as: binary[i] = binary[i+1] ^ gray[i]

    genvar i;
    generate
        // MSB is the same
        assign binary[WIDTH-1] = gray[WIDTH-1];

        // Remaining bits are XOR chain
        for (i = WIDTH-2; i >= 0; i = i - 1) begin : gray2bin_loop
            assign binary[i] = binary[i+1] ^ gray[i];
        end
    endgenerate

endmodule
