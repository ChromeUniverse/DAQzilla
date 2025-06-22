// `default_nettype none

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
  input wire start_i, tx_done_i, rx_done_i, 
              delay_1_done_i, delay_2_done_i, delay_3_done_i,
  input wire DRDY_L_i,

  // control signals (Moore FSM outputs)
  output wire tx_en_o, 
  output wire tx_load_o,
  output wire rx_en_o,
  output wire delay_1_en_o,
  output wire delay_1_clear_o,
  output wire delay_2_en_o,
  output wire delay_2_clear_o,
  output wire delay_3_en_o,
  output wire delay_3_clear_o,
  
  // external outputs
  output wire done_o,
  output wire CS_o
);  

  typedef enum logic [2:0] {
    IDLE, WAIT1_CS, TX, WAIT2, RX, WAIT3_CS, ILLEGAL_STATE
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
        case (mode_i)
          SPI_IDLE,
          SPI_RX_ONLY,
          SPI_TX_ONLY,
          SPI_TX_RX:
            // only initiate transactions on DRDY low
            // next_state = (start_i & ~DRDY_L_i) ? WAIT1_CS : IDLE;
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
            next_state = (delay_1_done_i) ? RX : WAIT1_CS;
          SPI_TX_ONLY,
          SPI_TX_RX:
            next_state = (delay_1_done_i) ? TX : WAIT1_CS;
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
            next_state = (delay_2_done_i) ? IDLE : WAIT2; 
          SPI_TX_RX:
            next_state = (delay_2_done_i) ? RX : WAIT2;
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
            next_state = (delay_3_done_i) ? IDLE : WAIT3_CS;
          default: 
            next_state = ILLEGAL_STATE;
        endcase
    endcase
  end

  // output generator
  logic [10:0] out_vector;
  assign {
    // TX
    tx_en_o, 
    tx_load_o, 
    // RX
    rx_en_o, 
    // delays
    delay_1_en_o, 
    delay_1_clear_o,
    delay_2_en_o, 
    delay_2_clear_o,
    delay_3_en_o, 
    delay_3_clear_o, 
    // done
    done_o,
    // "CS must stay low during the entire command sequence" (REF: p. 34)
    CS_o
  } = out_vector;

  always_comb begin
    case (state)
      IDLE:       out_vector = 11'b01_0_010101_0_0; 
      WAIT1_CS:   out_vector = 11'b00_0_100101_0_1;
      TX:         out_vector = 11'b10_0_010101_0_1;
      WAIT2:      out_vector = (mode_i == SPI_TX_ONLY) ? 11'b00_0_011001_1_1 : 11'b00_0_011001_0_1;
      RX:         out_vector = 11'b00_1_010101_0_1;
      WAIT3_CS:   out_vector = 11'b00_0_100110_1_1;
    endcase
   end
  
endmodule: spi_fsm


module spi (
  input  wire         reset_i,
  input  wire         clock_i,

  // control interface
  input  wire         start_i,
  input  wire         DRDY_L_i,
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
  wire tx_en, tx_load, rx_en, 
        delay_1_en, delay_1_clear,
        delay_2_en, delay_2_clear,
        delay_3_en, delay_3_clear;
  wire delay_1_done, delay_2_done, delay_3_done, tx_done, rx_done;

  // CS as driven by the FSM
  logic CS_o;

  // Must latch relevant values used by FSM-D during transaction 
  // on rising edge of start_i
  logic [7:0] tx_buffer_latched;
  spi_mode_t mode_latched;

  always @(posedge clock_i) begin
    if (reset_i) begin
      tx_buffer_latched = 8'b0;
      mode_latched = SPI_IDLE;
    end else if (start_i) begin
      tx_buffer_latched = tx_buffer_i;
      mode_latched = spi_mode_i;
    end

  end

  // FSM
  spi_fsm fsm (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .start_i(start_i),
    .delay_1_done_i(delay_1_done),
    .delay_2_done_i(delay_2_done),
    .delay_3_done_i(delay_3_done),
    .tx_done_i(tx_done),
    .rx_done_i(rx_done),
    .mode_i(mode_latched),
    .tx_en_o(tx_en),
    .tx_load_o(tx_load),
    .rx_en_o(rx_en),
    .delay_1_en_o(delay_1_en),
    .delay_1_clear_o(delay_1_clear),
    .delay_2_en_o(delay_2_en),
    .delay_2_clear_o(delay_2_clear),
    .delay_3_en_o(delay_3_en),
    .delay_3_clear_o(delay_3_clear),
    .done_o(done_o),
    .CS_o(CS_o),
    .DRDY_L_i(DRDY_L_i)
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
    .tx_buffer_i(tx_buffer_latched),
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

  // Delay Timers
  spi_delay_timer #(.MAX_COUNT(200)) delay_timer_1 (
    .clock_i(clock_i),
    .reset_i(reset_i | delay_1_clear),
    .delay_en_i(delay_1_en),
    .delay_done_o(delay_1_done)
  );

  spi_delay_timer #(.MAX_COUNT(700)) delay_timer_2 (
    .clock_i(clock_i),
    .reset_i(reset_i | delay_2_clear),
    .delay_en_i(delay_2_en),
    .delay_done_o(delay_2_done)
  );

  spi_delay_timer #(.MAX_COUNT(200)) delay_timer_3 (
    .clock_i(clock_i),
    .reset_i(reset_i | delay_3_clear),
    .delay_en_i(delay_3_en),
    .delay_done_o(delay_3_done)
  );

  // Chip Select asserted low
  assign CS_L_o = ~CS_o;


endmodule : spi