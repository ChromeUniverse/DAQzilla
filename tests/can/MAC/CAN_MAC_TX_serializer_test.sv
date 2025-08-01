module tb_can_bit_stuffer;
  logic clk, reset;

  // Inputs
  logic bit_in, valid, stuffing_enable;
  logic ready;

  // Outputs
  logic bit_out, bit_valid;

  // DUT
  CAN_MAC_TX_serializer dut (
      .clk(clk),
      .reset(reset),
      .bit_in(bit_in),
      .valid(valid),
      .ready(ready),
      .stuffing_enable(stuffing_enable),
      .bit_out(bit_out),
      .bit_valid(bit_valid)
  );

  // Clock generation
  always #5 clk = ~clk;

  // Test vector task
  task run_test(string name, bit stuffing_en, input logic din[],  // destuffed bits (unpacked)
                int len, input logic expected[],  // expected stuffed output
                int expected_len);
    int i, j;
    bit [127:0] result;
    logic mismatch = 0;

    $display("\nRunning test: %s", name);

    // Reset
    reset = 1;
    clk = 0;
    valid = 0;
    bit_in = 0;
    stuffing_enable = stuffing_en;
    repeat (2) @(posedge clk);
    reset = 0;

    // Feed input
    i = 0;
    j = 0;
    while (i < len || j < expected_len) begin
      @(posedge clk);

      // Drive input only when DUT is ready
      if (i < len && ready) begin
        bit_in = din[i];  // MSB-first
        valid  = 1;
        i++;
      end
      // else begin
      //   valid = 0;
      // end

      // Capture output
      if (bit_valid) begin
        result[j] = bit_out;
        j++;
      end
    end

    // Compare
    for (int k = 0; k < expected_len; k++) begin
      if (result[k] !== expected[k]) begin
        mismatch = 1;
        $display("Mismatch at bit %0d: Got %b, Expected %b", k, result[k], expected[k]);
      end
    end

    if (!mismatch) $display("PASS: Output matched expected.");
    else begin
      $display("FAIL: Output mismatch.");
      $write("Expected: ");
      for (int k = 0; k < expected_len; k++) $write("%b", expected[k]);
      $write("\nGot     : ");
      for (int k = 0; k < expected_len; k++) $write("%b", result[k]);
      $display();
    end

  endtask


  bit tc1_din     [0:10] = '{0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0};  // 11 bits
  bit tc1_expected[0:11] = '{0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0};  // 12 bits

  bit tc2_din     [0:10] = '{1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1};
  bit tc2_expected[0:11] = '{1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1};

  bit tc3_din     [0:13] = '{0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0};
  bit tc3_expected[0:15] = '{0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0};

  bit tc4_din     [0:13] = '{1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1};
  bit tc4_expected[0:15] = '{1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1};


  // Launch testcases
  initial begin
    run_test("TC1", 1, tc1_din, 11, tc1_expected, 12);
    run_test("TC2", 1, tc2_din, 11, tc2_expected, 12);
    run_test("TC3", 1, tc3_din, 14, tc3_expected, 16);
    run_test("TC4", 1, tc4_din, 14, tc4_expected, 16);
    $finish;
  end

endmodule
