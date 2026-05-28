// TopEntity: simple SPI slave that provides a 128x8 register file
// Command format: command byte = [W|addr6:0]; W=1 write, W=0 read

module TopEntity(
    input  wire sys_clk,
    input  wire rst_n,

    // SPI pins (mode 0, MSB-first)
    input  wire SPI_CLK,   // SCLK from master
    input  wire SPI_PICO,  // MOSI (master out -> slave in)
    output reg  SPI_POCI,  // MISO (slave out -> master in)
    input  wire SPI_CS,    // CS (active low)

    // Motor output
    output wire PWM_OUT
);

    // Simple register file
    reg [7:0] regs [0:127];
    localparam REG_SPEED = 8'h01; // bit7=dir, bits6:0=speed
    localparam REG_FLAGS = 8'h02; // bit0=enable, bit1=brake
    localparam REG_ENC_L = 8'h10; // encoder LSB
    localparam REG_ENC_H = 8'h11; // encoder MSB

    integer idx;
    initial begin
        for (idx = 0; idx < 128; idx = idx + 1) regs[idx] = 8'h00;
    end

    // Synchronize external SPI signals into sys_clk domain
    reg [1:0] clk_sync = 2'b00;
    reg [1:0] cs_sync  = 2'b11; // idle high

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_sync <= 2'b00;
            cs_sync  <= 2'b11;
        end else begin
            clk_sync <= {clk_sync[0], SPI_CLK};
            cs_sync  <= {cs_sync[0],  SPI_CS };
        end
    end

    wire clk_rising = clk_sync[1] & ~clk_sync[0];
    wire cs_active  = ~cs_sync[0];
    wire cs_falling = (cs_sync[1] == 1'b1) && (cs_sync[0] == 1'b0);
    wire cs_rising  = (cs_sync[1] == 1'b0) && (cs_sync[0] == 1'b1);

    // SPI byte receiver/transmitter
    reg [7:0] shift_rx;    // shift register for incoming bits
    reg [7:0] shift_tx;    // shift register for outgoing bits
    reg [2:0] bit_cnt;     // 7..0
    reg       expect_cmd;  // true when next completed byte is command
    reg       cmd_is_write;
    reg [6:0] addr_ptr;

    // Initialize and main SPI processing
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_rx    <= 8'h00;
            shift_tx    <= 8'hFE; // default ping reply
            bit_cnt     <= 3'd7;
            expect_cmd  <= 1'b1;
            cmd_is_write<= 1'b0;
            addr_ptr    <= 7'd0;
            SPI_POCI    <= 1'b0;
        end else begin
            // on CS falling edge: start a transfer
            if (cs_falling) begin
                shift_tx   <= 8'hFE;
                bit_cnt    <= 3'd7;
                shift_rx   <= 8'h00;
                expect_cmd <= 1'b1;
            end

            // while CS is active, sample MOSI on SCLK rising and drive MISO
            if (cs_active && clk_rising) begin
                // drive MISO with current MSB
                SPI_POCI <= shift_tx[7];
                // rotate transmit register left (MSB consumed)
                shift_tx <= {shift_tx[6:0], 1'b0};

                // sample MOSI into the current bit position (MSB-first)
                shift_rx[bit_cnt] <= SPI_PICO;

                // when a full byte has been shifted in
                if (bit_cnt == 3'd0) begin
                    // process completed byte in shift_rx
                    if (expect_cmd) begin
                        // command byte: W(7) + addr(6:0)
                        expect_cmd   <= 1'b0;
                        cmd_is_write <= shift_rx[7];
                        addr_ptr     <= shift_rx[6:0];

                        // Prepare the first data byte for read commands
                        if (!shift_rx[7]) begin
                            // read: preload data from the addressed register
                            if (shift_rx[6:0] == 7'd0)
                                shift_tx <= ~regs[shift_rx[6:0]]; // special echo-flip for addr 0
                            else
                                shift_tx <= regs[shift_rx[6:0]];
                        end
                    end else begin
                        // data phase
                        if (cmd_is_write) begin
                            // write incoming byte into register and advance address
                            regs[addr_ptr] <= shift_rx;
                            addr_ptr <= addr_ptr + 7'd1;
                        end else begin
                            // read data phase: master sent dummy, preload next byte
                            addr_ptr <= addr_ptr + 7'd1;
                            shift_tx <= regs[addr_ptr + 7'd1];
                        end
                    end
                    bit_cnt <= 3'd7;
                end else begin
                    bit_cnt <= bit_cnt - 3'd1;
                end
            end

            // on CS rising edge we end transfer; nothing automatic to do here
            if (cs_rising) begin
                // no-op: host controls state via regs
            end
        end
    end

    // ---------------------------
    // Map registers to PWM inputs so host controls speed over SPI
    // REG_SPEED: bit7=dir, bits6:0=speed
    // REG_FLAGS: bit0=enable, bit1=brake
    wire [6:0] pwm_speed  = regs[REG_SPEED][6:0];
    wire       pwm_dir    = regs[REG_SPEED][7];
    wire       pwm_enable = regs[REG_FLAGS][0];
    wire       pwm_brake  = regs[REG_FLAGS][1];

    // Instantiate placeholder PWM driver
    PWM_motordriver pwm (
        .clk(sys_clk),
        .rst_n(rst_n),
        .speed(pwm_speed),
        .dir(pwm_dir),
        .enable(pwm_enable),
        .brake(pwm_brake),
        .pwm_out(PWM_OUT)
    );

endmodule
