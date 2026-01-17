//==============================================================================
// File: fifo_sync.v
// Description: Synchronous FIFO (First-In-First-Out) Queue Implementation
//
// This module implements a synchronous FIFO with a single clock domain.
// Both read and write operations occur on the same clock edge, making
// timing analysis straightforward.
//
//==============================================================================
// ARCHITECTURE OVERVIEW
//==============================================================================
//
//                     +------------------------------------------+
//                     |           SYNCHRONOUS FIFO               |
//                     |                                          |
//     wr_en --------->|   +--------+                             |
//     wr_data[31:0]-->|   | Memory |  mem[0..DEPTH-1]            |
//                     |   | Array  |  [DATA_WIDTH-1:0]           |
//                     |   +--------+                             |
//                     |       ^                                  |
//                     |       |                                  |
//                     |   wr_ptr                  rd_ptr         |
//                     |   [ADDR_WIDTH:0]          [ADDR_WIDTH:0] |
//                     |       |                       |          |
//                     |       v                       v          |
//     rd_en --------->|   +------+    +------+    +------+       |
//     rd_data[31:0]<--|   |Status|    |Count |    |Peak  |       |
//                     |   |Logic |    |Logic |    |Track |       |
//                     |   +------+    +------+    +------+       |
//                     |       |           |           |          |
//     full <----------|-------+           |           |          |
//     empty <---------|-------+           |           |          |
//     almost_full <---|-------+           |           |          |
//     almost_empty <--|-------+           |           |          |
//     overflow <------|-------+           |           |          |
//     underflow <-----|-------+           |           |          |
//     data_count <----|-------------------+           |          |
//     peak_count <----|-------------------------------+          |
//                     |                                          |
//     clk ----------->|                                          |
//     rst_n --------->|                                          |
//                     +------------------------------------------+
//
//==============================================================================
// CIRCULAR BUFFER CONCEPT
//==============================================================================
//
// The FIFO uses a circular buffer (ring buffer) data structure:
//
// Memory Layout (DEPTH=16):
//
//     Index:   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
//            +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//            |   |   |   | D | D | D | D |   |   |   |   |   |   |   |   |   |
//            +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//                        ^               ^
//                        |               |
//                     rd_ptr          wr_ptr
//
// In this example:
// - rd_ptr points to the oldest data (next to be read)
// - wr_ptr points to the next empty slot (next write location)
// - Data exists from rd_ptr to wr_ptr-1 (wrapping around if necessary)
//
// The circular nature means indices wrap around:
//   After writing to index 15, the next write goes to index 0
//
//==============================================================================
// POINTER MANAGEMENT - THE MSB TRICK
//==============================================================================
//
// A common challenge in FIFO design: How to distinguish between FULL and EMPTY?
// Both conditions occur when rd_ptr == wr_ptr (considering only address bits).
//
// Solution: Use an extra MSB in the pointers
//
// Example with DEPTH=16 (ADDR_WIDTH=4), pointers are 5 bits:
//
//   Pointer format: [MSB | ADDR_WIDTH-1 : 0]
//                    ^    ^---------------^
//                    |    Actual memory address (0-15)
//                    Wrap-around indicator
//
// EMPTY Condition: wr_ptr == rd_ptr (exactly equal, including MSB)
//   Both pointers at same position, writer hasn't written ahead
//
// FULL Condition:
//   - Address bits match: wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]
//   - MSBs differ: wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]
//   This means the writer has wrapped around and caught up to the reader
//
// Example state progression:
//   State        wr_ptr(bin)  rd_ptr(bin)  Count  Status
//   Initial      00000        00000        0      EMPTY
//   Write 4x     00100        00000        4      Normal
//   Write 16x    10000        00000        16     FULL
//   Read 4x      10000        00100        12     Normal
//   Read 12x     10000        10000        0      EMPTY
//
//==============================================================================
// RELATIONSHIP TO COMPUTER ARCHITECTURE CONCEPTS
//==============================================================================
//
// 1. MEMORY HIERARCHY:
//    This FIFO uses register-based memory (synthesizes to flip-flops).
//    Benefits: Fast access, no read latency, simple addressing
//    Tradeoff: Higher area cost than SRAM for large depths
//
// 2. PRODUCER-CONSUMER SYNCHRONIZATION:
//    The FIFO implements hardware-level producer-consumer synchronization:
//    - Producer (writer) checks 'full' flag before writing
//    - Consumer (reader) checks 'empty' flag before reading
//    - No locks needed - hardware flags provide mutual exclusion
//
// 3. FLOW CONTROL:
//    The almost_full/almost_empty flags enable flow control:
//    - almost_full: Tell producer to slow down (backpressure)
//    - almost_empty: Tell consumer data is running low
//
// 4. BUFFERING AND LATENCY:
//    FIFOs decouple timing between producer and consumer:
//    - Absorbs burst traffic
//    - Allows rate matching
//    - Pipeline stage insertion
//
//==============================================================================

