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

  parameter SPEED_DIVITDER = 4;
  parameter CLK_FREQUENCY = 50_000_000;
  parameter PWM_FREQUENCY = 20_000;
  localparam PWM_PERIOD_COUNT = CLK_FREQUENCY / PWM_FREQUENCY;

  // ---------------- SPI SYNC ----------------
  reg spi_clk_meta = 0;
  reg spi_clk_sync = 0;
  reg spi_clk_prev = 0;

  wire spi_rising = (spi_clk_sync == 1 && spi_clk_prev == 0);

  always @(posedge clk) begin
    spi_clk_meta <= SPI_CLK;
    spi_clk_sync <= spi_clk_meta;
    spi_clk_prev <= spi_clk_sync;
  end

  // ---------------- SPI STATE ----------------
  reg [7:0] spi_shift = 0;
  reg [2:0] spi_bit_count = 0;

  reg [7:0] control_byte = 0;
  reg [7:0] speed_byte = 0;

  reg byte_select = 0;

  reg dir = 0;
  reg enable = 0;
  reg breaking = 0;
  reg [6:0] speed_percentage = 0;

  // ---------------- SPI DECODER (FIXED) ----------------
  always @(posedge clk) begin

    if (SPI_CS == 1'b1) begin
      spi_bit_count <= 0;
      byte_select <= 0;
    end
    else begin

      if (spi_rising) begin

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
  end

  // ---------------- PWM (UNCHANGED) ----------------
  reg [31:0] loop_count = 0;
  reg [31:0] duty_cycle_loop = 0;

  always @(posedge clk) begin
    loop_count <= loop_count + 1;

    if(loop_count > 0) begin
      PITCH_PWM_VAL <= 1;

      duty_cycle_loop <= (speed_percentage * PWM_PERIOD_COUNT) /
                         (100 * SPEED_DIVITDER);

      if(enable) begin
        if(breaking) begin
          PITCH_DIRA <= 0;
          PITCH_DIRB <= 0;
        end else begin
          if(dir) begin
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