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

  // ---------------- SPI CLOCK (SLOW, CLEAN EDGES) ----------------
  task spi_pulse;
    begin
      SPI_CLK = 0;
      #200;
      SPI_CLK = 1;
      #200;
      SPI_CLK = 0;
      #200;
    end
  endtask

  // ---------------- SEND ONE BYTE ----------------
  task spi_send_byte(input [7:0] data);
    integer i;
    begin
      for (i = 7; i >= 0; i = i - 1) begin
        SPI_PICO = data[i];
        spi_pulse();
      end
    end
  endtask

  // ---------------- SEND MOTOR FRAME ----------------
  task send_motor(input enable, input dir, input brake, input [7:0] speed);
    reg [7:0] control;
    begin
      control = 0;
      control[7] = enable;
      control[6] = dir;
      control[5] = brake;

      SPI_CS = 0;
      #100;

      spi_send_byte(control);
      spi_send_byte(speed);

      #100;
      SPI_CS = 1;

      #5000; // let PWM run
    end
  endtask

  // ---------------- TEST ----------------
  initial begin
    $dumpfile("signals.vcd");
    $dumpvars(0, PWM_Motordriver_tb);

    // init SPI
    SPI_CLK  = 0;
    SPI_PICO = 0;
    SPI_CS   = 1;

    #1000;

    // enable, dir=0, speed low
    send_motor(1, 0, 0, 8'd20);

    // enable, dir=1, speed high
    send_motor(1, 1, 0, 8'd80);

    // brake
    send_motor(1, 1, 1, 8'd50);

    // disable
    send_motor(0, 0, 0, 8'd0);

    #20000;
    $finish;
  end

endmodule