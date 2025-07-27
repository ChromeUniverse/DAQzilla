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
  logic [23:0] command;

  // DUT outputs
  logic done;
  logic spi_start;
  logic CS_L;
  logic [7:0] tx_buf;
  logic [1:0] read_reg_sel;
  logic read_reg_load;

  // Commands
  localparam CMD_NONE_BINARY = 24'h00_00_00;
  localparam CMD_WAKEUP   = 24'hFF_FF_FF;
  localparam CMD_RDATA    = 24'h01_FF_FF;
  localparam CMD_RDATAC   = 24'h03_FF_FF;
  localparam CMD_SDATAC   = 24'h0F_FF_FF;
  localparam CMD_SELFCAL  = 24'hF0_FF_FF;
  localparam CMD_RREG     = 24'h17_00_69;
  localparam CMD_WREG     = 24'h57_00_69;

  // Instantiate DUT
  spi_transaction_layer dut (
    .clock_i(clock),
    .reset_i(reset),
    .start_i(start),
    .done_o(done),
    .cmd_i(command),
    .read_reg_sel(read_reg_sel),
    .read_reg_load(read_reg_load),
    .spi_start_o(spi_start),
    .spi_done_i(spi_done),
    .CS_L_o(CS_L),
    .tx_buffer_o(tx_buf),
    .DRDY_L_i(DRDY_L)
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

    command = CMD_WREG;

    reg_addr = 4'd0; // Unused for RDATA

    // Hold reset
    #20;
    reset = 0;

    // Wait a few cycles
    #20;

    // -----------------------------------------------------
    // RDATA: single conversion
    // -----------------------------------------------------

    if (command == CMD_RDATA) begin
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
      repeat (400) @(posedge clock);

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
    end

    // -----------------------------------------------------
    // RDATAC/SDATAC: continuous conversions
    // -----------------------------------------------------

    else if (command == CMD_RDATAC) begin
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
      repeat (400) @(posedge clock);

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

      // ---------------------------
      // First conversion done! De-assert DRDY
      // Let's go through another conversion before we stop.

      DRDY_L = 1;
      repeat (200) @(posedge clock);
      DRDY_L = 0;
      // ---------------------------

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

      // ---------------------------
      // Second conversion done! De-assert DRDY
      // Now let's go issue a stop command during this pause 
      // and make sure we can go back into an idle state

      DRDY_L = 1;
      repeat (200) @(posedge clock);
      command = CMD_SDATAC;
      DRDY_L = 0;
      // ---------------------------

      // FSM should issue SPI transfer 4
      wait (spi_start === 1);
      $display("=== SPI transfer 4 started ===");

      // Simulate SPI done handshake for transfer 4
      repeat (20) @(posedge clock);
      spi_done = 1;
      repeat (1) @(posedge clock);
      spi_done = 0;

      $display("=== SPI transfer 4 done ===");

      // Wait for DONE signal to assert (or next transfer if you implement more states)
      wait (done === 1);
      repeat (20) @(posedge clock);
      $display("=== FSM done signal asserted ===");
    end

    // -----------------------------------------------------
    // SELFCAL: self-calibration
    // -----------------------------------------------------

    else if (command == CMD_SELFCAL) begin
      // Start transaction
      start = 1;

      // FSM should SELFCAL_SPI_TRANSFER immediately (Mealy)
      wait (spi_start === 1);
      $display("=== SPI transfer started ===");

      #10;
      start = 0;

      // Simulate SPI done handshake for transfer
      repeat (20) @(posedge clock);
      spi_done = 1;
      repeat (1) @(posedge clock);
      spi_done = 0;
      $display("=== SPI transfer 0 done ===");

      repeat (20) @(posedge clock);

    end

    // -----------------------------------------------------
    // RREG: single-register read from SPI peripheral
    // -----------------------------------------------------

    else if (command == CMD_RREG) begin
      // Start transaction
      start = 1;

      // FSM should RREG_SPI_TRANSFER_0 immediately (Mealy)
      wait (spi_start === 1);
      $display("=== SPI transfer 0 started ===");

      #10;
      start = 0;

      // Simulate SPI done handshake for transfer
      repeat (20) @(posedge clock);
      spi_done = 1;
      wait (spi_start === 1); 
      $display("=== SPI transfer 0 concluded / SPI transfer 1 started ===");
      repeat (1) @(posedge clock);
      spi_done = 0;

      // Simulate SPI done handshake for transfer
      repeat (20) @(posedge clock);
      spi_done = 1;
      repeat (1) @(posedge clock);
      spi_done = 0;
      $display("=== SPI transfer 1 concluded ===");

      // Going into t6 delay counting
      repeat (20) @(posedge clock);
      wait (spi_start === 1);
      $display("=== t6 delay done / SPI transfer 2 started ===");

      // Simulate SPI done handshake for transfer
      repeat (20) @(posedge clock);
      spi_done = 1;
      repeat (1) @(posedge clock);
      spi_done = 0;


      wait (done === 1);
      $display("=== Transaction concluded. ===");
      repeat (20) @(posedge clock);
    end

    // -----------------------------------------------------
    // WREG: single-register write to SPI peripheral
    // -----------------------------------------------------

    else if (command == CMD_WREG) begin
      // Start transaction
      start = 1;

      // FSM should WREG_SPI_TRANSFER_1 immediately (Mealy)
      wait (spi_start === 1);
      $display("=== SPI transfer 0 started ===");

      #10;
      start = 0;

      // Simulate SPI done handshake for transfer
      repeat (20) @(posedge clock);
      spi_done = 1;
      wait (spi_start === 1); 
      $display("=== SPI transfer 0 concluded / SPI transfer 1 started ===");
      repeat (1) @(posedge clock);
      spi_done = 0;

      // Simulate SPI done handshake for transfer
      repeat (20) @(posedge clock);
      spi_done = 1;
      wait (spi_start === 1); 
      $display("=== SPI transfer 1 concluded / SPI transfer 2 started ===");
      repeat (1) @(posedge clock);
      spi_done = 0;

      // Simulate SPI done handshake for transfer
      repeat (20) @(posedge clock);
      spi_done = 1;
      $display("=== SPI transfer 2 concluded ===");
      repeat (1) @(posedge clock);
      spi_done = 0;

      wait (done === 1);
      $display("=== Transaction concluded. ===");
      repeat (20) @(posedge clock);
    end

    $display("=== Test finished ===");
    $finish;
  end

endmodule
