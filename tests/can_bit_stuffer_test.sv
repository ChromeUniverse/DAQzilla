`default_nettype none

module can_bit_stuffer_test ();

  // DUT ports
  logic [65:0] unstuffed;
  logic start;
  logic clock, reset;
  logic serial, done;

  can_bit_stuffer dut(
    .unstuffed_i(unstuffed),
    .start_i(start),
    .clock_i(clock),
    .reset_i(reset),
    .serial_o(serial),
    .done_o(done)
  );

  initial begin
    forever #5 clock = ~clock;
  end

  initial begin

    // ------------------------------------
    // CAN frame
    // ------------------------------------
    
    logic SOF = 1'b0;
    logic [10:0] ID = 11'h123;
    logic RTR = 1'b0;
    logic [11:0] arb_field = {ID, RTR};

    logic [5:0] control_field = 6'b00_0100;
    logic [31:0] data_field = 32'hDEADBEEF;
    logic [14:0] crc = 51'h4e6b;

    assign unstuffed = {SOF, arb_field, control_field, data_field, crc};

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
    
    for (int i = 0; i < 80; i++) begin
      @(negedge clock);
    end

    @(negedge clock);
    
    $finish;
  end

  
endmodule