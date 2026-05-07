module Encoder(
    input       FPGA_CLK1_50,
	 input 	 	 [3:0] SW,		// as a manual reset line.
    output reg  [7:0] LED		// clockwise direction indication
);

// State of state machine, bits correspond to A and B dir.
parameter S00 = 2'b00;
parameter S01 = 2'b01;
parameter S10 = 2'b10;
parameter S11 = 2'b11;

parameter steps_per_revolution = 1;

// Current and previous state

//reg [1:0] previous_state = S00;

// Combine SW[0] and SW[1] into a 2-bit vector
//wire [1:0] inputAB;
//assign inputAB = {SW[0], SW[1]};

// current state
//reg [1:0] current_state = S00;
// Counter for steps and display
reg [7:0] steps = 0;
//reg [7:0] previous_steps = 0;

// Synchronize the input signals to the FPGA clock to avoid bouncing
reg [1:0] sync0;
reg [1:0] sync1;

always @(posedge FPGA_CLK1_50) begin
    sync0 <= SW[1:0];
    sync1 <= sync0;
end

wire [1:0] current_state = sync1;

reg [1:0] prev_state = 2'b00;

// Sequential logic: state update and counter/LEDs on clock edge
always @(posedge FPGA_CLK1_50) begin

	if(SW[3] == 1) begin
		LED[7:0] <= 0;
		prev_state <= current_state;
		steps <= 0;
	end
	// Save previous state for edge detection
	//previous_state <= current_state;
	//previous_steps <= steps;
	else begin
	// Compute next state (combinational logic folded into sequential)
		case (prev_state)
			S00: begin
				if (current_state == S10)
					steps <= steps + 8'd1;
				else if (current_state == S01)
					steps <= steps - 8'd1;
			end
			S01: begin
					// flipped these
				if (current_state == S11) 
					steps <= steps - 8'd1;
				else if (current_state == S00)
					steps <= steps + 8'd1;
			end
			S10: begin

				if (current_state == S00)
					steps <= steps - 8'd1;
				else if (current_state == S11)
					steps <= steps + 8'd1;
			end
			S11: begin
				if (current_state == S01)
					steps <= steps + 8'd1;
				else if (current_state == S10)
					steps <= steps - 8'd1;
			end
			default: prev_state <= S00;
		endcase
		prev_state <= current_state;
	end

	LED <= steps;
end
endmodule
