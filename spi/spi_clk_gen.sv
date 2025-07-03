`default_nettype none

module spi_clk_gen #(
  parameter EXP_FACTOR = 6
) (
  input  wire clock_i,
  input  wire reset_i,
  input  wire en_i,
  output wire SCLK_o
);

  logic clk_divided;

  clock_div #(.EXP_FACTOR(EXP_FACTOR)) clkgen (
    .clock_in_i(clock_i),
    .clock_out_o(clk_divided),
    .reset_i(reset_i),
    .clear_i(~en_i),
    .en_i(en_i)
  );

  assign SCLK_o = (en_i) ? clk_divided : 1'b0;

endmodule
