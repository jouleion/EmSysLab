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
  // Set SPEED_DIVIDER=1 so `speed` (0..100) maps directly to percent.
  parameter SPEED_DIVIDER = 5; // keep max speed ~20% for safety
  parameter CLK_FREQUENCY = 50_000_000;
  parameter PWM_FREQUENCY = 20000;
  localparam PWM_PERIOD_COUNT = CLK_FREQUENCY / PWM_FREQUENCY;

  // ---------------- PWM ----------------
  // Internally we use a 7-bit percentage (0..100 expected). Clamp speed to 0..100.
  reg [6:0] speed_percentage = 0;

  reg [31:0] loop_count = 0;
  reg [31:0] duty_cycle_loop = 0;

  // Combinationally compute duty from the current speed input to avoid
  // sequential update races. duty_cycle is number of clock cycles PWM is high.
  wire [31:0] duty_cycle = (speed > 100) ?
                           ((7'd100 * PWM_PERIOD_COUNT) / (100 * SPEED_DIVIDER)) :
                           ((speed * PWM_PERIOD_COUNT) / (100 * SPEED_DIVIDER));
  
  // Simple, readable PWM logic: counter, duty calc, direction and PWM output
  // Sequential counter and outputs. Use combinational `duty_cycle` computed
  // from `speed` for the PWM comparison to avoid update-order problems.
  always @(posedge clk) begin
    // advance counter and wrap
    if (loop_count >= PWM_PERIOD_COUNT - 1)
      loop_count <= 0;
    else
      loop_count <= loop_count + 1;

    // keep last sampled speed percent for debugging/visibility
    speed_percentage <= (speed > 8'd100) ? 7'd100 : speed[6:0];

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

    // update registered copy of duty for visibility (optional)
    duty_cycle_loop <= duty_cycle;

    // PWM output: compare current loop counter with combinational duty
    if (!enable || brake || (duty_cycle == 0))
      PITCH_PWM_VAL <= 0;
    else
      PITCH_PWM_VAL <= (loop_count < duty_cycle) ? 1 : 0;
  end

endmodule