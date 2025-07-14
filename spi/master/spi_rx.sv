`default_nettype none

module spi_rx #(
  parameter WIDTH = 8
) (
  input  wire             clock_i,
  input  wire             reset_i,
  input  wire             rx_en_i,
  input  wire             SCLK_i,
  input  wire             MISO_i,
  output wire [WIDTH-1:0] rx_data_o
);

  // SCLK falling edge detector:
  // Used for SPI mode 1. Bits are sampled on the falling edge of SCLK.

  logic SCLK_falling_edge;
  edge_trigger #(.DETECT_POS_EDGE(0)) posedge_trigger (
    .clk(clock_i),
    .reset(reset_i),
    .signal_in(SCLK_i),
    .pulse_out(SCLK_falling_edge)
  );

  // Shift register (SIPO)
  ShiftRegisterSIPO #(.WIDTH(WIDTH)) rx_shift_reg (
    .en    (rx_en_i & SCLK_falling_edge),
    .left  (1'b1), // MSB first
    .clock (clock_i),
    .serial(MISO_i),
    .Q     (rx_data_o)
  );

endmodule : spi_rx
