// `timescale 1ns/1ps
`default_nettype none

module spi_top_tb;

  // Clock and reset
  logic clock, reset;
  initial clock = 0;
  always #5 clock = ~clock; // 100MHz clock

  // SPI interface
  logic MISO;
  logic MOSI, SCLK, auto_CS, CS_L;

  // Transaction interface
  logic transaction_start;
  transaction_t transaction;
  logic transaction_done;

  // DRDY_L from ADC
  logic DRDY_L;

  // DUT instantiation
  spi_top dut (
    .clock_i(clock),
    .reset_i(reset),
    .DRDY_L_i(DRDY_L),
    .transaction_start_i(transaction_start),
    .transaction_i(transaction),
    .transaction_done_o(transaction_done),
    .MISO_i(MISO),
    .MOSI_o(MOSI),
    .SCLK_o(SCLK),
    .auto_CS_o(auto_CS),
    .CS_L_o(CS_L)
  );

  // 
  // A very simple behavioral model of an SPI slave (ADS1256)
  // 

  // TODO: DRDY_L controlled by number of bytes shifted out + delay
  logic [7:0] MISO_data = 8'h00;
  logic [7:0] MOSI_data = 8'h00;
  logic [2:0] dout_bit_index = 4'd7;  // Start with MSB
  logic [2:0] din_bit_index = 4'd7;  // Start with MSB  
  transaction_t received_cmd = CMD_NONE;
  logic [1:0] RDATA_index = 2'd2;
  
  logic [23:0] conversion_data = 24'h12_34_56;

  // Set up data on posedge of SCLK (well before negedge, when 
  // it's actually shifted into the SPI Master)
  always @(posedge SCLK) begin
    if (~CS_L) begin                    // Only shift when chip is selected
      case (received_cmd)

        // Determine which command was just received
        CMD_NONE: begin
          case (MOSI_data)
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
          8'h0F:
            received_cmd <= SDATAC;
          8'h1?:
            received_cmd <= RREG;
          8'h5?:
            received_cmd <= WREG;          
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
              received_cmd <= CMD_NONE;
            end
          end

          MISO_data = conversion_data[8 * RDATA_index +: 8];
        end

        // Continuous conversions
        RDATAC: begin
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
    received_cmd = CMD_NONE;
    dout_bit_index = 3'd7;
    din_bit_index = 3'd7;
    MISO = 1'bz;    
  end

  // Task to run one transaction
  task run_transaction(transaction_t cmd);
    begin
      @(negedge clock);
      transaction = cmd;
      transaction_start = 1;
      @(negedge clock);
      transaction_start = 0;
      
      // Wait for FSM to finish
      wait (transaction_done);
      repeat (2) @(posedge clock);
    end
  endtask

  // DRDY pulse generator
  task pulse_DRDY();
    begin
      @(negedge clock);
      DRDY_L = 1; // data not ready
      #100;
      DRDY_L = 0; // data ready (active low)
    end
  endtask

  // Stimulus
  initial begin
    // Initialize
    reset = 1;
    transaction_start = 0;
    transaction = RDATAC;
    MISO = 1'b0;
    DRDY_L = 1;
    @(negedge clock);
    reset = 0;

    // TODO: handle SDATAC for RDATAC
    // TODO: sweep thru multiple commands to test this thoroughly

    $display("Starting RDATA transaction...");

    fork
      begin
        #1000 pulse_DRDY();
        #33333 pulse_DRDY();
        #33333 pulse_DRDY();
        #33333 pulse_DRDY();
      end
      begin
        run_transaction(RDATA);
      end
    join

    $display("Starting RDATAC transaction...");
    fork
      begin
        #1000 pulse_DRDY();
        #3000 pulse_DRDY();
        #3000 pulse_DRDY();
        #3000 pulse_DRDY();
        #3000 pulse_DRDY(); // needed for SDATAC condition
      end
      begin
        run_transaction(RDATAC);
      end
    join

    $display("Test complete.");
    $finish;
  end

endmodule
