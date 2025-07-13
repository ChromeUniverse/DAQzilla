`default_nettype none

module spi_transaction_layer_tb;

  // Clock and reset
  logic clock;
  logic reset;

  // DUT inputs
  logic start;
  logic spi_done;
  logic DRDY_L;
  logic [3:0] reg_addr; // Unused for RDATA
  transaction_t transaction;

  // DUT outputs
  logic done;
  logic spi_start;
  logic CS_L;
  logic [7:0] tx_buf;

  // Instantiate DUT
  spi_transaction_layer dut (
    .clock_i(clock),
    .reset_i(reset),
    .start_i(start),
    .done_o(done),
    .transaction_i(transaction),
    .reg_addr_i(reg_addr),
    .spi_start_o(spi_start),
    .spi_done_i(spi_done),
    .CS_L_o(CS_L),
    .tx_buffer_o(tx_buf),
    .DRDL_L_i(DRDY_L)
  );

  // Clock generator: 10ns period = 100 MHz
  initial clock = 0;
  always #5 clock = ~clock;

  // Drive signals
  initial begin
    // Init
    reset = 1;
    start = 0;
    spi_done = 0;
    DRDY_L = 1; // DRDY_L active low, so 1 means not ready
    transaction = RDATA;

    reg_addr = 4'd0; // Unused for RDATA

    // Hold reset
    #20;
    reset = 0;

    // Wait a few cycles
    #20;

    // Start transaction
    start = 1;
    #10;
    start = 0;

    // FSM enters RDATA_WAIT_DRDY, so DRDY_L must go low to continue
    #100;
    $display("=== FSM should be waiting for DRDY ===");

    DRDY_L = 0; // DRDY_L goes active low => data ready

    // FSM should issue SPI transfer 0
    // Wait for spi_start_o
    wait (spi_start === 1);
    $display("=== SPI transfer started ===");

    // Simulate SPI done handshake for transfer 0
    repeat (20) @(posedge clock);
    spi_done = 1;
    repeat (1) @(posedge clock);
    spi_done = 0;

    $display("=== SPI transfer 0 done ===");

    // FSM should now wait for t6 delay
    // The Counter logic should increment until delay_t6_done triggers
    // So we wait enough cycles for the counter to reach the compare value

    // This simple test just waits long enough
    repeat (800) @(posedge clock);

    $display("=== t6 delay done, FSM should issue transfer 1 ===");

    // FSM should issue SPI transfer 1
    wait (spi_start === 1);
    $display("=== SPI transfer 1 started ===");

    // Simulate SPI done handshake for transfer 1
    repeat (20) @(posedge clock);
    spi_done = 1;
    repeat (1) @(posedge clock);
    spi_done = 0;

    $display("=== SPI transfer 1 done ===");


    // FSM should issue SPI transfer 2
    wait (spi_start === 1);
    $display("=== SPI transfer 2 started ===");

    // Simulate SPI done handshake for transfer 2
    repeat (20) @(posedge clock);
    spi_done = 1;
    repeat (1) @(posedge clock);
    spi_done = 0;

    $display("=== SPI transfer 2 done ===");

    // FSM should issue SPI transfer 3
    wait (spi_start === 1);
    $display("=== SPI transfer 3 started ===");

    // Simulate SPI done handshake for transfer 3
    repeat (20) @(posedge clock);
    spi_done = 1;
    repeat (1) @(posedge clock);
    spi_done = 0;

    $display("=== SPI transfer 3 done ===");

    // Wait for DONE signal to assert (or next transfer if you implement more states)
    wait (done === 1);
    repeat (20) @(posedge clock);
    $display("=== FSM done signal asserted ===");

    $display("=== Test finished ===");
    $finish;
  end

endmodule
