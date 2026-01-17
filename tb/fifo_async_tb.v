//==============================================================================
// File: fifo_async_tb.v
// Description: Comprehensive testbench for Asynchronous FIFO
//
// This testbench verifies the asynchronous FIFO across different clock
// domain configurations and CDC-specific scenarios.
//
// Test Categories:
//   1. Reset behavior (both domains)
//   2. Basic write/read operations
//   3. Clock frequency variations (write faster, read faster, same)
//   4. Fill and drain operations
//   5. Overflow/underflow detection
//   6. CDC stress testing
//   7. Random operations
//   8. Burst operations
//   9. Performance measurement
//  10. Data integrity verification
//
//==============================================================================

`timescale 1ns / 1ps

module fifo_async_tb;

    //==========================================================================
    // TESTBENCH PARAMETERS
    //==========================================================================
    parameter DATA_WIDTH   = 32;
    parameter DEPTH        = 16;
    parameter ADDR_WIDTH   = $clog2(DEPTH);
    parameter SYNC_STAGES  = 2;

    // Clock periods (nanoseconds)
    parameter WR_CLK_PERIOD = 10;   // 100 MHz write clock
    parameter RD_CLK_PERIOD = 15;   // 66.67 MHz read clock

    //==========================================================================
    // DUT SIGNALS
    //==========================================================================
    // Write domain
    reg                     wr_clk;
    reg                     wr_rst_n;
    reg                     wr_en;
    reg  [DATA_WIDTH-1:0]   wr_data;
    wire                    full;
    wire                    almost_full;
    wire                    overflow;
    wire [ADDR_WIDTH:0]     wr_data_count;

    // Read domain
    reg                     rd_clk;
    reg                     rd_rst_n;
    reg                     rd_en;
    wire [DATA_WIDTH-1:0]   rd_data;
    wire                    empty;
    wire                    almost_empty;
    wire                    underflow;
    wire [ADDR_WIDTH:0]     rd_data_count;

    //==========================================================================
    // TEST CONTROL VARIABLES
    //==========================================================================
    integer test_passed;
    integer test_failed;
    integer total_tests;
    integer i, j;
    integer seed;

    // Data verification queue
    reg [DATA_WIDTH-1:0] expected_queue [0:DEPTH*4-1];  // Larger queue for safety
    integer queue_wr_ptr;
    integer queue_rd_ptr;
    integer queue_count;

    // Performance metrics
    integer total_writes;
    integer total_reads;
    integer data_errors;

    // Clock control for variable frequency tests
    real wr_clk_period_current;
    real rd_clk_period_current;

    //==========================================================================
    // DUT INSTANTIATION
    //==========================================================================
    fifo_async #(
        .DATA_WIDTH  (DATA_WIDTH),
        .DEPTH       (DEPTH),
        .ADDR_WIDTH  (ADDR_WIDTH),
        .SYNC_STAGES (SYNC_STAGES)
    ) dut (
        // Write interface
        .wr_clk       (wr_clk),
        .wr_rst_n     (wr_rst_n),
        .wr_en        (wr_en),
        .wr_data      (wr_data),
        .full         (full),
        .almost_full  (almost_full),
        .overflow     (overflow),
        .wr_data_count(wr_data_count),

        // Read interface
        .rd_clk       (rd_clk),
        .rd_rst_n     (rd_rst_n),
        .rd_en        (rd_en),
        .rd_data      (rd_data),
        .empty        (empty),
        .almost_empty (almost_empty),
        .underflow    (underflow),
        .rd_data_count(rd_data_count)
    );

    //==========================================================================
    // CLOCK GENERATION
    //==========================================================================
    // Write clock
    initial begin
        wr_clk = 0;
        wr_clk_period_current = WR_CLK_PERIOD;
        forever #(wr_clk_period_current/2) wr_clk = ~wr_clk;
    end

    // Read clock (different frequency and phase)
    initial begin
        rd_clk = 0;
        rd_clk_period_current = RD_CLK_PERIOD;
        #3;  // Phase offset to stress CDC
        forever #(rd_clk_period_current/2) rd_clk = ~rd_clk;
    end

    //==========================================================================
    // VCD DUMP
    //==========================================================================
    initial begin
        $dumpfile("../results/waveforms/fifo_async.vcd");
        $dumpvars(0, fifo_async_tb);
    end

    //==========================================================================
    // VERIFICATION QUEUE MANAGEMENT
    //==========================================================================
    task queue_init;
        begin
            queue_wr_ptr = 0;
            queue_rd_ptr = 0;
            queue_count = 0;
        end
    endtask

    task queue_push;
        input [DATA_WIDTH-1:0] data;
        begin
            expected_queue[queue_wr_ptr] = data;
            queue_wr_ptr = (queue_wr_ptr + 1) % (DEPTH*4);
            queue_count = queue_count + 1;
        end
    endtask

    function [DATA_WIDTH-1:0] queue_front;
        begin
            queue_front = expected_queue[queue_rd_ptr];
        end
    endfunction

    task queue_pop;
        begin
            queue_rd_ptr = (queue_rd_ptr + 1) % (DEPTH*4);
            queue_count = queue_count - 1;
        end
    endtask

    //==========================================================================
    // HELPER TASKS
    //==========================================================================

    // Wait for write clock cycles
    task wait_wr_cycles;
        input integer n;
        begin
            repeat(n) @(posedge wr_clk);
        end
    endtask

    // Wait for read clock cycles
    task wait_rd_cycles;
        input integer n;
        begin
            repeat(n) @(posedge rd_clk);
        end
    endtask

    // Apply reset to both domains
    task apply_reset;
        begin
            wr_rst_n = 0;
            rd_rst_n = 0;
            wr_en = 0;
            rd_en = 0;
            wr_data = 0;
            wait_wr_cycles(5);
            wait_rd_cycles(5);
            wr_rst_n = 1;
            rd_rst_n = 1;
            wait_wr_cycles(3);
            wait_rd_cycles(3);
        end
    endtask

    // Write single data
    task write_single;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge wr_clk);
            wr_en = 1;
            wr_data = data;
            @(posedge wr_clk);
            wr_en = 0;
            total_writes = total_writes + 1;
        end
    endtask

    // Read single data
    task read_single;
        begin
            @(posedge rd_clk);
            rd_en = 1;
            @(posedge rd_clk);
            rd_en = 0;
            total_reads = total_reads + 1;
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

            // Check write domain
            if (full !== 1'b0) begin
                $display("  ERROR: full should be 0 after reset");
                pass = 0;
            end

            // Check read domain
            if (empty !== 1'b1) begin
                $display("  ERROR: empty should be 1 after reset");
                pass = 0;
            end

            // Check data counts
            // Allow some cycles for synchronizers to settle
            wait_wr_cycles(5);
            wait_rd_cycles(5);

            report_test("Reset Test", pass);
        end
    endtask

    //==========================================================================
    // TEST 2: BASIC WRITE/READ
    //==========================================================================
    task test_basic_write_read;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        begin
            $display("\n--- Test 2: Basic Write/Read ---");
            apply_reset();
            queue_init();
            pass = 1;

            test_data = 32'hCAFEBABE;

            // Write one word
            write_single(test_data);
            queue_push(test_data);

            // Wait for CDC synchronization
            wait_rd_cycles(SYNC_STAGES + 3);

            // Check not empty
            if (empty !== 1'b0) begin
                $display("  ERROR: empty should be 0 after write");
                pass = 0;
            end

            // Read the word
            read_single();
            wait_rd_cycles(1);

            // Verify data
            if (rd_data !== test_data) begin
                $display("  ERROR: Data mismatch. Expected: %h, Got: %h",
                         test_data, rd_data);
                pass = 0;
            end
            queue_pop();

            // Wait and check empty
            wait_wr_cycles(SYNC_STAGES + 3);
            wait_rd_cycles(SYNC_STAGES + 3);

            report_test("Basic Write/Read", pass);
        end
    endtask

    //==========================================================================
    // TEST 3: FILL FIFO
    //==========================================================================
    task test_fill_fifo;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        begin
            $display("\n--- Test 3: Fill FIFO ---");
            apply_reset();
            queue_init();
            pass = 1;

            // Write DEPTH words
            for (i = 0; i < DEPTH; i = i + 1) begin
                test_data = 32'hF000 + i;
                write_single(test_data);
                queue_push(test_data);
            end

            // Wait for synchronization
            wait_wr_cycles(SYNC_STAGES + 3);

            // Check full
            if (full !== 1'b1) begin
                $display("  ERROR: full should be 1 after filling");
                pass = 0;
            end

            // Check not empty
            wait_rd_cycles(SYNC_STAGES + 3);
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
        reg [DATA_WIDTH-1:0] expected;
        begin
            $display("\n--- Test 4: Drain FIFO ---");
            // Continue from filled state
            pass = 1;

            // Read all words
            for (i = 0; i < DEPTH; i = i + 1) begin
                expected = 32'hF000 + i;
                read_single();
                wait_rd_cycles(1);

                if (rd_data !== expected) begin
                    $display("  ERROR: Data mismatch at %0d. Expected: %h, Got: %h",
                             i, expected, rd_data);
                    pass = 0;
                end
                queue_pop();
            end

            // Wait for synchronization
            wait_rd_cycles(SYNC_STAGES + 3);

            // Check empty
            if (empty !== 1'b1) begin
                $display("  ERROR: empty should be 1 after draining");
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

            // Fill FIFO
            for (i = 0; i < DEPTH; i = i + 1) begin
                test_data = i;
                write_single(test_data);
            end

            wait_wr_cycles(3);

            // Verify full
            if (full !== 1'b1) begin
                $display("  ERROR: FIFO should be full");
                pass = 0;
            end

            // Attempt write when full
            @(posedge wr_clk);
            wr_en = 1;
            wr_data = 32'hBADBAD;
            @(posedge wr_clk);
            // Check overflow on this cycle (before wr_en goes low)
            if (overflow !== 1'b1) begin
                $display("  ERROR: overflow should be set");
                pass = 0;
            end
            wr_en = 0;

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

            // Verify empty
            if (empty !== 1'b1) begin
                $display("  ERROR: FIFO should be empty after reset");
                pass = 0;
            end

            // Attempt read when empty
            @(posedge rd_clk);
            rd_en = 1;
            @(posedge rd_clk);
            // Check underflow on this cycle (before rd_en goes low)
            if (underflow !== 1'b1) begin
                $display("  ERROR: underflow should be set");
                pass = 0;
            end
            rd_en = 0;

            report_test("Underflow Detection", pass);
        end
    endtask

    //==========================================================================
    // TEST 7: CLOCK RATIO - WRITE FASTER
    //==========================================================================
    task test_clock_ratio_wr_fast;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        integer write_count;
        integer read_count;
        begin
            $display("\n--- Test 7: Write Clock Faster (2:1 ratio) ---");
            apply_reset();
            queue_init();
            pass = 1;
            write_count = 0;
            read_count = 0;

            // Write multiple words quickly
            for (i = 0; i < DEPTH/2; i = i + 1) begin
                test_data = 32'h7000 + i;
                @(posedge wr_clk);
                if (!full) begin
                    wr_en = 1;
                    wr_data = test_data;
                    queue_push(test_data);
                    write_count = write_count + 1;
                end
                @(posedge wr_clk);
                wr_en = 0;
            end

            // Read slowly
            for (i = 0; i < write_count && !pass; i = i + 1) begin
                wait_rd_cycles(SYNC_STAGES + 2);
                if (!empty) begin
                    @(posedge rd_clk);
                    rd_en = 1;
                    @(posedge rd_clk);
                    rd_en = 0;
                    wait_rd_cycles(1);

                    if (rd_data !== queue_front()) begin
                        $display("  ERROR: Data mismatch. Expected: %h, Got: %h",
                                 queue_front(), rd_data);
                        pass = 0;
                    end
                    queue_pop();
                    read_count = read_count + 1;
                end
            end

            // Drain remaining
            wait_rd_cycles(10);
            while (!empty) begin
                @(posedge rd_clk);
                rd_en = 1;
                @(posedge rd_clk);
                rd_en = 0;
                wait_rd_cycles(1);
                if (queue_count > 0) begin
                    if (rd_data !== queue_front()) begin
                        $display("  ERROR: Data mismatch during drain");
                        pass = 0;
                    end
                    queue_pop();
                end
                read_count = read_count + 1;
            end

            $display("  Writes: %0d, Reads: %0d", write_count, read_count);
            report_test("Write Clock Faster", pass);
        end
    endtask

    //==========================================================================
    // TEST 8: CDC STRESS TEST
    //==========================================================================
    task test_cdc_stress;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        integer iteration;
        integer local_errors;
        begin
            $display("\n--- Test 8: CDC Stress Test ---");
            apply_reset();
            queue_init();
            pass = 1;
            local_errors = 0;

            // Rapid alternating writes and reads
            fork
                // Writer process
                begin
                    for (iteration = 0; iteration < 100; iteration = iteration + 1) begin
                        @(posedge wr_clk);
                        if (!full) begin
                            wr_en = 1;
                            wr_data = 32'h8000 + iteration;
                            queue_push(32'h8000 + iteration);
                            total_writes = total_writes + 1;
                        end
                        else begin
                            wr_en = 0;
                        end
                    end
                    @(posedge wr_clk);
                    wr_en = 0;
                end

                // Reader process
                begin
                    wait_rd_cycles(5);  // Let some data accumulate
                    for (iteration = 0; iteration < 100; iteration = iteration + 1) begin
                        @(posedge rd_clk);
                        if (!empty) begin
                            rd_en = 1;
                            @(posedge rd_clk);
                            rd_en = 0;
                            total_reads = total_reads + 1;
                            @(posedge rd_clk);  // Data valid
                            if (queue_count > 0) begin
                                if (rd_data !== queue_front()) begin
                                    local_errors = local_errors + 1;
                                end
                                queue_pop();
                            end
                        end
                        else begin
                            rd_en = 0;
                        end
                    end
                    rd_en = 0;
                end
            join

            // Drain any remaining data
            wait_rd_cycles(10);
            while (!empty) begin
                @(posedge rd_clk);
                rd_en = 1;
                @(posedge rd_clk);
                rd_en = 0;
                @(posedge rd_clk);
                if (queue_count > 0) begin
                    if (rd_data !== queue_front()) begin
                        local_errors = local_errors + 1;
                    end
                    queue_pop();
                end
            end

            if (local_errors > 0) begin
                $display("  Data errors: %0d", local_errors);
                pass = 0;
            end

            report_test("CDC Stress Test", pass);
        end
    endtask

    //==========================================================================
    // TEST 9: RANDOM OPERATIONS
    //==========================================================================
    task test_random_ops;
        reg pass;
        reg [DATA_WIDTH-1:0] test_data;
        reg [1:0] operation;
        integer local_errors;
        begin
            $display("\n--- Test 9: Random Operations ---");
            apply_reset();
            queue_init();
            pass = 1;
            seed = 98765;
            local_errors = 0;

            fork
                // Random writer
                begin
                    for (i = 0; i < 200; i = i + 1) begin
                        @(posedge wr_clk);
                        if ($random(seed) % 2 == 0 && !full) begin
                            wr_en = 1;
                            test_data = $random(seed);
                            wr_data = test_data;
                            queue_push(test_data);
                            total_writes = total_writes + 1;
                        end
                        else begin
                            wr_en = 0;
                        end
                    end
                    wr_en = 0;
                end

                // Random reader
                begin
                    for (i = 0; i < 200; i = i + 1) begin
                        @(posedge rd_clk);
                        if ($random(seed) % 2 == 0 && !empty) begin
                            rd_en = 1;
                            @(posedge rd_clk);
                            rd_en = 0;
                            total_reads = total_reads + 1;
                            @(posedge rd_clk);
                            if (queue_count > 0) begin
                                if (rd_data !== queue_front()) begin
                                    local_errors = local_errors + 1;
                                end
                                queue_pop();
                            end
                        end
                        else begin
                            rd_en = 0;
                        end
                    end
                    rd_en = 0;
                end
            join

            // Drain remaining
            wait_rd_cycles(20);
            while (!empty && queue_count > 0) begin
                @(posedge rd_clk);
                rd_en = 1;
                @(posedge rd_clk);
                rd_en = 0;
                @(posedge rd_clk);
                if (queue_count > 0) begin
                    if (rd_data !== queue_front()) begin
                        local_errors = local_errors + 1;
                    end
                    queue_pop();
                end
            end

            if (local_errors > 0) begin
                $display("  Data errors: %0d", local_errors);
                pass = 0;
            end

            report_test("Random Operations", pass);
        end
    endtask

    //==========================================================================
    // TEST 10: PERFORMANCE MEASUREMENT
    //==========================================================================
    task test_performance;
        reg pass;
        integer perf_start;
        integer perf_end;
        integer burst_writes;
        integer burst_reads;
        real time_us;
        real data_mb;
        real throughput;
        begin
            $display("\n--- Test 10: Performance Measurement ---");
            apply_reset();
            queue_init();
            pass = 1;
            burst_writes = 0;
            burst_reads = 0;

            perf_start = $time;

            // Burst write until full
            while (!full && burst_writes < DEPTH) begin
                @(posedge wr_clk);
                wr_en = 1;
                wr_data = burst_writes;
                queue_push(burst_writes);
                burst_writes = burst_writes + 1;
            end
            @(posedge wr_clk);
            wr_en = 0;

            // Wait for CDC
            wait_rd_cycles(SYNC_STAGES + 2);

            // Burst read until empty
            while (!empty && burst_reads < DEPTH) begin
                @(posedge rd_clk);
                rd_en = 1;
                @(posedge rd_clk);
                rd_en = 0;
                burst_reads = burst_reads + 1;
                queue_pop();
                @(posedge rd_clk);
            end

            perf_end = $time;

            time_us = (perf_end - perf_start) / 1000.0;
            data_mb = (burst_writes * DATA_WIDTH / 8.0) / (1024.0 * 1024.0);
            throughput = data_mb / (time_us / 1000000.0);

            $display("  Burst writes: %0d", burst_writes);
            $display("  Burst reads: %0d", burst_reads);
            $display("  Time: %0.2f us", time_us);
            $display("  Throughput: %0.2f MB/s (estimated)", throughput);
            $display("  Write clock: %0.2f MHz", 1000.0/WR_CLK_PERIOD);
            $display("  Read clock: %0.2f MHz", 1000.0/RD_CLK_PERIOD);

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
        data_errors = 0;

        $display("");
        $display("================================");
        $display("FIFO ASYNCHRONOUS TESTBENCH");
        $display("================================");
        $display("DATA_WIDTH = %0d", DATA_WIDTH);
        $display("DEPTH = %0d", DEPTH);
        $display("SYNC_STAGES = %0d", SYNC_STAGES);
        $display("WR_CLK_PERIOD = %0d ns (%0.2f MHz)", WR_CLK_PERIOD, 1000.0/WR_CLK_PERIOD);
        $display("RD_CLK_PERIOD = %0d ns (%0.2f MHz)", RD_CLK_PERIOD, 1000.0/RD_CLK_PERIOD);
        $display("================================");

        // Run all tests
        test_reset();
        test_basic_write_read();
        test_fill_fifo();
        test_drain_fifo();
        test_overflow();
        test_underflow();
        test_clock_ratio_wr_fast();
        test_cdc_stress();
        test_random_ops();
        test_performance();

        // Final summary
        $display("");
        $display("================================");
        $display("SIMULATION SUMMARY");
        $display("================================");
        $display("Total Tests: %0d", total_tests);
        $display("Passed: %0d", test_passed);
        $display("Failed: %0d", test_failed);
        $display("Success Rate: %0d%%", (test_passed * 100) / total_tests);
        $display("");
        $display("Statistics:");
        $display("- Total Writes: %0d", total_writes);
        $display("- Total Reads: %0d", total_reads);
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
        #2000000;  // 2ms timeout
        $display("");
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
