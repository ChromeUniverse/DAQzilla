`default_nettype none

module edge_trigger_test;
  logic clk, reset, signal_in, pulse_out;

  // Instantiate DUT
  edge_trigger dut (
    .clk(clk),
    .reset(reset),
    .signal_in(signal_in),
    .pulse_out(pulse_out)
  );

  // Clock generation: 10ns period
  always #5 clk = ~clk;

  initial begin
    // $dumpfile("wave.vcd"); $dumpvars(0, tb_pulse_on_rising_edge);
    clk = 0;
    reset = 1;
    signal_in = 0;
    #10;
    reset = 0;

    // Test rising edge at t=20
    #10 signal_in = 1;
    #50 signal_in = 1; // Hold high
    #30 signal_in = 0;
    #10 signal_in = 1; // Another rising edge
    #10 signal_in = 0;
    #10 $finish;
  end
endmodule
