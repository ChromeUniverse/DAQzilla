`default_nettype none

module can_bit_stuffer_FSM_moore (
  input wire clock_i, reset_i,

  // status signals
  input wire start_i,
  input wire stuff_i, count_done_i,

  // control signals
  output wire pipo_en_o, pipo_load_o, sipo_en_o, count_en_o, count_clr_o, select_o, done_o
);

  typedef enum logic [2:0] { 
    IDLE, LATCH, SHIFT, STUFF, DONE, ILLEGAL_STATE
  } state_t;

  state_t state, next_state;

  always_ff @(posedge clock_i, reset_i) begin
    if (reset_i)
      state <= IDLE;
    else
      state <= next_state;
  end

  // next state generation

  always_comb begin
    case (state)
      IDLE: 
        next_state = (start_i) ? LATCH : IDLE;
      LATCH:
        next_state = SHIFT;
      SHIFT:
        if (stuff_i)
          next_state = STUFF;
        else if (count_done_i)
          next_state = DONE;
        else
          next_state = SHIFT;
      STUFF:
        if (count_done_i)
          next_state = DONE;
        else
          next_state = SHIFT;
      DONE:
        next_state = IDLE;
      default: 
        next_state = ILLEGAL_STATE;
    endcase
  end

  // output generation

  logic [6:0] out_vector;
  assign {
    pipo_en_o,
    pipo_load_o,
    sipo_en_o,
    count_en_o,
    count_clr_o,
    select_o,
    done_o
  } = out_vector;

  always_comb begin 
    case (state)
      IDLE:     out_vector = 7'b000_0000;
      LATCH:    out_vector = 7'b010_0100;
      SHIFT:    out_vector = 7'b101_1000;
      STUFF:    out_vector = 7'b001_0010;
      DONE:     out_vector = 7'b000_0001;
      default:  out_vector = 7'b000_0000;
    endcase
  end
  
  
endmodule


module can_bit_stuffer_FSM_mealy (
  input wire clock_i, reset_i,

  // status signals
  input wire start_i,
  input wire stuff_i, count_done_i,

  // control signals
  output logic pipo_en_o, pipo_load_o, sipo_en_o, count_en_o, count_clr_o, select_o, done_o
);

  typedef enum logic [2:0] { 
    IDLE, SHIFT, STUFF, DONE, ILLEGAL_STATE
  } state_t;

  state_t state, next_state;

  always_ff @(posedge clock_i, reset_i) begin
    if (reset_i)
      state <= IDLE;
    else
      state <= next_state;
  end

  // next state generation

  always_comb begin
    case (state)
      IDLE: 
        next_state = (start_i) ? SHIFT : IDLE;
      // LATCH: 
      //   next_state = SHIFT;
      SHIFT:
        if (stuff_i)
          next_state = SHIFT;
        else if (count_done_i)
          // next_state = DONE;
          next_state = IDLE;
        else
          next_state = SHIFT;
      // TODO: do we still need the STUFF state?
      // STUFF:
      //   if (count_done_i)
      //     next_state = DONE;
      //   else
      //     next_state = SHIFT;
      // DONE:
      //   next_state = IDLE;
      default: 
        next_state = ILLEGAL_STATE;
    endcase
  end

  // output generation

  // logic [6:0] out_vector;
  // assign {
  //   pipo_en_o,
  //   pipo_load_o,
  //   sipo_en_o,
  //   count_en_o,
  //   count_clr_o,
  //   select_o,
  //   done_o
  // } = out_vector;

  // always_comb begin 

  //   pipo_en_o,
  //   pipo_load_o,
  //   sipo_en_o,
  //   count_en_o,
  //   count_clr_o,
  //   select_o,
  //   done_o

  //   case (state)
  //     IDLE:     out_vector = 7'b000_0000;
  //     LATCH:    out_vector = 7'b010_0100;
  //     SHIFT:    out_vector = 7'b101_1000;
  //     STUFF:    out_vector = 7'b001_0010;
  //     DONE:     out_vector = 7'b000_0001;
  //     default:  out_vector = 7'b000_0000;
  //   endcase
  // end

  always_comb begin 

    pipo_en_o = 1'b0;
    pipo_load_o = 1'b0;
    sipo_en_o = 1'b0;
    count_en_o = 1'b0;
    count_clr_o = 1'b0;
    select_o = 1'b0;
    done_o = 1'b0;

    case (state)
      IDLE:
        if (start_i) begin
          pipo_load_o = 1'b1;
          count_clr_o = 1'b1;
        end
      SHIFT:
        if (stuff_i) begin
          select_o =  1'b1;
          sipo_en_o = 1'b1;
        end
        else if (count_done_i)
          done_o = 1;
        else begin
          pipo_en_o = 1'b1;
          sipo_en_o = 1'b1;
          count_en_o = 1'b1;
        end
          
      // STUFF:    out_vector = 7'b001_0010;
      // DONE:     out_vector = 7'b000_0001;
    endcase
  end
  
  
endmodule


module can_bit_stuffer (
  input wire [65:0] unstuffed_i,
  input wire start_i,
  input wire clock_i, reset_i,
  output wire serial_o, done_o
); 

  // FSM status signals
  wire stuff, count_done;

  // FSM control signals
  wire pipo_en, pipo_load, sipo_en, count_en, count_clr, select, fsm_done;

  // can_bit_stuffer_FSM_moore FSM(
  //   .clock_i(clock_i),
  //   .reset_i(reset_i),
  //   .start_i(start_i),
  //   .stuff_i(stuff),
  //   .count_done_i(count_done),
  //   .pipo_en_o(pipo_en), 
  //   .pipo_load_o(pipo_load),
  //   .sipo_en_o(sipo_en), 
  //   .count_en_o(count_en),
  //   .count_clr_o(count_clr),
  //   .select_o(select), 
  //   .done_o(fsm_done)
  // );  

  can_bit_stuffer_FSM_mealy FSM(
    .clock_i(clock_i),
    .reset_i(reset_i),
    .start_i(start_i),
    .stuff_i(stuff),
    .count_done_i(count_done),
    .pipo_en_o(pipo_en), 
    .pipo_load_o(pipo_load),
    .sipo_en_o(sipo_en), 
    .count_en_o(count_en),
    .count_clr_o(count_clr),
    .select_o(select), 
    .done_o(fsm_done)
  );  

  wire [65:0] pipo_out;

  ShiftRegisterPIPO #(.WIDTH(66)) pipo (
    .en(pipo_en),
    .left(1'b1),
    .load(pipo_load),
    .clock(clock_i),
    .D(unstuffed_i),
    .Q(pipo_out)
  );

  wire sipo_serial;
  wire [4:0] stuff_buffer;
  // assign sipo_serial = pipo_out[65] ^ select;
  assign sipo_serial = select ? ~stuff_buffer[0] : pipo_out[65];


  ShiftRegisterSIPO #(.WIDTH(5)) sipo (
    .serial(sipo_serial),
    .en(sipo_en),
    .left(1'b1),
    .clock(clock_i),
    .Q(stuff_buffer)
  );

  assign stuff = (stuff_buffer == 5'b1_1111) | (stuff_buffer == 5'b0_0000);

  wire [6:0] count_out;
  Counter #(.WIDTH(7)) counter (
    .en(count_en),
    .clear(count_clr),
    .load(1'b0),
    .up(1'b1),
    .D(7'b0),
    .clock(clock_i),
    .Q(count_out)
  );

  assign count_done = (count_out == 7'd66);

  assign done_o = fsm_done;

  assign serial_o = sipo_serial;
  
endmodule