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
wire [1:0] inputAB;
assign inputAB = {SW[0], SW[1]};

// current state
reg [1:0] current_state = S00;
// Counter for steps and display
reg [7:0] steps = 0; 
reg [0:0] flag = 0;
//reg [7:0] previous_steps = 0;

// Sequential logic: state update and counter/LEDs on clock edge
always @(posedge FPGA_CLK1_50) begin

	if(SW[3] == 1) begin
		LED[1] <= 0;
		LED[2] <= 0;
		current_state <= inputAB;
		//previous_state <= S00;
		steps <= 0;
		//previous_steps <= 0;
	end
	if (flag == 0) begin
		flag <=1;
		current_state <= inputAB;
	end
	// Save previous state for edge detection
	//previous_state <= current_state;
	//previous_steps <= steps;

	// Compute next state (combinational logic folded into sequential)
	case (current_state)
		S00: begin
			if (inputAB == S10) begin
				current_state <= S10;
				steps <= steps + 8'd1;
			end else if (inputAB == S01) begin
				current_state <= S01;
				steps <= steps - 8'd1;
			end else begin
				current_state <= S00;
			end
		end
		S01: begin
                // flipped these
			if (inputAB == S11) begin 
				current_state <= S11;
				steps <= steps - 8'd1;
			end else if (inputAB == S00) begin
				current_state <= S00;
				steps <= steps + 8'd1;
			end else begin
				current_state <= S01;
			end
		end
		S10: begin
        
			if (inputAB == S00) begin
				current_state <= S00;
				steps <= steps - 8'd1;
			end else if (inputAB == S11) begin
				current_state <= S11;
				steps <= steps + 8'd1;
			end else begin
				current_state <= S10;
			end
		end
		S11: begin
			if (inputAB == S01) begin
				current_state <= S01;
				steps <= steps + 8'd1;
			end else if (inputAB == S10) begin
				current_state <= S10;
				steps <= steps - 8'd1;
			end else begin
				current_state <= S11;
			end
		end
		default: current_state <= S00;
	endcase

	// Assign an LED to indicate the direction of rotation.
	//if(previous_steps < steps) begin
		// Clockwise
		// LED[1] <= 1; 
		// LED[2] <= 0;
	//end else if (previous_steps > steps) begin
		// Counterclockwise
		// LED[1] <= 0;
		// LED[2] <= 1; 
	//end

	LED <= steps;
end
endmodule
