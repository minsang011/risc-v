`timescale 1ns / 1ps

module counter (
    input logic clk, rst, en,
    output logic [7:0] count //[7:0] when testbench claude version
);
    always_ff @(posedge clk) begin
        if (rst) begin
            count <= 0;
        end else if(en) begin
            count <= count + 1;
        end
    end

endmodule