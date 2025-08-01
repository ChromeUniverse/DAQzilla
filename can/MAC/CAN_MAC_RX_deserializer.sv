module CAN_MAC_RX_deserializer (
    input logic clk,
    input logic can_clk_en,
    input logic reset,

    // Deserializer → Destuffer
    input logic bit_in,  // stuffed bit from MAC

    // Control
    input logic destuffing_enable,  // Enable destuffing during SOF to CRC

    // Destuffer → MAC
    output logic bit_out,     // destuffed bit
    output logic valid,       // output is valid this cycle
    input  logic ready,       // MAC is ready to accept this bit
    output logic stuff_error  // stuff error detected: 6 identical consecutive bits
);

  typedef enum logic [3:0] {
    IDLE,
    ONE_1,
    TWO_1,
    THREE_1,
    FOUR_1,
    FIVE_1,
    DROP_STUFFED_0,
    ONE_0,
    TWO_0,
    THREE_0,
    FOUR_0,
    FIVE_0,
    DROP_STUFFED_1,
    STUFF_ERROR
  } state_t;

  state_t state, next_state;

  logic bit_buf;  // store input bit for use after destuffing
  // logic consume_bit;  // internal signal: consume from MAC

  // Sequential logic

  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      state   <= IDLE;
      bit_buf <= 1'b0;
    end else if (can_clk_en) begin
      state   <= next_state;
      bit_buf <= bit_in;
    end
  end

  // Next state logic

  always_comb begin : next_state_generator
    if (reset) begin
      next_state = IDLE;
    end else begin

      case (state)
        IDLE: begin
          if (ready) next_state = (bit_in == 1) ? ONE_1 : ONE_0;
        end

        ONE_1:
        if (!destuffing_enable) next_state = (bit_in == 1) ? ONE_1 : ONE_0;
        else next_state = (bit_in == 1) ? TWO_1 : ONE_0;

        TWO_1:   next_state = (bit_in == 1) ? THREE_1 : ONE_0;
        THREE_1: next_state = (bit_in == 1) ? FOUR_1 : ONE_0;
        FOUR_1:  next_state = (bit_in == 1) ? FIVE_1 : ONE_0;

        FIVE_1: begin
          if (destuffing_enable) next_state = (bit_in == 1) ? STUFF_ERROR : DROP_STUFFED_0;
          else next_state = (bit_in == 1) ? FIVE_1 : ONE_0;
        end

        DROP_STUFFED_0: begin
          next_state = (bit_in == 0) ? TWO_0 : ONE_1;
        end

        ONE_0:
        if (!destuffing_enable) next_state = (bit_in == 0) ? ONE_0 : ONE_1;
        else next_state = (bit_in == 0) ? TWO_0 : ONE_1;

        TWO_0:   if (ready) next_state = (bit_in == 0) ? THREE_0 : ONE_1;
        THREE_0: if (ready) next_state = (bit_in == 0) ? FOUR_0 : ONE_1;
        FOUR_0:  if (ready) next_state = (bit_in == 0) ? FIVE_0 : ONE_1;

        FIVE_0: begin
          if (destuffing_enable) next_state = (bit_in == 0) ? STUFF_ERROR : DROP_STUFFED_1;
          else next_state = (bit_in == 0) ? FIVE_0 : ONE_1;
        end

        DROP_STUFFED_1: begin
          next_state = (bit_in == 1) ? TWO_1 : ONE_0;
        end

        default: next_state = IDLE;
      endcase

    end
  end

  // Output logic
  always_comb begin : output_generator
    bit_out     = 1'bx;
    valid       = 1'b1;
    stuff_error = 1'b0;

    case (state)
      IDLE: begin
        valid = 1'b0;
      end

      ONE_1, TWO_1, THREE_1, FOUR_1, FIVE_1: begin
        bit_out = 1;
      end

      ONE_0, TWO_0, THREE_0, FOUR_0, FIVE_0: begin
        bit_out = 0;
      end

      DROP_STUFFED_0, DROP_STUFFED_1: begin
        bit_out = 1'bx;
        valid   = 1'b0;
      end

      STUFF_ERROR: begin
        bit_out = 1'bx;
        valid = 1'b0;
        stuff_error = 1'b1;
      end

      default: begin
        bit_out     = 1'bx;
        valid       = 1'b0;
        stuff_error = 1'b0;
      end
    endcase
  end

endmodule
