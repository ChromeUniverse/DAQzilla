`default_nettype none

module register_file_tb;

  localparam DEPTH = 16;
  localparam WIDTH = 8;

  logic clk, rst;
  logic [$clog2(DEPTH)-1:0] sel_in_i, sel_out_i;
  logic load_i, clear_i;
  logic [WIDTH-1:0] in_i;
  wire [WIDTH-1:0] out_o;
  wire [3*WIDTH-1:0] out_conversion_o;

  // DUT instantiation
  register_file #(
    .DEPTH(DEPTH),
    .WIDTH(WIDTH)
  ) dut (
    .clock_i(clk),
    .sel_in_i(sel_in_i),
    .sel_out_i(sel_out_i),
    .load_i(load_i),
    .clear_i(clear_i),
    .in_i(in_i),
    .out_o(out_o),
    .out_conversion_o(out_conversion_o)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  // Stimulus
  initial begin

    clear_i = 1;
    load_i = 0;
    in_i = '0;
    sel_in_i = '0;
    sel_out_i = '0;

    repeat (2) @(posedge clk);
    clear_i = 0;

    // Write pattern to all registers
    for (int i = 0; i < DEPTH; i++) begin
      @(posedge clk);
      sel_in_i = i;
      in_i = 8'hA0 + i;
      load_i = 1;
      @(posedge clk);
      load_i = 0;
    end

    // Read back each register
    for (int i = 0; i < DEPTH; i++) begin
      @(posedge clk);
      sel_out_i = i;
      @(posedge clk);
      $display("REG[%0d] = 0x%0h", i, out_o);
    end

    // Check conversion data output
    $display("Conversion data = %6h", out_conversion_o);

    // Trigger clear
    @(posedge clk);
    clear_i = 1;
    @(posedge clk);
    clear_i = 0;

    // Check cleared values
    for (int i = 0; i < DEPTH; i++) begin
      @(posedge clk);
      sel_out_i = i;
      @(posedge clk);
      $display("REG[%0d] after clear = 0x%0h", i, out_o);
    end

    $finish;
  end

endmodule
