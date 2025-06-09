`default_nettype none

module clock_div #(
  parameter EXP_FACTOR = 2
) (
  input  wire clock_in_i,
  input  wire reset_i,
  input  wire en_i,
  output wire clock_out_o
);

  logic [EXP_FACTOR-1:0] clk_div;

  always_ff @(posedge clock_in_i) begin
    if (reset_i)
      clk_div <= '0;
    else if (en_i)
      clk_div <= clk_div + 1;
    // NOTE: no update is the default behavior in SV.
    // this just makes it explicit: hold value when not enabled
    else 
      clk_div <= clk_div; 
  end

  assign clock_out_o = clk_div[EXP_FACTOR-1];

endmodule
