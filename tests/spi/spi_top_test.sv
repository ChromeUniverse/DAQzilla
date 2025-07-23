// `timescale 1ns/1ps
`default_nettype none

module spi_top_tb;

  // Clock and reset
  logic clock, reset;
  initial clock = 0;
  always #5 clock = ~clock;

  // ADS1256 interface
  logic MISO, DRDY_L;
  logic MOSI, SCLK, auto_CS, CS_L;

  // System controller interface
  logic routine_start, routine_done;
  routine_t routine;
  logic [23:0] data_out;
  logic continuous_stop;

  // Commands
  localparam CMD_NONE_BINARY = 24'h00_00_00;
  localparam CMD_WAKEUP   = 24'hFF_FF_FF;
  localparam CMD_RDATA    = 24'h01_FF_FF;
  localparam CMD_RDATAC   = 24'h03_FF_FF;
  localparam CMD_SDATAC   = 24'h0F_FF_FF;
  localparam CMD_SELFCAL  = 24'hF0_FF_FF;
  localparam CMD_RREG     = 24'h17_00_69;
  localparam CMD_WREG     = 24'h57_00_69;

  logic [23:0] conversion_data_out;

  // DUT instantiation
  spi_top dut (
    .clock_i(clock),
    .reset_i(reset),
    .routine_start_i(routine_start),
    .routine_done_o(routine_done),
    .routine_i(routine),
    .continuous_stop_i(continuous_stop),
    .data_o(data_out),
    .MISO_i(MISO),
    .DRDY_L_i(DRDY_L),
    .MOSI_o(MOSI),
    .SCLK_o(SCLK),
    .auto_CS_o(auto_CS),
    .CS_L_o(CS_L)
  );

  // 
  // A very simple behavioral model of an SPI slave (ADS1256)
  // 

  // TODO: DRDY_L controlled by number of bytes shifted out + delay
  // TODO: need logic for RREG and WREG commands
  // TODO: calibration is only complete once DRDY_L goes low again
  // "DRDY goes high at the beginning of the calibration. It goes low after the calibration
  // completes and settled data is ready. Do not send additional commands after issuing 
  // this command until DRDY goes low indicating that the calibration is complete."
  // 
  logic [7:0] MISO_data = 8'h00;
  logic [7:0] MOSI_data = 8'h00;
  logic [2:0] dout_bit_index = 4'd7;  // Start with MSB
  logic [2:0] din_bit_index = 4'd7;  // Start with MSB  
  
  transaction_t received_cmd = TRANSACTION_NONE;
  logic [1:0] RDATA_index = 2'd2;
  
  logic [23:0] conversion_data = 24'h12_34_56;

  // Set up data on posedge of SCLK (well before negedge, when 
  // it's actually shifted into the SPI Master)
  always @(posedge SCLK) begin
    if (~CS_L) begin                    // Only shift when chip is selected
      case (received_cmd)

        // Determine which command was just received
        TRANSACTION_NONE: begin
          casez (MOSI_data)
            8'hF0:
              received_cmd <= SELFCAL;
            8'h01: begin
              received_cmd <= RDATA;
              RDATA_index = 2'd2;
            end
            8'h03: begin
              received_cmd <= RDATAC;
              RDATA_index = 2'd2;
            end
            8'h0F:        received_cmd <= SDATAC;
            8'b0001_????: received_cmd <= RREG;
            8'b0101_????: received_cmd <= WREG;
            default: ;
          endcase
        end

        // Single-shot conversion
        RDATA: begin
          // 1st SCLK rising edge
          if (din_bit_index == 4'd7) begin
            if (RDATA_index >= 0) begin
              RDATA_index = RDATA_index - 4'd1;
            end else begin
              RDATA_index = 4'd2;
              received_cmd <= TRANSACTION_NONE;
            end
          end

          MISO_data = conversion_data[8 * RDATA_index +: 8];
        end

        // Continuous conversions
        RDATAC: begin          
          // SDATAC issued: stop conversions
          // "The command must be issued after DRDY goes low and completed before DRDY goes high." (p.35)
          if (~DRDY_L & MOSI_data == 8'h0F & din_bit_index == 4'd7) begin
            RDATA_index = 4'd2;
            received_cmd <= TRANSACTION_NONE;
          end

          else begin
            // 1st SCLK rising edge
            if (din_bit_index == 4'd7) begin
              if (RDATA_index > 0) begin
                RDATA_index = RDATA_index - 4'd1;
              end else begin
                RDATA_index = 4'd2;
              end
            end

            MISO_data = conversion_data[8 * RDATA_index +: 8];
            
          end          
        end

        // TODO: RREG
        // TODO: WREG
        // TODO: SELFCAL

        default: ;
      endcase
      
      MISO <= MISO_data[dout_bit_index];   // shift out
      
      if (dout_bit_index > 0) 
        dout_bit_index <= dout_bit_index - 1;
      else
        dout_bit_index <= 3'd7;            // Restart or hold value
    end
  end  

  always @(negedge SCLK) begin
    if (~CS_L) begin
      MOSI_data[din_bit_index] <= MOSI;   // shift in

      if (din_bit_index > 0)
        din_bit_index <= din_bit_index - 1;
      else                
        din_bit_index <= 3'd7;
    end
  end

  // reset parameters when chip is de-selected
  always @(posedge CS_L) begin
    MISO_data = 8'h00;
    MOSI_data = 8'h00;
    received_cmd = TRANSACTION_NONE;
    dout_bit_index = 3'd7;
    din_bit_index = 3'd7;
    MISO = 1'bz;    
  end

  // Task to run one transaction
  // task run_transaction(logic [23:0] cmd);
  //   begin
  //     @(negedge clock);
  //     command = cmd;
  //     transaction_start = 1;
  //     @(negedge clock);
  //     transaction_start = 0;
      
  //     // Wait for FSM to finish
  //     wait (transaction_done);
  //     repeat (2) @(posedge clock);
  //   end
  // endtask

  logic [31:0] drdy_count;

  // DRDY pulse generator
  task pulse_DRDY();
    begin
      @(negedge clock);
      DRDY_L = 1; // data not ready
      #100;
      DRDY_L = 0; // data ready (active low)
    end
  endtask

  // --- Task to trigger one routine ---
  task run_routine(routine_t r, bit continuous_mode = 0);
    begin
      @(negedge clock);
      routine = r;
      routine_start = 1;

      @(negedge clock);
      routine_start = 0;

      drdy_count = 0;
      repeat (200) begin
        @(negedge clock);

        if (~DRDY_L && !CS_L) begin
          pulse_DRDY();
          drdy_count++;
        end

        // TODO: this is broken.
        // TODO: Reimplement this to assert continuous_stop after at least one full conversion.
        // if (continuous_mode && dut.System_Controller.FSM.state == 4'd6 /* CONTINUOUS_RDATAC */)
        //   continuous_stop = 1;

        if (continuous_mode) begin
          repeat (2000) @(posedge clock);
          repeat (2000) @(posedge clock);
          continuous_stop = 1;
          // repeat (2000) @(posedge clock);
        end

        wait(routine_done);
        $display("Routine %0d done after %0d DRDY pulses. Data = %0h", r, drdy_count, data_out);
        repeat (500) @(posedge clock);
        break;
      end

      routine = ROUTINE_NONE;
      continuous_stop = 0;
    end
  endtask  

  // Stimulus
  // initial begin
  //   // Initialize
  //   reset = 1;
  //   transaction_start = 0;
  //   MISO = 1'b0;
  //   DRDY_L = 1;
  //   @(negedge clock);
  //   reset = 0;

  //   // TODO: sweep thru multiple commands to test this thoroughly

  //   // RDATA

  //   $display("Starting RDATA transaction...");
  //   fork
  //     begin
  //       #1000 pulse_DRDY();
  //       #33333 pulse_DRDY();
  //       #33333 pulse_DRDY();
  //       #33333 pulse_DRDY();
  //     end
  //     begin
  //       run_transaction(CMD_RDATA);
  //     end
  //   join

  //   // RDATAC

  //   // $display("Starting RDATAC transaction...");
  //   // fork
  //   //   begin
  //   //     #1000 pulse_DRDY();
  //   //     #3000 pulse_DRDY();
  //   //     #3000 pulse_DRDY();
  //   //     #3000 pulse_DRDY();
  //   //     #3000 pulse_DRDY(); // needed for SDATAC condition
  //   //   end
  //   //   begin
  //   //     // mannually run RDATAC transation
  //   //     @(negedge clock);
  //   //     command = CMD_RDATAC;
  //   //     transaction_start = 1;
  //   //     @(negedge clock);
  //   //     transaction_start = 0;

  //   //     // Wait for 3 complete conversions

  //   //     wait (dut.handler.FSM.state == dut.handler.FSM.RDATAC_WAIT_DRDY_C);
  //   //     $display("1st conversion complete");
  //   //     repeat (2) @(posedge clock);
  //   //     wait (dut.handler.FSM.state == dut.handler.FSM.RDATAC_WAIT_DRDY_C);
  //   //     $display("2nd conversion complete");
  //   //     repeat (2) @(posedge clock);
  //   //     wait (dut.handler.FSM.state == dut.handler.FSM.RDATAC_WAIT_DRDY_C);
  //   //     $display("3rd conversion complete");

  //   //     repeat (2) @(posedge clock);

  //   //     // issue SDATAC command
  //   //     command = CMD_SDATAC;
  //   //     wait (transaction_done);

  //   //     repeat (100) @(posedge clock);
  //   //   end
  //   // join

  //   // SELFCAL

  //   // $display("Starting RREG transaction...");
  //   // fork
  //   //   run_transaction(CMD_SELFCAL);
  //   // join

  //   // RREG

  //   // $display("Starting RREG transaction...");
  //   // fork
  //   //   run_transaction(CMD_RREG);
  //   // join

  //   // WREG

  //   // $display("Starting WREG transaction...");
  //   // fork
  //   //   run_transaction(CMD_WREG);
  //   // join

  //   $display("Test complete.");
  //   $finish;
  // end


  // --- Main test sequence ---
  initial begin
    reset = 1;
    routine_start = 0;
    DRDY_L = 1;
    MISO = 1'b0;
    continuous_stop = 0;
    MISO_data = 8'hAA;

    @(negedge clock);
    reset = 0;

    $display("Running CALIBRATE...");
    run_routine(ROUTINE_CALIBRATE);

    // $display("Running READBACK...");
    // run_routine(ROUTINE_READBACK);

    // $display("Running SINGLE...");
    // pulse_DRDY();
    // run_routine(ROUTINE_SINGLE);

    // $display("Running CONTINUOUS...");
    // repeat (3) pulse_DRDY();
    // run_routine(ROUTINE_CONTINUOUS, 1);

    // $display("Running ILLEGAL...");
    // run_routine(ROUTINE_ILLEGAL);

    $display("Test complete.");
    $finish;
  end

endmodule
