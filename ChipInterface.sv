`default_nettype none

module ChipInterface(
  input wire [15:0] SW,
  input wire CLOCK_100,
  output wire [15:0] LD,
  output wire [3:0] D1_AN, D2_AN,  // Hex displays
  output wire [7:0] D1_SEG, D2_SEG,  // Also, hex displays
  output wire CLK_OUT_TEST
); 

  // wire a, b, f;

  // assign a = SW[0];
  // assign b = SW[1];

  // glorified_and_gate dut(.*);
  
  // assign f = LD[0];

  clock_div #(.EXP_FACTOR(7)) c0 (
    .clock_in_i(CLOCK_100),
    .clock_out_o(CLK_OUT_TEST)
  );

endmodule: ChipInterface