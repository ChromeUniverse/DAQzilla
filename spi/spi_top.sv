`default_nettype none

module spi_top (
  input logic clock_i, reset_i,
  input logic DRDY_L_i,

  // Transaction handler
  input logic transaction_start_i,
  input [23:0] cmd_i,
  output logic transaction_done_o,

  // Conversion data
  output logic [23:0] data_o,

  // SPI interface
  input logic MISO_i,
  output logic MOSI_o, SCLK_o, auto_CS_o, CS_L_o
);

  logic spi_start, spi_done;
  logic [7:0] spi_tx_buffer, spi_rx_buffer;

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

  logic [1:0] reg_read_sel;
  logic reg_read_load;

  spi_transaction_layer handler (
    .clock_i(clock_i),
    .reset_i(reset_i),

    // Transaction control interface
    .start_i(transaction_start_i),
    .done_o(transaction_done_o),
    .cmd_i(cmd_i),

    // Register file control interface
    .read_reg_sel(reg_read_sel),
    .read_reg_load(reg_read_load),

    // ADS1256 interrupts
    .DRDY_L_i(DRDY_L_i),
    
    // SPI Master interface
    .spi_start_o(spi_start),
    .spi_done_i(spi_done),
    .CS_L_o(CS_L_o),
    .tx_buffer_o(spi_tx_buffer)
  );

  logic [7:0] reg_file_RREG;
  logic [23:0] reg_file_conversion_data;

  register_file #(
    .REG_COUNT(4),
    .REG_WIDTH(8)
  ) reg_file (
    .clock_i(clock_i),
    .sel_in_i(reg_read_sel),
    .load_i(reg_read_load),
    .clear_i(reset_i),
    .in_i(spi_rx_buffer),
    .RREG_out_o(reg_file_RREG),
    .conversion_data_o(reg_file_conversion_data)
  );

  // TODO: ADS1256 system controller
  
endmodule