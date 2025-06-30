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

  // Datapath status signals:

  // CRC generation
  input wire crc_done_i,

  // Bit stuffing
  input wire start_i,
  input wire stuff_i, stuffable_count_done_i, full_count_done_i,

  // Datapath control signals:

  // CRC generation
  output logic crc_pipo_en_o, 
    crc_pipo_load_o, 
    crc_en_o,
    crc_clear_o,
    crc_count_en_o,
    crc_count_clear_o,

  // Bit stuffing
  output logic pipo_en_o, 
    pipo_load_o,
    sipo_en_o, 
    count_en_o, 
    count_clr_o, 
    select_o, 
    done_o,
    bus_idle_o,
    can_clk_en_o
);

  typedef enum logic [1:0] { 
    IDLE, CRC_COMPUTE, SHIFT, ILLEGAL_STATE
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
        next_state = (start_i) ? CRC_COMPUTE : IDLE;
      CRC_COMPUTE:
        next_state = (crc_done_i) ? SHIFT : CRC_COMPUTE;
      SHIFT:
        next_state = (full_count_done_i) ? IDLE : SHIFT;
      default: 
        next_state = ILLEGAL_STATE;
    endcase
  end

  // output generation

  always_comb begin 

    bus_idle_o = 1'b0;

    // CRC generation
    crc_pipo_en_o = 1'b0;
    crc_pipo_load_o = 1'b0;
    crc_en_o = 1'b0;
    crc_clear_o = 1'b0;
    crc_count_en_o = 1'b0;
    crc_count_clear_o = 1'b0;

    // bit stuffing/serialization
    pipo_en_o = 1'b0;
    pipo_load_o = 1'b0;
    sipo_en_o = 1'b0;
    count_en_o = 1'b0;
    count_clr_o = 1'b0;
    select_o = 1'b0;
    done_o = 1'b0;
    can_clk_en_o = 1'b0;

    case (state)
      IDLE:
        begin
          bus_idle_o = 1'b1;

          // latch inputs: CRC scoped fields
          count_clr_o = 1'b1;
          if (start_i) begin
            crc_pipo_load_o = 1'b1;
            crc_count_clear_o = 1'b1;
            crc_clear_o = 1'b1;
          end
        end

      CRC_COMPUTE:
        begin
          bus_idle_o = 1'b1;
          
          crc_count_en_o = 1'b1;
          crc_pipo_en_o = 1'b1;
          crc_en_o = 1'b1;

          // latch inputs: unstuffed fields
          count_clr_o = 1'b1;
          if (crc_done_i) pipo_load_o = 1'b1;
        end

      SHIFT: begin
        can_clk_en_o = 1'b1;

        if (stuff_i) begin
          select_o =  1'b1;
          sipo_en_o = 1'b1;
        end else if (full_count_done_i)
          done_o = 1;
        else if (stuffable_count_done_i) begin
          pipo_en_o = 1'b1;
          count_en_o = 1'b1;
        end else begin
          pipo_en_o = 1'b1;
          sipo_en_o = 1'b1;
          count_en_o = 1'b1;
        end
      end        
          
      // STUFF:    out_vector = 7'b001_0010;
      // DONE:     out_vector = 7'b000_0001;
    endcase
  end
  
  
endmodule


module can_bit_stuffer (
  // input wire [82:0] unstuffed_i,
  input wire [31:0] data_i,
  input wire [10:0] msg_id_i,
  input wire start_i,
  input wire clock_i, reset_i,
  output logic serial_o, done_o
); 

  // FSM status signals

  // CRC
  wire crc_done;
  
  // Bit stuffing
  wire stuff, stuffable_count_done, full_count_done;

  // FSM control signals:

  // CRC
  wire crc_pipo_en, crc_pipo_load, crc_en, crc_clear, crc_count_en, crc_count_clear;

  // Bit stuffing
  wire pipo_en, pipo_load, sipo_en, count_en, count_clr, select, fsm_done, bus_idle, can_clk_en;

  can_bit_stuffer_FSM_mealy FSM(
    .clock_i(clock_i),
    .reset_i(reset_i),

    // Status: CRC
    .crc_done_i(crc_done),
    
    // Status: Bit stuffing
    .start_i(start_i),
    .stuff_i(stuff),
    .stuffable_count_done_i(stuffable_count_done),
    .full_count_done_i(full_count_done),

    // Control: CRC
    .crc_pipo_en_o(crc_pipo_en),
    .crc_pipo_load_o(crc_pipo_load),
    .crc_en_o(crc_en),
    .crc_clear_o(crc_clear),
    .crc_count_en_o(crc_count_en),
    .crc_count_clear_o(crc_count_clear),

    // Control: Bit stuffing
    .pipo_en_o(pipo_en), 
    .pipo_load_o(pipo_load),
    .sipo_en_o(sipo_en), 
    .count_en_o(count_en),
    .count_clr_o(count_clr),
    .select_o(select), 
    .done_o(fsm_done),
    .bus_idle_o(bus_idle),
    .can_clk_en_o(can_clk_en)
  );

  // DATAPATH: CRC generation

  // CAN frame constants
  wire sof_bit = 1'b0;
  wire rtr_bit = 1'b0;
  wire [11:0] arb_field = {msg_id_i, rtr_bit};
  wire [5:0] control_field = 6'b00_0100;

  wire [50:0] crc_pipo_in = {sof_bit, arb_field, control_field, data_i};
  wire [50:0] crc_pipo_out;

  ShiftRegisterPIPO #(.WIDTH(51)) crc_pipo(
    .en(crc_pipo_en),
    .left(1'b1),
    .load(crc_pipo_load),
    .clock(clock_i),
    .D(crc_pipo_in),
    .Q(crc_pipo_out)
  );

  wire [14:0] crc_out;
  wire bitstrb;
  assign bitstrb = (crc_en) ? clock_i : 1'b0;

  CRC_Unit crc_generator (
    .BITVAL(crc_pipo_out[50]),
    .BITSTRB(bitstrb),
    .CLEAR(crc_clear),
    .CRC(crc_out)
  );

  wire [5:0] crc_count_out;

  Counter #(.WIDTH(6)) crc_counter (
    .en(crc_count_en),
    .clear(crc_clear),
    .load(1'b0),
    .up(1'b1),
    .clock(clock_i),
    .D(6'd0),
    .Q(crc_count_out)
  );

  assign crc_done = (crc_count_out == 6'd51);


  // DATAPATH: Bit-stuffing/serialization

  wire can_clk, can_clk_pulse;
  can_clk_gen #(.DIVISOR(200)) can_serial_clk (
    .clock_in_i(clock_i),
    .reset_i(reset_i),
    .en_i(can_clk_en),
    .clock_out_o(can_clk),
    .clock_pulse_out_o(can_clk_pulse)
  );

  wire [82:0] pipo_out;

  wire [65:0] stuffable = {sof_bit, arb_field, control_field, data_i, crc_out};

  logic crc_d = 1'b1;
  logic ack = 1'b1;               // TX node must drive this at recessive (1)
  logic ack_d = 1'b1;
  logic [6:0] eof = 7'b111_1111;
  logic [6:0] ifs = 7'b111_1111;

  wire [16:0] unstuffable = {crc_d, ack, ack_d, eof, ifs};

  wire [82:0] payload = {stuffable, unstuffable};

  wire pipo_enable_line;
  assign pipo_enable_line = pipo_en & can_clk_pulse;

  ShiftRegisterPIPO #(.WIDTH(83)) pipo (
    .en(pipo_enable_line),
    // .en(pipo_en),
    .left(1'b1),
    .load(pipo_load),
    .clock(clock_i),
    .D(payload),
    .Q(pipo_out)
  );

  wire sipo_serial;
  wire [4:0] stuff_buffer;
  // assign sipo_serial = pipo_out[65] ^ select;
  assign sipo_serial = select ? ~stuff_buffer[0] : pipo_out[82];


  wire sipo_enable_line;
  assign sipo_enable_line = sipo_en & can_clk_pulse;

  ShiftRegisterSIPO #(.WIDTH(5)) sipo (
    .en(sipo_enable_line),
    .serial(sipo_serial),
    .left(1'b1),
    .clock(clock_i),
    .Q(stuff_buffer)
  );

  assign stuff = (stuff_buffer == 5'b1_1111) | (stuff_buffer == 5'b0_0000);

  wire [6:0] count_out;
  wire counter_enable_line;
  assign counter_enable_line = count_en & can_clk_pulse;
  Counter #(.WIDTH(7)) counter (
    .en(counter_enable_line),
    // .en(count_en),
    .clear(count_clr),
    .load(1'b0),
    .up(1'b1),
    .D(7'b0),
    .clock(clock_i),
    .Q(count_out)
  );

  // Count number of TX'd bits in stuffable fields:
  // SOF, Arbitration, Control, Data, CRC
  assign stuffable_count_done = (count_out >= 7'd66);

  // Count total number of TX'd bits
  assign full_count_done = (count_out >= 7'd82);

  // DEBUGGING: CAN frame sections

  typedef enum logic [3:0] { 
    SOF, ARB, CTRL, DATA, CRC, CRCD, ACK, ACKD, EOF, IFS
  } frame_state_t;

  frame_state_t frame_state;
  always_comb begin
    if (count_out >= 76)      frame_state = IFS;
    else if (count_out >= 69) frame_state = EOF;
    else if (count_out >= 68) frame_state = ACKD;
    else if (count_out >= 67) frame_state = ACK;
    else if (count_out >= 66) frame_state = CRCD;
    else if (count_out >= 51) frame_state = CRC;
    else if (count_out >= 19) frame_state = DATA;
    else if (count_out >= 13) frame_state = CTRL;
    else if (count_out >= 1)  frame_state = ARB;
    else if (count_out >= 0)  frame_state = SOF;
  end

  assign done_o = fsm_done;


  // CAN TX serial output: 
  // if not driven by serializer, bus shall remain in a recessive state (1)
  // assign serial_o = bus_idle ? 1'b1 : sipo_serial;

  always_comb begin
    if (bus_idle)
      serial_o = 1'b1;
    else
      serial_o = sipo_serial;
  end
  
endmodule