`timescale 1ns / 1ps

module fifo_sync #(
    // FIFO Configuration Parameters
    parameter DATA_WIDTH         = 32,                      // Width of data bus
    parameter DEPTH              = 16,                      // Number of entries
    parameter ADDR_WIDTH         = $clog2(DEPTH),           // Address width (auto-calculated)
    parameter ALMOST_FULL_THRESH = DEPTH - 2,               // Almost full threshold
    parameter ALMOST_EMPTY_THRESH = 2                       // Almost empty threshold
) (
    //==========================================================================
    // Clock and Reset
    //==========================================================================
    input  wire                    clk,       // System clock
    input  wire                    rst_n,     // Active-low synchronous reset

    //==========================================================================
    // Write Interface
    //==========================================================================
    input  wire                    wr_en,     // Write enable (active high)
    input  wire [DATA_WIDTH-1:0]   wr_data,   // Write data
    output reg                     full,      // FIFO full flag
    output reg                     almost_full,  // Almost full flag
    output reg                     overflow,  // Overflow error (write when full)

    //==========================================================================
    // Read Interface
    //==========================================================================
    input  wire                    rd_en,     // Read enable (active high)
    output reg  [DATA_WIDTH-1:0]   rd_data,   // Read data
    output reg                     empty,     // FIFO empty flag
    output reg                     almost_empty, // Almost empty flag
    output reg                     underflow, // Underflow error (read when empty)

    //==========================================================================
    // Status and Debug Interface
    //==========================================================================
    output reg  [ADDR_WIDTH:0]     data_count,  // Current number of entries
    output reg  [ADDR_WIDTH:0]     peak_count   // Peak occupancy (watermark)
);

    //==========================================================================
    // INTERNAL SIGNALS
    //==========================================================================

    // Memory array - register-based storage
    // For DEPTH=16 and DATA_WIDTH=32: 16 x 32-bit registers = 512 bits
    // Synthesizes to flip-flops, providing single-cycle access
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers with extra MSB for full/empty detection
    // ADDR_WIDTH+1 bits total: MSB for wrap detection, remaining for address
    reg [ADDR_WIDTH:0] wr_ptr;    // Write pointer
    reg [ADDR_WIDTH:0] rd_ptr;    // Read pointer

    // Internal flags for combinatorial logic
    wire [ADDR_WIDTH:0] next_wr_ptr;  // Next write pointer value
    wire [ADDR_WIDTH:0] next_rd_ptr;  // Next read pointer value
    wire [ADDR_WIDTH:0] next_data_count;  // Next data count

    // Full and empty detection signals
    wire full_cond;   // Combinatorial full condition
    wire empty_cond;  // Combinatorial empty condition

    // Actual write and read operations
    wire do_write;    // Actual write will occur
    wire do_read;     // Actual read will occur

    //==========================================================================
    // POINTER ADDRESS EXTRACTION
    //==========================================================================
    // Extract the actual memory address from the pointers (lower bits only)
    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    //==========================================================================
    // FULL/EMPTY DETECTION LOGIC
    //==========================================================================
    //
    // EMPTY: Both pointers are exactly equal (same position, same wrap count)
    //        This means no unread data exists in the FIFO
    //
    // FULL:  Address portions match, but MSBs differ
    //        This means writer has wrapped around and caught up to reader
    //        The FIFO contains DEPTH elements
    //
    assign empty_cond = (wr_ptr == rd_ptr);

    assign full_cond = (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]) &&
                       (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]);

    //==========================================================================
    // OPERATION VALIDATION
    //==========================================================================
    // Only perform actual operations if conditions allow
    // This prevents corrupting data or generating spurious errors

    assign do_write = wr_en && !full;    // Write only if not full
    assign do_read  = rd_en && !empty;   // Read only if not empty

    //==========================================================================
    // NEXT POINTER CALCULATION
    //==========================================================================
    // Calculate what the pointers will be after this cycle
    // Pointers naturally wrap due to overflow of the address bits

    assign next_wr_ptr = do_write ? (wr_ptr + 1'b1) : wr_ptr;
    assign next_rd_ptr = do_read  ? (rd_ptr + 1'b1) : rd_ptr;

    //==========================================================================
    // DATA COUNT CALCULATION
    //==========================================================================
    // The count is simply the difference between pointers
    // Due to 2's complement arithmetic, this works correctly even with wrap
    //
    // Example: wr_ptr=0x12, rd_ptr=0x10 -> count = 0x12 - 0x10 = 2
    // Example: wr_ptr=0x02, rd_ptr=0x1F -> count = 0x02 - 0x1F = -29
    //          In unsigned: 0x02 - 0x1F + 0x20 (modulo 32) = 3
    //
    assign next_data_count = next_wr_ptr - next_rd_ptr;

    //==========================================================================
    // SEQUENTIAL LOGIC - WRITE OPERATIONS
    //==========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset: Clear write pointer
            wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else if (do_write) begin
            // Write data to memory at current write address
            mem[wr_addr] <= wr_data;
            // Increment write pointer (wraps automatically)
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    //==========================================================================
    // SEQUENTIAL LOGIC - READ OPERATIONS
    //==========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset: Clear read pointer and output
            rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
            rd_data <= {DATA_WIDTH{1'b0}};
        end
        else if (do_read) begin
            // Read data from memory at current read address
            // Data is available on the next clock cycle
            rd_data <= mem[rd_addr];
            // Increment read pointer (wraps automatically)
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    //==========================================================================
    // STATUS FLAG GENERATION
    //==========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset all flags to safe states
            full         <= 1'b0;
            empty        <= 1'b1;  // Empty after reset
            almost_full  <= 1'b0;
            almost_empty <= 1'b1;  // Also empty after reset
            data_count   <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            // Update data count
            data_count <= next_data_count;

            // Full flag: Next state will be full
            // Full when addresses match and MSBs differ
            full <= (next_wr_ptr[ADDR_WIDTH-1:0] == next_rd_ptr[ADDR_WIDTH-1:0]) &&
                    (next_wr_ptr[ADDR_WIDTH] != next_rd_ptr[ADDR_WIDTH]);

            // Empty flag: Next state will be empty
            empty <= (next_wr_ptr == next_rd_ptr);

            // Almost full: Count reaches or exceeds threshold
            // Useful for flow control (backpressure signaling)
            almost_full <= (next_data_count >= ALMOST_FULL_THRESH);

            // Almost empty: Count falls to or below threshold
            // Useful for low-water warning to consumers
            almost_empty <= (next_data_count <= ALMOST_EMPTY_THRESH);
        end
    end

    //==========================================================================
    // ERROR FLAG GENERATION
    //==========================================================================
    // Overflow and underflow are error conditions that indicate
    // protocol violations by the producer or consumer

    always @(posedge clk) begin
        if (!rst_n) begin
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end
        else begin
            // Overflow: Attempted write when FIFO was full
            // This is a protocol violation - producer should check 'full'
            overflow <= wr_en && full;

            // Underflow: Attempted read when FIFO was empty
            // This is a protocol violation - consumer should check 'empty'
            underflow <= rd_en && empty;
        end
    end

    //==========================================================================
    // PEAK OCCUPANCY TRACKING
    //==========================================================================
    // Track the maximum occupancy reached - useful for profiling and
    // determining optimal FIFO sizing

    always @(posedge clk) begin
        if (!rst_n) begin
            peak_count <= {(ADDR_WIDTH+1){1'b0}};
        end
        else if (next_data_count > peak_count) begin
            peak_count <= next_data_count;
        end
    end

    //==========================================================================
    // ASSERTIONS (for simulation/verification)
    //==========================================================================
    // synthesis translate_off

    // Check for overflow - should never happen in correct design
    always @(posedge clk) begin
        if (rst_n && wr_en && full) begin
            $display("[%0t] WARNING: FIFO overflow detected - write attempted when full", $time);
        end
    end

    // Check for underflow - should never happen in correct design
    always @(posedge clk) begin
        if (rst_n && rd_en && empty) begin
            $display("[%0t] WARNING: FIFO underflow detected - read attempted when empty", $time);
        end
    end

    // Verify data count never exceeds DEPTH
    always @(posedge clk) begin
        if (rst_n && (data_count > DEPTH)) begin
            $display("[%0t] ERROR: Data count (%0d) exceeds DEPTH (%0d)",
                     $time, data_count, DEPTH);
            $finish;
        end
    end

    // synthesis translate_on

endmodule
