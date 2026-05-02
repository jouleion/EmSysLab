module TopEntity(
    input       clk,
    input       PITCH_DIRA,  // Pin assignment for dir[0]
    input       PITCH_DIRB,  // Pin assignment for dir[1]
    output reg  led1,
    output reg  led2
);


    // State of state machine, bits correspond to A and B dir.
    parameter S00 = 2'b00;
    parameter S01 = 2'b01;
    parameter S10 = 2'b10;
    parameter S11 = 2'b11;

    // Current and previous state
    reg [1:0] current_state = S00;
    reg [1:0] previous_state = S00;

    // Combine PITCH_DIRA and PITCH_DIRB into a 2-bit vector
    wire [1:0] dir;
    assign dir = {PITCH_DIRB, PITCH_DIRA};

    // Sequential logic: state update and counter/LEDs on clock edge
    always @(posedge clk) begin
        // if (reset) begin
        //     current_state <= S00;
        //     previous_state <= S00;
        //     // count <= 0;
        //     led1 <= 0;
        //     led2 <= 0;
        // end else begin
            // Save previous state for edge detection
            previous_state <= current_state;

            // Compute next state (combinational logic folded into sequential)
            case (current_state)
                S00: begin
                    if (dir == S10) current_state <= S10;
                    else if (dir == S01) current_state <= S01;
                    else current_state <= S00;
                end
                S01: begin
                    if (dir == S11) current_state <= S11;
                    else if (dir == S00) current_state <= S00;
                    else current_state <= S01;
                end
                S10: begin
                    if (dir == S00) current_state <= S00;
                    else if (dir == S11) current_state <= S11;
                    else current_state <= S10;
                end
                S11: begin
                    if (dir == S01) current_state <= S01;
                    else if (dir == S10) current_state <= S10;
                    else current_state <= S11;
                end
                default: current_state <= S00;
            endcase

            // Clockwise and counterclockwise detection
            // For S00
            if (previous_state == S00 && current_state == S10) begin
                led1 <= 1;          // Clockwise
                led2 <= 0;
                count <= count + 1;
            end else if (previous_state == S00 && current_state == S01) begin
                led1 <= 0;          // Counterclockwise
                led2 <= 1;
                count <= count - 1;
            end

            // For S01      
            if (previous_state == S01 && current_state == S11) begin
                led1 <= 0;          // Counter Clockwise
                led2 <= 1;
                count <= count + 1;
            end else if (previous_state == S01 && current_state == S00) begin
                led1 <= 1;          // clockwise
                led2 <= 0;
                count <= count - 1;
            end
            // For S10
            if (previous_state == S10 && current_state == S00) begin
                led1 <= 0;          // Counter Clockwise
                led2 <= 1;
                count <= count + 1;
            end else if (previous_state == S10 && current_state == S11) begin
                led1 <= 1;          // Clockwise
                led2 <= 0;
                count <= count - 1;
            end
            // For S11
            if (previous_state == S11 && current_state == S01) begin
                led1 <= 1;          // Clockwise
                led2 <= 0;
                count <= count + 1;
            end else if (previous_state == S11 && current_state == S10) begin
                led1 <= 0;          // Counterclockwise
                led2 <= 1;
                count <= count - 1;
            end
        end
    

endmodule