`default_nettype none

module clock_div_test;

  logic clock_in;
  logic reset;
  logic enable;
  wire clock_out;

  // Instantiate DUT
  clock_div #(.EXP_FACTOR(4)) dut (
    .clock_in_i(clock_in),
    .clock_out_o(clock_out),
    .reset_i(reset),
    .en_i(enable)
  );

  // Generate 100 MHz clock → 10 ns period
  always #5 clock_in = ~clock_in;

  initial begin
    clock_in = 0;
    reset = 1;
    enable = 0;
    
    // reset
    #10 reset = 0;

    // enable LOW -- shouldn't do anything

    #1000;

    // enable HIGH -- should start counting
    enable = 1;

    #1000 $finish;
  end

endmodule
