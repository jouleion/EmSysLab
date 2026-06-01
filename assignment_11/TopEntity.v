`include "PWM_motordriver.v"

module TopEntity(
    input  wire clk,

    input  wire SPI_CLK,
    input  wire SPI_PICO,
    input  wire SPI_CS,
    output reg  SPI_POCI,

    input  wire btn1,
    input  wire btn2,

    output wire led1,
    output wire led2,
    output wire led3,

    output wire PITCH_PWM_VAL,
    output wire PITCH_DIRA,
    output wire PITCH_DIRB,

    output wire PITCH_ENC_A,
    output wire PITCH_ENC_B,

    output wire YAW_PWM_VAL,
    output wire YAW_DIRA,
    output wire YAW_DIRB,

    output wire YAW_ENC_A,
    output wire YAW_ENC_B,

    output wire pmod1_8,
    output wire pmod1_9,
    output wire pmod1_10,

    output wire pmod2_8,
    output wire pmod2_9,
    output wire pmod2_10,

    output wire pmod3_4,
    output wire pmod3_9,
    output wire pmod3_10,

    output wire pmod4_1,
    output wire pmod4_2,
    output wire pmod4_3,
    output wire pmod4_4,
    output wire pmod4_7,
    output wire pmod4_8,
    output wire pmod4_9,
    output wire pmod4_10
);

// register for incomming bytes
reg [7:0] byte_in;
reg [2:0] bit_count;

// the command names 0x01 or 0x02.
localparam MOTOR1_COMMAND = 8'h01;
localparam MOTOR2_COMMAND = 8'h02;

// the command names 0x03
localparam LED_COMMAND = 8'h03;

// store the current command state
reg [7:0] current_command;

// make a variable for the motor driver inputs.
reg [4:0] pwm_speed;
reg pwm_dir;
reg pwm_enable;
reg pwm_brake;

// make a variable for the led state.
reg led_state = 1'b0;

// SPI sync
reg [2:0] spi_clk_sync;
reg [2:0] spi_cs_sync;
reg [2:0] spi_mosi_sync;

wire spi_clk_rise = (spi_clk_sync[2:1] == 2'b01);
wire spi_cs_active = ~spi_cs_sync[2];

// encoder placeholder (14-bit)
reg [13:0] encoder_value = 14'b00110011001100;

// MISO shift register
reg [15:0] miso_shift;

// LED mapping (LED1 may be unreliable pin / routing)
assign led1 = led_state;
assign led2 = led_state;
assign led3 = led_state;

// PMOD / unused outputs tied low (safe default)
assign pmod1_8  = 1'b0;
assign pmod1_9  = 1'b0;
assign pmod1_10 = 1'b0;

assign pmod2_8  = 1'b0;
assign pmod2_9  = 1'b0;
assign pmod2_10 = 1'b0;

assign pmod3_4  = 1'b0;
assign pmod3_9  = 1'b0;
assign pmod3_10 = 1'b0;

assign pmod4_1  = 1'b0;
assign pmod4_2  = 1'b0;
assign pmod4_3  = 1'b0;
assign pmod4_4  = 1'b0;
assign pmod4_7  = 1'b0;
assign pmod4_8  = 1'b0;
assign pmod4_9  = 1'b0;
assign pmod4_10 = 1'b0;

// have the main clk loop of the fpga clock.
always @(posedge clk) begin

    // sync SPI signals into clk domain
    spi_clk_sync  <= {spi_clk_sync[1:0], SPI_CLK};
    spi_cs_sync   <= {spi_cs_sync[1:0], SPI_CS};
    spi_mosi_sync <= {spi_mosi_sync[1:0], SPI_PICO};

    if (!spi_cs_active) begin

        bit_count <= 0;
        current_command <= 8'h00;

        miso_shift <= {2'b00, encoder_value};
        SPI_POCI <= 1'b0;

    end else begin

        SPI_POCI <= miso_shift[15];

        if (spi_clk_rise) begin

            byte_in <= {byte_in[6:0], spi_mosi_sync[2]};
            bit_count <= bit_count + 1;

            miso_shift <= {miso_shift[14:0], 1'b0};

            if (bit_count == 3'd7) begin

                if (current_command == 8'h00) begin
                    case ({byte_in[6:0], spi_mosi_sync[2]})
                        MOTOR1_COMMAND: current_command <= MOTOR1_COMMAND;
                        MOTOR2_COMMAND: current_command <= MOTOR2_COMMAND;
                        LED_COMMAND:    current_command <= LED_COMMAND;
                    endcase
                end else if (current_command == MOTOR1_COMMAND) begin
                    pwm_speed  <= byte_in[4:0];
                    pwm_dir    <= byte_in[5];
                    pwm_enable <= byte_in[6];
                    pwm_brake  <= byte_in[7];
                    current_command <= 8'h00;
                end else if (current_command == MOTOR2_COMMAND) begin
                    current_command <= 8'h00;
                end else if (current_command == LED_COMMAND) begin
                    led_state <= byte_in[0];
                    current_command <= 8'h00;
                end

            end

        end
    end
end

// Instantiate PWM driver
PWM_motordriver pwm (
    .clk(clk),
    .rst_n(btn1),

    .speed(pwm_speed),
    .dir(pwm_dir),
    .enable(pwm_enable),
    .brake(pwm_brake),

    .pwm_out(PITCH_PWM_VAL),
    .dirA(PITCH_DIRA),
    .dirB(PITCH_DIRB)
);

endmodule