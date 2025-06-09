`default_nettype none

module edge_trigger #(
  parameter bit DETECT_POS_EDGE = 1
) (
  input  logic clk,
  input  logic reset,
  input  logic signal_in,
  output logic pulse_out
);

  logic signal_d;

  always_ff @(posedge clk) begin
    if (reset) begin
      signal_d  <= 1'b0;
      pulse_out <= 1'b0;
    end else begin
      signal_d  <= signal_in;

      // Use ternary operator to select edge type
      pulse_out <= DETECT_POS_EDGE
                 ? ( signal_in & ~signal_d)  // rising edge
                 : (~signal_in &  signal_d); // falling edge
    end
  end

endmodule
