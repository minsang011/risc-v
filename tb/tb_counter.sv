`timescale 1ns / 1ps

module tb_counter;
logic clk=0, rst=1, en=0;
logic [4:0] count;

// Declaring counter class
counter dut (.clk(clk), .rst(rst), .en(en), .count(count));

// Declaring the clock period
always #5 clk = ~clk;

initial begin
    $dumpfile("tb/tb_ctr.vcd");
    $dumpvars(0, tb_counter);
    // Begin
    rst=1; en=0;
    #12 
    // FIRST: Checks it increments successfully
    rst=0; en=1;
    #100;
    if (count==5'd10) begin
        $display("FIRST TEST PASS count = %d", count);
    end else begin
        $display("FIRST TEST FAIL count == %d", count);
    end
    // SECOND: Checks rst signal
    rst=1; en=1;
    #100;
    if (count==5'd0) begin
        $display("SECOND TEST PASS count = %d", count);
    end else begin
        $display("SECOND TEST FAIL count == %d", count);
    end
    // THIRD == FIRST
    rst=0; en=1;
    #100;
    if (count==5'd10) begin
        $display("THIRD TEST PASS count = %d", count);
    end else begin
        $display("THIRD TEST FAIL count == %d", count);
    end
    // FOURTH: Checks it holds the value well
    rst=0; en=0;
    #100;
    if (count==5'd10) begin
        $display("FOURTH TEST PASS count = %d", count);
    end else begin
        $display("FOURTH TEST FAIL count == %d", count);
    end
 

    $finish;
end

endmodule