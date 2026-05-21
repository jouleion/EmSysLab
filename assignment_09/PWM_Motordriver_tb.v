`timescale 1ns/1ps

module PWM_Motordriver_tb;

  reg clk;

  // SPI lines
  reg SPI_CLK;
  reg SPI_PICO;
  reg SPI_CS;

  wire PITCH_DIRA;
  wire PITCH_DIRB;
  wire PITCH_PWM_VAL;

  PWM_Motordriver dut (
    .clk(clk),

    .SPI_CLK(SPI_CLK),
    .SPI_PICO(SPI_PICO),
    .SPI_CS(SPI_CS),

    .PITCH_DIRA(PITCH_DIRA),
    .PITCH_DIRB(PITCH_DIRB),
    .PITCH_PWM_VAL(PITCH_PWM_VAL)
  );

  // system clock (PWM domain)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ---------------- SPI CLOCK (MODE 0 SAFE) ----------------
  task spi_tick;
    begin
      #100 SPI_CLK = 1; // Shortened clock high time for better alignment
      #100 SPI_CLK = 0; // Shortened clock low time for better alignment
    end
  endtask

  // ---------------- SEND ONE BYTE ----------------
  task spi_send_byte(input [7:0] data);
    integer i;
    begin
      for (i = 7; i >= 0; i = i - 1) begin
        SPI_PICO = data[i];
        #50;          // setup time BEFORE clock edge
        spi_tick();   // rising edge sampled by DUT
        #50;          // hold time AFTER edge
      end
    end
  endtask

  // ---------------- SEND MOTOR FRAME ----------------
  task send_motor(input enable, input dir, input brake, input [7:0] speed);
    reg [7:0] control;
    begin
      control = 0;
      // New encoding: bit6 = enable, bit5 = dir, bit4 = brake
      control[6] = enable;
      control[5] = dir;
      control[4] = brake;

      SPI_CLK  = 0;
      SPI_PICO = 0;

      #500;
      SPI_CS = 0;   // ASSERT CS BEFORE FIRST BIT
      #500;

      spi_send_byte(control);
      spi_send_byte(speed);

      #500;
      SPI_CS = 1;   // DEASSERT

      #5000;
    end
  endtask

  // ---------------- TEST ----------------
  initial begin
    $dumpfile("signals.vcd");
    $dumpvars(0, PWM_Motordriver_tb);

    SPI_CLK  = 0;
    SPI_PICO = 0;
    SPI_CS   = 1;

    #2000;

    send_motor(1, 0, 0, 8'd20); // Enable motor, forward direction, no brake
    send_motor(1, 1, 0, 8'd80); // Enable motor, reverse direction, no brake
    send_motor(1, 1, 1, 8'd50); // Enable motor, reverse direction, brake
    send_motor(0, 0, 0, 8'd0);  // Disable motor

    #20000;
    $finish;
  end

endmodule