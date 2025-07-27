import spi_types_pkg::*;

// list of commands
// TODO: fill these in with actual meaningful values. 
// TODO: refer to register map in datasheet and logic analyzer tests
// localparam ADS1256_NONE_BINARY  = 24'h00_00_00;
localparam ADS1256_SELFCAL      = 24'hF0_FF_FF;
localparam ADS1256_RDATA        = 24'h01_FF_FF;
localparam ADS1256_RDATAC       = 24'h03_FF_FF;
localparam ADS1256_SDATAC       = 24'h0F_FF_FF;
localparam ADS1256_RREG_ADCON   = 24'h12_00_FF;
localparam ADS1256_RREG_MUX     = 24'h11_00_FF;
localparam ADS1256_RREG_DRATE   = 24'h13_00_FF;
localparam ADS1256_WREG_ADCON   = 24'h52_00_00; // CLKOUT off, Sensor detect off, PGA = 1
localparam ADS1256_WREG_MUX     = 24'h51_00_01; // AIN_P = AIN0, AIN_N = AIN1
// localparam ADS1256_WREG_DRATE   = 24'h53_00_82; // 100 SPS
localparam ADS1256_WREG_DRATE   = 24'h53_00_F0; // 30k SPS


module ADS1256_System_Controller_FSM (
  input logic clock_i, reset_i,

  // Status signals
  input logic start_i,
  input routine_t routine_i,
  input logic transaction_done_i,
  input logic continuous_stop_i,
  input logic conversion_ready_i,
  input logic wait_count_done_i,

  // Control signals
  output logic [23:0] command_o,
  output logic done_o,
  output logic transaction_start_o,
  output logic wait_count_en_o,
  output logic wait_count_clr_o
);

  typedef enum logic [3:0] {
    IDLE, 
    CALIBRATE_SET_PGA,
    CALIBRATE_SET_MUX,
    CALIBRATE_SET_DRATE,
    CALIBRATE_SELFCAL,
    SINGLE_RDATA,
    CONTINUOUS_RDATAC,    
    CONTINUOUS_SDATAC,
    READBACK_GET_PGA,
    READBACK_GET_MUX,
    READBACK_GET_DRATE,
    DONE,
    WAIT,
    ILLEGAL_STATE
  } state_t;

  state_t state, next_state;

  always_ff @(posedge clock_i) begin
    if (reset_i)
      state <= IDLE;
    else
      state <= next_state;
  end

  always_comb begin : next_state_generator
    case (state)
      IDLE: begin
        if (start_i)
          case (routine_i)
            ROUTINE_CALIBRATE:  next_state = CALIBRATE_SET_PGA;
            ROUTINE_SINGLE:     next_state = SINGLE_RDATA;
            ROUTINE_CONTINUOUS: next_state = CONTINUOUS_RDATAC;
            ROUTINE_READBACK:   next_state = READBACK_GET_PGA;
            default:            next_state = ILLEGAL_STATE;
          endcase
        else
          next_state = IDLE;
      end
      
      CALIBRATE_SET_PGA:
        next_state = (transaction_done_i) ? CALIBRATE_SET_MUX : CALIBRATE_SET_PGA;
      CALIBRATE_SET_MUX:
        next_state = (transaction_done_i) ? CALIBRATE_SET_DRATE : CALIBRATE_SET_MUX;
      CALIBRATE_SET_DRATE:
        next_state = (transaction_done_i) ? CALIBRATE_SELFCAL : CALIBRATE_SET_DRATE;
      CALIBRATE_SELFCAL:
        next_state = (transaction_done_i) ? WAIT : CALIBRATE_SELFCAL;

      SINGLE_RDATA:
        next_state = (transaction_done_i) ? WAIT : SINGLE_RDATA;

      CONTINUOUS_RDATAC:
        // NOTE: this logic results in SDATAC only being issued 1 conversion after 
        // continuous_stop_i is asserted. not ideal but like, just be aware of this
        // slightly funky behavior
        next_state = (continuous_stop_i & conversion_ready_i) ? CONTINUOUS_SDATAC : CONTINUOUS_RDATAC;
      CONTINUOUS_SDATAC:
        next_state = (transaction_done_i) ? WAIT : CONTINUOUS_SDATAC;

      READBACK_GET_PGA:
        next_state = (transaction_done_i) ? READBACK_GET_MUX : READBACK_GET_PGA;
      READBACK_GET_MUX:
        next_state = (transaction_done_i) ? READBACK_GET_DRATE : READBACK_GET_MUX;
      READBACK_GET_DRATE:
        next_state = (transaction_done_i) ? WAIT : READBACK_GET_DRATE;

      WAIT:
        next_state = (wait_count_done_i) ? DONE : WAIT;

      DONE: begin
        if (start_i)
          case (routine_i)
            ROUTINE_CALIBRATE:  next_state = CALIBRATE_SET_PGA;
            ROUTINE_SINGLE:     next_state = SINGLE_RDATA;
            ROUTINE_CONTINUOUS: next_state = CONTINUOUS_RDATAC;
            ROUTINE_READBACK:   next_state = READBACK_GET_PGA;
            default:            next_state = ILLEGAL_STATE;
          endcase
        else
          next_state = IDLE;
      end
      
      default: 
        next_state = ILLEGAL_STATE;
    endcase
  end

  always_comb begin : output_generator
    // WARNING: transaction_start_o is HIGH by default!!
    transaction_start_o = 1'b0;
    command_o = '0;
    done_o = 1'b0;
    wait_count_clr_o = 1'b1;  // clear by default
    wait_count_en_o = 1'b0;

    case (state)
      IDLE: begin
        if (start_i)
          case (routine_i)
            ROUTINE_CALIBRATE:  
              begin transaction_start_o = 1'b1; command_o = ADS1256_WREG_ADCON; end
            ROUTINE_SINGLE:     
              begin transaction_start_o = 1'b1; command_o = ADS1256_RDATA; end
            ROUTINE_CONTINUOUS: 
              begin transaction_start_o = 1'b1; command_o = ADS1256_RDATAC; end
            ROUTINE_READBACK:   
              begin transaction_start_o = 1'b1; command_o = ADS1256_RREG_ADCON; end
            default: ;
          endcase
      end

      CALIBRATE_SET_PGA:    
        if (transaction_done_i)
          begin transaction_start_o = 1'b1; command_o = ADS1256_WREG_MUX; end
      CALIBRATE_SET_MUX:    
        if (transaction_done_i)
          begin transaction_start_o = 1'b1; command_o = ADS1256_WREG_DRATE; end
      CALIBRATE_SET_DRATE:  
        if (transaction_done_i)
          begin transaction_start_o = 1'b1; command_o = ADS1256_SELFCAL; end
      CALIBRATE_SELFCAL:
        ;
        // if (transaction_done_i) done_o = 1'b1;

      SINGLE_RDATA:
        ;
        // if (transaction_done_i) done_o = 1'b1;

      CONTINUOUS_RDATAC:
        if (continuous_stop_i & conversion_ready_i) begin 
          transaction_start_o = 1'b1; command_o = ADS1256_SDATAC;
        end

      CONTINUOUS_SDATAC:
        command_o = ADS1256_SDATAC;
        // if (transaction_done_i) done_o = 1'b1;
      
      READBACK_GET_PGA:
        if (transaction_done_i) 
          begin transaction_start_o = 1'b1; command_o = ADS1256_RREG_MUX; end
      READBACK_GET_MUX:
        if (transaction_done_i) 
          begin transaction_start_o = 1'b1; command_o = ADS1256_RREG_DRATE; end
      READBACK_GET_DRATE:
        ;
        // if (transaction_done_i) done_o = 1'b1;

      WAIT: begin
        wait_count_clr_o = 1'b0;
        wait_count_en_o = 1'b1;
      end

      DONE: begin
        done_o = 1'b1;

        if (start_i)
          case (routine_i)
            ROUTINE_CALIBRATE:  
              begin transaction_start_o = 1'b1; command_o = ADS1256_WREG_ADCON; end
            ROUTINE_SINGLE:     
              begin transaction_start_o = 1'b1; command_o = ADS1256_RDATA; end
            ROUTINE_CONTINUOUS: 
              begin transaction_start_o = 1'b1; command_o = ADS1256_RDATAC; end
            ROUTINE_READBACK:   
              begin transaction_start_o = 1'b1; command_o = ADS1256_RREG_ADCON; end
            default: ;
          endcase
      end
      
      default: ;
    endcase
  end
  
