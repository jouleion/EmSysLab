`timescale 1ns/1ps

module PWM_Motordriver_tb;

  reg clk;
  reg dir;
  reg enable;
  reg breaking;
  reg [6:0] speed_percentage;

  wire signalA;
  wire signalB;
  wire PWM_signal;

  PWM_Motordriver dut (
    .clk(clk),
    .dir(dir),
    .enable(enable),
    .breaking(breaking),
    .speed_percentage(speed_percentage),
    .signalA(signalA),
    .signalB(signalB),
    .PWM_signal(PWM_signal)
  );

  // clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // dump
  initial begin
    $dumpfile("signals.vcd");
    $dumpvars(0, PWM_Motordriver_tb);
  end

  task write_inputs(input dir_val, input enable_val, input breaking_val, input [6:0] speed_val);
    begin
      dir = dir_val;
      enable = enable_val;
      breaking = breaking_val;
      speed_percentage = speed_val;
    end
  endtask

  task check_outputs(input expected_signalA, input expected_signalB);
    begin
      if (signalA !== expected_signalA) begin
        $display("FAIL: signalA is %b, expected %b", signalA, expected_signalA);
        $finish;
      end
      if (signalB !== expected_signalB) begin
        $display("FAIL: signalB is %b, expected %b", signalB, expected_signalB);
        $finish;
      end
    end
  endtask

  initial begin

    // case 1, dir = 0, enable = 0, breaking = 0, speed = 0 (should have no PWM)
    write_inputs(0, 0, 0, 0);
    #200000;
    check_outputs(0, 0);

    // case 2, dir = 0, enable = 0, breaking = 0, speed = 50 (should have no PWM)
    write_inputs(0, 0, 0, 50);
    #200000;
    check_outputs(0, 0);

    // case 3, dir = 0, enable = 1, breaking = 0, speed = 50 (PWM visible)
    write_inputs(0, 1, 0, 50);
    #300000;

    // case 4, dir = 1, enable = 1, breaking = 0, speed = 100 (PWM visible)
    write_inputs(1, 1, 0, 100);
    #300000;
    check_outputs(1, 0);

    // other direction
    // case 5, dir = 1, enable = 0, breaking = 0, speed = 50 (should have no PWM)
    write_inputs(1, 0, 0, 50);
    #200000;
    check_outputs(0, 1);

    // case 6, dir = 1, enable = 1, breaking = 0, speed = 100 (PWM visible)
    write_inputs(1, 1, 0, 100);
    #300000;
    check_outputs(1, 0);

    // case 7, dir = 1, enable = 1, breaking = 1, speed = 100 (A and B should be 0)
    write_inputs(1, 1, 1, 100);
    #300000;
    check_outputs(0, 0);

    $display("PASS");
    $finish;
  end

endmodule