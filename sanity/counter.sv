module counter (
  input  logic       clk, rst,
  output logic [4:0] count
);
  always_ff @(posedge clk or negedge clk)
    if (rst) count <= '0;
    else     count <= count + 1;
endmodule