`default_nettype none

module register_file #(
  parameter REG_COUNT = 4,
  parameter REG_WIDTH = 8
) (
  input wire clock_i,
  input wire [$clog2(REG_COUNT)-1:0] sel_in_i,
  input wire load_i,
  input wire clear_i,
  input wire [REG_WIDTH-1:0] in_i,
  output wire [REG_WIDTH-1:0] RREG_out_o,
  output wire [3*(REG_WIDTH)-1:0] conversion_data_o
);
  
  logic [REG_COUNT-1:0] decoder_out;
  
  Decoder #(.WIDTH(REG_COUNT)) load_selector (
    .en(load_i),
    .I(sel_in_i),
    .D(decoder_out)
  );

  logic [REG_COUNT-1:0][REG_WIDTH-1:0] reg_data_out_array;
  
  genvar i;

  generate
    for (i = 0; i < REG_COUNT; i = i+1) begin : registers
      Register #(.WIDTH(REG_WIDTH)) register (
        .clock(clock_i),
        .clear(clear_i),
        .en(decoder_out[i]),
        .D(in_i),
        .Q(reg_data_out_array[i])
      );
    end
  endgenerate

  // hardcoded: first register is the output data from RREG command

  assign RREG_out_o = reg_data_out_array[0];
  
  // hardcoded: last 3 registers are reserved for 24-bit conversion data from ADC
  // format: MSB
  assign conversion_data_o = {
    reg_data_out_array[REG_COUNT-3],
    reg_data_out_array[REG_COUNT-2],
    reg_data_out_array[REG_COUNT-1]
  };
  
endmodule