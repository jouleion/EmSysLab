`timescale 1ns/1ps

module PWM_Motordriver_tb;

  reg clk;
  reg dir;
  reg enable;
  reg [6:0] speed_percentage;

  wire signalA;
  wire signalB;
  wire PWM_signal;

  PWM_Motordriver dut (
    .clk(clk),
    .dir(dir),
    .enable(enable),
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

  task write_inputs(input reg dir_val, input reg enable_val, input reg breaking_val, input reg [6:0] speed_val);
    begin
      dir = dir_val;
      enable = enable_val;
      breaking = breaking_val;
      speed_percentage = speed_val;
      #100; // wait for 100 ns
    end
  endtask

  task check_outputs(input reg expected_signalA, input reg expected_signalB, input reg expected_PWM);
    begin
      if (signalA !== expected_signalA) begin
        $display("FAIL: signalA is %b, expected %b", signalA, expected_signalA);
        $finish;
      end
      if (signalB !== expected_signalB) begin
        $display("FAIL: signalB is %b, expected %b", signalB, expected_signalB);
        $finish;
      end
      if (PWM_signal !== expected_PWM) begin
        $display("FAIL: PWM_signal is %b, expected %b", PWM_signal, expected_PWM);
        $finish;
      end
    end
  endtask

  initial begin
    // case 1, dir = 0, enable = 0, breaking = 0, speed = 0 (should have no PWM)
    write_inputs(0, 0, 0, 0);
    check_outputs(0, 0, 0);

    // case 2, dir = 0, enable = 0, breaking = 0, speed = 50   (should have no PWM)
    write_inputs(0, 0, 0, 50);
    check_outputs(0, 0, 0);
    // case 3, dir = 0, enable = 1, breaking = 0, speed = 50   (should have PWM with 10% duty cycle)
    write_inputs(0, 1, 0, 50);
    check_outputs(0, 0, 1);

    // case 4, dir = 1, enable = 1, breaking = 0, speed = 100  (should have PWM with 20% duty cycle)
    write_inputs(1, 1, 0, 100);
    check_outputs(1, 0, 1);

    // other direction
    // case 5, dir = 1, enable = 0, breaking = 0, speed = 50   (should have no PWM)
    write_inputs(1, 0, 0, 50);
    check_outputs(0, 1, 0);

    // case 6, dir = 1, enable = 1, breaking = 0, speed = 100  (should have PWM with 20% duty cycle)
    write_inputs(1, 1, 0, 100);
    check_outputs(1, 0, 1);

    // case 7, dir = 1, enable = 1, breaking = 1, speed = 100  (should have PWM, A and B should be 0)
    write_inputs(1, 1, 1, 100);
    check_outputs(0, 0, 1);

    $display("PASS");
    $finish;
  end

endmodule