// Testbench for CAN_MAC_RX_deserializer using destuffed → stuffed test vectors

module tb_can_rx_deserializer;
  logic clk, reset;
  logic can_clk_en;

  // Inputs
  logic bit_in, destuffing_enable;
  logic ready;

  // Outputs
  logic bit_out, valid, stuff_error;

  // DUT
  CAN_MAC_RX_deserializer dut (
      .clk(clk),
      .can_clk_en(can_clk_en),
      .reset(reset),
      .bit_in(bit_in),
      .destuffing_enable(destuffing_enable),
      .bit_out(bit_out),
      .valid(valid),
      .ready(ready),
      .stuff_error(stuff_error)
  );

  // Clock generation
  always #5 clk = ~clk;

  // Generate can_clk_en pulse every 10 cycles
  logic [3:0] tq_cnt;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      tq_cnt <= 0;
      can_clk_en <= 0;
    end else begin
      if (tq_cnt == 9) begin
        tq_cnt <= 0;
        can_clk_en <= 1;
      end else begin
        tq_cnt <= tq_cnt + 1;
        can_clk_en <= 0;
      end
    end
  end

  // Test vector task
  task run_test(string name, bit destuffing_en, input logic din[], int len, input logic expected[],
                int expected_len, bit expect_error);
    int i, j;
    bit [127:0] result;
    logic mismatch = 0;
    logic error_seen = 0;

    $display("\nRunning test: %s", name);

    // Reset
    reset = 1;
    clk = 0;
    bit_in = 0;
    destuffing_enable = destuffing_en;
    repeat (2) @(posedge clk);
    reset = 0;
    error_seen = 0;

    i = 0;
    j = 0;
    while (i < len || j < expected_len) begin
      @(posedge can_clk_en);
      if (i < len) begin
        bit_in = din[i];
        i++;
      end

      // We assume receiver is always ready in this MVP
      ready = 1;

      if (valid) begin
        result[j] = bit_out;
        j++;
      end
      if (stuff_error) begin
        error_seen = 1;
        $display("Stuff error detected at input index %0d", i - 1);
      end
    end

    if (!error_seen && stuff_error) begin
      error_seen = 1;
      $display("Stuff error detected at input index %0d", i - 1);
    end

    // Compare
    if (expect_error && error_seen) begin
      $display("PASS: Stuff error correctly detected!");
    end else if (expect_error && !error_seen) begin
      $display("FAIL: Expected stuff error, but none detected.");
    end else if (!expect_error && error_seen) begin
      $display("FAIL: Unexpected stuff error detected.");
    end else if (!expect_error) begin
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
    end
  endtask

  // Reversed test vectors (stuffed → destuffed)
  bit tc1_in[0:11] = '{0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0};
  bit tc1_out[0:10] = '{0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0};

  bit tc2_in[0:11] = '{1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1};
  bit tc2_out[0:10] = '{1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1};

  bit tc3_in[0:15] = '{0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0};
  bit tc3_out[0:13] = '{0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0};

  bit tc4_in[0:15] = '{1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1};
  bit tc4_out[0:13] = '{1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1};

  // Stuff error test cases
  bit err1[0:6] = '{1, 1, 1, 1, 1, 1, 0};  // 6 ones in a row
  bit err2[0:6] = '{0, 0, 0, 0, 0, 0, 1};  // 6 zeros in a row
  bit err3[0:7] = '{1, 1, 1, 1, 1, 1, 1, 1};  // 8 ones in a row
  bit err4[0:7] = '{0, 0, 0, 0, 0, 0, 0, 0};  // 8 zeros in a row

  // Destuffing disabled test cases

  bit no_err1_in[0:6] = '{1, 1, 1, 1, 1, 1, 0};  // 6 ones in a row
  bit no_err1_out[0:6] = '{1, 1, 1, 1, 1, 1, 0};
  bit no_err2_in[0:6] = '{0, 0, 0, 0, 0, 0, 1};  // 6 zeros in a row
  bit no_err2_out[0:6] = '{0, 0, 0, 0, 0, 0, 1};
  bit no_err3_in[0:7] = '{1, 1, 1, 1, 1, 1, 1, 1};  // 8 ones in a row
  bit no_err3_out[0:7] = '{1, 1, 1, 1, 1, 1, 1, 1};
  bit no_err4_in[0:7] = '{0, 0, 0, 0, 0, 0, 0, 0};  // 8 zeros in a row
  bit no_err4_out[0:7] = '{0, 0, 0, 0, 0, 0, 0, 0};

  // Launch testcases
  initial begin
    run_test("TC1", 1, tc1_in, 12, tc1_out, 11, 0);
    run_test("TC2", 1, tc2_in, 12, tc2_out, 11, 0);
    run_test("TC3", 1, tc3_in, 16, tc3_out, 14, 0);
    run_test("TC4", 1, tc4_in, 16, tc4_out, 14, 0);

    run_test("Stuff Error 1", 1, err1, 7, '{}, 0, 1);
    run_test("Stuff Error 2", 1, err2, 7, '{}, 0, 1);
    run_test("Stuff Error 3", 1, err3, 8, '{}, 0, 1);
    run_test("Stuff Error 4", 1, err4, 8, '{}, 0, 1);

    run_test("No Stuff Error 1", 0, no_err1_in, 7, no_err1_out, 7, 0);
    run_test("No Stuff Error 2", 0, no_err2_in, 7, no_err2_out, 7, 0);
    run_test("No Stuff Error 3", 0, no_err3_in, 8, no_err3_out, 8, 0);
    run_test("No Stuff Error 4", 0, no_err4_in, 8, no_err4_out, 8, 0);

    $finish;
  end

endmodule
