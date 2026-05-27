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

    // Test sequence — set raw inputs directly
    enable = 1; dir = 0; brake = 0; speed = 8'd20; // forward, 20%
    #5000;

    enable = 1; dir = 1; brake = 0; speed = 8'd80; // reverse, 80%
    #5000;

    enable = 1; dir = 1; brake = 1; speed = 8'd50; // brake applied
    #5000;

    enable = 0; dir = 0; brake = 0; speed = 8'd0;  // disable
    #20000;

    $finish;
  end

endmodule