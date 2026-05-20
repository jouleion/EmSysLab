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

  // task 1: set inputs
  task set_inputs;
    input r_dir;
    input r_enable;
    input [6:0] r_speed;
    begin
      dir = r_dir;
      enable = r_enable;
      speed_percentage = r_speed;
    end
  endtask

  // task 2: wait time
  task wait_time;
    input integer t;
    begin
      #t;
    end
  endtask

  // task 3: check direction only
  task check_dir;
    input expA;
    input expB;
    begin
      if (signalA !== expA || signalB !== expB) begin
        $display("FAIL: A=%b B=%b", signalA, signalB);
        $stop;
      end
    end
  endtask

  initial begin

    set_inputs(0, 0, 0);
    wait_time(20);

    set_inputs(0, 1, 20);
    wait_time(200);

    check_dir(0, 1);

    set_inputs(1, 1, 20);
    wait_time(200);

    check_dir(1, 0);

    set_inputs(1, 1, 80);
    wait_time(200);

    set_inputs(0, 0, 0);
    wait_time(200);

    check_dir(0, 0);

    $display("PASS");
    $finish;
  end

endmodule