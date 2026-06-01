module Encoder(
    input       FPGA_CLK1_50,
	//input FPGA_CLK1_50,
	input PITCH_ENC_A,
	input PITCH_ENC_B,
	input YAW_ENC_A,
	input YAW_ENC_B,
	input [3:0] SW,
	output reg [7:0] LED,

	output reg [15:0] pitch_steps_out,
	output reg [15:0] yaw_steps_out
    //output reg  [7:0] LED		// clockwise direction indication
);

// State of state machine, bits correspond to A and B dir.
parameter PITCH_S00 = 2'b00;
parameter PITCH_S01 = 2'b01;
parameter PITCH_S10 = 2'b10;
parameter PITCH_S11 = 2'b11;

parameter YAW_S00 = 2'b00;
parameter YAW_S01 = 2'b01;
parameter YAW_S10 = 2'b10;
parameter YAW_S11 = 2'b11;

parameter steps_per_revolution = 1;

// Current and previous state

//reg [1:0] previous_state = S00;

// Combine SW[0] and SW[1] into a 2-bit vector
//wire [1:0] inputAB;
//assign inputAB = {SW[0], SW[1]};

// current state
//reg [1:0] current_state = S00;
// Counter for steps and display
reg [15:0] pitch_steps = 0;
reg [15:0] yaw_steps = 0;
//reg [7:0] previous_steps = 0;

// Synchronize the input signals to the FPGA clock to avoid bouncing
reg [1:0] sync0;
reg [1:0] sync1;
reg [1:0] sync2;
reg [1:0] sync3;

always @(posedge FPGA_CLK1_50) begin
    sync0 <= {PITCH_ENC_A, PITCH_ENC_B};
    sync1 <= sync0;
end

always @(posedge FPGA_CLK1_50) begin
    sync2 <= {YAW_ENC_A, YAW_ENC_B};
    sync3 <= sync2;
end

wire [1:0] current_pitch_state = sync1;
wire [1:0] current_yaw_state = sync3;

reg [1:0] prev_pitch_state = PITCH_S00;
reg [1:0] prev_yaw_state = PITCH_S00;

// Sequential logic: state update and counter/LEDs on clock edge
always @(posedge FPGA_CLK1_50) begin

	if(SW[3] == 1) begin
		pitch_steps <= 0;
		yaw_steps <= 0;
		prev_pitch_state <= current_pitch_state;
		prev_yaw_state <= current_yaw_state;
		LED <= 0;
		pitch_steps_out <= 0;
		yaw_steps_out <= 0;
	end
	// Save previous state for edge detection
	//previous_state <= current_state;
	//previous_steps <= steps;
	else begin
	// Compute next state (combinational logic folded into sequential)
		case (prev_pitch_state)
			PITCH_S00: begin
				if (current_pitch_state == PITCH_S10)
					pitch_steps <= pitch_steps + 16'd1;				// 8'd1 is just 1 as an 8 bit integer, typing 1 would result in a 32 bit integer
				else if (current_pitch_state == PITCH_S01)
					pitch_steps <= pitch_steps - 16'd1;
			end
			PITCH_S01: begin
					// flipped these
				if (current_pitch_state == PITCH_S11) 
					pitch_steps <= pitch_steps - 16'd1;
				else if (current_pitch_state == PITCH_S00)
					pitch_steps <= pitch_steps + 16'd1;
			end
			PITCH_S10: begin

				if (current_pitch_state == PITCH_S00)
					pitch_steps <= pitch_steps - 16'd1;
				else if (current_pitch_state == PITCH_S11)
					pitch_steps <= pitch_steps + 16'd1;
			end
			PITCH_S11: begin
				if (current_pitch_state == PITCH_S01)
					pitch_steps <= pitch_steps + 16'd1;
				else if (current_pitch_state == PITCH_S10)
					pitch_steps <= pitch_steps - 16'd1;
			end
			default: prev_pitch_state <= PITCH_S00;
		endcase
		prev_pitch_state <= current_pitch_state;
		case (prev_yaw_state)
			YAW_S00: begin
				if (current_yaw_state == YAW_S10)
					yaw_steps <= yaw_steps + 16'd1;				// 8'd1 is just 1 as an 8 bit integer, typing 1 would result in a 32 bit integer
				else if (current_yaw_state == YAW_S01)
					yaw_steps <= yaw_steps - 16'd1;
			end
			YAW_S01: begin
					// flipped these
				if (current_yaw_state == YAW_S11) 
					yaw_steps <= yaw_steps - 16'd1;
				else if (current_yaw_state == YAW_S00)
					yaw_steps <= yaw_steps + 16'd1;
			end
			YAW_S10: begin

				if (current_yaw_state == YAW_S00)
					yaw_steps <= yaw_steps - 16'd1;
				else if (current_yaw_state == YAW_S11)
					yaw_steps <= yaw_steps + 16'd1;
			end
			YAW_S11: begin
				if (current_yaw_state == YAW_S01)
					yaw_steps <= yaw_steps + 16'd1;
				else if (current_yaw_state == YAW_S10)
					yaw_steps <= yaw_steps - 16'd1;
			end
			default: prev_yaw_state <= YAW_S00;
		endcase
		prev_yaw_state <= current_yaw_state;
	end

	LED <= pitch_steps[15:8];
	pitch_steps_out <= pitch_steps;
	yaw_steps_out <= yaw_steps;
end
endmodule