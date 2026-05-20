module PWM_Motordriver (
    input clk,
    input dir,
    input enable,
    input breaking,
    input [6:0]speed_percentage, 

    output reg signalA = 0,
    output reg signalB = 0,
    output reg PWM_signal = 0
);

  parameter CLK_FREQUENCY = 50_000_000; // 50 MHz
  parameter PWM_FREQUENCY = 20_000;  // 20 kHz
  parameter SPEED_DIVIDER = 5; // divide by 5 for 20% as the max speed.
  localparam PWM_PERIOD_COUNT = CLK_FREQUENCY / PWM_FREQUENCY;

  reg [31:0] loop_count = 0;  // current loop count
  reg [31:0] duty_cycle_loop = 0; // loop cycle when PWM should be off

  always @(posedge clk) begin
    loop_count <= loop_count + 1;

    // start the PWM signal.
    // and set the A and B signals.
    if(loop_count > 0) begin
      // turn on
      PWM_signal <= 1;

      // calculate at which cycle the PWM signal should be turned off.
      duty_cycle_loop <= (speed_percentage * PWM_PERIOD_COUNT) / (100 * SPEED_DIVIDER);

      if(enable) begin
        // if enabled
        if(breaking) begin
          // if breaking, set A and B to 0, break to ground.
          signalA <= 0;
          signalB <= 0;
        end else begin
          // determine the state of A and B based on the direction.
          if(dir) begin
            signalA <= 1;
            signalB <= 0;
          end else begin
            signalA <= 0;
            signalB <= 1;
          end
        end
      end else begin
        // if not enabled, turn off the motor.
        signalA <= 0;
        signalB <= 0;
        PWM_signal <= 0;
      end    
    end 
    
    if (loop_count >= duty_cycle_loop) begin
      // turn off
      PWM_signal <= 0;
    end

    // reset when the PWM_PERIOD is reached.
    if (loop_count == PWM_PERIOD_COUNT) begin
      loop_count <= 0;
    end
  end

endmodule