// SPI slave register file (clean, commented, board pin names at module ports)
// Simple register protocol (mode 0, MSB-first):
//  - Master sends command byte: [W bit][7-bit addr]
//    - W=1 (write): subsequent bytes are stored at addr, addr++ per byte
//    - W=0 (read): master clocks dummy bytes, slave returns regs[addr], addr++ per byte
//  - Ping: sending single byte 0xFE returns 0xFE
//  - Address 0x00: special debug register — reads return bitwise-NOT of stored value

module spi_slave_regfile(
    input  wire sys_clk,      // system clock (connect to board clk)
    input  wire rst_n,        // active-low reset
    input  wire SPI_CLK,      // SPI SCLK from master
    input  wire SPI_PICO,     // SPI MOSI (master out -> slave in)
    output reg  SPI_POCI,     // SPI MISO (slave out -> master in)
    input  wire SPI_CS        // SPI chip-select (active low)
);

    // 128x8 register file
    reg [7:0] regs [0:127];

    // configuration/status register aliases for clarity
    // regs[0x01] = SPEED (RW)
    // regs[0x02] = STATUS (RO)
    // regs[0x10/0x11] = ENCODER (16-bit, LSB/MSB)

    // Synchronize SPI signals into sys_clk domain to detect edges safely.
    reg [1:0] spi_clk_sync;
    reg [1:0] spi_cs_sync;
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_clk_sync <= 2'b00;
            spi_cs_sync  <= 2'b11;
        end else begin
            spi_clk_sync <= {spi_clk_sync[0], SPI_CLK};
            spi_cs_sync  <= {spi_cs_sync[0], SPI_CS};
        end
    end

    wire spi_clk_rising = spi_clk_sync[1] & ~spi_clk_sync[0];
    wire cs_active = ~spi_cs_sync[0];
    wire cs_start  = (spi_cs_sync[1] == 1'b1 && spi_cs_sync[0] == 1'b0); // falling edge
    wire cs_end    = (spi_cs_sync[1] == 1'b0 && spi_cs_sync[0] == 1'b1); // rising edge

    // Byte-level SPI handling
    reg [7:0] rx_byte;      // shift-in from MOSI
    reg [7:0] tx_byte;      // shift-out to MISO
    reg [2:0] bit_index;    // counts 7..0
    reg [6:0] addr_ptr;     // current register address pointer
    reg       is_write;     // current command is write
    reg       cmd_received; // true after command byte processed

    // initialize regs
    integer i;
    initial begin
        for (i = 0; i < 128; i = i + 1) regs[i] = 8'h00;
        regs[8'h02] = 8'h00; // STATUS default
        regs[8'h10] = 8'h00; // ENCODER LSB
        regs[8'h11] = 8'h00; // ENCODER MSB
    end

    // Main synchronized SPI byte FSM
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_byte      <= 8'h00;
            tx_byte      <= 8'hFE; // default ping reply
            SPI_POCI     <= 1'b0;
            bit_index    <= 3'd7;
            cmd_received <= 1'b0;
            addr_ptr     <= 7'd0;
            is_write     <= 1'b0;
        end else begin
            if (cs_start) begin
                // transfer start: preload ping value and reset counters
                tx_byte      <= 8'hFE;
                bit_index    <= 3'd7;
                rx_byte      <= 8'h00;
                cmd_received <= 1'b0;
            end

            if (cs_active && spi_clk_rising) begin
                // output MSB first
                SPI_POCI <= tx_byte[7];
                tx_byte  <= {tx_byte[6:0], 1'b0};

                // sample MOSI
                rx_byte <= {rx_byte[6:0], SPI_PICO};

                if (bit_index == 3'd0) begin
                    // one byte completed
                    if (!cmd_received) begin
                        // parse command byte
                        cmd_received <= 1'b1;
                        is_write     <= rx_byte[7];
                        addr_ptr     <= rx_byte[6:0];
                        if (rx_byte == 8'hFE) begin
                            // ping: tx_byte already 0xFE
                        end else if (!rx_byte[7]) begin
                            // read command: preload first data byte to send
                            if (rx_byte[6:0] == 7'd0)
                                tx_byte <= ~regs[rx_byte[6:0]]; // echo-flip for addr 0
                            else
                                tx_byte <= regs[rx_byte[6:0]];
                        end
                    end else begin
                        // command already received: handle data phase
                        if (is_write) begin
                            // write incoming byte to current address
                            regs[addr_ptr] <= rx_byte;
                            addr_ptr <= addr_ptr + 7'd1;
                        end else begin
                            // read data phase: master sent dummy, we already had tx_byte for this addr
                            addr_ptr <= addr_ptr + 7'd1;
                            if ((addr_ptr + 7'd1) == 7'd0)
                                tx_byte <= ~regs[addr_ptr + 7'd1];
                            else
                                tx_byte <= regs[addr_ptr + 7'd1];
                        end
                    end
                    bit_index <= 3'd7;
                end else begin
                    bit_index <= bit_index - 3'd1;
                end
            end

            if (cs_end) begin
                // transfer ended: optional tasks — simulate encoder increment when speed>0
                if (regs[8'h01] != 8'h00) begin
                    {regs[8'h11], regs[8'h10]} <= {regs[8'h11], regs[8'h10]} + 16'h0001;
                end
            end
        end
    end

endmodule
