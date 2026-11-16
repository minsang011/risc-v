module regfile
    (
        input logic [4:0] raddr1, raddr2, waddr,
        input logic [31:0] wdata,
        input logic we, clk, rst,
        output logic [31:0] rdata1, rdata2
    ); 

    // x0 is reserved to 'd0
    logic [31:0] regs [1:31];
    

    always_comb begin
        // Handle reading on x0 strictly gives 0
        if (raddr1 == '0) begin
            rdata1 = '0;
        end else begin
            rdata1 = regs[raddr1];
        end

        if (raddr2 == '0) begin
            rdata2 = '0;
        end else begin
            rdata2 = regs[raddr2];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            foreach (regs[i]) begin
                regs[i] <= '0;
            end
        end else if (we && (waddr!='0)) begin
            regs[waddr] <= wdata;
        end
    end




endmodule
