`include "TopEntity.v" // Include YOUR entity.
`timescale 1ns / 1ps  // Time unit = period, precision
module TopEntity_tb;
  reg clk;
  reg btn1;
  reg PITCH_DIRA;
  reg PITCH_DIRB;
  wire led1;
  wire led2;

  integer i;

  TopEntity dut (
      .clk(clk),
      .btn1(btn1),
      .PITCH_DIRA(PITCH_DIRA),
      .PITCH_DIRB(PITCH_DIRB),
      .led1(led1),
      .led2(led2)
  );

  // Generate clock signal
  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  // Testbench script
  initial begin
    $dumpfile("signals.vcd");  // Name of the signal dump file
    $dumpvars(0, TopEntity_tb);  // Signals to dump

    // Initialize inputs
    btn1 = 0;
    PITCH_DIRA = 0;
    PITCH_DIRB = 0;

    // Reset the system
    btn1 = 1;
    #5;
    btn1 = 0;

    // Simulate CCW rotation (Counterclockwise)
    for (i = 0; i < 4; i = i + 1) begin
      case (i)
        0: {PITCH_DIRA, PITCH_DIRB} = 2'b00;
        1: {PITCH_DIRA, PITCH_DIRB} = 2'b01;
        2: {PITCH_DIRA, PITCH_DIRB} = 2'b11;
        3: {PITCH_DIRA, PITCH_DIRB} = 2'b10;
      endcase
      #10;
    end

    // Simulate CW rotation (Clockwise)
    for (i = 0; i < 4; i = i + 1) begin
      case (i)
        0: {PITCH_DIRA, PITCH_DIRB} = 2'b00;
        1: {PITCH_DIRA, PITCH_DIRB} = 2'b10;
        2: {PITCH_DIRA, PITCH_DIRB} = 2'b11;
        3: {PITCH_DIRA, PITCH_DIRB} = 2'b01;
      endcase
      #10;
    end

    #500; // Allow time for simulation
    $finish;  // End simulation
  end
endmodule