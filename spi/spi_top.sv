// `default_nettype none

import spi_types_pkg::*;

module spi_top (
  input logic clock_i, reset_i,  

  // System controller interface
  input logic routine_start_i,
  output logic routine_done_o,
  input routine_t routine_i,
  input logic continuous_stop_i,

  // Conversion data
  output logic [23:0] data_o,

  // ADS1256 interface (SPI + interrupts)
  input logic MISO_i,
  input logic DRDY_L_i,
  output logic MOSI_o, SCLK_o, auto_CS_o, CS_L_o

  // TODO: AXI-Stream ports
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
  logic transaction_start, transaction_done;
  logic [23:0] command;
  logic conversion_ready;

  spi_transaction_layer handler (
    .clock_i(clock_i),
    .reset_i(reset_i),

    // Transaction control interface
    .start_i(transaction_start),
    .done_o(transaction_done),
    .cmd_i(command),
    .conversion_data_ready_o(conversion_ready),

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
    .conversion_data_o(data_o)
  );

  ADS1256_System_Controller System_Controller (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .start_i(routine_start_i),
    .done_o(routine_done_o),
    .routine_i(routine_i),
    .command_o(command),
    .transaction_start_o(transaction_start),
    .transaction_done_i(transaction_done),
    .continuous_stop_i(continuous_stop_i),
    .conversion_ready_i(conversion_ready)
  );
  
endmodule