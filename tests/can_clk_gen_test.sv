`default_nettype none

module tb_can_clk_gen;

  logic clock_in;
  logic reset;
  logic en;
  logic clock_out;
  logic clock_pulse_out;

  // Instantiate your updated clock divider
  can_clk_gen #(.DIVISOR(200)) uut (
    .clock_in_i(clock_in),
    .reset_i(reset),
    .en_i(en),
    .clock_out_o(clock_out),
    .clock_pulse_out_o(clock_pulse_out)
  );

  // Generate 100 MHz input clock => 10 ns period
  initial clock_in = 0;
  always #5 clock_in = ~clock_in;

  // Stimulus
  initial begin
    $display("Time(ns) | clock_out");
    $monitor("%0t | %b", $time, clock_out);

    // Init
    reset = 1;
    en = 0;
    #20;

    reset = 0;
    en = 1;

    // Run for enough time to see several output clock cycles:
    // 1 output period = 200 * 10 ns = 2000 ns.
    // So run for ~10,000 ns to see multiple edges.
    #10000;

    $finish;
  end

endmodule
