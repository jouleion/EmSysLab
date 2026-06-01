`timescale 1 ps / 1 ps
module esl_bus_demo #(
		parameter LED_WIDTH = 8,
        parameter DATA_WIDTH = 32
	) (
		input  wire [7:0]  slave_address,     //      avs_s0.address
		input  wire        slave_read,        //            .read
		output reg  [DATA_WIDTH-1:0] slave_readdata,    //            .readdata
		input  wire        slave_write,       //            .write
		input  wire [DATA_WIDTH-1:0] slave_writedata,   //            .writedata
		input  wire        clk,          //       clock.clk
		input  wire        reset,        //       reset.reset
      input  wire [(DATA_WIDTH/8)-1:0] slave_byteenable,
		output wire [LED_WIDTH-1:0]  user_output,         // user_output.new_signal
		input wire PITCH_ENC_A,
		input wire PITCH_ENC_B,
		input wire YAW_ENC_A,
		input wire YAW_ENC_B,
        input wire [3:0] SW,
        output wire [7:0] LED
	);

    // Internal memory for the system and a subset for the IP
    reg [31:0] mem;
    wire [LED_WIDTH-1:0] mem_masked;
    wire enable;
    wire [15:0] pitch_steps;
    wire [15:0] yaw_steps;

    Encoder encoder_inst (
        .FPGA_CLK1_50(clk),
        .PITCH_ENC_A(PITCH_ENC_A),
        .PITCH_ENC_B(PITCH_ENC_B),
        .YAW_ENC_A(YAW_ENC_A),
        .YAW_ENC_B(YAW_ENC_B),
        .LED(LED),
        .pitch_steps_out(pitch_steps),
        .yaw_steps_out(yaw_steps),
        .SW(SW)
    );

    assign mem_masked = mem[LED_WIDTH-1:0];
    assign enable = mem[31];
    //assign LED = user_output;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem <= 32'b0;
            slave_readdata <= 32'b0;
        end else begin
            slave_readdata <= {pitch_steps, yaw_steps};
            if (slave_write) begin
                mem <= slave_writedata;
            end;
        end;
    end



endmodule
