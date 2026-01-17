//==============================================================================
// File: fifo_sync_tb.v
// Description: Comprehensive testbench for Synchronous FIFO
//
// This testbench implements a complete verification strategy including:
//   - Basic functionality tests
//   - Corner case testing
//   - Stress testing
//   - Performance measurement
//   - Self-checking with automatic pass/fail
//
// Test Categories:
//   1. Reset behavior verification
//   2. Single write/read operations
//   3. Fill FIFO to capacity
//   4. Drain FIFO completely
//   5. Overflow detection
//   6. Underflow detection
//   7. Simultaneous read/write
//   8. Random operation patterns
//   9. Burst operations
//  10. Performance metrics collection
//
//==============================================================================

`timescale 1ns / 1ps

module fifo_sync_tb;

    //==========================================================================
    // TESTBENCH PARAMETERS
    //==========================================================================
    parameter DATA_WIDTH         = 32;
    parameter DEPTH              = 16;
    parameter ADDR_WIDTH         = $clog2(DEPTH);
    parameter ALMOST_FULL_THRESH = DEPTH - 2;
    parameter ALMOST_EMPTY_THRESH = 2;
    parameter CLK_PERIOD         = 10;  // 100 MHz

    //==========================================================================
    // DUT SIGNALS
    //==========================================================================
    reg                     clk;
    reg                     rst_n;
    reg                     wr_en;
    reg  [DATA_WIDTH-1:0]   wr_data;
    wire                    full;
    wire                    almost_full;
    wire                    overflow;
    reg                     rd_en;
    wire [DATA_WIDTH-1:0]   rd_data;
    wire                    empty;
    wire                    almost_empty;
    wire                    underflow;
    wire [ADDR_WIDTH:0]     data_count;
    wire [ADDR_WIDTH:0]     peak_count;

    //==========================================================================
    // TEST CONTROL VARIABLES
    //==========================================================================
    integer test_passed;
    integer test_failed;
    integer total_tests;
    integer i, j;
    integer seed;

    // Data verification storage
    reg [DATA_WIDTH-1:0] expected_data_queue [0:DEPTH-1];
    integer queue_head;
    integer queue_tail;
    integer queue_count;

    // Performance metrics
    integer total_writes;
    integer total_reads;
    integer start_time;
    integer end_time;
    real    throughput_mbps;
    integer total_latency;
    integer latency_samples;

    //==========================================================================
    // DUT INSTANTIATION
    //==========================================================================
    fifo_sync #(
        .DATA_WIDTH         (DATA_WIDTH),
        .DEPTH              (DEPTH),
        .ADDR_WIDTH         (ADDR_WIDTH),
        .ALMOST_FULL_THRESH (ALMOST_FULL_THRESH),
        .ALMOST_EMPTY_THRESH(ALMOST_EMPTY_THRESH)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .wr_en        (wr_en),
        .wr_data      (wr_data),
        .full         (full),
        .almost_full  (almost_full),
        .overflow     (overflow),
        .rd_en        (rd_en),
        .rd_data      (rd_data),
        .empty        (empty),
        .almost_empty (almost_empty),
        .underflow    (underflow),
        .data_count   (data_count),
        .peak_count   (peak_count)
    );

    //==========================================================================
    // CLOCK GENERATION
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // VCD DUMP FOR WAVEFORM VIEWING
    //==========================================================================
    initial begin
        $dumpfile("../results/waveforms/fifo_sync.vcd");
        $dumpvars(0, fifo_sync_tb);
    end

    //==========================================================================
    // EXPECTED DATA QUEUE MANAGEMENT
    //==========================================================================
    // This queue tracks expected data for verification

    task queue_init;
        begin
            queue_head = 0;
            queue_tail = 0;
            queue_count = 0;
        end
    endtask

    task queue_push;
        input [DATA_WIDTH-1:0] data;
        begin
            expected_data_queue[queue_tail] = data;
            queue_tail = (queue_tail + 1) % DEPTH;
            queue_count = queue_count + 1;
        end
    endtask

    function [DATA_WIDTH-1:0] queue_pop;
        begin
            queue_pop = expected_data_queue[queue_head];
            queue_head = (queue_head + 1) % DEPTH;
            queue_count = queue_count - 1;
        end
    endfunction

    //==========================================================================
    // HELPER TASKS
    //==========================================================================

    // Wait for specified number of clock cycles
    task wait_cycles;
        input integer n;
        begin
            repeat(n) @(posedge clk);
        end
    endtask

    // Apply reset
    task apply_reset;
        begin
            rst_n = 0;
            wr_en = 0;
            rd_en = 0;
            wr_data = 0;
            wait_cycles(5);
            rst_n = 1;
            wait_cycles(2);
        end
    endtask

    // Write single data word
    task write_data;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            wr_en = 1;
            wr_data = data;
            @(posedge clk);
            wr_en = 0;
            total_writes = total_writes + 1;
        end
    endtask

    // Read single data word (returns data via rd_data signal)
    task read_data;
        begin
            @(posedge clk);
            rd_en = 1;
            @(posedge clk);
            rd_en = 0;
            total_reads = total_reads + 1;
        end
    endtask

    // Write without waiting (for burst operations)
    task write_nowait;
        input [DATA_WIDTH-1:0] data;
        begin
            wr_en = 1;
            wr_data = data;
        end
    endtask

    // Stop writing
    task write_stop;
        begin
            wr_en = 0;
        end
    endtask

    // Start reading
    task read_start;
        begin
            rd_en = 1;
        end
    endtask

    // Stop reading
    task read_stop;
        begin
            rd_en = 0;
        end
    endtask

    // Report test result
    task report_test;
        input [255:0] test_name;
        input pass;
        begin
            total_tests = total_tests + 1;
            if (pass) begin
                test_passed = test_passed + 1;
                $display("[TEST %0d] %0s.............. PASS", total_tests, test_name);
            end
            else begin
                test_failed = test_failed + 1;
                $display("[TEST %0d] %0s.............. FAIL", total_tests, test_name);
            end
        end
    endtask

    //==========================================================================
    // TEST 1: RESET BEHAVIOR
    //==========================================================================
    task test_reset;
        reg pass;
        begin
            $display("\n--- Test 1: Reset Behavior ---");
            apply_reset();

            pass = 1;

            // After reset, FIFO should be empty
            if (empty !== 1'b1) begin
                $display("  ERROR: empty should be 1 after reset");
                pass = 0;
            end

            // Full should be deasserted
            if (full !== 1'b0) begin
                $display("  ERROR: full should be 0 after reset");
                pass = 0;
            end

            // Data count should be 0
            if (data_count !== 0) begin
                $display("  ERROR: data_count should be 0 after reset");
                pass = 0;
            end

            // Almost empty should be asserted (count <= threshold)
            if (almost_empty !== 1'b1) begin
                $display("  ERROR: almost_empty should be 1 after reset");
                pass = 0;
            end

            // Almost full should be deasserted
            if (almost_full !== 1'b0) begin
                $display("  ERROR: almost_full should be 0 after reset");
                pass = 0;
            end

            report_test("Reset Test", pass);
        end
    endtask

    //==========================================================================
    // TEST 2: SINGLE WRITE/READ
    //==========================================================================
    task test_single_write_read;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        reg [DATA_WIDTH-1:0] read_result;
        begin
            $display("\n--- Test 2: Single Write/Read ---");
            apply_reset();
            queue_init();
            pass = 1;

            test_data = 32'hDEADBEEF;

            // Write single word
            write_data(test_data);
            queue_push(test_data);
            wait_cycles(1);

            // Verify not empty anymore
            if (empty !== 1'b0) begin
                $display("  ERROR: empty should be 0 after write");
                pass = 0;
            end

            // Verify count is 1
            if (data_count !== 1) begin
                $display("  ERROR: data_count should be 1, got %0d", data_count);
                pass = 0;
            end

            // Read the data back
            read_data();
            read_result = queue_pop();
            wait_cycles(1);

            // Verify read data matches written data
            if (rd_data !== test_data) begin
                $display("  ERROR: Read data mismatch. Expected: %h, Got: %h",
                         test_data, rd_data);
                pass = 0;
            end

            // Verify FIFO is empty again
            if (empty !== 1'b1) begin
                $display("  ERROR: empty should be 1 after read");
                pass = 0;
            end

            report_test("Single Write/Read", pass);
        end
    endtask

    //==========================================================================
    // TEST 3: FILL FIFO
    //==========================================================================
    task test_fill_fifo;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        integer count;
        begin
            $display("\n--- Test 3: Fill FIFO ---");
            apply_reset();
            queue_init();
            pass = 1;

            // Write DEPTH words
            for (i = 0; i < DEPTH; i = i + 1) begin
                test_data = i + 32'hA000;
                write_data(test_data);
                queue_push(test_data);
            end
            wait_cycles(1);

            // Verify FIFO is full
            if (full !== 1'b1) begin
                $display("  ERROR: full should be 1 after writing DEPTH words");
                pass = 0;
            end

            // Verify count equals DEPTH
            if (data_count !== DEPTH) begin
                $display("  ERROR: data_count should be %0d, got %0d", DEPTH, data_count);
                pass = 0;
            end

            // Verify almost_full is set
            if (almost_full !== 1'b1) begin
                $display("  ERROR: almost_full should be 1 when full");
                pass = 0;
            end

            // Verify empty is not set
            if (empty !== 1'b0) begin
                $display("  ERROR: empty should be 0 when full");
                pass = 0;
            end

            report_test("Fill FIFO", pass);
        end
    endtask

    //==========================================================================
    // TEST 4: DRAIN FIFO
    //==========================================================================
    task test_drain_fifo;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        reg [DATA_WIDTH-1:0] expected;
        begin
            $display("\n--- Test 4: Drain FIFO ---");
            // Start from filled state (test_fill_fifo already ran)
            pass = 1;

            // Read all words and verify data
            for (i = 0; i < DEPTH; i = i + 1) begin
                expected = i + 32'hA000;  // Same pattern as written
                read_data();
                wait_cycles(1);

                if (rd_data !== expected) begin
                    $display("  ERROR: Data mismatch at index %0d. Expected: %h, Got: %h",
                             i, expected, rd_data);
                    pass = 0;
                end
            end
            wait_cycles(1);

            // Verify FIFO is empty
            if (empty !== 1'b1) begin
                $display("  ERROR: empty should be 1 after draining");
                pass = 0;
            end

            // Verify count is 0
            if (data_count !== 0) begin
                $display("  ERROR: data_count should be 0, got %0d", data_count);
                pass = 0;
            end

            report_test("Drain FIFO", pass);
        end
    endtask

    //==========================================================================
    // TEST 5: OVERFLOW DETECTION
    //==========================================================================
    task test_overflow;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        begin
            $display("\n--- Test 5: Overflow Detection ---");
            apply_reset();
            pass = 1;

            // Fill the FIFO
            for (i = 0; i < DEPTH; i = i + 1) begin
                test_data = i;
                write_data(test_data);
            end
            wait_cycles(1);

            // Verify full
            if (full !== 1'b1) begin
                $display("  ERROR: FIFO should be full");
                pass = 0;
            end

            // Attempt to write when full
            write_data(32'hBADBAD);
            wait_cycles(1);

            // Verify overflow flag was set
            if (overflow !== 1'b1) begin
                $display("  ERROR: overflow should be set after write when full");
                pass = 0;
            end

            // Verify count didn't exceed DEPTH
            if (data_count > DEPTH) begin
                $display("  ERROR: data_count (%0d) exceeded DEPTH (%0d)", data_count, DEPTH);
                pass = 0;
            end

            report_test("Overflow Detection", pass);
        end
    endtask

    //==========================================================================
    // TEST 6: UNDERFLOW DETECTION
    //==========================================================================
    task test_underflow;
        reg pass;
        begin
            $display("\n--- Test 6: Underflow Detection ---");
            apply_reset();
            pass = 1;

            // Verify FIFO is empty
            if (empty !== 1'b1) begin
                $display("  ERROR: FIFO should be empty after reset");
                pass = 0;
            end

            // Attempt to read when empty
            read_data();
            wait_cycles(1);

            // Verify underflow flag was set
            if (underflow !== 1'b1) begin
                $display("  ERROR: underflow should be set after read when empty");
                pass = 0;
            end

            report_test("Underflow Detection", pass);
        end
    endtask

    //==========================================================================
    // TEST 7: SIMULTANEOUS READ/WRITE
    //==========================================================================
    task test_simultaneous_rw;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        integer initial_count;
        begin
            $display("\n--- Test 7: Simultaneous Read/Write ---");
            apply_reset();
            queue_init();
            pass = 1;

            // Pre-fill with some data
            for (i = 0; i < DEPTH/2; i = i + 1) begin
                test_data = 32'hC000 + i;
                write_data(test_data);
                queue_push(test_data);
            end
            wait_cycles(1);

            initial_count = data_count;

            // Perform simultaneous read and write for several cycles
            for (i = 0; i < 10; i = i + 1) begin
                @(posedge clk);
                wr_en = 1;
                rd_en = 1;
                wr_data = 32'hD000 + i;
                queue_pop();  // Pop for the read
                queue_push(32'hD000 + i);  // Push for the write
                total_writes = total_writes + 1;
                total_reads = total_reads + 1;
            end
            @(posedge clk);
            wr_en = 0;
            rd_en = 0;
            wait_cycles(1);

            // Count should remain the same
            if (data_count !== initial_count) begin
                $display("  ERROR: data_count changed during simultaneous R/W");
                $display("         Initial: %0d, Final: %0d", initial_count, data_count);
                pass = 0;
            end

            report_test("Simultaneous R/W", pass);
        end
    endtask

    //==========================================================================
    // TEST 8: RANDOM OPERATIONS
    //==========================================================================
    task test_random_ops;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        reg [DATA_WIDTH-1:0] expected_val;
        reg [1:0] operation;
        integer write_count;
        integer read_count;
        integer local_wr_idx;
        integer local_rd_idx;
        begin
            $display("\n--- Test 8: Random Operations ---");
            apply_reset();
            pass = 1;
            seed = 12345;
            write_count = 0;
            read_count = 0;
            local_wr_idx = 0;
            local_rd_idx = 0;

            // Pre-fill FIFO with some data
            for (i = 0; i < DEPTH/2; i = i + 1) begin
                test_data = 32'hA000 + i;
                write_data(test_data);
                expected_data_queue[local_wr_idx] = test_data;
                local_wr_idx = local_wr_idx + 1;
                write_count = write_count + 1;
            end

            // Perform 50 random operations
            for (i = 0; i < 50; i = i + 1) begin
                operation = $random(seed) % 4;

                case (operation)
                    2'b00, 2'b01: begin
                        // Write operation (50% probability)
                        if (!full) begin
                            test_data = 32'hB000 + i;
                            write_data(test_data);
                            expected_data_queue[local_wr_idx % (DEPTH*4)] = test_data;
                            local_wr_idx = local_wr_idx + 1;
                            write_count = write_count + 1;
                        end
                    end
                    2'b10, 2'b11: begin
                        // Read operation (50% probability)
                        if (!empty && (local_rd_idx < local_wr_idx)) begin
                            expected_val = expected_data_queue[local_rd_idx % (DEPTH*4)];
                            read_data();
                            if (rd_data !== expected_val) begin
                                $display("  ERROR: Random test data mismatch at iteration %0d", i);
                                $display("         Expected: %h, Got: %h", expected_val, rd_data);
                                pass = 0;
                            end
                            local_rd_idx = local_rd_idx + 1;
                            read_count = read_count + 1;
                        end
                    end
                endcase
            end

            $display("  Random ops completed: %0d writes, %0d reads", write_count, read_count);
            report_test("Random Operations", pass);
        end
    endtask

    //==========================================================================
    // TEST 9: BURST WRITE/READ
    //==========================================================================
    task test_burst_ops;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        reg [DATA_WIDTH-1:0] expected;
        begin
            $display("\n--- Test 9: Burst Write/Read ---");
            apply_reset();
            pass = 1;

            // Burst write
            $display("  Starting burst write of %0d words", DEPTH);
            @(posedge clk);
            for (i = 0; i < DEPTH; i = i + 1) begin
                wr_en = 1;
                wr_data = 32'hE000 + i;
                @(posedge clk);
                total_writes = total_writes + 1;
            end
            wr_en = 0;
            wait_cycles(1);

            // Verify full
            if (full !== 1'b1) begin
                $display("  ERROR: FIFO should be full after burst write");
                pass = 0;
            end

            // Burst read
            $display("  Starting burst read of %0d words", DEPTH);
            for (i = 0; i < DEPTH; i = i + 1) begin
                @(posedge clk);
                rd_en = 1;
                total_reads = total_reads + 1;
            end
            @(posedge clk);
            rd_en = 0;

            // Wait for last data to appear
            @(posedge clk);

            // Verify last read
            if (rd_data !== (32'hE000 + DEPTH - 1)) begin
                $display("  ERROR: Burst read mismatch. Expected: %h, Got: %h",
                         32'hE000 + DEPTH - 1, rd_data);
                pass = 0;
            end

            // Verify empty
            if (empty !== 1'b1) begin
                $display("  ERROR: FIFO should be empty after burst read");
                pass = 0;
            end

            report_test("Burst Write/Read", pass);
        end
    endtask

    //==========================================================================
    // TEST 10: PERFORMANCE MEASUREMENT
    //==========================================================================
    task test_performance;
        reg pass;
        integer perf_writes;
        integer perf_reads;
        integer perf_start;
        integer perf_end;
        real data_transferred_mb;
        real time_elapsed_us;
        begin
            $display("\n--- Test 10: Performance Measurement ---");
            apply_reset();
            pass = 1;
            perf_writes = 0;
            perf_reads = 0;

            perf_start = $time;

            // Run continuous write/read for 1000 transactions
            for (i = 0; i < 500; i = i + 1) begin
                // Write phase
                if (!full) begin
                    @(posedge clk);
                    wr_en = 1;
                    wr_data = i;
                    @(posedge clk);
                    wr_en = 0;
                    perf_writes = perf_writes + 1;
                end

                // Read phase
                if (!empty) begin
                    @(posedge clk);
                    rd_en = 1;
                    @(posedge clk);
                    rd_en = 0;
                    perf_reads = perf_reads + 1;
                end
            end

            perf_end = $time;

            // Calculate throughput
            time_elapsed_us = (perf_end - perf_start) / 1000.0;  // ns to us
            data_transferred_mb = (perf_writes * DATA_WIDTH / 8.0) / (1024.0 * 1024.0);  // bytes to MB
            throughput_mbps = data_transferred_mb / (time_elapsed_us / 1000000.0);  // MB/s

            $display("  Writes: %0d, Reads: %0d", perf_writes, perf_reads);
            $display("  Time elapsed: %0.2f us", time_elapsed_us);
            $display("  Data transferred: %0.4f MB", data_transferred_mb);
            $display("  Throughput: %0.2f MB/s (estimated)", throughput_mbps);
            $display("  Peak occupancy: %0d/%0d (%0d%%)",
                     peak_count, DEPTH, (peak_count * 100) / DEPTH);

            report_test("Performance Test", pass);
        end
    endtask

    //==========================================================================
    // MAIN TEST SEQUENCE
    //==========================================================================
    initial begin
        // Initialize
        test_passed = 0;
        test_failed = 0;
        total_tests = 0;
        total_writes = 0;
        total_reads = 0;

        $display("");
        $display("================================");
        $display("FIFO SYNCHRONOUS TESTBENCH");
        $display("================================");
        $display("DATA_WIDTH = %0d", DATA_WIDTH);
        $display("DEPTH = %0d", DEPTH);
        $display("CLK_PERIOD = %0d ns", CLK_PERIOD);
        $display("================================");

        // Run all tests
        test_reset();
        test_single_write_read();
        test_fill_fifo();
        test_drain_fifo();
        test_overflow();
        test_underflow();
        test_simultaneous_rw();
        test_random_ops();
        test_burst_ops();
        test_performance();

        // Final report
        $display("");
        $display("================================");
        $display("SIMULATION SUMMARY");
        $display("================================");
        $display("Total Tests: %0d", total_tests);
        $display("Passed: %0d", test_passed);
        $display("Failed: %0d", test_failed);
        $display("Success Rate: %0d%%", (test_passed * 100) / total_tests);
        $display("");
        $display("Performance Metrics:");
        $display("- Peak Occupancy: %0d/%0d (%0d%%)",
                 peak_count, DEPTH, (peak_count * 100) / DEPTH);
        $display("- Total Writes: %0d", total_writes);
        $display("- Total Reads: %0d", total_reads);
        $display("- Throughput: %0.2f MB/s (estimated)", throughput_mbps);
        $display("");

        if (test_failed == 0) begin
            $display("================================");
            $display("SIMULATION COMPLETE - ALL TESTS PASSED!");
            $display("================================");
        end
        else begin
            $display("================================");
            $display("SIMULATION COMPLETE - SOME TESTS FAILED!");
            $display("================================");
        end

        $finish;
    end

    //==========================================================================
    // TIMEOUT WATCHDOG
    //==========================================================================
    initial begin
        #1000000;  // 1ms timeout
        $display("");
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
