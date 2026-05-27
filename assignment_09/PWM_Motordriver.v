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
  reg [31:0] next_count;
  reg [31:0] next_duty;
  
  // Simple, readable PWM logic: counter, duty calc, direction and PWM output
  // compute next values in temporaries (avoids non-blocking race conditions)
  always @(posedge clk) begin
    // compute next counter value (wrap at PWM_PERIOD_COUNT)
    next_count = loop_count + 1;
    if (next_count >= PWM_PERIOD_COUNT)
      next_count = 0;

    // clamp speed and compute next duty threshold using current 'speed' input
    // avoid depending on speed_percentage non-blocking update
    if (speed > 100)
      next_duty = (7'd100 * PWM_PERIOD_COUNT) / (100 * SPEED_DIVIDER);
    else
      next_duty = (speed * PWM_PERIOD_COUNT) / (100 * SPEED_DIVIDER);

    // update direction outputs (based on current inputs)
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

    // update sequential state
    loop_count <= next_count;
    duty_cycle_loop <= next_duty;
    speed_percentage <= (speed > 8'd100) ? 7'd100 : speed[6:0];

    // PWM output uses next_count/next_duty so it's stable within this clock
    if (!enable || brake || (next_duty == 0))
      PITCH_PWM_VAL <= 0;
    else
      PITCH_PWM_VAL <= (next_count < next_duty) ? 1 : 0;
  end

endmodule