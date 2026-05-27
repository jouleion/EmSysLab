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

  parameter SPEED_DIVIDER = 4;
  parameter CLK_FREQUENCY = 50_000_000;
  parameter PWM_FREQUENCY = 20_000;
  localparam PWM_PERIOD_COUNT = CLK_FREQUENCY / PWM_FREQUENCY;

  // ---------------- PWM ----------------
  // Internally we use a 7-bit percentage (0..100 expected). Clamp speed to 0..100.
  reg [6:0] speed_percentage = 0;

  reg [31:0] loop_count = 0;
  reg [31:0] duty_cycle_loop = 0;
  
  // Simple, readable PWM logic: counter, duty calc, direction and PWM output
  always @(posedge clk) begin
    // advance counter and wrap
    if (loop_count == PWM_PERIOD_COUNT - 1)
      loop_count <= 0;
    else
      loop_count <= loop_count + 1;

    // clamp speed to 0..100 (store as 7-bit)
    speed_percentage <= (speed > 8'd100) ? 7'd100 : speed[6:0];

    // compute duty threshold (cycles motor is ON). keep SPEED_DIVIDER for now.
    duty_cycle_loop <= (speed_percentage * PWM_PERIOD_COUNT) / (100 * SPEED_DIVIDER);

    // direction / brake / enable handling (kept simple)
    if (!enable || brake) begin
      PITCH_DIRA <= 0;
      PITCH_DIRB <= 0;
    end else if (dir) begin
      PITCH_DIRA <= 1;
      PITCH_DIRB <= 0;
    end else begin
      PITCH_DIRA <= 0;
      PITCH_DIRB <= 1;
    end

    // PWM output: active-high while counter < duty
    if (!enable || brake || (duty_cycle_loop == 0))
      PITCH_PWM_VAL <= 0;
    else
      PITCH_PWM_VAL <= (loop_count < duty_cycle_loop) ? 1 : 0;
  end

endmodule