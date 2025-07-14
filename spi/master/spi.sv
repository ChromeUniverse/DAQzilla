// `default_nettype none

module spi_fsm (
  input wire clock_i, reset_i,

  // status signals (inform transitions)
  input wire start_i, bit_count_done_i, hold_delay_done_i,

  // control signals (Mealy FSM outputs)
  output logic shift_en_o, 
  output logic tx_load_o,
  output logic bit_count_en_o,
  output logic bit_count_clear_o,
  output logic hold_delay_en_o,
  
  // external outputs
  output logic done_o
);  

  typedef enum logic [2:0] {
    IDLE, TRANSFER, HOLD_DELAY, ILLEGAL_STATE
  } state_t;

  state_t state, next_state;

  always_ff @(posedge clock_i) begin
     if (reset_i)
       state <= IDLE;
     else
       state <= next_state;
  end

  // next state generator
  // TODO: thoroughly test and debug these changes
  // TODO: document all timing constraints based on Timing Characteristics
  always_comb begin
    case (state)
      IDLE:
        next_state = (start_i) ? TRANSFER : IDLE;
      TRANSFER:
        next_state = (bit_count_done_i) ? HOLD_DELAY : TRANSFER;
      HOLD_DELAY:
        if (~hold_delay_done_i)
          next_state = HOLD_DELAY;
        else if (start_i) 
          next_state = TRANSFER;
        else 
          next_state = IDLE;
      
    endcase
  end

  // output generator

  always_comb begin
    shift_en_o = 1'b0;
    tx_load_o = 1'b0;
    bit_count_en_o = 1'b0;
    bit_count_clear_o = 1'b0;
    hold_delay_en_o = 1'b0;
    done_o = 1'b0;

    case (state)
      IDLE: 
        if (start_i) begin
          tx_load_o = 1'b1;
          bit_count_clear_o = 1'b1;
        end
      TRANSFER:
        if (~bit_count_done_i) begin
          shift_en_o = 1'b1;
          bit_count_en_o = 1'b1;
        end else
          shift_en_o = 1'b1;
      HOLD_DELAY:
        // if (hold_delay_done_i)
        //   done_o = 1'b1;
        // else begin
        //   hold_delay_en_o = 1'b1;
        //   shift_en_o = 1'b1;
        // end

        if (~hold_delay_done_i) begin
          hold_delay_en_o = 1'b1;
          shift_en_o = 1'b1;
        end else begin
          done_o = 1'b1;
          if (start_i) begin
            tx_load_o = 1'b1;
            bit_count_clear_o = 1'b1;
          end
        end

      default:
        ;
    endcase
   end
  
endmodule: spi_fsm


module spi #(
  parameter WIDTH = 8
) (
  input  wire         reset_i,
  input  wire         clock_i,

  // control interface
  input  wire             start_i,
  output wire             done_o,
  input  wire [WIDTH-1:0] tx_buffer_i,
  output wire [WIDTH-1:0] rx_buffer_o,

  // SPI protocol interface
  input  wire MISO_i,
  output wire MOSI_o,
  output wire SCLK_o,
  output wire auto_CS_o    // asserted only while a transfer is happening
);

  // FSM status
  wire bit_count_done, hold_delay_done;

  // FSM control
  wire shift_en, tx_load, bit_count_en, bit_count_clear, hold_delay_en;

  // FSM
  spi_fsm fsm (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .start_i(start_i),
    .bit_count_done_i(bit_count_done),
    .shift_en_o(shift_en),
    .tx_load_o(tx_load),
    .bit_count_en_o(bit_count_en),
    .bit_count_clear_o(bit_count_clear),
    .hold_delay_done_i(hold_delay_done),
    .hold_delay_en_o(hold_delay_en),
    .done_o(done_o)
  );

  // SPI Clock Generation
  spi_clk_gen #(.EXP_FACTOR(6)) clkgen (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .SCLK_o(SCLK_o),
    .en_i(shift_en)
  );

  logic SCLK_falling_edge;
  edge_trigger #(.DETECT_POS_EDGE(0)) posedge_trigger (
    .clk(clock_i),
    .reset(reset_i),
    .signal_in(SCLK_o),
    .pulse_out(SCLK_falling_edge)
  );

  // TODO: must ensure this allows RX to shift in all 8 bits
  logic [3:0] bit_count_out;
  Counter #(.WIDTH(4)) bit_count (
    .clock(clock_i),
    .en(bit_count_en & SCLK_falling_edge),
    .clear(bit_count_clear),
    .load(1'b0),
    .up(1'b1),
    .D(4'b0),
    .Q(bit_count_out)
  );
  assign bit_count_done = (bit_count_out == 4'd8);

  // SPI TX
  spi_tx #(.WIDTH(8)) spi_tx_unit (
    .clock_i(clock_i),
    // NOTE: `bit_count_clear` also clears internal MOSI output register
    // when transitioning into TRANSFER state. also prevents glitching! :)
    .reset_i(reset_i | bit_count_clear),  
    .tx_en_i(shift_en),
    .tx_load_i(tx_load),
    .SCLK_i(SCLK_o),
    .tx_buffer_i(tx_buffer_i),
    .MOSI_o(MOSI_o)
  );

  // SPI RX
  spi_rx #(.WIDTH(8)) spi_rx_unit (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .rx_en_i(shift_en),
    .SCLK_i(SCLK_o),
    .MISO_i(MISO_i),
    .rx_data_o(rx_buffer_o)
  );

  spi_delay_timer #(.MAX_COUNT(20)) delay_time (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .delay_en_i(hold_delay_en),
    .delay_done_o(hold_delay_done)
  );

endmodule : spi