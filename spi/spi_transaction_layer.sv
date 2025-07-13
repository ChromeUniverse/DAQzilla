`default_nettype none

typedef enum logic [2:0] { 
  WAKEUP, RDATA, RDATAC, SDATAC, SELFCAL, RREG, WREG
} transaction_t;


module spi_transaction_layer_fsm (
  input wire clock_i, reset_i,

  // Datapath status
  input wire start_i, spi_done_i, DRDY_L_i, 
  input wire delay_t6_done_i,
  input transaction_t transaction_i,

  // Datapath control
  output logic spi_start_o,
  output logic CS_L_o,
  output logic [7:0] tx_buffer_o,
  output logic delay_t6_en_o,
  output logic delay_t6_count_clear_o,

  output logic done_o
);

  typedef enum logic [6:0] { 
    IDLE, 
    
    // RDATA
    RDATA_WAIT_DRDY, 
    RDATA_SPI_TRANSFER_0,
    RDATA_WAIT_T6, 
    RDATA_SPI_TRANSFER_1,
    RDATA_SPI_TRANSFER_2,
    RDATA_SPI_TRANSFER_3,
    
    // RDATAC/SDATAC
    RDATAC_WAIT_DRDY, 
    RDATAC_SPI_TRANSFER_0,
    RDATAC_WAIT_T6, 
    RDATAC_SPI_TRANSFER_1,
    RDATAC_SPI_TRANSFER_2,
    RDATAC_SPI_TRANSFER_3,
    RDATAC_WAIT_DRDY_C,
    RDATAC_SPI_TRANSFER_4,

    // SELFCAL
    SELFCAL_SPI_TRANSFER,

    // RREG
    RREG_SPI_TRANSFER_0,
    RREG_SPI_TRANSFER_1,
    RREG_WAIT_T6, 
    RREG_SPI_TRANSFER_2,

    // WREG
    WREG_SPI_TRANSFER_0,
    WREG_SPI_TRANSFER_1,
    WREG_WAIT_T6, 
    WREG_SPI_TRANSFER_2,
    
    DONE,     
    ILLEGAL_STATE
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
      IDLE: begin
        if (~start_i)
          next_state = IDLE;
        else 
          case (transaction_i)
            RDATA:    next_state = RDATA_WAIT_DRDY;
            RDATAC:   next_state = RDATAC_WAIT_DRDY;
            SELFCAL:  next_state = SELFCAL_SPI_TRANSFER;
            RREG:     next_state = RREG_SPI_TRANSFER_0;
            WREG:     next_state = WREG_SPI_TRANSFER_0;
            default:  next_state = ILLEGAL_STATE;
          endcase
      end

      // RDATA
      RDATA_WAIT_DRDY:
        next_state = (~DRDY_L_i) ? RDATA_SPI_TRANSFER_0 : RDATA_WAIT_DRDY;
      RDATA_SPI_TRANSFER_0:
        next_state = (spi_done_i) ? RDATA_WAIT_T6 : RDATA_SPI_TRANSFER_0;
      RDATA_WAIT_T6:
        next_state = (delay_t6_done_i) ? RDATA_SPI_TRANSFER_1 : RDATA_WAIT_T6;
      RDATA_SPI_TRANSFER_1:
        next_state = (spi_done_i) ? RDATA_SPI_TRANSFER_2 : RDATA_SPI_TRANSFER_1;
      RDATA_SPI_TRANSFER_2:
        next_state = (spi_done_i) ? RDATA_SPI_TRANSFER_3 : RDATA_SPI_TRANSFER_2;
      RDATA_SPI_TRANSFER_3:
        next_state = (spi_done_i) ? DONE : RDATA_SPI_TRANSFER_3;

      // TODO: RDATAC/SDATAC
      // TODO: SELFCAL
      // TODO: RREG
      // TODO: WREG

      DONE: 
        next_state = IDLE;

      default:
        next_state = ILLEGAL_STATE;
    endcase
  end

  // output generator
  // TODO: add I/O for register file select lines

  // TODO: might need I/O to control loads into the register file.
  // TODO: would involved updating FSM with latching logic in between SPI Transfers.
  // TODO: a Hybrid Mealy/Moore FSM might do the trick! let's get creative

  always_comb begin
    spi_start_o = 1'b0;
    CS_L_o = 1'b0;
    tx_buffer_o = 8'h00;
    done_o = 1'b0;
    delay_t6_en_o = 1'b0;
    delay_t6_count_clear_o = 1'b0;

    case (state)
      RDATA_WAIT_DRDY:
        CS_L_o = 1'b0;

      RDATA_SPI_TRANSFER_0: begin
        CS_L_o = 1'b0;
        spi_start_o = 'b1;
        tx_buffer_o = 8'h01;

        // TODO: change delay_t6_count_clear_o to Mealy style 
        // if (spi_done) delay_t6_count_clear_o = 1'b1;
        delay_t6_count_clear_o = 1'b1;
        
      end
      
      // TODO: include timing reference for t6 from datasheet
      RDATA_WAIT_T6: begin
        CS_L_o = 1'b0;
        delay_t6_en_o = 1'b1;
      end
      
      
      RDATA_SPI_TRANSFER_1: begin
        CS_L_o = 1'b0;
        // TODO: change spi_start_o to Mealy style 
        spi_start_o = 1'b1;
        tx_buffer_o = 8'h01;
      end

      RDATA_SPI_TRANSFER_2: begin
        CS_L_o = 1'b0;
        // TODO: change spi_start_o to Mealy style 
        spi_start_o = 1'b1;
        tx_buffer_o = 8'h69;
      end

      RDATA_SPI_TRANSFER_3: begin
        CS_L_o = 1'b0;
        // TODO: change spi_start_o to Mealy style 
        spi_start_o = 1'b1;
        tx_buffer_o = 8'h69;
      end
      
      // TODO: RDATAC/SDATAC
      // TODO: SELFCAL
      // TODO: RREG
      // TODO: WREG
      
      DONE: begin
        done_o = 1'b1;
        CS_L_o = 1'b1;
      end
      
      default:
        ;
    endcase
  end
  
endmodule

module spi_transaction_layer (
  input wire clock_i, reset_i,

  // Transaction control interface
  input wire start_i,
  output wire done_o,
  input transaction_t transaction_i,
  input wire [3:0] reg_addr_i,        // used for RREG/WREG

  // Register file control interface
  output wire [2:0] register_file_sel_in_o,
  // TODO: might need I/O to control loads into the register file.
  // TODO: would involved updating FSM with latching logic in between SPI Transfers.
  // TODO: a Hybrid Mealy/Moore FSM might do the trick! let's get creative
  output wire register_file_load_o,

  // ADS1256 interrupts
  input wire DRDL_L_i,
  
  // SPI Master interface
  output wire spi_start_o,
  input wire spi_done_i,
  output wire CS_L_o,
  output wire [7:0] tx_buffer_o
);

  // FSM status
  wire delay_t6_done;

  // FSM control
  logic delay_t6_count_en, DRDL_L, delay_t6_count_clear;

  spi_transaction_layer_fsm FSM (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .done_o(done_o),
    .start_i(start_i),
    .spi_done_i(spi_done_i),
    .DRDY_L_i(DRDL_L_i),
    .delay_t6_done_i(delay_t6_done),
    .delay_t6_en_o(delay_t6_count_en),
    .delay_t6_count_clear_o(delay_t6_count_clear),
    .transaction_i(transaction_i),
    .spi_start_o(spi_start_o),
    .CS_L_o(CS_L_o),
    .tx_buffer_o(tx_buffer_o)
  );

  // TODO: delay for t6 constraint
  // t6 = 6.51us

  logic [9:0] delay_t6_count_out;
  Counter #(.WIDTH(10)) delay_t6_counter (
    .clock(clock_i),
    .en(delay_t6_count_en),
    .clear(delay_t6_count_clear),
    .load(),
    .up(1'b1),
    .D(10'b0),
    .Q(delay_t6_count_out)
  );
  assign delay_t6_done = (delay_t6_count_out == 10'd700);
  
endmodule