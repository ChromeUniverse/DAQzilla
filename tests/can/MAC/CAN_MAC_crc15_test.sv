`default_nettype none

module can_crc15_test ();
  logic data, clock, clear;
  logic [14:0] CRC;

  // CRC scope: SOF, Arbitration, Control, Data
  logic SOF = 1'b0;
  
  logic [10:0] ID = 11'h123;
  logic RTR = 1'b0;
  logic [11:0] arb_field = {ID, RTR};

  logic [5:0] control_field = 6'b00_0100;
  logic [31:0] data_field = 32'hDEADBEEF;
  logic [50:0] crc_input_buffer = {SOF, arb_field, control_field, data_field};
  
  CRC_Unit dut (.BITVAL(data), .BITSTRB(clock), .CLEAR(clear), .CRC(CRC));

  initial begin
    forever #5 clock = ~clock;
    $monitor("%4t | Data: %1b | CRC: %15b", $time, data, CRC);
  end

  initial begin
    clock = 0;

    clear = 1;
    #10;
    clear = 0;

    for (int i = 0; i < 51; i++) begin
      @(negedge clock);
      data = crc_input_buffer[50 - i];
    end

    @(negedge clock);
    $finish;
  end

  
endmodule