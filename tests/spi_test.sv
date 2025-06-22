`default_nettype none

module spi_tb;

  logic clock;
  logic reset;
  logic start;
  spi_mode_t mode;
  logic [7:0] tx_buffer;
  logic MISO;
  wire MOSI, CS, SCLK;
  wire [23:0] rx_buffer;
  wire done;
  logic DRDY, DRDY_en;

  // Internal signals for observing FSM state indirectly
  wire tx_en_i, rx_en_i;
  assign tx_en_i = dut.tx_en;
  assign rx_en_i = dut.rx_en;

  // Instantiate DUT
  spi dut (
    .reset_i(reset),
    .clock_i(clock),
    .start_i(start),
    .tx_buffer_i(tx_buffer),
    .MISO_i(MISO),
    .MOSI_o(MOSI),
    .CS_L_o(CS),
    .SCLK_o(SCLK),
    .rx_buffer_o(rx_buffer),
    .done_o(done),
    .spi_mode_i(mode),
    .DRDY_L_i(DRDY)
  );

  // Clock generation: 100 MHz (10 ns period)
  always #5 clock = ~clock;

  // MISO stimulus: 3 bytes = 0xAA, 0xBB, 0xCC (MSB first)
  logic [23:0] miso_data = 24'hAABBCC;
  int miso_bit_index = 23;

  always @(negedge SCLK) begin
    if (rx_en_i && miso_bit_index >= 0 && !CS)
      MISO <= miso_data[miso_bit_index--];
  end

  // assume DRATE = 30kSPS
  // 33.333us period
  initial begin
    DRDY = 0;
    forever begin
      wait (DRDY_en == 1);

      // DRDY goes high
      DRDY = 1;
      #2_000;
      // DRDY goes low
      DRDY = 0;
      #31_333;
    end
  end

  initial begin

    // 
    // Test Case #1:
    // SPI TX + RX: RDATA, etc.
    // 

    DRDY_en = 1;

    #4000

    clock = 0;
    reset = 1;
    start = 0;
    mode = SPI_TX_RX;
    tx_buffer = 8'h87;
    MISO = 0;

    #20;
    reset = 0;
    #20;

    // Start the SPI transaction
    start = 1;
    #10;
    start = 0;

    // Wait for the entire transaction to complete
    wait(done);

    // 
    // Test Case #2:
    // SPI TX only (SELFCAL)
    // 

    // TODO

    // 
    // Test Case #3:
    // SPI RX only (RDATAC)
    // 

    // TODO

    // 
    // Test Case #4:
    // SPI IDLE (NOP)
    // 

    // TODO

    #20000;
    $display("Received data: %h", rx_buffer);
    $finish;
  end

endmodule : spi_tb
