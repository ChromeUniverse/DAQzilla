`default_nettype none

module spi_delay_timer #(
  parameter int MAX_COUNT = 10
) (
  input  wire clock_i,
  input  wire reset_i,
  input  wire delay_en_i,
  output wire delay_done_o
);

  localparam int WIDTH = $clog2(MAX_COUNT + 1);

  logic [WIDTH-1:0] counter;

  always_ff @(posedge clock_i) begin
    if (reset_i | ~delay_en_i)
      counter <= '0;
    else if (counter != MAX_COUNT)
      counter <= counter + 1;
  end

  assign delay_done_o = (counter == MAX_COUNT);

endmodule
