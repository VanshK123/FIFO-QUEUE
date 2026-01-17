//==============================================================================
// File: fifo_async.v
// Description: Asynchronous FIFO with Clock Domain Crossing (CDC)
//
// This module implements an asynchronous FIFO where the write and read
// interfaces operate in different clock domains. This is a critical
// component for interfacing between systems running at different frequencies.
//
// Key features:
//   - Dual-clock operation (separate write and read clocks)
//   - Gray code pointer synchronization for safe CDC
//   - Configurable synchronizer depth for metastability protection
//   - Full and empty flag generation with conservative detection
//
//==============================================================================
// ARCHITECTURE OVERVIEW
//==============================================================================
//
//     WRITE CLOCK DOMAIN                      READ CLOCK DOMAIN
//     ==================                      ==================
//
//     wr_en                                            rd_en
//       |                                                |
//       v                                                v
//     +-------------------+                  +-------------------+
//     | Write Pointer     |                  | Read Pointer      |
//     | (Binary Counter)  |                  | (Binary Counter)  |
//     +-------------------+                  +-------------------+
//       |         |                                |         |
//       |         v                                |         v
//       |   +-----------+                          |   +-----------+
//       |   | Bin2Gray  |                          |   | Bin2Gray  |
//       |   +-----------+                          |   +-----------+
//       |         |                                |         |
//       |         v                                |         v
//       |   wr_gray_ptr                            |   rd_gray_ptr
//       |         |                                |         |
//       |         |    +------------------+        |         |
//       |         +--->| 2-Stage Sync     |--------|-------->+ (to read domain)
//       |              | (wr_clk -> rd_clk)|       |         |   rd_gray_sync
//       |              +------------------+        |         |
//       |                                          |         |
//       |              +------------------+        |         |
//       +<-------------| 2-Stage Sync     |<-------+---------+ (to write domain)
//       |              | (rd_clk -> wr_clk)|                 |   wr_gray_sync
//       |              +------------------+                  |
//       v                                                    v
//     +-------------------+                  +-------------------+
//     | Full Detection    |                  | Empty Detection   |
//     | (compare pointers)|                  | (compare pointers)|
//     +-------------------+                  +-------------------+
//       |                                                    |
//       v                                                    v
//     full                                                empty
//
//==============================================================================
// DUAL-PORT MEMORY
//==============================================================================
//
//              wr_clk domain          rd_clk domain
//                   |                      |
//                   v                      v
//              +----+----+            +----+----+
//     wr_data->|  WRITE  |            |  READ   |->rd_data
//              |  PORT   |            |  PORT   |
//              +----+----+            +----+----+
//                   |                      |
//                   v                      v
//              +---------------------------------+
//              |                                 |
//              |      DUAL-PORT MEMORY           |
//              |      mem[0..DEPTH-1]            |
//              |      [DATA_WIDTH-1:0]           |
//              |                                 |
//              +---------------------------------+
//
// Important: The memory is written in wr_clk domain and read in rd_clk domain.
// There's no arbitration needed because write and read addresses are different
// (except when FIFO is empty, but then no read occurs).
//
//==============================================================================
// GRAY CODE FULL/EMPTY DETECTION
//==============================================================================
//
// The challenge: Comparing pointers across clock domains safely.
//
// Empty Detection (in read domain):
//   - Compare local rd_gray with synchronized wr_gray_sync
//   - Empty when rd_gray == wr_gray_sync
//   - This is conservative: may show empty when there's actually data
//     (because wr_gray_sync may be stale)
//
// Full Detection (in write domain):
//   - Compare local wr_gray with synchronized rd_gray_sync
//   - Full when pointers match with top 2 bits inverted
//   - This is conservative: may show full when there's actually space
//     (because rd_gray_sync may be stale)
//
// Gray Code Full Condition:
//   For N-bit pointers, FULL when:
//     wr_gray[N-1]   != rd_gray_sync[N-1]     (MSB different)
//     wr_gray[N-2]   != rd_gray_sync[N-2]     (2nd MSB different)
//     wr_gray[N-3:0] == rd_gray_sync[N-3:0]   (remaining bits same)
//
// This works because in Gray code, when the writer wraps around and
// catches up to the reader, the top two bits will be inverted while
// the lower bits match.
//
//==============================================================================
// REFERENCE: Cliff Cummings' SNUG Papers
//==============================================================================
// This design follows the principles from:
//   "Simulation and Synthesis Techniques for Asynchronous FIFO Design"
//   by Clifford E. Cummings, SNUG 2002
//
// Key takeaways from the paper:
// 1. Use Gray code for pointer CDC (only 1 bit changes)
// 2. Register Gray pointers before synchronizing
// 3. Use 2+ stage synchronizers
// 4. Full/empty are conservative (safe for hardware)
//
//==============================================================================

