// PWM_Motordriver
// Inputs:
//  - clk: system clock
//  - enable: master ON/OFF switch (when 0 all outputs are off)
//  - dir: direction (0 = forward, 1 = reverse)
//  - brake: when asserted while enabled, drive outputs to ground with PWM braking
//  - speed: desired speed percentage (0..100)
// Outputs:
//  - dirA / dirB: direction outputs (one-hot when running)
//  - pwm_out: active-high PWM signal driving the motor (or braking)
// How it works:
//  Count clock cycles to form a PWM period. Convert `speed` into a duty
//  threshold (number of clock cycles PWM should be high). PWM is high while
//  the counter is below that threshold; the counter wraps each period.


module PWM_motordriver (
  input clk,
  input rst_n,

  // Raw control inputs (replaces SPI interface)
  input enable,
  input dir,
  input brake,
  input [5:0] speed,

  output reg dirA,
  output reg dirB,
  output reg pwm_out
);

  // Default parameters for hardware: 20 kHz PWM.
  // Choose a default CLK_FREQUENCY that matches the board oscillator
  // (e.g. 12 MHz on many iCE40 boards). Override at instantiation if
  // your platform uses a different system clock.
  parameter CLK_FREQUENCY = 12000000;
  parameter PWM_FREQUENCY = 20000;

  // Period in clock cycles and bit widths sized to the actual period so
  // we avoid unnecessarily wide arithmetic that creates long carry chains.
  localparam integer PWM_PERIOD_COUNT = CLK_FREQUENCY / PWM_FREQUENCY;
  localparam integer PWM_CNT_WIDTH = ($clog2(PWM_PERIOD_COUNT + 1) > 0) ? $clog2(PWM_PERIOD_COUNT + 1) : 1;



  // counters sized to the actual PWM period
  reg [PWM_CNT_WIDTH-1:0] loop_count = 0;
  reg [PWM_CNT_WIDTH-1:0] duty_cycle_loop = 0;

  // Make the duty cyle from the 5 incomming bits (0 - 31% = dutycycle of 0% - 100%)
  wire [PWM_CNT_WIDTH-1:0] duty_cycle_calc = ( speed * PWM_PERIOD_COUNT ) / 100;

  // make sure pwn has no output for duty = 0.
  wire pwm_out_calc = (duty_cycle_loop == 0) ? 0 : ((loop_count < duty_cycle_loop) ? 1 : 0);

  // Main sequential block:
  // - advance the period counter
  // - sample `speed` for visibility
  // - set direction outputs or braking
  // - set PWM according to the computed duty_cycle_loop
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      loop_count <= {PWM_CNT_WIDTH{1'b0}};
      duty_cycle_loop <= {PWM_CNT_WIDTH{1'b0}};
      speed <= 0;
      dirA <= 0;
      dirB <= 0;
      pwm_out <= 0;
    end else begin
      // advance counter and wrap
      if (loop_count >= PWM_PERIOD_COUNT - 1)
        loop_count <= {PWM_CNT_WIDTH{1'b0}};
      else
        loop_count <= loop_count + 1;

      // store sampled speed for waveform visibility
      speed_percentage <= (speed > 8'd100) ? 7'd100 : speed[6:0];

      // store duty_cycle in a register so the comparator uses registered value
      duty_cycle_loop <= duty_cycle_calc;

      // Master enable: when disabled everything is forced off
      if (!enable) begin
        dirA <= 0;
        dirB <= 0;
        pwm_out <= 0;
      end else begin
        // when braking while enabled: force DIR outputs to 0 (break to ground)
        if (brake) begin
          dirA <= 0;
          dirB <= 0;
          pwm_out <= (duty_cycle_loop == 0) ? 0 : ((loop_count < duty_cycle_loop) ? 1 : 0);
        end else begin
          // normal running: set direction and drive PWM
          if (dir) begin
            dirA <= 1;
            dirB <= 0;
          end else begin
            dirA <= 0;
            dirB <= 1;
          end
          pwm_out <= (duty_cycle_loop == 0) ? 0 : ((loop_count < duty_cycle_loop) ? 1 : 0);
        end
      end
    end
  end

  // pwm_out is driven directly as a reg in the sequential block
endmodule