`default_nettype none

module spi_delay_timer_test;

  // Test parameters
  localparam MAX_COUNT = 50;

  logic clock, reset, delay_en;
  logic delay_done;

  // DUT
  spi_delay_timer #(.MAX_COUNT(MAX_COUNT)) dut (
    .clock_i(clock),
    .reset_i(reset),
    .delay_en_i(delay_en),
    .delay_done_o(delay_done)
  );

  // 100 MHz clock (10 ns period)
  always #5 clock = ~clock;

  initial begin
    $display("Starting delay_timer test...");
    clock = 0;
    reset = 1;
    delay_en = 0;

    #12;
    reset = 0;

    // Enable delay counting
    delay_en = 1;

    // Wait for MAX_COUNT + a few cycles
    repeat (MAX_COUNT + 2) @(posedge clock);
    if (delay_done !== 1'b1) begin
      $fatal(1, "ERROR: delay_done did not assert after expected cycles!");
    end else begin
      $display("PASS: delay_done asserted after %0d cycles", MAX_COUNT);
    end

    // Turn off enable → should reset timer
    delay_en = 0;
    @(posedge clock);
    delay_en = 1;

    repeat (MAX_COUNT) @(posedge clock);
    if (delay_done !== 1'b1) begin
      $fatal(1, "ERROR: delay_done did not re-assert after enable reset!");
    end else begin
      $display("PASS: delay_done correctly reset and re-asserted.");
    end

    $display("Test complete.");
    $finish;
  end

endmodule
