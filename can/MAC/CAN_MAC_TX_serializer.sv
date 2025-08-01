module CAN_MAC_TX_serializer (
    input logic clk,
    input logic reset,

    // MAC → Stuffer
    input  logic bit_in,  // destuffed bit from MAC
    input  logic valid,   // MAC says bit_in is valid
    output logic ready,   // Stuffer is ready to consume bit_in

    // Control
    input logic stuffing_enable,  // Stuffing enable (active during SOF to CRC)

    // Stuffer → Serializer
    output logic bit_out,   // stuffed bit out
    output logic bit_valid  // output is valid this cycle
);


  typedef enum logic [3:0] {
    IDLE,
    ONE_1,
    TWO_1,
    THREE_1,
    FOUR_1,
    FIVE_1,
    ONE_0,
    TWO_0,
    THREE_0,
    FOUR_0,
    FIVE_0
  } state_t;

  state_t state, next_state;

  logic bit_buf;  // store input bit for use after stuffing
  logic consume_bit;  // internal signal: consume from MAC

  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      state   <= IDLE;
      bit_buf <= 1'b0;
    end else begin
      state <= next_state;
      if (consume_bit) bit_buf <= bit_in;
    end
  end

  always_comb begin
    next_state  = state;
    consume_bit = 1'b0;

    case (state)
      IDLE: begin
        if (valid) next_state = (bit_in == 1) ? ONE_1 : ONE_0;
      end

      ONE_1:
      if (!stuffing_enable) next_state = IDLE;
      else if (valid) next_state = (bit_in == 1) ? TWO_1 : ONE_0;

      TWO_1:   if (valid) next_state = (bit_in == 1) ? THREE_1 : ONE_0;
      THREE_1: if (valid) next_state = (bit_in == 1) ? FOUR_1 : ONE_0;
      FOUR_1:  if (valid) next_state = (bit_in == 1) ? FIVE_1 : ONE_0;

      FIVE_1: begin
        if (stuffing_enable) next_state = ONE_0;
        else if (valid) next_state = (bit_in == 1) ? FIVE_1 : ONE_0;
      end

      ONE_0:
      if (!stuffing_enable) next_state = IDLE;
      else if (valid) next_state = (bit_in == 0) ? TWO_0 : ONE_1;

      TWO_0:   if (valid) next_state = (bit_in == 0) ? THREE_0 : ONE_1;
      THREE_0: if (valid) next_state = (bit_in == 0) ? FOUR_0 : ONE_1;
      FOUR_0:  if (valid) next_state = (bit_in == 0) ? FIVE_0 : ONE_1;

      FIVE_0: begin
        if (stuffing_enable) next_state = ONE_1;
        else if (valid) next_state = (bit_in == 0) ? FIVE_0 : ONE_1;
      end

      default: next_state = IDLE;
    endcase

    // Consume input bit only when not stuffing
    if (state inside {
      IDLE, ONE_1, TWO_1, THREE_1, FOUR_1, FIVE_1,
            ONE_0, TWO_0, THREE_0, FOUR_0, FIVE_0
    } && valid) begin
      consume_bit = 1;
    end
  end



  always_comb begin
    bit_out   = 1'bx;
    bit_valid = 1'b1;
    ready     = 1'b0;

    case (state)
      IDLE: begin
        bit_valid = 1'b0;
        ready     = 1'b1;
      end

      ONE_1, TWO_1, THREE_1, FOUR_1: begin
        bit_out = 1;
        ready   = 1'b1;
      end

      ONE_0, TWO_0, THREE_0, FOUR_0: begin
        bit_out = 0;
        ready   = 1'b1;
      end

      FIVE_1: begin
        bit_out = 1;
        ready   = 1'b0;
      end

      FIVE_0: begin
        bit_out = 0;
        ready   = 1'b0;
      end

      default: begin
        bit_valid = 1'b0;
        ready     = 1'b0;
      end
    endcase
  end


endmodule
