`default_nettype none

module ChipInterface(
  input wire [15:0] SW,
  input wire [3:0] BTN,
  input wire CLOCK_100,
  output wire [15:0] LD,
  output wire [3:0] D1_AN, D2_AN,  // Hex displays
  output wire [7:0] D1_SEG, D2_SEG,  // Also, hex displays

  // ADS1256 SPI interface
  input wire ADS1256_DOUT,  // MISO
  input wire ADS1256_DRDY,  
  output wire ADS1256_SCLK,
  output wire ADS1256_DIN,  // MOSI
  output wire ADS1256_CS
); 

  // board I/O
  wire reset, clock, start, done;
  assign reset = BTN[0];
  assign clock = CLOCK_100;
  assign start = BTN[1];
  assign done = LD[0];

  // SPI interface (PMOD)
  wire MOSI, MISO, SCLK, CS_L;
  assign MOSI = ADS1256_DIN;
  assign MISO = ADS1256_DOUT;
  assign CS_L = ADS1256_CS;
  assign SCLK = ADS1256_SCLK;

  // hardcoding TX buffer with RDATA (01h)
  logic [7:0] tx_buffer;
  assign tx_buffer = 8'h01;
  
  spi_mode_t mode;
  assign mode = SPI_TX_RX;

  spi spi_core (
    .reset_i(reset),
    .clock_i(clock),
    .start_i(start),
    .tx_buffer_i(tx_buffer),
    .MISO_i(MISO),
    .MOSI_o(MOSI),
    .CS_L_o(CS_L),
    .SCLK_o(SCLK),
    .rx_buffer_o(),
    .done_o(done),
    .spi_mode_i(mode)
  );

endmodule: ChipInterface