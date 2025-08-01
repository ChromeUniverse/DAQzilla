// CAN MAC TX testbench (MVP)

module tb_can_mac_tx;
  logic clk, rst, can_clk_en;
  logic can_tx;

  // === Interface Instances ===
  MA_data_request_if req_if (.clock(clk));
  MA_data_confirm_if cfm_if (.clock(clk));

  // === DUT ===
  can_mac_tx dut (
      .clk(clk),
      .rst(rst),
      .can_clk_en(can_clk_en),
      .can_tx(can_tx),
      .ma_req(req_if),
      .ma_cfm(cfm_if)
  );

  // === Clock Generation ===
  always #5 clk = ~clk;  // 100 MHz
  // always #50 can_clk_en = ~can_clk_en;  // 10 MHz = 1 time quantum = 100ns
  // // assign can_clk_en = clk;

  // Generate can_clk_en every 10 cycles (i.e., 10 MHz if clk = 100 MHz)
  logic [3:0] can_clk_div;
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      can_clk_div <= 0;
      can_clk_en  <= 0;
    end else begin
      if (can_clk_div == 9) begin
        can_clk_en  <= 1;
        can_clk_div <= 0;
      end else begin
        can_clk_en  <= 0;
        can_clk_div <= can_clk_div + 1;
      end
    end
  end

  // === Constants ===
  localparam [10:0] MSG_ID = 11'h123;
  localparam [31:0] DATA_WORD = 32'hDEADBEEF;
  localparam [3:0] DLC = 4'd4;

  // === Stimulus ===
  initial begin
    clk = 0;
    // can_clk_en = 0;
    rst = 1;
    req_if.valid = 0;
    cfm_if.ready = 1;

    repeat (5) @(posedge clk);
    rst = 0;

    repeat (5) @(posedge clk);

    // Send MA_data.request
    @(posedge clk);
    req_if.identifier   = MSG_ID;
    req_if.dlc          = DLC;
    req_if.data_payload = DATA_WORD;
    req_if.valid        = 1;

    // Wait for MAC to accept the request
    wait (req_if.ready);
    @(posedge clk);
    req_if.valid = 0;

    // Wait for tx_done
    wait (cfm_if.valid);
    $display("TX DONE: ID=%h, Status=%s", cfm_if.identifier,
             (cfm_if.status == cfm_if.Success) ? "Success" : "Fail");

    #100;
    $finish;
  end
endmodule
