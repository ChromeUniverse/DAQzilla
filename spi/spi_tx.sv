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

  output wire             MOSI_o,
  output wire             tx_done_o
);

  // SCLK rising edge trigger

  logic SCLK_rising_edge, SCLK_falling_edge;
  edge_trigger #(.DETECT_POS_EDGE(1)) posedge_trigger (
    .clk(clock_i),
    .reset(reset_i),
    .signal_in(SCLK_i),
    .pulse_out(SCLK_rising_edge)
  );

  edge_trigger #(.DETECT_POS_EDGE(0)) negedge_trigger (
    .clk(clock_i),
    .reset(reset_i),
    .signal_in(SCLK_i),
    .pulse_out(SCLK_falling_edge)
  );

  // Shift register
  logic [WIDTH-1:0] tx_buffer_out;
  ShiftRegisterPIPO #(.WIDTH(WIDTH)) tx_buffer (
    .en   (tx_en_i & SCLK_rising_edge),
    .left (1'b1), // MSB first 
    .load (tx_load_i),
    .clock(clock_i),
    .D    (tx_buffer_i),
    .Q    (tx_buffer_out)
  );

  // MOSI buffer register
  logic mosi_reg;
  always_ff @(posedge clock_i) begin
    if (reset_i)
      mosi_reg <= 1'b0;
    else if (tx_en_i & SCLK_rising_edge)
      mosi_reg <= tx_buffer_out[WIDTH-1];
  end

  assign MOSI_o = tx_en_i ? mosi_reg : 1'b0;

  // Bit counter
  logic [$clog2(WIDTH):0] tx_counter_value;
  Counter #(.WIDTH($clog2(WIDTH)+1)) tx_counter (
    .en   (tx_en_i & SCLK_falling_edge),
    .clear(~tx_en_i),  // TODO: optionally override
    .load (),
    .up   (1'b1),
    .clock(clock_i),
    .D    ('0),
    .Q    (tx_counter_value)
  );

  assign tx_done_o = (tx_counter_value == WIDTH);

endmodule: spi_tx
