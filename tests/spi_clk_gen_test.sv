`default_nettype none

module spi_clk_gen_test;

  logic reset;
  logic clock;
  logic tx_en, rx_en;
  logic enable;
  wire SCLK;

  // Instantiate the DUT
  // 100MHz / (2 ** 6) = 1.5625MHz
  spi_clk_gen #(.EXP_FACTOR(6)) dut (
    .clock_i(clock),
    .tx_en_i(tx_en),
    .rx_en_i(rx_en),
    .SCLK_o(SCLK),  
    .reset_i(reset),
    .en_i(enable)
  );

  // Clock generator: 10ns period → 100 MHz
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  initial begin
    clock = 0;
    enable = 0;

    // reset
    reset = 1;
    #10;
    reset = 0;

    tx_en = 0;
    rx_en = 0;

    #20;

    // Nothing should happen here

    // Enable TX
    tx_en = 1;
    #2000;

    tx_en = 0;
    #2000;

    rx_en = 1;
    #2000;

    rx_en = 0;

    // ENABLE
    enable = 1;

    // Enable TX — should enable SCLK toggling
    tx_en = 1;

    #2000;

    // Disable TX and RX — SCLK_o should go to 0
    tx_en = 0;

    #2000;

    // Enable RX — SCLK should toggle again
    rx_en = 1;

    #2000;

    rx_en = 0;

    #50 $finish;
  end

endmodule
