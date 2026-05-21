module PWM_Motordriver (
    input clk,

    // SPI inputs
    input SPI_CLK,
    input SPI_PICO,
    input SPI_CS,

    output reg PITCH_DIRA = 0,
    output reg PITCH_DIRB = 0,
    output reg PITCH_PWM_VAL = 0
);

  parameter SPEED_DIVITDER = 4; // limit to 25% duty cycle with divider of 4

  parameter CLK_FREQUENCY = 50_000_000; // 50 MHz
  parameter PWM_FREQUENCY = 20_000;  // 20 kHz
  localparam PWM_PERIOD_COUNT = CLK_FREQUENCY / PWM_FREQUENCY;

  // SPI Input handling (2 bytes: control and speed)
   // SPI Input handling (2 bytes: control and speed)
  reg [7:0] spi_shift = 0;
  reg [2:0] spi_bit_count = 0;

  reg [7:0] control_byte = 0;
  reg [7:0] speed_byte = 0;

  reg dir = 0;
  reg enable = 0;
  reg breaking = 0;

  // use 6 bits to set the speed percentage.
  reg [6:0] speed_percentage = 0;

  reg byte_select = 0; // 0 = control, 1 = speed

  always @(posedge SPI_CLK or negedge SPI_CS) begin

    if (!SPI_CS) begin
      spi_bit_count <= 0;
      byte_select <= 0;
      spi_shift <= 0;
    end else begin

      spi_shift <= {spi_shift[6:0], SPI_PICO};

      if (spi_bit_count == 3'd7) begin
        spi_bit_count <= 0;

        if (byte_select == 0) begin
          control_byte <= spi_shift;
          byte_select <= 1;
        end else begin
          speed_byte <= spi_shift;
          byte_select <= 0;

          enable   <= control_byte[7];
          dir      <= control_byte[6];
          breaking <= control_byte[5];

          speed_percentage <= speed_byte[6:0];
        end

      end else begin
        spi_bit_count <= spi_bit_count + 1;
      end

    end
  end
  
  reg [31:0] loop_count = 0;  // current loop count
  reg [31:0] duty_cycle_loop = 0; // loop cycle when PWM should be off

  always @(posedge clk) begin
    loop_count <= loop_count + 1;

    // start the PWM signal.
    // and set the A and B signals.
    if(loop_count > 0) begin
      // turn on
      PITCH_PWM_VAL <= 1;

      // calculate at which cycle the PWM signal should be turned off.
      duty_cycle_loop <= (speed_percentage * PWM_PERIOD_COUNT) / (100 * SPEED_DIVITDER);

      if(enable) begin
        // if enabled
        if(breaking) begin
          // if breaking, set A and B to 0, break to ground.
          PITCH_DIRA <= 0;
          PITCH_DIRB <= 0;
        end else begin
          // determine the state of A and B based on the direction.
          if(dir) begin
            PITCH_DIRA <= 1;
            PITCH_DIRB <= 0;
          end else begin
            PITCH_DIRA <= 0;
            PITCH_DIRB <= 1;
          end
        end
      end else begin
        // if not enabled, turn off the motor.
        PITCH_DIRA <= 0;
        PITCH_DIRB <= 0;
        PITCH_PWM_VAL <= 0;
      end    
    end 
    
    if (loop_count >= duty_cycle_loop) begin
      // turn off
      PITCH_PWM_VAL <= 0;
    end

    // reset when the PWM_PERIOD is reached.
    if (loop_count == PWM_PERIOD_COUNT) begin
      loop_count <= 0;
    end
  end

endmodule