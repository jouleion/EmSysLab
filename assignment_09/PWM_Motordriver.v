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

  always @(posedge clk) begin
    loop_count <= loop_count + 1;

    // clamp incoming speed to 0..100
    speed_percentage <= (speed > 8'd100) ? 7'd100 : speed[6:0];

    if (loop_count > 0) begin
      PITCH_PWM_VAL <= 1;

      duty_cycle_loop <= (speed_percentage * PWM_PERIOD_COUNT) /
                         (100 * SPEED_DIVIDER);

      if (enable) begin
        if (brake) begin
          PITCH_DIRA <= 0;
          PITCH_DIRB <= 0;
        end else begin
          if (dir) begin
            PITCH_DIRA <= 1;
            PITCH_DIRB <= 0;
          end else begin
            PITCH_DIRA <= 0;
            PITCH_DIRB <= 1;
          end
        end
      end else begin
        PITCH_DIRA <= 0;
        PITCH_DIRB <= 0;
        PITCH_PWM_VAL <= 0;
      end
    end

    if (loop_count >= duty_cycle_loop)
      PITCH_PWM_VAL <= 0;

    if (loop_count == PWM_PERIOD_COUNT)
      loop_count <= 0;

  end
endmodule