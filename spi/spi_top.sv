`default_nettype none

module spi_top (
  input wire clock_i, reset_i,
  input wire DRDY_L_i,

  // Transaction handler
  input wire transaction_start_i,
  input transaction_t transaction_i,
  output wire transaction_done_o,

  // SPI interface
  input wire MISO_i,
  output wire MOSI_o, SCLK_o, auto_CS_o, CS_L_o
);

  // shared lines
  wire spi_start, spi_done;
  wire [7:0] spi_tx_buffer, spi_rx_buffer;

  // TODO: SPI master

  spi #(.WIDTH(8)) spi_master (
    .reset_i(reset_i),
    .clock_i(clock_i),

    // control interface
    .start_i(spi_start),
    .done_o(spi_done),
    .tx_buffer_i(spi_tx_buffer),
    .rx_buffer_o(spi_rx_buffer),

    // SPI protocol interface
    .MISO_i(MISO_i),
    .MOSI_o(MOSI_o),
    .SCLK_o(SCLK_o),
    .auto_CS_o(auto_CS_o)    // asserted only while a transfer is happening
  );

  // TODO: SPI transaction layer

  spi_transaction_layer handler (
  .clock_i(clock_i),
  .reset_i(reset_i),

  // Transaction control interface
  .start_i(transaction_start_i),
  .done_o(transaction_done_o),
  .transaction_i(transaction_i),
  .reg_addr_i(),

  // Register file control interface
  .register_file_sel_in_o(),
  .register_file_load_o(),

  // ADS1256 interrupts
  .DRDY_L_i(DRDY_L_i),
  
  // SPI Master interface
  .spi_start_o(spi_start),
  .spi_done_i(spi_done),
  .CS_L_o(CS_L_o),
  .tx_buffer_o(spi_tx_buffer)

  // TODO: ADS1256 system controller

  // TODO: register file

  // TODO: databus interconnect
);
  
endmodule