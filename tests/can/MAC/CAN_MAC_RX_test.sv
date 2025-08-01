// `timescale 1ns / 1ps

module tb_can_mac_rx;
  logic clk, reset;
  logic can_clk_en;
  logic bit_in;

  // MA_data_indication_if
  MA_data_indication_if ind_if (.clock(clk));

  // DUT
  CAN_MAC_RX dut (
      .clk(clk),
      .reset(reset),
      .can_clk_en(can_clk_en),
      .bit_in(bit_in),
      .ma_ind(ind_if.MAC)
  );

  // Clocking
  always #5 clk = ~clk;  // 100 MHz

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

  // Constructed and stuffed CAN bit stream (SOF to EOF)
  bit frame_bits[] = '{
      // SOF
      0,
      // ID 0x123 = 001_0010_0011
      0,
      0,
      1,  //
      0,
      0,
      1,
      0,  //
      0,
      0,
      1,
      1,  //
      // RTR=0
      0,
      // IDE=0, r0=0, DLC=4'd4 = 0100
      0,
      0,
      0,
      1,
      0,
      0,
      // Data = 0xDEADBEEF
      1,
      1,
      0,
      1,  // D
      1,
      1,
      1,
      0,  // E
      1,
      0,
      1,
      0,  // A
      1,
      1,
      0,
      1,  // D
      1,
      0,
      1,
      1,  // B
      1,
      1,
      1,  // five 1's
      0,  // stuffed 0
      0,  // E
      1,
      1,
      1,
      0,  // E
      1,
      1,
      1,
      1,  // F
      // CRC = 0x4E6B = 100_1110_0110_1011 (15 bits, with stuffing)
      1,  // five 1's 
      0,  // stuffed 0's
      0,
      0,  //
      1,
      1,
      1,
      0,  //
      0,
      1,
      1,
      0,  //
      1,
      0,
      1,
      1,  //
      // CRC-D
      1,
      // ACK Slot
      1,
      // ACK-D
      1,
      // EOF
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      // IFS
      1,
      1,
      1,
      1,
      1,
      1,
      1
  };

  initial begin
    $display("\n=== CAN MAC RX Test: ID 0x123, DATA 0xDEADBEEF ===");
    clk = 0;
    reset = 1;
    bit_in = 1;  // starting from bus idle = recessive state (1)
    ind_if.ready = 1;

    repeat (5) @(posedge clk);
    reset = 0;

    repeat (5) @(posedge clk);

    for (int i = 0; i < frame_bits.size(); i++) begin
      @(posedge can_clk_en);
      bit_in = frame_bits[i];
    end

    // Wait for MA_data.indication.valid
    wait (ind_if.valid);
    $display("\nFrame received:");
    $display("  ID        = 0x%0h", ind_if.identifier);
    $display("  DLC       = %0d", ind_if.dlc);
    $display("  Data      = 0x%0h", ind_if.data_payload);

    #100;
    $finish;
  end
endmodule
