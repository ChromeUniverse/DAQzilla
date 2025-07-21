module ADS1256_System_Controller_tb;

  // DUT inputs
  logic clock_i, reset_i;
  logic start_i, transaction_done_i, continuous_stop_i;
  routine_t routine_i;

  // DUT outputs
  logic transaction_start_o;
  logic done_o;
  logic [23:0] command_o;

  // DUT instance
  ADS1256_System_Controller dut (
    .clock_i(clock_i),
    .reset_i(reset_i),
    .start_i(start_i),
    .done_o(done_o),
    .routine_i(routine_i),
    .transaction_done_i(transaction_done_i),
    .continuous_stop_i(continuous_stop_i),
    .transaction_start_o(transaction_start_o),
    .command_o(command_o)
  );

  // Clock generation
  always #5 clock_i = ~clock_i;

  // Task to trigger a routine (Mealy-style: transaction_start_o depends on start_i)
  task run_routine(routine_t routine, bit continuous_mode = 0);
    begin
      @(negedge clock_i);
      routine_i = routine;
      start_i = 1'b1;

      // Wait 1 cycle to allow transaction_start_o to go high (same cycle as start_i)
      @(posedge clock_i);
      // if (transaction_start_o) begin
      //   @(negedge clock_i);
      //   transaction_done_i = 1'b1;
      //   @(posedge clock_i);
      //   transaction_done_i = 1'b0;
      // end
      start_i = 1'b0;

      // Continue FSM progression after initial transaction
      repeat (20) begin
        @(negedge clock_i);

        // Simulate ongoing transaction handshakes
        if (dut.FSM.state != 4'd0) begin
          @(negedge clock_i);
          transaction_done_i = 1'b1;
          @(posedge clock_i);
          transaction_done_i = 1'b0;
        end

        // Handle continuous_stop during continuous routine
        if (continuous_mode && dut.FSM.state == dut.FSM.CONTINUOUS_RDATAC) begin
          continuous_stop_i = 1'b1;
        end

        // Check for FSM completion
        if (done_o) begin
          @(negedge clock_i);
          $display("Routine %0d complete. Final command: %0h", routine, command_o);
          break;
        end
      end

      // Reset for next routine
      continuous_stop_i = 1'b0;
      routine_i = ROUTINE_NONE;
    end
  endtask


  initial begin
    // Initialize
    clock_i = 0;
    reset_i = 1;
    start_i = 0;
    routine_i = ROUTINE_NONE;
    transaction_done_i = 0;
    continuous_stop_i = 0;

    @(negedge clock_i);
    reset_i = 0;

    // Run all routines
    $display("Starting CALIBRATE routine...");
    run_routine(ROUTINE_CALIBRATE);

    $display("Starting READBACK routine...");
    run_routine(ROUTINE_READBACK);

    $display("Starting SINGLE routine...");
    run_routine(ROUTINE_SINGLE);

    $display("Starting CONTINUOUS routine...");
    run_routine(ROUTINE_CONTINUOUS, .continuous_mode(1));

    $display("Starting ILLEGAL routine...");
    run_routine(ROUTINE_ILLEGAL);

    $display("Testbench complete.");
    $finish;
  end

endmodule
