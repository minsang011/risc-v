module tb_counter;
  logic clk = 0, rst = 1;
  logic [4:0] count;
  counter dut (.*);
  always #5 clk = ~clk;
  initial begin
    $dumpfile("wave.vcd"); $dumpvars(0, tb_counter);
    #12 rst = 0;
    #100;
    if (count == 5'd20) $display("PASS: count = %0d", count);
    else                $display("FAIL: count = %0d", count);
    $finish;
  end
endmodule