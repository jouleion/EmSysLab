`timescale 1ns/1ps

module PWM_Motordriver_tb;

  reg clk;

  // Raw control inputs (no SPI)
  reg enable;
  reg dir;
  reg brake;
  reg [7:0] speed;

  wire PITCH_DIRA;
  wire PITCH_DIRB;
  wire PITCH_PWM_VAL;

  PWM_Motordriver dut (
    .clk(clk),
    .enable(enable),
    .dir(dir),
    .brake(brake),
    .speed(speed),

    .PITCH_DIRA(PITCH_DIRA),
    .PITCH_DIRB(PITCH_DIRB),
    .PITCH_PWM_VAL(PITCH_PWM_VAL)
  );

  // system clock (PWM domain)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Using raw inputs directly in this testbench; no SPI helper tasks needed.

  // ---------------- TEST ----------------
  initial begin
    $dumpfile("signals.vcd");
    $dumpvars(0, PWM_Motordriver_tb);

    // initialize raw inputs
    enable = 0;
    dir = 0;
    brake = 0;
    speed = 8'd0;

    #2000;

    // add a simple console monitor
    $display("time\tenable\tdir\tbrake\tspeed\tPWM\tDIRA\tDIRB");
    $monitor("%0t\t%b\t%b\t%b\t%0d\t%b\t%b\t%b", $time, enable, dir, brake, speed, PITCH_PWM_VAL, PITCH_DIRA, PITCH_DIRB);

    // 1) forward: low -> medium -> high
    enable = 1; dir = 0; brake = 0; speed = 8'd10; // forward, low
    #3000;
    speed = 8'd50; // forward, medium
    #3000;
    speed = 8'd90; // forward, high
    #3000;

    // 2) reverse at medium
    enable = 1; dir = 1; brake = 0; speed = 8'd60;
    #3000;

    // 3) brake while enabled (direction should be masked)
    enable = 1; dir = 0; brake = 1; speed = 8'd60;
    #2500;

    // 4) brake with opposite direction set (still braking)
    enable = 1; dir = 1; brake = 1; speed = 8'd60;
    #2500;

    // 5) release brake while enabled, change direction
    brake = 0; dir = 0; speed = 8'd40; // should run forward at 40%
    #3000;

    // 6) quick enable/disable toggles
    enable = 0; #1000;
    enable = 1; speed = 8'd30; #1000;
    enable = 0; #1000;

    // 7) final disable and idle
    enable = 0; dir = 0; brake = 0; speed = 8'd0;
    #4000;

    $finish;
  end

endmodule