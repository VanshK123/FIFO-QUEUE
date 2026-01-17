//==============================================================================
// File: test_params.vh
// Description: Test configuration parameters for FIFO testbenches
//
// This file centralizes test configuration to make it easy to modify
// test parameters without changing the testbench code.
//==============================================================================

`ifndef TEST_PARAMS_VH
`define TEST_PARAMS_VH

//==============================================================================
// FIFO PARAMETERS
//==============================================================================
// These should match the DUT parameters

`define TEST_DATA_WIDTH         32
`define TEST_FIFO_DEPTH         16
`define TEST_ADDR_WIDTH         $clog2(`TEST_FIFO_DEPTH)
`define TEST_SYNC_STAGES        2

//==============================================================================
// TIMING PARAMETERS
//==============================================================================

// Synchronous FIFO clock period (ns)
`define TEST_SYNC_CLK_PERIOD    10      // 100 MHz

// Asynchronous FIFO clock periods (ns)
`define TEST_WR_CLK_PERIOD      10      // 100 MHz write clock
`define TEST_RD_CLK_PERIOD      15      // 66.67 MHz read clock

// Alternative clock configurations for testing
`define TEST_FAST_CLK_PERIOD    8       // 125 MHz
`define TEST_SLOW_CLK_PERIOD    20      // 50 MHz

//==============================================================================
// TEST CONFIGURATION
//==============================================================================

// Number of random operations in stress tests
`define TEST_RANDOM_OPS         100

// Number of burst operations
`define TEST_BURST_COUNT        1000

// Timeout value (ns) - simulation will abort if exceeded
`define TEST_TIMEOUT            2000000  // 2 ms

// Random seed for reproducibility
`define TEST_RANDOM_SEED        12345

//==============================================================================
// THRESHOLD PARAMETERS
//==============================================================================

`define TEST_ALMOST_FULL_THRESH  (`TEST_FIFO_DEPTH - 2)
`define TEST_ALMOST_EMPTY_THRESH 2

//==============================================================================
// DEBUG FLAGS
//==============================================================================

// Uncomment to enable verbose debug output
// `define TEST_DEBUG_VERBOSE

// Uncomment to enable waveform dumping (usually enabled by default)
`define TEST_DUMP_WAVES

// Uncomment to enable performance measurement
`define TEST_MEASURE_PERF

`endif // TEST_PARAMS_VH
