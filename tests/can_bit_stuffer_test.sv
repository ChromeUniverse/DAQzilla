`default_nettype none

module can_bit_stuffer_test ();

  // DUT ports
  // logic [65:0] stuffable;
  // logic [16:0] unstuffable;
  // logic [82:0] payload;
  logic start;
  logic clock, reset;
  logic serial, done;

  logic [31:0] data = 32'hDEADBEEF;
  logic [10:0] msg_id = 11'h123;

  can_bit_stuffer dut(
    .data_i(data),
    .msg_id_i(msg_id),
    .start_i(start),
    .clock_i(clock),
    .reset_i(reset),
    .serial_o(serial),
    .done_o(done)
  );


  // ------------------------------------
  // Building CAN frame
  // ------------------------------------
  
  // logic SOF = 1'b0;
  // logic [10:0] ID = 11'h123;
  // logic RTR = 1'b0;
  // logic [11:0] arb_field = {ID, RTR};

  // logic [5:0] control_field = 6'b00_0100;
  // logic [31:0] data_field = 32'hDEADBEEF;
  // logic [14:0] crc = 51'h4e6b;              // pre-computed CRC-15 for data above

  // // total: 66 bits
  // assign stuffable = {SOF, arb_field, control_field, data_field, crc};

  // logic crc_d = 1'b1;
  // logic ack = 1'b0;
  // logic ack_d = 1'b1;
  // logic [6:0] eof = 7'b111_1111;
  // logic [6:0] ifs = 7'b111_1111;

  // // total: 17 bits
  // assign unstuffable = {crc_d, ack, ack_d, eof, ifs};

  // // complete CAN frame
  // assign payload = {stuffable, unstuffable};


  initial begin
    forever #5 clock = ~clock;
  end

  initial begin
    // ------------------------------------
    // Driving clocks + input ports
    // ------------------------------------

    clock = 0;
    start = 0;
    reset = 1;
    @(posedge clock);
    @(posedge clock);

    reset = 0;
    @(posedge clock);
    start = 1;
    @(posedge clock);
    start = 0;
    
    // for (int i = 0; i < 190000; i++) begin
    //   @(negedge clock);
    // end

    wait(done);

    @(negedge clock);
    
    $finish;
  end

  
endmodule