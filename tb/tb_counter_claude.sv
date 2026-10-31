`timescale 1ns/1ps
module tb_counter;
  logic clk = 0, rst, en;
  logic [7:0] count;
  int errors = 0;

  counter dut (.clk(clk), .rst(rst), .en(en), .count(count));

  always #5 clk = ~clk;

  task automatic check(input logic [7:0] exp, input string what);
    if (count !== exp) begin
      $display("ERROR %s: count=%0d expected=%0d @%0t", what, count, exp, $time);
      errors++;
    end
  endtask

  initial begin
    $dumpfile("build/tb_counter_claude.vcd");
    $dumpvars(0, tb_counter);
    rst = 1; en = 0;
    repeat (2) @(posedge clk); #1;
    check(8'd0,  "reset");
    rst = 0; en = 1;
    repeat (10) @(posedge clk); #1;
    check(8'd10, "count 10");
    en = 0;
    repeat (3) @(posedge clk); #1;
    check(8'd10, "hold when en=0");
    en = 1;
    repeat (246) @(posedge clk); #1;
    check(8'd0,  "wraparound 255->0");
    if (errors == 0) $display("PASS");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule