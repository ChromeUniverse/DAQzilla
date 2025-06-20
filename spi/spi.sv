`default_nettype none

// NOTE: this is referring to transaction modes, 
// not actual SPI modes (permutations of CPOL and CPHA)
// as defined in the SPI spec.

typedef enum logic [1:0] { 
  SPI_IDLE,
  SPI_TX_ONLY,
  SPI_RX_ONLY,
  SPI_TX_RX
} spi_mode_t;

module spi_fsm (
  input wire clock_i, reset_i,

  // status signals (inform transitions)
  input spi_mode_t mode_i,
  input wire start_i, delay_done_i, tx_done_i, rx_done_i, 

  // control signals (Moore FSM outputs)
  output wire tx_en_o, 
  output wire tx_load_o,
  output wire rx_en_o,
  output wire delay_en_o,
  output wire delay_clear_o,
  
  // external outputs
  output wire done_o,
  output wire CS_o
);  

  typedef enum logic [2:0] {
    IDLE, WAIT1_CS, TX, WAIT2, RX, WAIT3_CS, ILLEGAL_STATE
  } state_t;

  state_t state, next_state;

  // TODO: implement latched transaction modes and buffer states
  // at the start of the transaction.
  spi_mode_t mode_latched;

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
        case (mode_i)
          SPI_IDLE: 
            next_state = IDLE;
          SPI_RX_ONLY,
          SPI_TX_ONLY,
          SPI_TX_RX:
            next_state = (start_i) ? WAIT1_CS : IDLE;
          default: 
            next_state = ILLEGAL_STATE;
        endcase

      // "t3: CS low to first SCLK: setup time"
      // 0ns < t3
      // [REF: Timing Characteristics, p. 6]
      WAIT1_CS:
        case (mode_i)
          SPI_IDLE: 
            next_state = ILLEGAL_STATE;
          SPI_RX_ONLY:
            next_state = (delay_done_i) ? RX : WAIT1_CS;
          SPI_TX_ONLY,
          SPI_TX_RX:
            next_state = (delay_done_i) ? TX : WAIT1_CS;
          default: 
            next_state = ILLEGAL_STATE;
        endcase

      TX:
        case (mode_i)
          SPI_IDLE,
          SPI_RX_ONLY:
            next_state = ILLEGAL_STATE;
          SPI_TX_ONLY,
          SPI_TX_RX:
            next_state = (tx_done_i) ? WAIT2 : TX;
          default: 
            next_state = ILLEGAL_STATE;
        endcase

      // "t6: Delay from last SCLK edge for DIN to first SCLK rising edge for DOUT"
      // 50 * T_clkin < t6 
      // [REF: Timing Characteristics, p. 6]
      WAIT2:
        case (mode_i)
          SPI_IDLE,
          SPI_RX_ONLY:
            next_state = ILLEGAL_STATE;
          SPI_TX_ONLY:
            next_state = (delay_done_i) ? IDLE : WAIT2; 
          SPI_TX_RX:
            next_state = (delay_done_i) ? RX : WAIT2;
          default: 
            next_state = ILLEGAL_STATE;
        endcase
      
      RX:
        case (mode_i)
          SPI_IDLE,
          SPI_TX_ONLY:
            next_state = ILLEGAL_STATE;
          SPI_RX_ONLY,
          SPI_TX_RX:
            next_state = (rx_done_i) ? WAIT3_CS : RX;
          default: 
            next_state = ILLEGAL_STATE;
        endcase
      
      WAIT3_CS:
        case (mode_i)
          SPI_IDLE,
          SPI_TX_ONLY:
            next_state = ILLEGAL_STATE;
          SPI_RX_ONLY,
          SPI_TX_RX:
            next_state = (delay_done_i) ? IDLE : WAIT3_CS;
          default: 
            next_state = ILLEGAL_STATE;
        endcase
    endcase
  end

  // output generator
  logic [6:0] out_vector;
  assign {
    tx_en_o, 
    tx_load_o, 
    rx_en_o, 
    delay_en_o, 
    delay_clear_o, 
    done_o,
    // "CS must stay low during the entire command sequence" (REF: p. 34)
    CS_o
  } = out_vector;

  always_comb begin
    case (state)
      IDLE:       out_vector = 7'b01_0_01_0_0; 
      WAIT1_CS:   out_vector = 7'b00_0_10_0_1;
      TX:         out_vector = 7'b10_0_01_0_1;
      WAIT2:      out_vector = (mode_i == SPI_TX_ONLY) ? 7'b00_0_10_1_1 : 7'b00_0_10_0_1;
      RX:         out_vector = 7'b00_1_01_0_1;
      WAIT3_CS:   out_vector = 7'b00_0_10_1_1;
    endcase
   end
  
endmodule: spi_fsm


module spi (
  input  wire         reset_i,
  input  wire         clock_i,

  // control interface
  input  wire         start_i,
  input  wire [7:0]   tx_buffer_i,
  input  spi_mode_t   spi_mode_i,
  output wire         done_o,
  output wire [23:0]  rx_buffer_o,

  // TODO: All transaction inputs MUST be held stable even after
  // `start_i` has been asserted.

  // protocol interface
  input  wire         MISO_i,
  output wire         MOSI_o,
  output wire         CS_L_o,
  output wire         SCLK_o
);

  // FSM control and status
  wire tx_en, tx_load, rx_en, delay_en, delay_clear;
  wire delay_done, tx_done, rx_done;

  // CS as driven by the FSM
  logic CS_o;

  // FSM
  spi_fsm fsm (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .start_i(start_i),
    .delay_done_i(delay_done),
    .tx_done_i(tx_done),
    .rx_done_i(rx_done),
    .mode_i(spi_mode_i),
    .tx_en_o(tx_en),
    .tx_load_o(tx_load),
    .rx_en_o(rx_en),
    .delay_en_o(delay_en),
    .delay_clear_o(delay_clear),
    .done_o(done_o),
    .CS_o(CS_o)
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

  // Chip Select asserted low
  assign CS_L_o = ~CS_o;


endmodule : spi