endmodule


module ADS1256_System_Controller (
  input logic reset_i, clock_i,

  // System controller interface
  input logic start_i,
  output logic done_o,
  input routine_t routine_i,
  input logic continuous_stop_i,
  input logic conversion_ready_i,

  // Transaction layer interface
  input logic transaction_done_i,
  output logic transaction_start_o,
  output logic [23:0] command_o

  // TODO: AXI-Stream ports
);

  logic wait_count_done, wait_count_en, wait_count_clr;

  ADS1256_System_Controller_FSM FSM(
    .clock_i(clock_i),
    .reset_i(reset_i),

    // Status signals
    .routine_i(routine_i),
    .transaction_done_i(transaction_done_i),
    .continuous_stop_i(continuous_stop_i),
    .transaction_start_o(transaction_start_o),
    .start_i(start_i),
    .conversion_ready_i(conversion_ready_i),
    .wait_count_done_i(wait_count_done),

    // Control signals
    .command_o(command_o),
    .done_o(done_o),
    .wait_count_en_o(wait_count_en),
    .wait_count_clr_o(wait_count_clr)
  );

  // DEBUGGING: a counter that delays transmitting again for like a second or two idk
  logic [26:0] wait_counter_out;
  Counter #(.WIDTH(27)) wait_counter (
    .en(wait_count_en),
    .clear(wait_count_clr),
    .load(1'b0),
    .up(1'b1),
    .clock(clock_i),
    .D(27'd1),
    .Q(wait_counter_out)
  );

  // localparam logic [26:0] wait_counter_out_limit = 27'd2_000;
  localparam logic [26:0] wait_counter_out_limit = 27'd20_000_000; // .2 second @ 100 MHz

  assign wait_count_done = (wait_counter_out == wait_counter_out_limit);  
  
endmodule