`timescale 1ns / 1ps

module fifo_async #(
    parameter DATA_WIDTH  = 32,              // Width of data bus
    parameter DEPTH       = 16,              // Number of entries (power of 2)
    parameter ADDR_WIDTH  = $clog2(DEPTH),   // Address width
    parameter SYNC_STAGES = 2                // Synchronizer stages
) (
    //==========================================================================
    // Write Clock Domain Interface
    //==========================================================================
    input  wire                    wr_clk,       // Write clock
    input  wire                    wr_rst_n,     // Write domain reset (active low)
    input  wire                    wr_en,        // Write enable
    input  wire [DATA_WIDTH-1:0]   wr_data,      // Write data
    output reg                     full,         // FIFO full flag
    output reg                     almost_full,  // Almost full flag
    output reg                     overflow,     // Overflow error flag
    output reg  [ADDR_WIDTH:0]     wr_data_count,// Data count (write domain view)

    //==========================================================================
    // Read Clock Domain Interface
    //==========================================================================
    input  wire                    rd_clk,       // Read clock
    input  wire                    rd_rst_n,     // Read domain reset (active low)
    input  wire                    rd_en,        // Read enable
    output reg  [DATA_WIDTH-1:0]   rd_data,      // Read data
    output reg                     empty,        // FIFO empty flag
    output reg                     almost_empty, // Almost empty flag
    output reg                     underflow,    // Underflow error flag
    output reg  [ADDR_WIDTH:0]     rd_data_count // Data count (read domain view)
);

    //==========================================================================
    // LOCAL PARAMETERS
    //==========================================================================
    localparam PTR_WIDTH = ADDR_WIDTH + 1;  // Pointer width (extra bit for wrap)
    localparam ALMOST_FULL_THRESH  = DEPTH - 2;
    localparam ALMOST_EMPTY_THRESH = 2;

    //==========================================================================
    // DUAL-PORT MEMORY
    //==========================================================================
    // Simple dual-port RAM: one write port, one read port
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    //==========================================================================
    // WRITE DOMAIN SIGNALS
    //==========================================================================
    reg  [PTR_WIDTH-1:0] wr_ptr_bin;      // Write pointer (binary)
    reg  [PTR_WIDTH-1:0] wr_ptr_gray;     // Write pointer (Gray code)
    wire [PTR_WIDTH-1:0] wr_ptr_bin_next; // Next write pointer (binary)
    wire [PTR_WIDTH-1:0] wr_ptr_gray_next;// Next write pointer (Gray code)

    wire [ADDR_WIDTH-1:0] wr_addr;        // Memory write address
    wire do_write;                         // Actual write enable

    wire [PTR_WIDTH-1:0] rd_ptr_gray_sync; // Read pointer synchronized to wr_clk
    wire [PTR_WIDTH-1:0] rd_ptr_bin_sync;  // Read pointer (binary) in write domain
    wire full_cond;                        // Full condition

    //==========================================================================
    // READ DOMAIN SIGNALS
    //==========================================================================
    reg  [PTR_WIDTH-1:0] rd_ptr_bin;      // Read pointer (binary)
    reg  [PTR_WIDTH-1:0] rd_ptr_gray;     // Read pointer (Gray code)
    wire [PTR_WIDTH-1:0] rd_ptr_bin_next; // Next read pointer (binary)
    wire [PTR_WIDTH-1:0] rd_ptr_gray_next;// Next read pointer (Gray code)

    wire [ADDR_WIDTH-1:0] rd_addr;        // Memory read address
    wire do_read;                          // Actual read enable

    wire [PTR_WIDTH-1:0] wr_ptr_gray_sync; // Write pointer synchronized to rd_clk
    wire [PTR_WIDTH-1:0] wr_ptr_bin_sync;  // Write pointer (binary) in read domain
    wire empty_cond;                       // Empty condition

    //==========================================================================
    // BINARY-TO-GRAY CONVERSION FUNCTIONS
    //==========================================================================
    function [PTR_WIDTH-1:0] bin2gray;
        input [PTR_WIDTH-1:0] binary;
        begin
            bin2gray = binary ^ (binary >> 1);
        end
    endfunction

    function [PTR_WIDTH-1:0] gray2bin;
        input [PTR_WIDTH-1:0] gray;
        integer i;
        begin
            gray2bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
            for (i = PTR_WIDTH-2; i >= 0; i = i - 1) begin
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
            end
        end
    endfunction

    //==========================================================================
    // ADDRESS EXTRACTION
    //==========================================================================
    assign wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];
    assign rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

    //==========================================================================
    // WRITE OPERATION CONTROL
    //==========================================================================
    assign do_write = wr_en && !full;

    //==========================================================================
    // WRITE POINTER LOGIC
    //==========================================================================
    assign wr_ptr_bin_next  = wr_ptr_bin + 1'b1;
    assign wr_ptr_gray_next = bin2gray(wr_ptr_bin_next);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= {PTR_WIDTH{1'b0}};
            wr_ptr_gray <= {PTR_WIDTH{1'b0}};
        end
        else if (do_write) begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    //==========================================================================
    // MEMORY WRITE
    //==========================================================================
    always @(posedge wr_clk) begin
        if (do_write) begin
            mem[wr_addr] <= wr_data;
        end
    end

    //==========================================================================
    // READ OPERATION CONTROL
    //==========================================================================
    assign do_read = rd_en && !empty;

    //==========================================================================
    // READ POINTER LOGIC
    //==========================================================================
    assign rd_ptr_bin_next  = rd_ptr_bin + 1'b1;
    assign rd_ptr_gray_next = bin2gray(rd_ptr_bin_next);

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= {PTR_WIDTH{1'b0}};
            rd_ptr_gray <= {PTR_WIDTH{1'b0}};
        end
        else if (do_read) begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    //==========================================================================
    // MEMORY READ
    //==========================================================================
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_data <= {DATA_WIDTH{1'b0}};
        end
        else if (do_read) begin
            rd_data <= mem[rd_addr];
        end
    end

    //==========================================================================
    // SYNCHRONIZERS
    //==========================================================================
    // Synchronize read pointer to write clock domain (for full detection)
    synchronizer #(
        .WIDTH  (PTR_WIDTH),
        .STAGES (SYNC_STAGES)
    ) sync_rd_ptr (
        .clk       (wr_clk),
        .rst_n     (wr_rst_n),
        .async_in  (rd_ptr_gray),
        .sync_out  (rd_ptr_gray_sync)
    );

    // Synchronize write pointer to read clock domain (for empty detection)
    synchronizer #(
        .WIDTH  (PTR_WIDTH),
        .STAGES (SYNC_STAGES)
    ) sync_wr_ptr (
        .clk       (rd_clk),
        .rst_n     (rd_rst_n),
        .async_in  (wr_ptr_gray),
        .sync_out  (wr_ptr_gray_sync)
    );

    //==========================================================================
    // GRAY TO BINARY CONVERSION FOR DATA COUNT
    //==========================================================================
    // Convert synchronized pointers back to binary for count calculation
    assign rd_ptr_bin_sync = gray2bin(rd_ptr_gray_sync);
    assign wr_ptr_bin_sync = gray2bin(wr_ptr_gray_sync);

    //==========================================================================
    // FULL DETECTION (Write Clock Domain)
    //==========================================================================
    // Full when write pointer has wrapped around and caught up to read pointer.
    // In Gray code, this means:
    //   - Top 2 bits are inverted between wr_gray and rd_gray_sync
    //   - Remaining bits are the same
    //
    // Why? When the binary write pointer wraps (goes from 01111 to 10000),
    // the Gray code goes from 01000 to 11000. If read pointer is at 00000
    // (Gray: 00000), then:
    //   - wr_gray = 11000, rd_gray = 00000
    //   - Top bits: 11 vs 00 (inverted!)
    //   - Lower bits: 000 vs 000 (same)
    //
    assign full_cond = (wr_ptr_gray[PTR_WIDTH-1]   != rd_ptr_gray_sync[PTR_WIDTH-1]) &&
                       (wr_ptr_gray[PTR_WIDTH-2]   != rd_ptr_gray_sync[PTR_WIDTH-2]) &&
                       (wr_ptr_gray[PTR_WIDTH-3:0] == rd_ptr_gray_sync[PTR_WIDTH-3:0]);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            full <= 1'b0;
        end
        else begin
            // Check if next state will be full
            if (do_write) begin
                full <= (wr_ptr_gray_next[PTR_WIDTH-1]   != rd_ptr_gray_sync[PTR_WIDTH-1]) &&
                        (wr_ptr_gray_next[PTR_WIDTH-2]   != rd_ptr_gray_sync[PTR_WIDTH-2]) &&
                        (wr_ptr_gray_next[PTR_WIDTH-3:0] == rd_ptr_gray_sync[PTR_WIDTH-3:0]);
            end
            else begin
                full <= full_cond;
            end
        end
    end

    //==========================================================================
    // EMPTY DETECTION (Read Clock Domain)
    //==========================================================================
    // Empty when read pointer equals write pointer (both in Gray code)
    // This is straightforward: if they're the same, FIFO is empty
    //
    assign empty_cond = (rd_ptr_gray == wr_ptr_gray_sync);

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            empty <= 1'b1;  // Empty after reset
        end
        else begin
            // Check if next state will be empty
            if (do_read) begin
                empty <= (rd_ptr_gray_next == wr_ptr_gray_sync);
            end
            else begin
                empty <= empty_cond;
            end
        end
    end

    //==========================================================================
    // DATA COUNT - WRITE DOMAIN
    //==========================================================================
    // Calculate approximate data count in write domain
    // Note: This is approximate due to synchronization latency

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_data_count <= {(ADDR_WIDTH+1){1'b0}};
            almost_full   <= 1'b0;
        end
        else begin
            wr_data_count <= wr_ptr_bin - rd_ptr_bin_sync;
            almost_full   <= (wr_ptr_bin - rd_ptr_bin_sync) >= ALMOST_FULL_THRESH;
        end
    end

    //==========================================================================
    // DATA COUNT - READ DOMAIN
    //==========================================================================
    // Calculate approximate data count in read domain
    // Note: This is approximate due to synchronization latency

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_data_count <= {(ADDR_WIDTH+1){1'b0}};
            almost_empty  <= 1'b1;  // Almost empty after reset
        end
        else begin
            rd_data_count <= wr_ptr_bin_sync - rd_ptr_bin;
            almost_empty  <= (wr_ptr_bin_sync - rd_ptr_bin) <= ALMOST_EMPTY_THRESH;
        end
    end

    //==========================================================================
    // ERROR FLAGS
    //==========================================================================
    // Overflow detection (write domain)
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            overflow <= 1'b0;
        end
        else begin
            overflow <= wr_en && full;
        end
    end

    // Underflow detection (read domain)
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            underflow <= 1'b0;
        end
        else begin
            underflow <= rd_en && empty;
        end
    end

    //==========================================================================
    // ASSERTIONS (Simulation Only)
    //==========================================================================
    // synthesis translate_off

    // Check for overflow
    always @(posedge wr_clk) begin
        if (wr_rst_n && wr_en && full) begin
            $display("[%0t] ASYNC FIFO WARNING: Write attempted when full (overflow)",
                     $time);
        end
    end

    // Check for underflow
    always @(posedge rd_clk) begin
        if (rd_rst_n && rd_en && empty) begin
            $display("[%0t] ASYNC FIFO WARNING: Read attempted when empty (underflow)",
                     $time);
        end
    end

    // synthesis translate_on

endmodule
