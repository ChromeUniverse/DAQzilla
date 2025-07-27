`default_nettype none

module spi_rx_test;

  logic clock, reset, rx_en, SCLK, MISO;
  logic [7:0] rx_data;

  // DUT
  spi_rx #(.WIDTH(8)) dut (
    .clock_i   (clock),
    .reset_i   (reset),
    .rx_en_i   (rx_en),
    .SCLK_i    (SCLK),
    .MISO_i    (MISO),
    .rx_data_o (rx_data)
  );

  // Clock generation: 100 MHz
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  initial begin
    clock = 0;
    reset = 1;
    rx_en = 0;
    SCLK = 0;
    MISO = 0;

    #20 reset = 0;
    #10 rx_en = 1;

    // Transmit a test pattern: 0xAABBCC (MSB first, on falling edges)
    send_spi_byte(8'hAA);
    send_spi_byte(8'hBB);
    send_spi_byte(8'hCC);

    #100 $display("Received: %h", rx_data);
    #20 $finish;
  end

  task send_spi_byte(input [7:0] data);
    integer i;
    for (i = 7; i >= 0; i--) begin
      #40 SCLK = 1;
      #0 MISO = data[i];
      #40 SCLK = 0;
      #0; // wait between clocks
    end
    #80;
  endtask

endmodule : spi_rx_test
