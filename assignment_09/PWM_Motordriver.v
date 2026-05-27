// PWM_Motordriver
// Inputs:
//  - clk: system clock
//  - enable: master ON/OFF switch (when 0 all outputs are off)
//  - dir: direction (0 = forward, 1 = reverse)
//  - brake: when asserted while enabled, drive outputs to ground with PWM braking
//  - speed: desired speed percentage (0..100)
// Outputs:
//  - PITCH_DIRA / PITCH_DIRB: direction outputs (one-hot when running)
//  - PITCH_PWM_VAL: active-high PWM signal driving the motor (or braking)
// How it works:
//  Count clock cycles to form a PWM period. Convert `speed` into a duty
//  threshold (number of clock cycles PWM should be high). PWM is high while
//  the counter is below that threshold; the counter wraps each period.


module PWM_Motordriver (
  input clk,

  // Raw control inputs (replaces SPI interface)
  input enable,
  input dir,
  input brake,
  input [7:0] speed,

  output reg PITCH_DIRA = 0,
  output reg PITCH_DIRB = 0,
  output reg PITCH_PWM_VAL = 0
);

  // Default parameters for hardware: 20 kHz PWM at 50 MHz clock.
  // Use SPEED_DIVIDER=5 to cap maximum effective duty to ~20% for safety.
  parameter SPEED_DIVIDER = 5;
  parameter CLK_FREQUENCY = 50_000_000;
  parameter PWM_FREQUENCY = 20000;
  localparam PWM_PERIOD_COUNT = CLK_FREQUENCY / PWM_FREQUENCY;

  // ---------------- PWM ----------------
  // Internally we use a 7-bit percentage (0..100 expected). Clamp speed to 0..100.
  reg [6:0] speed_percentage = 0;

  reg [31:0] loop_count = 0;
  reg [31:0] duty_cycle_loop = 0;

  // Compute duty_cycle (number of clock cycles PWM is high) directly from
  // the current `speed` input. This keeps the PWM comparison independent of
  // register update ordering.
  wire [31:0] duty_cycle = (speed > 100) ?
                           ((7'd100 * PWM_PERIOD_COUNT) / (100 * SPEED_DIVIDER)) :
                           ((speed * PWM_PERIOD_COUNT) / (100 * SPEED_DIVIDER));
  
  // Main sequential block:
  // - advance the period counter
  // - sample `speed` for visibility
  // - set direction outputs or braking
  // - set PWM according to the combinational duty_cycle
  always @(posedge clk) begin
    // advance counter and wrap
    if (loop_count >= PWM_PERIOD_COUNT - 1)
      loop_count <= 0;
    else
      loop_count <= loop_count + 1;

    // store sampled speed for visibility in the waveform
    speed_percentage <= (speed > 8'd100) ? 7'd100 : speed[6:0];

    // store duty_cycle in a register so it's visible in the waveform
    duty_cycle_loop <= duty_cycle;

    // Master enable: when disabled everything is forced off
    if (!enable) begin
      PITCH_DIRA <= 0;
      PITCH_DIRB <= 0;
      PITCH_PWM_VAL <= 0;
    end else begin
      // when braking while enabled: force DIR outputs to 0 (break to ground)
      if (brake) begin
        PITCH_DIRA <= 0;
        PITCH_DIRB <= 0;
        PITCH_PWM_VAL <= (duty_cycle == 0) ? 0 : ((loop_count < duty_cycle) ? 1 : 0);
      end else begin
        // normal running: set direction and drive PWM
        if (dir) begin
          PITCH_DIRA <= 1;
          PITCH_DIRB <= 0;
        end else begin
          PITCH_DIRA <= 0;
          PITCH_DIRB <= 1;
        end
        PITCH_PWM_VAL <= (duty_cycle == 0) ? 0 : ((loop_count < duty_cycle) ? 1 : 0);
      end
    end
  end

endmodule