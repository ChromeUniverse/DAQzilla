`default_nettype none

module spi_tb;

  // Clocking
  logic clk;
  always #5 clk = ~clk;  // 100 MHz

  // DUT I/O
  logic reset;
  logic [7:0] tx_buffer;
  logic [23:0] rx_buffer;
  logic miso;
  logic mosi, cs, sclk;

  logic start;
  logic done;

  logic start_o, delay_done_o, tx_done_o, rx_done_o;
  logic tx_en_i, tx_load_i, rx_en_i, delay_en_i, delay_clear_i;

  // DUT instance
  spi dut (
    .reset_i(reset),
    .clock_i(clk),
    .tx_buffer_i(tx_buffer),
    .rx_buffer_o(rx_buffer),
    .MISO_i(miso),
    .MOSI_o(mosi),
    .CS_o(cs),
    .SCLK_o(sclk),
    .start_i(start),
    .done_o(done),
    .start_o(start_o),
    .delay_done_o(delay_done_o),
    .tx_done_o(tx_done_o),
    .rx_done_o(rx_done_o),
    .tx_en_i(tx_en_i),
    .tx_load_i(tx_load_i),
    .rx_en_i(rx_en_i),
    .delay_en_i(delay_en_i),
    .delay_clear_i(delay_clear_i)
  );

  // Task to simulate MISO data input
  task automatic send_miso_data(input [23:0] data);
    for (int i = 23; i >= 0; i--) begin
      @(negedge sclk);
      miso = data[i];
    end
  endtask

  // Monitor logic
  initial begin
    $display("Time\tState\t\tCS\tSCLK\tMOSI\tMISO\tTX_EN\tRX_EN\tTX_DONE\tRX_DONE\tDELAY_DONE");
    $monitor("%4t\t%s\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b",
             $time,
             dut.fsm.state.name(),  // assumes `state` is visible and enum has `name()` method (SystemVerilog 2012+)
             cs, sclk, mosi, miso,
             tx_en_i, rx_en_i,
             tx_done_o, rx_done_o, delay_done_o
    );
  end

  // Main test stimulus
  initial begin
    // Initialize
    clk = 0;
    reset = 1;
    start = 0;
    miso = 0;
    tx_buffer = 8'hA5;

    #20;
    reset = 0;

    #20;
    $display("\nStarting SPI transaction...\n");
    start = 1;
    #10;
    start = 0;

    // Optionally simulate data from slave
    fork
      send_miso_data(24'hDECADE);
    join_none

    // Wait for transfer to complete
    wait(done);

    $display("\nTransaction complete at t=%0t", $time);
    $display("Received RX Buffer: %h", rx_buffer);
    $finish;
  end

endmodule
