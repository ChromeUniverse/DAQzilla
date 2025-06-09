`default_nettype none

module spi_tx_tb;

  logic clk, rst;
  logic tx_en, tx_load, SCLK;
  logic [7:0] tx_data;
  logic MOSI;
  logic tx_done;

  spi_tx #(.WIDTH(8)) dut (
    .clock_i(clk),
    .reset_i(rst),
    .tx_en_i(tx_en),
    .tx_load_i(tx_load),
    .SCLK_i(SCLK),
    .tx_buffer_i(tx_data),
    .MOSI_o(MOSI),
    .tx_done_o(tx_done)
  );

  // clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // monitor
  initial begin
    $monitor("Time: %4t | MOSI: %b, TX_DONE: %b", $time, MOSI, tx_done);
  end

  initial begin
    rst = 1;
    tx_en = 0;
    tx_load = 0;
    SCLK = 0;
    tx_data = 8'hA5;

    #10;
    rst = 0;

    // Load data
    tx_load = 1;
    #10;
    tx_load = 0;

    // Enable TX
    tx_en = 1;

    // Simulate a few SLCK rising edges
    repeat (12) begin
      #80 SCLK = 1;
      #80 SCLK = 0;
    end

    #20;
    $finish;
  end

endmodule
