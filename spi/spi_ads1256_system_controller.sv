typedef enum logic [2:0] {
  ROUTINE_NONE, 
  ROUTINE_CALIBRATE, 
  ROUTINE_READBACK, 
  ROUTINE_SINGLE, 
  ROUTINE_CONTINUOUS, 
  ROUTINE_ILLEGAL
} routine_t;

// list of commands
// TODO: fill these in with actual meaningful values. 
// TODO: refer to register map in datasheet and logic analyzer tests
localparam ADS1256_NONE_BINARY  = 24'h00_00_00;
localparam ADS1256_SELFCAL      = 24'h00_00_00;
localparam ADS1256_RDATA        = 24'h00_00_00;
localparam ADS1256_RDATAC       = 24'h00_00_00;
localparam ADS1256_SDATAC       = 24'h00_00_00;
localparam ADS1256_WREG_ADCON   = 24'h00_00_00;
localparam ADS1256_WREG_MUX     = 24'h00_00_00;
localparam ADS1256_WREG_DRATE   = 24'h00_00_00;
localparam ADS1256_RREG_ADCON   = 24'h00_00_00;
localparam ADS1256_RREG_MUX     = 24'h00_00_00;
localparam ADS1256_RREG_DRATE   = 24'h00_00_00;

module ADS1256_System_Controller_FSM (
  input logic clock_i, reset_i,

  // Status signals
  input logic start_i,
  input routine_t routine_i,
  input logic transaction_done_i,
  input logic continuous_stop_i,
  output logic transaction_start_o,

  // Control signals
  output logic [23:0] command_o,
  output logic done_o
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
        next_state = (transaction_done_i) ? IDLE : CALIBRATE_SELFCAL;

      SINGLE_RDATA:
        next_state = (transaction_done_i) ? IDLE : SINGLE_RDATA;

      CONTINUOUS_RDATAC:
        next_state = (continuous_stop_i) ? CONTINUOUS_SDATAC : CONTINUOUS_RDATAC;
      CONTINUOUS_SDATAC:
        next_state = (transaction_done_i) ? IDLE : CONTINUOUS_SDATAC;

      READBACK_GET_PGA:
        next_state = (transaction_done_i) ? READBACK_GET_MUX : READBACK_GET_PGA;
      READBACK_GET_MUX:
        next_state = (transaction_done_i) ? READBACK_GET_DRATE : READBACK_GET_MUX;
      READBACK_GET_DRATE:
        next_state = (transaction_done_i) ? IDLE : READBACK_GET_DRATE;      
      
      default: 
        next_state = ILLEGAL_STATE;
    endcase
  end

  always_comb begin : output_generator
    // WARNING: transaction_start_o is HIGH by default!!
    transaction_start_o = 1'b0;
    command_o = '0;
    done_o = 1'b0;

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
        if (transaction_done_i) done_o = 1'b1;

      SINGLE_RDATA:
        if (transaction_done_i) done_o = 1'b1;

      CONTINUOUS_RDATAC:
        if (continuous_stop_i) begin transaction_start_o = 1'b1; command_o = ADS1256_SDATAC; end
      CONTINUOUS_SDATAC:
        if (transaction_done_i) done_o = 1'b1;
      
      READBACK_GET_PGA:
        if (transaction_done_i) 
          begin transaction_start_o = 1'b1; command_o = ADS1256_RREG_MUX; end
      READBACK_GET_MUX:
        if (transaction_done_i) 
          begin transaction_start_o = 1'b1; command_o = ADS1256_RREG_DRATE; end
      READBACK_GET_DRATE:
        if (transaction_done_i) done_o = 1'b1;
      
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

  // Transaction layer interface
  input logic transaction_done_i,
  output logic transaction_start_o,
  output logic [23:0] command_o

  // TODO: AXI-Stream ports
);

  ADS1256_System_Controller_FSM FSM(
    .clock_i(clock_i),
    .reset_i(reset_i),

    // Status signals
    .routine_i(routine_i),
    .transaction_done_i(transaction_done_i),
    .continuous_stop_i(continuous_stop_i),
    .transaction_start_o(transaction_start_o),
    .start_i(start_i),

    // Control signals
    .command_o(command_o),
    .done_o(done_o)
);
  
endmodule