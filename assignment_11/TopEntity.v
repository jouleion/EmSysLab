`include "PWM_motordriver.v"

module TopEntity(
    input  wire clk,

    input  wire SPI_CLK,
    input  wire SPI_PICO,
    input  wire SPI_CS,
    output reg  SPI_POCI,

    input  wire btn1,

    output wire led1,
    output wire led2,
    output wire led3,
    output wire PITCH_PWM_VAL,
    output wire PITCH_DIRA,
    output wire PITCH_DIRB
);

// register for incomming bytes
reg [7:0] byte_in;
// number of incommming bits
reg [2:0] bit_count;

// the command names 0x01 or 0x02.
localparam MOTOR1_COMMAND = 8'h01;
// mapping of the motor command:
// 0, 0, 0, 00000
// enable, dir, breaking, (dutycycle 0-32)

// the command names 0x01 or 0x02.
localparam MOTOR2_COMMAND = 8'h02;

localparam LED_COMMAND = 8'h03;

// store the current command state
reg [7:0] current_command;

// make a variable for the motor driver inputs.
reg [4:0] pwm_speed;
reg pwm_dir;
reg pwm_enable;
reg pwm_brake;

// make a variable for the led state.
reg led_latch = 1'b0;

// SPI sync
reg [2:0] spi_clk_sync;
reg [2:0] spi_cs_sync;
reg [2:0] spi_mosi_sync;

reg spi_clk_prev;

wire spi_clk_rise = (spi_clk_sync[2] && !spi_clk_prev);
wire spi_cs_active = ~spi_cs_sync[2];

// encoder placeholder (14-bit)
reg [13:0] encoder_value = 14'b11001100110011;

// MISO shift register
reg [15:0] miso_shift;

// have the main clk loop of the fpga clock.
always @(posedge clk) begin

    // sync SPI signals into clk domain
    spi_clk_sync  <= {spi_clk_sync[1:0], SPI_CLK};
    spi_cs_sync   <= {spi_cs_sync[1:0], SPI_CS};
    spi_mosi_sync <= {spi_mosi_sync[1:0], SPI_PICO};

    spi_clk_prev <= spi_clk_sync[2];

    if (!spi_cs_active) begin

        bit_count <= 0;
        current_command <= 8'h00;

        miso_shift <= {2'b00, encoder_value};
        SPI_POCI <= 1'b0;

    end else begin

        // MISO only driven when CS active (prevents SPI feedback issues)
        SPI_POCI <= miso_shift[15];

        if (spi_clk_rise) begin

            // shift in MOSI
            byte_in <= {byte_in[6:0], spi_mosi_sync[2]};
            bit_count <= bit_count + 1;

            // shift MISO
            miso_shift <= {miso_shift[14:0], 1'b0};

            // if we have received 8 bits, process the byte
            if (bit_count == 3'd7) begin

                if (current_command == 8'h00) begin
                    // no command yet, so store the incoming command
                    case (byte_in)
                        MOTOR1_COMMAND: current_command <= MOTOR1_COMMAND;
                        MOTOR2_COMMAND: current_command <= MOTOR2_COMMAND;
                        LED_COMMAND:    current_command <= LED_COMMAND;
                    endcase
                end else if (current_command == MOTOR1_COMMAND) begin
                    // process motor command using the bit mapping.
                    pwm_speed  <= byte_in[4:0];
                    pwm_dir    <= byte_in[5];
                    pwm_enable <= byte_in[6];
                    pwm_brake  <= byte_in[7];
                    current_command <= 8'h00;
                end else if (current_command == MOTOR2_COMMAND) begin
                    // second motor not implemented yet
                    current_command <= 8'h00;
                end else if (current_command == LED_COMMAND) begin
                    // process LED command
                    led_latch <= byte_in[0];
                    current_command <= 8'h00;
                end

            end
        end
    end
end

// connect LED output
assign led1 = led_latch;
assign led2 = led_latch;
assign led3 = led_latch;

// Instantiate PWM driver
PWM_motordriver pwm (
    .clk(clk),
    .rst_n(btn1),

    // input mapping
    .speed(pwm_speed),
    .dir(pwm_dir),
    .enable(pwm_enable),
    .brake(pwm_brake),

    // output mapping
    .pwm_out(PITCH_PWM_VAL),
    .dirA(PITCH_DIRA),
    .dirB(PITCH_DIRB)
);

// add other motor as well. 

// later well add the encoder IPs.

endmodule