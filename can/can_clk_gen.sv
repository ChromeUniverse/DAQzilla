module can_clk_gen #(
  parameter DIVISOR = 200
)(
  input  wire clock_in_i,
  input  wire reset_i,
  input  wire en_i,
  output logic clock_out_o,
  output logic clock_pulse_out_o
);

  logic [$clog2(DIVISOR)-1:0] count;

  always_ff @(posedge clock_in_i or posedge reset_i) begin
    if (reset_i) begin
      count <= 0;
    end
    else if (en_i) begin
      if (count == DIVISOR - 1)
        count <= 0;
      else
        count <= count + 1;
    end
  end

  always_comb begin
    if (count < (DIVISOR / 2))
      clock_out_o = 1'b0;
    else
      clock_out_o = 1'b1;
  end

  assign clock_pulse_out_o = (count == 0);

endmodule
