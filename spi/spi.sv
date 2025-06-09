`default_nettype none

module spi_fsm (
  input wire clock_i, reset_i,

  // status signals
  input wire start_i, delay_done_i, tx_done_i, rx_done_i,
  // control signals
  output wire tx_en_o, tx_load_o, rx_en_o, delay_en_o, delay_clear_o,
  
  // external outputs
  output done_o
);

  typedef enum logic [2:0] {
    IDLE, WAIT1_CS, TX, WAIT2, RX, WAIT3_CS
  } state_t;

  state_t state, next_state;

  always_ff @(posedge clock_i) begin
     if (reset_i)
       state <= IDLE;
     else
       state <= next_state;
  end

  // next state generator
  always_comb begin
    case (state)
      IDLE:
        next_state = (start_i) ? WAIT1_CS : IDLE;
      WAIT1_CS:
        next_state = (delay_done_i) ? TX : WAIT1_CS;
      TX:
        next_state = (tx_done_i) ? WAIT2 : TX;
      WAIT2:
        next_state = (delay_done_i) ? RX : WAIT2;
      RX:
        next_state = (rx_done_i) ? WAIT3_CS : RX;
      WAIT3_CS:
        next_state = (delay_done_i) ? IDLE : WAIT3_CS;
    endcase
  end

  // TODO: SPI trailing edge??????

  // output generator
  logic [5:0] out_vector;
  assign {
    tx_en_o, 
    tx_load_o, 
    rx_en_o, 
    delay_en_o, 
    delay_clear_o, 
    done_o
  } = out_vector;

  always_comb begin
    case (state)
      IDLE:       out_vector = 6'b01_0_01_0; 
      WAIT1_CS:   out_vector = 6'b00_0_10_0;
      TX:         out_vector = 6'b10_0_01_0;
      WAIT2:      out_vector = 6'b00_0_10_0;
      RX:         out_vector = 6'b00_1_01_0;
      WAIT3_CS:   out_vector = 6'b00_0_10_1;
    endcase
   end
  
endmodule: spi_fsm


module spi (
  input  wire        reset_i,
  input  wire        clock_i,
  input  wire        start_i,
  input  wire [7:0]  tx_buffer_i,
  input  wire        MISO_i,

  output wire        MOSI_o,
  output wire        CS_o,
  output wire        SCLK_o,
  output wire [23:0] rx_buffer_o,
  output wire        done_o
);

  // FSM control and status
  wire tx_en, tx_load, rx_en, delay_en, delay_clear;
  wire delay_done, tx_done, rx_done;

  // FSM
  spi_fsm fsm (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .start_i(start_i),
    .delay_done_i(delay_done),
    .tx_done_i(tx_done),
    .rx_done_i(rx_done),
    .tx_en_o(tx_en),
    .tx_load_o(tx_load),
    .rx_en_o(rx_en),
    .delay_en_o(delay_en),
    .delay_clear_o(delay_clear),
    .done_o(done_o)
  );

  // SPI Clock Generation
  spi_clk_gen #(.EXP_FACTOR(6)) clkgen (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .tx_en_i(tx_en),
    .rx_en_i(rx_en),
    .SCLK_o(SCLK_o),
    .en_i(tx_en | rx_en)
  );

  // SPI TX
  spi_tx #(.WIDTH(8)) tx_unit (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .tx_en_i(tx_en),
    .tx_load_i(tx_load),
    .SCLK_i(SCLK_o),
    .tx_buffer_i(tx_buffer_i),
    .MOSI_o(MOSI_o),
    .tx_done_o(tx_done)
  );

  // SPI RX
  spi_rx #(.WIDTH(24)) rx_unit (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .rx_en_i(rx_en),
    .SCLK_i(SCLK_o),
    .MISO_i(MISO_i),
    .rx_data_o(rx_buffer_o),
    .rx_done_o(rx_done)
  );

  // Delay Timer
  spi_delay_timer #(.MAX_COUNT(200)) delay_timer (
    .clock_i(clock_i),
    .reset_i(reset_i | delay_clear),
    .delay_en_i(delay_en),
    .delay_done_o(delay_done)
  );

  // Chip Select (Active-low)
  assign CS_o = ~(tx_en | rx_en);

endmodule : spi