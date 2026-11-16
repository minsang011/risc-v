module regfile_tb;
    import rv32i_pkg::*;

    // Declaring variables and dut
    logic [4:0] raddr1, raddr2, waddr;
    logic [31:0] rdata1, rdata2, wdata;
    logic clk, rst, we;
    int error = 0;


    regfile dut (.*);
    

    // Helpers 1. reg_write 2. check_read 3. val
    task automatic reg_write(input logic [4:0] t_addr, input logic [31:0] t_data);
        // first negedge (change the flag and prepare the data)
        // first posedge (apply that change to rd)
        // second negedge (reset we flag)
        @(negedge clk);
        we = 1; waddr = t_addr; wdata = t_data;
        // @(posedge clk) regs[waddr] <= wdata -- happens in dut
        @(negedge clk);
        we = 0;
    endtask

    task automatic check_read(input logic [4:0] t_addr1, input logic [4:0] t_addr2, 
                              input logic [31:0] exp1, input logic [31:0] exp2,
                              input string what);
        raddr1 = t_addr1; raddr2 = t_addr2;
        #1;
        if (rdata1 !== exp1) begin
            $display("ERROR %s: regs[%d](addr1) and exp1 not match. exp=%d", 
                     what, t_addr1, exp1);
            error++;
        end
        if (rdata2 !== exp2) begin
            $display("ERROR %s: regs[%d](addr2) and exp2 not match. exp=%d", 
                     what, t_addr2, exp2);
            error++;
        end
    endtask

    function automatic logic [31:0] val(input int n);
        return {8'hB2, 8'(n), 8'h5A, 8'(~n)};
    endfunction




// ------------------- Simulation -------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/regfile_tb.vcd");
        $dumpvars(0, regfile_tb);
        rst = 1; we = 0;
        @(negedge clk) rst = 0; // Put rst=0 when clk falls

        // 1. Reset 1 
        for (int i = 1; i < 32; i++) begin
            check_read(5'(i), 5'(i), 32'h0, 32'h0, "Reset 1");
        end

        // 2. Readback test
        for (int i = 1; i < 32; i++) begin
            reg_write(5'(i), val(i));
        end
        for (int i = 1; i < 32; i++) begin
            check_read(5'(i), 5'(i), val(i), val(i), "Readback");
        end

        // 3. Ports agreement
        for (int i = 1; i < 32; i++) begin 
            raddr1 = 5'(i); raddr2 = 5'(i);
            check_read(raddr1, raddr2, val(i), val(i), "Ports agreement");
        end

        // 4. Port independency
        for (int i = 1; i < 32; i++) begin
            raddr1 = 5'(i); raddr2 = 5'(32)-5'(i);
            check_read(raddr1, raddr2, val(i), val(32-i), "Port independency");
        end

        // 5. Write to x0 (should be ignored)
        reg_write(0, 32'hFFFFFFFF);
        check_read(0, 0, 0, 0, "Write to x0");

        // 6. we flag sanity test
        @(negedge clk) 
        we = 0; waddr = 5'(3); wdata = 32'hC21FB412;
        @(negedge clk)
        check_read(waddr, waddr, val(3), val(3), "we flag sanity test");

        // 7. Sequential test
        @(negedge clk);
        we = 1; waddr = 5'(5); wdata = 32'hFFFFFFFA;
        check_read(waddr, waddr, val(5), val(5), "Sequential test (old value)");
        @(posedge clk); // should be changed now
        check_read(waddr, waddr, 32'hFFFFFFFA, 32'hFFFFFFFA, "Sequential test (NEW value)");

        // 8. Reset 2
        @(negedge clk) rst = 1; we = 0;
        @(negedge clk) rst = 0;
        #1;
        for (int i = 1; i < 32; i++) begin 
            check_read(5'(i), 5'(i), 32'h0, 32'h0, "Reset 2");
        end
        
        if (error == 0) begin
            $display("PASS regfile_tb");
        end else begin
            $fatal(1, "regfile_tb: %0d check(s) failed", error);
        end

        $finish();
    end


endmodule
