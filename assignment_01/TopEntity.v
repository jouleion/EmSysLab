module TopEntity (
    input clk,
    output reg led1 = 0,
    output reg led2 = 0
);
  reg [31:0] count = 0;
  reg [31:0] count2 = 0;
  always @(posedge clk) begin
    if (count == 10000000) begin  //Time is up
      count <= 0;  //Reset count register
      led1   <= ~led1;  //Toggle led (in each second)
    end else begin
      count <= count + 1;  //Counts 100MHz clock
    end

    if (count2 == 50000000) begin  //Time is up
      count2 <= 0;  //Reset count register
      led2   <= ~led2;  //Toggle led (in each 5 seconds)
    end else begin
      count2 <= count2 + 1;  //Counts 100MHz clock
    end
  end
endmodule
