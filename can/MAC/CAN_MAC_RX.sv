// MVP: CAN MAC RX module with basic frame field extraction and CRC computation

module CAN_MAC_RX #(
    parameter CLK_HZ = 16_000_000
) (
    input logic clk,
    input logic reset,
    input logic can_clk_en, // one pulse per time quantum (bit edge)

    // RX bitstream from deserializer
    input logic bit_in,

    // Output to LLC (MA_Data.indication)
    MA_data_indication_if.MAC ma_ind
);

  typedef enum logic [3:0] {
    IDLE,
    SOF,
    ARB,
    CTRL,
    DATA,
    CRC,
    CRC_DELIM,
    ACK,
    ACK_DELIM,
    EOF,
    IFS,
    STATE_ERROR
  } state_t;

  typedef enum logic [3:0] {
    ERROR_NONE,
    ERROR_BIT,
    ERROR_STUFF,
    ERROR_CRC,
    ERROR_FORM,
    ERROR_ACK
  } error_t;

  error_t rx_error, next_rx_error;

  state_t state, next_state;
  logic [6:0] bit_cnt;

  logic [10:0] identifier;
  logic [3:0] dlc;
  logic [63:0] data;
  logic [14:0] crc_wire;
  logic crc_clear;
  logic crc_en;

  logic [63:0] data_shift;
  logic data_shift_en;

  logic [10:0] arb_shift;
  logic [3:0] ctrl_shift;

  assign ma_ind.identifier   = identifier;
  assign ma_ind.dlc          = dlc;
  assign ma_ind.data_payload = data;
  assign ma_ind.valid        = (state == IFS && bit_cnt == 6);

  // === Deserializer (stuffed bitstream -> destuffed bitstream) ===
  logic destuffed_bit, destuffed_valid, destuffed_ready;
  logic stuff_error;

  // Latch can_clk_en for one cycle
  logic can_clk_en_delayed, can_clk_en_delayed_2, destuffed_bit_delayed, destuffed_valid_delayed;
  always_ff @(posedge clk) begin
    can_clk_en_delayed <= can_clk_en;
    can_clk_en_delayed_2 <= can_clk_en_delayed;
    destuffed_bit_delayed <= destuffed_bit;
    destuffed_valid_delayed <= destuffed_valid_delayed;
  end

  // FSM sequential logic
  always_ff @(posedge clk, posedge reset) begin : fsm_sequential
    if (reset) state <= IDLE;
    else if (rx_error != ERROR_NONE) state <= STATE_ERROR;
    else if (can_clk_en_delayed && destuffed_valid) state <= next_state;
  end

  // Error detection
  always_ff @(posedge clk) begin : error_detection_sequential
    if (reset) rx_error <= ERROR_NONE;
    else rx_error <= next_rx_error;
  end


  logic destuffing_enable;
  assign destuffing_enable = (state inside {SOF, ARB, CTRL, DATA, CRC});

  CAN_MAC_RX_deserializer deser (
      .clk(clk),
      .can_clk_en(can_clk_en),
      .reset(reset),
      .bit_in(bit_in),
      .destuffing_enable(destuffing_enable),
      .bit_out(destuffed_bit),
      .valid(destuffed_valid),
      .ready(destuffed_ready),
      .stuff_error(stuff_error)
  );

  assign destuffed_ready = 1'b1;  // always accept bits

  always_comb begin : next_state_generator
    next_state = state;
    case (state)
      IDLE:      if (destuffed_valid && destuffed_bit == 1'b0) next_state = SOF;
      SOF:       next_state = ARB;
      ARB:       if (bit_cnt == 11) next_state = CTRL;
      CTRL:      if (bit_cnt == 5) next_state = (ctrl_shift[3:0] == 0) ? CRC : DATA;
      DATA:      if (bit_cnt == (dlc * 8 - 1)) next_state = CRC;
      CRC:       if (bit_cnt == 14) next_state = CRC_DELIM;
      CRC_DELIM: next_state = ACK;
      ACK:       next_state = ACK_DELIM;
      ACK_DELIM: next_state = EOF;
      EOF:       if (bit_cnt == 6) next_state = IFS;
      IFS:       if (bit_cnt == 6) next_state = IDLE;
    endcase
  end

  // Bit counter
  always_ff @(posedge clk, posedge reset) begin
    if (reset) bit_cnt <= 0;
    else if (can_clk_en_delayed && destuffed_valid) begin
      if (state != next_state) bit_cnt <= 0;
      else bit_cnt <= bit_cnt + 1;
    end
  end


  // Shift registers for fields
  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      arb_shift  <= 0;
      identifier <= 0;
      ctrl_shift <= 0;
      dlc        <= 0;
      data       <= 0;
      data_shift <= 0;
    end else if (can_clk_en_delayed_2 && destuffed_valid) begin
      if (state == ARB) begin
        arb_shift <= {arb_shift[9:0], destuffed_bit};
        if (bit_cnt == 11) identifier <= arb_shift;
      end else if (state == CTRL) begin
        ctrl_shift <= {ctrl_shift[3:0], destuffed_bit};
        if (bit_cnt == 5) dlc <= {ctrl_shift[3:0], destuffed_bit};
      end else if (state == DATA) begin
        data_shift <= {data_shift[62:0], destuffed_bit};
        if (bit_cnt == (dlc * 8 - 1)) data <= {data_shift[62:0], destuffed_bit};
      end
    end
  end

  always_comb begin : error_detection
    case (state)
      STATE_ERROR: next_rx_error = rx_error;
      // Computed CRC from SOF up to CRC must be zero
      CRC_DELIM: if (crc_wire != 15'h0) next_rx_error = ERROR_CRC;
      // ACK slot must be driven with a dominant by receiving nodes 
      ACK: if (can_clk_en_delayed_2 & destuffed_bit) next_rx_error = ERROR_ACK;
      default: next_rx_error = ERROR_NONE;
    endcase
  end

  // CRC unit
  CRC_Unit crc_inst (
      .BITVAL(destuffed_bit),
      .BITSTRB(can_clk_en && destuffed_valid && crc_en),
      .CLEAR(crc_clear),
      .CRC(crc_wire)
  );

  assign crc_clear = (state == IDLE);
  assign crc_en = (state inside {SOF, ARB, CTRL, DATA, CRC});

endmodule

module RX_top_wrapper;
  logic clk, rst, can_clk_en;
  logic can_rx;
  logic bit_in, bit_valid, bit_ready;

  MA_data_indication_if ind_if (.clock(clk));

  CAN_MAC_RX dut (
      .clk(clk),
      .reset(rst),
      .can_clk_en(can_clk_en),
      .bit_in(can_rx),
      .ma_ind(ind_if)
  );
endmodule
