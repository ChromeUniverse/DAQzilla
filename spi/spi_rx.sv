`default_nettype none

module spi_rx #(
  parameter WIDTH = 24
) (
  input  wire             clock_i,
  input  wire             reset_i,
  input  wire             rx_en_i,
  input  wire             SCLK_i,
  input  wire             MISO_i,
  output wire [WIDTH-1:0] rx_data_o,
  output wire             rx_done_o
);

  // SCLK falling edge detector
  logic SCLK_d, SCLK_falling_edge;
  always_ff @(posedge clock_i) begin
    SCLK_d <= SCLK_i;
  end
  assign SCLK_falling_edge = (SCLK_d == 1'b1 && SCLK_i == 1'b0);

  // Shift register (SIPO)
  ShiftRegisterSIPO #(.WIDTH(WIDTH)) rx_shift_reg (
    .en    (rx_en_i & SCLK_falling_edge),
    .left  (1'b1), // MSB first
    .clock (clock_i),
    .serial(MISO_i),
    .Q     (rx_data_o)
  );

  // Counter
  localparam COUNT_WIDTH = $clog2(WIDTH) + 1;
  logic [COUNT_WIDTH-1:0] bit_count;

  Counter #(.WIDTH(COUNT_WIDTH)) rx_counter (
    .en    (rx_en_i & SCLK_falling_edge),
    .clear (~rx_en_i),
    .load  (),
    .up    (1'b1),
    .clock (clock_i),
    .D     ('0),
    .Q     (bit_count)
  );

  assign rx_done_o = (bit_count == WIDTH);

endmodule : spi_rx
