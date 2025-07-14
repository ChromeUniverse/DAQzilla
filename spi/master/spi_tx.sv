`default_nettype none

module spi_tx #(
  parameter WIDTH = 8
) (
  input  wire             clock_i,
  input  wire             reset_i,

  input  wire             tx_en_i,
  input  wire             tx_load_i,
  input  wire             SCLK_i,

  input  wire [WIDTH-1:0] tx_buffer_i,

  output wire             MOSI_o
);

  // SCLK rising edge trigger:
  // Used for SPI Mode 1. Bits are set up well before the falling edge
  // to ensure setup time constraints are met.

  logic SCLK_rising_edge;
  edge_trigger #(.DETECT_POS_EDGE(1)) posedge_trigger (
    .clk(clock_i),
    .reset(reset_i),
    .signal_in(SCLK_i),
    .pulse_out(SCLK_rising_edge)
  );

  // PIPO Shift register
  logic [WIDTH-1:0] tx_buffer_out;
  ShiftRegisterPIPO #(.WIDTH(WIDTH)) tx_buffer (
    .en   (tx_en_i & SCLK_rising_edge),
    .left (1'b1), // MSB first 
    .load (tx_load_i),
    .clock(clock_i),
    .D    (tx_buffer_i),
    .Q    (tx_buffer_out)
  );

  // MOSI buffer register:
  // MSB of shift register above is shifted into this 1-bit
  // register before being put on the MOSI line.

  logic mosi_reg;
  always_ff @(posedge clock_i) begin
    if (reset_i)
      mosi_reg <= 1'b0;
    else if (tx_en_i & SCLK_rising_edge)
      mosi_reg <= tx_buffer_out[WIDTH-1];
  end

  assign MOSI_o = tx_en_i ? mosi_reg : 1'b0;

endmodule: spi_tx
