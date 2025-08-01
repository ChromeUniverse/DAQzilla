// Minimal CAN MAC TX with MA_data.request + MA_data.confirm support

module can_mac_tx #(
    parameter CLK_FREQ_HZ = 16_000_000
) (
    input logic clk,
    input logic rst,

    input  logic can_clk_en,
    output logic can_tx,

    // MAC <-> LLC service interfaces
    MA_data_request_if.MAC ma_req,
    MA_data_confirm_if.MAC ma_cfm
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
    // TODO: differentiate IFS and intermission
    IFS
  } tx_state_t;

  tx_state_t state, next_state;
  logic [6:0] bit_cnt;

  logic       tx_active;
  logic       stuffing_enable;

  // === Request handshake ===
  assign ma_req.ready = (state == IDLE);
  wire tx_start = ma_req.valid && ma_req.ready;  // Shorthard for handshake complete

  // === Confirm handshake ===
  assign ma_cfm.valid = (state == IFS && bit_cnt == 6);
  assign ma_cfm.identifier = ma_req.identifier;
  assign ma_cfm.status = (ma_cfm.valid ? ma_cfm.Success : ma_cfm.No_Success); // Always success in MVP

  // === Frame fields ===
  logic [11:0] arb_field;  // 11-bit ID + RTR=0
  logic [ 5:0] ctrl_field;  // IDE=0, r0=0, DLC[3:0]
  logic [63:0] data_reg;
  logic [14:0] crc_out;
  logic crc_clear, crc_en, crc_bit_in;

  // === CRC Generator ===
  CRC_Unit crc_unit (
      .BITVAL(crc_bit_in),
      .BITSTRB(can_clk_en & crc_en),
      .CLEAR(crc_clear),
      .CRC(crc_out)
  );

  // === FSM ===
  always_ff @(posedge clk, posedge rst) begin
    if (rst) state <= IDLE;
    else if (can_clk_en) state <= next_state;
  end

  logic tx_latched;

  always_ff @(posedge clk or posedge rst) begin : tx_start_latching
    if (rst) tx_latched <= 0;
    else if (tx_start) tx_latched <= 1;
    else if (can_clk_en && state == SOF) tx_latched <= 0;
  end

  always_comb begin : next_state_generator
    next_state = state;
    case (state)
      IDLE:      if (tx_latched) next_state = SOF;
      SOF:       next_state = ARB;
      ARB:       if (bit_cnt == 11) next_state = CTRL;
      CTRL:      if (bit_cnt == 5) next_state = (ma_req.dlc == 0) ? CRC : DATA;
      DATA:      if (bit_cnt == (ma_req.dlc * 8 - 1)) next_state = CRC;
      CRC:       if (bit_cnt == 14) next_state = CRC_DELIM;
      CRC_DELIM: next_state = ACK;
      ACK:       next_state = ACK_DELIM;
      ACK_DELIM: next_state = EOF;
      EOF:       if (bit_cnt == 6) next_state = IFS;
      IFS:       if (bit_cnt == 6) next_state = IDLE;
      default:   next_state = IDLE;
    endcase
  end


  always_ff @(posedge clk or posedge rst) begin : bit_cnt_update
    if (rst) bit_cnt <= 0;
    else if (can_clk_en) bit_cnt <= (state != next_state) ? 0 : bit_cnt + 1;
  end

  always_ff @(posedge clk or posedge rst) begin : latch_inputs
    if (rst) begin
      arb_field  <= 0;
      ctrl_field <= 0;
      data_reg   <= 0;
    end else if (tx_start) begin
      arb_field  <= {ma_req.identifier, 1'b0};  // NOTE: RTR=0
      ctrl_field <= {2'b00, ma_req.dlc};
      data_reg   <= ma_req.data_payload;
    end
  end

  // === Bitstream ===
  logic raw_bit;
  always_comb begin
    unique case (state)
      SOF:       raw_bit = 1'b0;
      ARB:       raw_bit = arb_field[11-bit_cnt];
      CTRL:      raw_bit = ctrl_field[5-bit_cnt];
      DATA:      raw_bit = data_reg[(ma_req.dlc*8-1)-bit_cnt];
      CRC:       raw_bit = crc_out[14-bit_cnt];
      CRC_DELIM: raw_bit = 1'b1;
      ACK:       raw_bit = 1'b1;  // dominant ACK driven externally
      ACK_DELIM: raw_bit = 1'b1;
      EOF, IFS:  raw_bit = 1'b1;
      default:   raw_bit = 1'b1;
    endcase
  end

  assign stuffing_enable = (state inside {SOF, ARB, CTRL, DATA, CRC});

  // === CRC control ===
  assign crc_clear = (state == IDLE);
  // FIXME: might require SOF as well
  assign crc_en    = (state inside {ARB, CTRL, DATA});
  // assign crc_en    = (state inside {SOF, ARB, CTRL, DATA});
  assign crc_bit_in = raw_bit;

  // === Bit Stuffer/Serializer ===
  logic stuff_valid, stuff_ready;
  logic can_bit, can_valid;

  CAN_MAC_TX_serializer serializer (
      .clk(clk),
      .reset(rst),
      .bit_in(raw_bit),
      .valid(stuff_valid),
      .ready(stuff_ready),
      .stuffing_enable(stuffing_enable),
      .bit_out(can_bit),
      .bit_valid(can_valid)
  );

  assign stuff_valid = can_clk_en && (state != IDLE);
  assign can_tx = can_valid ? can_bit : 1'b1;

endmodule


module TX_top_wrapper;
  logic clk, rst, can_clk_en;
  logic can_tx;

  MA_data_request_if req_if (.clock(clk));
  MA_data_confirm_if cfm_if (.clock(clk));

  can_mac_tx dut (
      .clk(clk),
      .rst(rst),
      .can_clk_en(can_clk_en),
      .can_tx(can_tx),
      .ma_req(req_if),
      .ma_cfm(cfm_if)
  );
endmodule
