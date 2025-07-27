`default_nettype none

module spi_clk_gen_test;

  logic reset;
  logic clock;
  logic enable;
  wire SCLK;

  // Instantiate the DUT
  // 100 MHz / 2^6 = 1.5625 MHz SCLK
  spi_clk_gen #(.EXP_FACTOR(6)) dut (
    .clock_i(clock),
    .reset_i(reset),
    .en_i(enable),
    .SCLK_o(SCLK)
  );

  // Clock generator: 10ns period → 100 MHz
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  initial begin
    // Initialize signals
    reset  = 1;
    enable = 0;

    // Apply reset
    #20;
    reset = 0;
    #20;

    // Wait with enable low — SCLK should be 0
    #2000;

    // Enable clock generation — SCLK should toggle
    enable = 1;

    #5000;

    // Disable clock generation — SCLK should stop (forced to 0)
    enable = 0;

    #2000;

    // Re-enable
    enable = 1;

    #5000;

    // Done
    $finish;
  end

endmodule
