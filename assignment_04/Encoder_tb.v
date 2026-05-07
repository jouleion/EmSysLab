`include "Encoder.v" // Include YOUR entity.
`timescale 1ns / 1ps  // Time unit = period, precision
module Encoder_tb;
  reg FPGA_CLK1_50;
  reg [3:0] SW;
  wire [7:0] LED; // Changed from reg to wire

  integer i;
  integer j;

  Encoder dut (
      .FPGA_CLK1_50(FPGA_CLK1_50),
      .SW(SW),
      .LED(LED)
  );

  // Generate clock signal
  initial begin
    FPGA_CLK1_50 = 0;
    forever #1 FPGA_CLK1_50 = ~FPGA_CLK1_50;
  end

  // Testbench script
  initial begin
    $dumpfile("signals.vcd");  // Name of the signal dump file
    $dumpvars(0, Encoder_tb);  // Updated to reference Encoder_tb

    // Initialize inputs
    SW = 4'b0000;

    // Reset the system
    SW[3] = 1;
    #5;
    SW[3] = 0;
    #0;

    // Simulate CW rotation (Clockwise)
    for (j = 0; j < 5; j = j + 1) begin
      for (i = 0; i < 4; i = i + 1) begin
        case (i)
          0: {SW[0], SW[1]} = 2'b00;
          1: {SW[0], SW[1]} = 2'b10;
          2: {SW[0], SW[1]} = 2'b11;
          3: {SW[0], SW[1]} = 2'b01;
        endcase
        #10;
      end
    end

        // Initialize inputs
    SW = 4'b0000;

    // Reset the system
    SW[3] = 1;
    #10;
    SW[3] = 0;
    #0;


    for (j = 0; j < 5; j = j + 1) begin
        for (i = 0; i < 4; i = i + 1) begin
        case (i)
            0: {SW[0], SW[1]} = 2'b00;
            1: {SW[0], SW[1]} = 2'b01;
            2: {SW[0], SW[1]} = 2'b11;
            3: {SW[0], SW[1]} = 2'b10;
        endcase
        #10;
        end
    end

    // Simulate CCW rotation (Counterclockwise)
    // for (j = 0; j < 5; j = j + 1) begin
    //   for (i = 0; i < 4; i = i + 1) begin
    //     case (i)
    //       0: {SW[0], SW[1]} = 2'b00;
    //       1: {SW[0], SW[1]} = 2'b01;
    //       2: {SW[0], SW[1]} = 2'b11;
    //       3: {SW[0], SW[1]} = 2'b10;
    //     endcase
    //     #10;
    //   end
    // end

    #500; // Allow time for simulation
    $finish;  // End simulation
  end
endmodule