`default_nettype none

typedef enum logic [2:0] { 
  TRANSACTION_NONE, RDATA, RDATAC, SDATAC, SELFCAL, RREG, WREG, ILLEGAL_TRANSACTION
} transaction_t;


function automatic transaction_t decode_transaction(logic [23:0] cmd);
  case (cmd[15:0])
    16'hFF_FF: begin
      case (cmd[23:16])
        8'hF0:    return SELFCAL;
        8'h01:    return RDATA;
        8'h03:    return RDATAC;
        8'h0F:    return SDATAC;
        default:  return ILLEGAL_TRANSACTION;
      endcase
    end

    default: begin
      // must ensure we're only writing or reading one byte at a time
      // (because i said so haha)
      if (cmd[15:8] != 8'h00)
        return ILLEGAL_TRANSACTION;

      case (cmd[23:20])
        4'h1:     return RREG;
        4'h5:     return WREG;
        default:  return ILLEGAL_TRANSACTION;
      endcase
    end 
  endcase

  return ILLEGAL_TRANSACTION;

endfunction

// TODO: Lots of repetitive code here, need to clean this up (later).
// Remember: D.R.Y.

module spi_transaction_layer_fsm (
  input wire clock_i, reset_i,

  // Datapath status
  input wire start_i, spi_done_i, DRDY_L_i, 
  input wire delay_t6_done_i,
  input wire [23:0] cmd_i,
  input logic post_conversion_delay_done_i,
  input logic delay_t10_done_i,

  // Datapath control
  output logic spi_start_o,
  output logic CS_L_o,
  output logic [7:0] tx_buffer_o,
  output logic delay_t6_en_o,
  output logic delay_t6_count_clear_o,

  output logic [1:0] read_reg_sel_i,
  output logic read_reg_load_i,

  output logic conversion_data_ready_o,

  output logic post_conversion_delay_en_o,
  output logic post_conversion_delay_clear_o,

  output logic delay_t10_en_o,
  output logic delay_t10_clear_o,

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
    RDATAC_POST_CONVERSION_DELAY,
    RDATAC_WAIT_DRDY_C,
    RDATAC_SPI_TRANSFER_4,

    // SELFCAL
    SELFCAL_SPI_TRANSFER,
    SELFCAL_WAIT_DRDY_LOW,

    // RREG
    RREG_SPI_TRANSFER_0,
    RREG_SPI_TRANSFER_1,
    RREG_WAIT_T6, 
    RREG_SPI_TRANSFER_2,

    // WREG
    WREG_SPI_TRANSFER_0,
    WREG_SPI_TRANSFER_1,
    WREG_SPI_TRANSFER_2,
    
    WAIT_T10,
    DONE,     
    ILLEGAL_STATE
  } state_t;

  state_t state, next_state;
  transaction_t decoded_transaction;
  logic [23:0] latched_command;

  always_ff @(posedge clock_i) begin
    if (reset_i)
      state <= IDLE;
    else
      state <= next_state;
  end

  // ------------------------------------------
  // next state generator
  // ------------------------------------------

  // TODO: add references for each state from SPI Command Definitions in datasheet

  always_comb begin: next_state_generator
    case (state)
      IDLE: begin
        decoded_transaction = TRANSACTION_NONE;

        if (~start_i)
          next_state = IDLE;
        else begin
          latched_command = cmd_i;
          decoded_transaction = decode_transaction(cmd_i);

          case (decoded_transaction)
            RDATA:    next_state = RDATA_WAIT_DRDY;
            RDATAC:   next_state = RDATAC_WAIT_DRDY;
            SELFCAL:  next_state = SELFCAL_SPI_TRANSFER;
            RREG:     next_state = RREG_SPI_TRANSFER_0;
            WREG:     next_state = WREG_SPI_TRANSFER_0;
            default:  next_state = IDLE;
          endcase
        end
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
        next_state = (spi_done_i) ? WAIT_T10 : RDATA_SPI_TRANSFER_3;

      // RDATAC/SDATAC
      RDATAC_WAIT_DRDY:
        next_state = (~DRDY_L_i) ? RDATAC_SPI_TRANSFER_0 : RDATAC_WAIT_DRDY;
      RDATAC_SPI_TRANSFER_0:
        next_state = (spi_done_i) ? RDATAC_WAIT_T6 : RDATAC_SPI_TRANSFER_0;
      RDATAC_WAIT_T6:
        next_state = (delay_t6_done_i) ? RDATAC_SPI_TRANSFER_1 : RDATAC_WAIT_T6;
      RDATAC_SPI_TRANSFER_1:
        next_state = (spi_done_i) ? RDATAC_SPI_TRANSFER_2 : RDATAC_SPI_TRANSFER_1;
      RDATAC_SPI_TRANSFER_2:
        next_state = (spi_done_i) ? RDATAC_SPI_TRANSFER_3 : RDATAC_SPI_TRANSFER_2;
      RDATAC_SPI_TRANSFER_3:
        next_state = (spi_done_i) ? RDATAC_POST_CONVERSION_DELAY : RDATAC_SPI_TRANSFER_3;
      RDATAC_POST_CONVERSION_DELAY: begin
        // next_state = (post_conversion_delay_done_i) ? RDATAC_WAIT_DRDY_C : RDATAC_POST_CONVERSION_DELAY;
        if (~post_conversion_delay_done_i) 
          next_state = RDATAC_POST_CONVERSION_DELAY;
        else begin
          decoded_transaction = decode_transaction(cmd_i);
          latched_command = cmd_i;
          // data not ready -- keep waiting
          if (DRDY_L_i) 
            next_state = RDATAC_WAIT_DRDY_C;
          // 
          // TODO: maybe require `start_i` to be asserted here as well?
          // 
          // data ready and stop command issued
          else if (decoded_transaction == SDATAC)
            next_state = RDATAC_SPI_TRANSFER_4;
          // data ready and no stop command issued
          else
            next_state = RDATAC_SPI_TRANSFER_1;
        end
      end
      RDATAC_WAIT_DRDY_C: begin
        decoded_transaction = decode_transaction(cmd_i);
        latched_command = cmd_i;
        // data not ready -- keep waiting
        if (DRDY_L_i) 
          next_state = RDATAC_WAIT_DRDY_C;
        // 
        // TODO: maybe require `start_i` to be asserted here as well?
        // 
        // data ready and stop command issued
        else if (decoded_transaction == SDATAC)
          next_state = RDATAC_SPI_TRANSFER_4;
        // data ready and no stop command issued
        else
          next_state = RDATAC_SPI_TRANSFER_1;
      end
      RDATAC_SPI_TRANSFER_4:
        next_state = (spi_done_i) ? WAIT_T10 : RDATAC_SPI_TRANSFER_4;


      // SELFCAL
      // "DRDY goes high at the beginning of the calibration. It goes low after the calibration
      // completes and settled data is ready. Do not send additional commands after issuing 
      // this command until DRDY goes low indicating that the calibration is complete."
      // 
      // NOTE: we *technically* don't need to assert CS_L for this to work.
      // We just need to wait until calibration is finished for completedness.
      
      SELFCAL_SPI_TRANSFER:
        next_state = (spi_done_i) ? WAIT_T10 : SELFCAL_SPI_TRANSFER;

      SELFCAL_WAIT_DRDY_LOW:
        next_state = (~DRDY_L_i) ? DONE : SELFCAL_WAIT_DRDY_LOW;

      // RREG
      RREG_SPI_TRANSFER_0:
        next_state = (spi_done_i) ? RREG_SPI_TRANSFER_1 : RREG_SPI_TRANSFER_0;
      RREG_SPI_TRANSFER_1:
        next_state = (spi_done_i) ? RREG_WAIT_T6 : RREG_SPI_TRANSFER_1;
      RREG_WAIT_T6:
        next_state = (delay_t6_done_i) ? RREG_SPI_TRANSFER_2 : RREG_WAIT_T6;
      RREG_SPI_TRANSFER_2:
        next_state = (spi_done_i) ? WAIT_T10 : RREG_SPI_TRANSFER_2;

      // WREG
      WREG_SPI_TRANSFER_0:
        next_state = (spi_done_i) ? WREG_SPI_TRANSFER_1 : WREG_SPI_TRANSFER_0;
      WREG_SPI_TRANSFER_1:
        next_state = (spi_done_i) ? WREG_SPI_TRANSFER_2 : WREG_SPI_TRANSFER_1;
      WREG_SPI_TRANSFER_2:
        next_state = (spi_done_i) ? WAIT_T10 : WREG_SPI_TRANSFER_2;

      WAIT_T10: begin
        // next_state = (delay_t10_done_i) ? DONE : WAIT_T10;
        if (~delay_t10_done_i)
          next_state = WAIT_T10;
        else if (decoded_transaction == SELFCAL) 
          next_state = SELFCAL_WAIT_DRDY_LOW;
        else 
          next_state = DONE;
      end

      DONE: begin
        decoded_transaction = TRANSACTION_NONE;
        latched_command = cmd_i;

        if (~start_i)
          next_state = IDLE;
        else           
          decoded_transaction = decode_transaction(cmd_i);

          case (decoded_transaction)
            RDATA:    next_state = RDATA_WAIT_DRDY;
            RDATAC:   next_state = RDATAC_WAIT_DRDY;
            SELFCAL:  next_state = SELFCAL_SPI_TRANSFER;
            RREG:     next_state = RREG_SPI_TRANSFER_0;
            WREG:     next_state = WREG_SPI_TRANSFER_0;
            default:  next_state = IDLE;
          endcase
      end

      default:
        next_state = ILLEGAL_STATE;
    endcase
  end

  // ------------------------------------------
  // output generator
  // ------------------------------------------

  logic [3:0] reg_address;
  logic [7:0] WREG_data;

  always_comb begin: output_generator
    spi_start_o = 1'b0;
    CS_L_o = 1'b1;
    tx_buffer_o = 8'h00;
    done_o = 1'b0;
    delay_t6_en_o = 1'b0;
    delay_t6_count_clear_o = 1'b0;
    
    read_reg_sel_i = 2'b00;
    read_reg_load_i = 1'b0;

    conversion_data_ready_o = 1'b0;
    post_conversion_delay_en_o = 1'b0;
    post_conversion_delay_clear_o = 1'b0;

    delay_t10_en_o = 1'b0;
    delay_t10_clear_o = 1'b0;

    case (state)

      IDLE: begin
        delay_t10_clear_o = 1'b1;
        if (start_i) begin
          case (decoded_transaction)
            SELFCAL: begin
              spi_start_o = 1'b1;
              tx_buffer_o = 8'hF0;
            end
            RREG: begin
              spi_start_o = 1'b1;
              reg_address = latched_command[19:16];
              tx_buffer_o = {4'h1, reg_address};
            end
            WREG: begin
              spi_start_o = 1'b1;
              reg_address = latched_command[19:16];
              tx_buffer_o = {4'h5, reg_address};
            end
            default: ;
          endcase
        end
      end

      RDATA_WAIT_DRDY: begin
        CS_L_o = 1'b0;
        if (~DRDY_L_i) begin
          spi_start_o = 1'b1;
          tx_buffer_o = 8'h01;
        end
      end

      RDATA_SPI_TRANSFER_0: begin
        CS_L_o = 1'b0;
        // tx_buffer_o = 8'h01;
        if (spi_done_i) delay_t6_count_clear_o = 1'b1;
      end
      
      // TODO: include timing reference for t6 from datasheet
      RDATA_WAIT_T6: begin
        CS_L_o = 1'b0;
        delay_t6_en_o = 1'b1;
        if (delay_t6_done_i) begin
          spi_start_o = 1'b1;
          tx_buffer_o = 8'h67;
        end
      end
      
      
      RDATA_SPI_TRANSFER_1: begin
        CS_L_o = 1'b0;        
        if (spi_done_i) begin
          // MSB stored in register 1
          read_reg_load_i = 1'b1;
          read_reg_sel_i = 2'b01;

          spi_start_o = 1'b1;
          tx_buffer_o = 8'h68;          
        end
      end

      RDATA_SPI_TRANSFER_2: begin
        CS_L_o = 1'b0;
        if (spi_done_i) begin
          // Mid-byte stored in register 2
          read_reg_load_i = 1'b1;
          read_reg_sel_i = 2'b10;

          spi_start_o = 1'b1;
          tx_buffer_o = 8'h69;          
        end
      end

      RDATA_SPI_TRANSFER_3: begin
        CS_L_o = 1'b0;
        if (spi_done_i) begin
          // LSB stored in register 3
          read_reg_load_i = 1'b1;
          read_reg_sel_i = 2'b11;
        end
      end
      
      // RDATAC/SDATAC

      RDATAC_WAIT_DRDY: begin
        CS_L_o = 1'b0;
        if (~DRDY_L_i) begin
          tx_buffer_o = 8'h03;
          spi_start_o = 1'b1;
        end
      end

      RDATAC_SPI_TRANSFER_0: begin
        CS_L_o = 1'b0;        
        if (spi_done_i) delay_t6_count_clear_o = 1'b1;
      end

      // TODO: include timing reference for t6 from datasheet
      RDATAC_WAIT_T6: begin
        CS_L_o = 1'b0;
        delay_t6_en_o = 1'b1;
        if (delay_t6_done_i) begin
          spi_start_o = 1'b1;
          tx_buffer_o = 8'h69;
        end
      end
      
      RDATAC_SPI_TRANSFER_1: begin
        CS_L_o = 1'b0;
        if (spi_done_i) begin
          // MSB stored in register 1
          read_reg_load_i = 1'b1;
          read_reg_sel_i = 2'b01;

          spi_start_o = 1'b1;
          tx_buffer_o = 8'h69;
        end
      end

      RDATAC_SPI_TRANSFER_2: begin
        CS_L_o = 1'b0;
        tx_buffer_o = 8'h69;
        if (spi_done_i) begin
          // Mid-byte stored in register 2
          read_reg_load_i = 1'b1;
          read_reg_sel_i = 2'b10;

          spi_start_o = 1'b1;
          tx_buffer_o = 8'h69;
        end
      end      

      RDATAC_SPI_TRANSFER_3: begin
        CS_L_o = 1'b0;
        
        // clear delay counter
        post_conversion_delay_clear_o = 1'b1;
        
        if (spi_done_i) begin
          // LSB stored in register 3
          read_reg_load_i = 1'b1;
          read_reg_sel_i = 2'b11;          
        end
      end

      RDATAC_POST_CONVERSION_DELAY: begin
        CS_L_o = 1'b0;
        post_conversion_delay_en_o = 1'b1;
        if (post_conversion_delay_done_i) begin
          conversion_data_ready_o = 1'b1;

          // edge case: DRDY_L doesn't go low immeadiately after conversion delay
          // had to do this janky ahh fix because i was too lazy to implement proper DRDL_Y logic 
          // in the BFM for the ADS1256 lmao. check FSM next state logic above for more details.
          // bro i swear this makes logical sense. trust. please.
          if (~DRDY_L_i) begin
            spi_start_o = 1'b1;
            if (decoded_transaction == SDATAC) begin
              tx_buffer_o = 8'h0F;
            end
          end
        end
      end

      RDATAC_WAIT_DRDY_C: begin
        CS_L_o = 1'b0;
        // data ready indicates an SPI transfer is about to start
        if (~DRDY_L_i) begin
          spi_start_o = 1'b1;
          if (decoded_transaction == SDATAC) begin
            tx_buffer_o = 8'h0F;
          end
        end
      end

      RDATAC_SPI_TRANSFER_4: begin
        CS_L_o = 1'b0;
        tx_buffer_o = 8'h0F;
      end
      
      // SELFCAL
      SELFCAL_SPI_TRANSFER: begin
        CS_L_o = 1'b0;
        tx_buffer_o = 8'hF0;
      end

      // deasserting CS_L here should be fine in theory.
      // the SPI transfer is effectively done, we're just waiting on DRDY to go low
      // so we can be absolutely sure that the calibration procedure is finished.
      SELFCAL_WAIT_DRDY_LOW: begin
        CS_L_o = 1'b1;
      end
      
      // RREG
      RREG_SPI_TRANSFER_0: begin
        CS_L_o = 1'b0;        
        if (spi_done_i) begin
          spi_start_o = 1'b1;
          tx_buffer_o = 8'h00;
        end
      end

      RREG_SPI_TRANSFER_1: begin
        CS_L_o = 1'b0;
        tx_buffer_o = 8'h00;
        if (spi_done_i) begin
          delay_t6_count_clear_o = 1'b1;
        end
      end

      RREG_WAIT_T6: begin
        CS_L_o = 1'b0;
        delay_t6_en_o = 1'b1;
        if (delay_t6_done_i) begin
          spi_start_o = 1'b1;
          tx_buffer_o = 8'h69;
        end
      end

      RREG_SPI_TRANSFER_2: begin
        CS_L_o = 1'b0;        

        // Data being read will be stored in register 0
        if (spi_done_i) begin
          read_reg_load_i = 1'b1;
          read_reg_sel_i = 2'b00;
        end
      end

      // WREG
      WREG_SPI_TRANSFER_0: begin
        CS_L_o = 1'b0;
        if (spi_done_i) begin
          spi_start_o = 1'b1;
          tx_buffer_o = 8'h00;
        end
      end

      WREG_SPI_TRANSFER_1: begin
        CS_L_o = 1'b0;
        if (spi_done_i) begin          
          spi_start_o = 1'b1;
          WREG_data = latched_command[7:0];
          tx_buffer_o = WREG_data;
        end
      end

      WREG_SPI_TRANSFER_2: begin
        CS_L_o = 1'b0;
      end

      // just asserts CS_L waits long enough to satisfy t10 timing constraint
      WAIT_T10: begin
        CS_L_o = 1'b0;
        delay_t10_en_o = 1'b1;
      end
      
      DONE: begin
        done_o = 1'b1;
        CS_L_o = 1'b1;
        delay_t10_clear_o = 1'b1;

        if (start_i) begin
          case (decoded_transaction)
            SELFCAL: begin
              spi_start_o = 1'b1;
              tx_buffer_o = 8'hF0;
            end
            RREG: begin
              spi_start_o = 1'b1;
              reg_address = latched_command[19:16];
              tx_buffer_o = {4'h1, reg_address};
            end
            WREG: begin
              spi_start_o = 1'b1;
              reg_address = latched_command[19:16];
              tx_buffer_o = {4'h5, reg_address};
            end
            default: ;
          endcase
        end
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
  input wire [23:0] cmd_i,
  output logic conversion_data_ready_o,

  // Read register signals
  output wire [1:0] read_reg_sel,
  output wire read_reg_load,

  // ADS1256 interrupts
  input wire DRDY_L_i,
  
  // SPI Master interface
  output wire spi_start_o,
  input wire spi_done_i,
  output wire CS_L_o,
  output wire [7:0] tx_buffer_o
);

  // FSM status
  logic delay_t6_done;
  logic post_conversion_delay_done;
  logic delay_t10_done;

  // FSM control
  logic delay_t6_count_en, delay_t6_count_clear, DRDY_L;
  logic post_conversion_delay_en, post_conversion_delay_clear;
  logic delay_t10_en, delay_t10_clear;

  spi_transaction_layer_fsm FSM (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .done_o(done_o),
    .start_i(start_i),
    .spi_done_i(spi_done_i),
    .DRDY_L_i(DRDY_L_i),
    .delay_t6_done_i(delay_t6_done),
    .delay_t6_en_o(delay_t6_count_en),
    .delay_t6_count_clear_o(delay_t6_count_clear),
    .cmd_i(cmd_i),
    .spi_start_o(spi_start_o),
    .CS_L_o(CS_L_o),
    .tx_buffer_o(tx_buffer_o),
    .read_reg_load_i(read_reg_load),
    .read_reg_sel_i(read_reg_sel),
    .conversion_data_ready_o(conversion_data_ready_o),
    .post_conversion_delay_done_i(post_conversion_delay_done),
    .post_conversion_delay_en_o(post_conversion_delay_en),
    .post_conversion_delay_clear_o(post_conversion_delay_clear),
    .delay_t10_done_i(delay_t10_done),
    .delay_t10_en_o(delay_t10_en),
    .delay_t10_clear_o(delay_t10_clear)
  );

  // t6: Delay from last SCLK edge for DIN to first SCLK rising edge for DOUT
  // t6 >= 6.51us

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

  // delay post-conversion for continuous conversions
  // NOTE: need at least 1.8us based empirical measurements

  logic [9:0] post_conversion_delay_count_out;
  Counter #(.WIDTH(10)) post_conversion_delay_counter (
    .clock(clock_i),
    .en(post_conversion_delay_en),
    .clear(post_conversion_delay_clear),
    .load(),
    .up(1'b1),
    .D(10'b0),
    .Q(post_conversion_delay_count_out)
  );
  assign post_conversion_delay_done = 
    (post_conversion_delay_count_out == 10'd200);

  // t10: CS low after final SCLK falling edge
  // t10 >= 1.04us

  logic [9:0] delay_t10_counter_out;
  Counter #(.WIDTH(10)) delay_t10_counter (
    .clock(clock_i),
    .en(delay_t10_en),
    .clear(delay_t10_clear),
    .load(),
    .up(1'b1),
    .D(10'b0),
    .Q(delay_t10_counter_out)
  );
  assign delay_t10_done = 
    (delay_t10_counter_out == 10'd110);
  
endmodule

