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

  logic [7:0] MISO_data = 8'hA5;
  logic [2:0] bit_index = 3'd7;  // Start with MSB

  // Set up data on posedge of SCLK (well before negedge, when 
  // it's actually shifted into the SPI Master)
  always @(posedge SCLK) begin
      if (~CS_L) begin            // Only shift when chip is selected
          MISO <= MISO_data[bit_index];
          if (bit_index > 0)
              bit_index <= bit_index - 1;
          else
              bit_index <= 3'd7;  // Restart or hold value
      end else begin
          bit_index <= 3'd7;      // Reset if chip deselected
          MISO <= 1'bz;           // Tri-state MISO when not selected
      end
  end

  always @(posedge dut.spi_master.done_o) begin
    MISO_data += 1;
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
        run_transaction(SELFCAL);
      end
    join

    // $display("Starting RDATAC transaction...");
    // fork
    //   begin
    //     #1000 pulse_DRDY();
    //     #3000 pulse_DRDY();
    //     #3000 pulse_DRDY();
    //     #3000 pulse_DRDY();
    //     #3000 pulse_DRDY(); // needed for SDATAC condition
    //   end
    //   begin
    //     run_transaction(RDATAC);
    //   end
    // join

    $display("Test complete.");
    $finish;
  end

endmodule
