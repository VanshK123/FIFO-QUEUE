//==============================================================================
// File: fifo_pkg.vh
// Description: Common parameters, macros, and function definitions for FIFO
//              implementations. This package provides reusable components for
//              both synchronous and asynchronous FIFO designs.
//
// Key Features:
//   - Default parameter definitions
//   - Binary-to-Gray and Gray-to-Binary conversion functions
//   - Useful macros for synthesis attributes
//   - Timing parameter definitions for simulation
//
// Author: FIFO Project
// Date: January 2026
//==============================================================================

`ifndef FIFO_PKG_VH
`define FIFO_PKG_VH

//==============================================================================
// DEFAULT PARAMETERS
//==============================================================================
// These can be overridden at module instantiation

`ifndef DATA_WIDTH
    `define DATA_WIDTH 32
`endif

`ifndef FIFO_DEPTH
    `define FIFO_DEPTH 16
`endif

`ifndef SYNC_STAGES
    `define SYNC_STAGES 2
`endif

//==============================================================================
// TIMING PARAMETERS (for simulation)
//==============================================================================
// Clock periods in nanoseconds

`ifndef CLK_PERIOD
    `define CLK_PERIOD 10       // 100 MHz default
`endif

`ifndef WR_CLK_PERIOD
    `define WR_CLK_PERIOD 10    // 100 MHz write clock
`endif

`ifndef RD_CLK_PERIOD
    `define RD_CLK_PERIOD 15    // 66.67 MHz read clock
`endif

//==============================================================================
// SYNTHESIS ATTRIBUTES
//==============================================================================
// Macros for common synthesis attributes

// Attribute to prevent register optimization across clock domains
// Use on synchronizer flip-flops to ensure they remain in the design
`define ASYNC_REG_ATTR (* ASYNC_REG = "TRUE" *)

// Attribute to preserve registers (prevent optimization)
`define KEEP_REG_ATTR (* KEEP = "TRUE" *)

//==============================================================================
// BINARY TO GRAY CODE CONVERSION
//==============================================================================
//
// Gray code is essential for safe clock domain crossing because only ONE bit
// changes between consecutive values. This property prevents glitches that
// could occur if multiple bits changed simultaneously.
//
// Conversion Algorithm:
//   gray[n] = binary[n]           (MSB remains the same)
//   gray[i] = binary[i+1] ^ binary[i]  for i = n-1 down to 0
//
// Simplified form: gray = binary ^ (binary >> 1)
//
// Example (4-bit):
//   Binary: 0000 -> Gray: 0000
//   Binary: 0001 -> Gray: 0001
//   Binary: 0010 -> Gray: 0011
//   Binary: 0011 -> Gray: 0010
//   Binary: 0100 -> Gray: 0110
//   ...
//
// Notice how each consecutive Gray code differs by only 1 bit!

//==============================================================================
// GRAY TO BINARY CONVERSION
//==============================================================================
//
// To convert Gray code back to binary:
//   binary[n] = gray[n]           (MSB remains the same)
//   binary[i] = binary[i+1] ^ gray[i]  for i = n-1 down to 0
//
// This is an iterative process starting from MSB
//

//==============================================================================
// SYNCHRONIZER DESIGN NOTES
//==============================================================================
//
// Multi-flop synchronizers reduce the probability of metastability propagation.
//
// Metastability occurs when a signal changes too close to a clock edge,
// violating setup or hold time requirements. The flip-flop output may enter
// an indeterminate state for some time before settling to 0 or 1.
//
// MTBF (Mean Time Between Failures) for a synchronizer:
//
//   MTBF = exp(Tr/Tw) / (Fc * Fd * Tw)
//
// Where:
//   Tr = Resolution time constant (technology dependent, ~1-2 ns)
//   Tw = Metastability window (technology dependent, ~50-200 ps)
//   Fc = Capturing clock frequency
//   Fd = Data toggle frequency
//
// Adding more synchronizer stages increases MTBF exponentially:
//   MTBF_N_stages = MTBF_1_stage ^ N
//
// For reliable operation, target MTBF > 100 years (3.15e9 seconds)
//
//==============================================================================

//==============================================================================
// CLOCK DOMAIN CROSSING (CDC) RULES
//==============================================================================
//
// 1. NEVER cross binary counters directly - use Gray code
// 2. Synchronize all signals crossing clock domains
// 3. Use at least 2 synchronizer stages (3 for high-speed designs)
// 4. No combinatorial logic between synchronizer flip-flops
// 5. Apply ASYNC_REG attribute to synchronizer flip-flops
// 6. Use proper reset strategy: async assert, sync de-assert
//
//==============================================================================

`endif // FIFO_PKG_VH
