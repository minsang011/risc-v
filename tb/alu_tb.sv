// --------------- OVERALL STRCUTRE OF TB ---------------
//              ┌──────────────┐
// (op, a, b) ─▶│ ALU (DUT)    │──▶ actual result ───┐
//      │       └──────────────┘                     ▼
//      │       ┌──────────────┐                  check: actual !== expected?
//      └──────▶│ ref_alu()    │──▶ expected ──────▲    → mismatch: print + count error
//              └──────────────┘
// ------------------------------------------------------

module alu_tb;
    import rv32i_pkg::*;

    // Declaring variables and mount it to dut
    logic [31:0] a, b, result;
    alu_op_e op;
    int error = 0;

    alu dut (.*);
    
    // 1. Checker
    task automatic check(input alu_op_e t_op, input logic [31:0] t_a, 
                        input logic [31:0] t_b, input logic [31:0] ref_alu, input string what); 
        op = t_op; a = t_a; b = t_b; // Drive values to DUT
        #1 // Wait 1 time period to be updated
        if (result !== ref_alu) begin
            $display("ERROR %s: %s a=%h b=%h result=%h expected=%h",
                     what, t_op.name(), t_a, t_b, result, ref_alu);
            error++;
        end
    endtask

    // 2. Reference model
    //    SLT, SLTU and SRA are written differently from alu.sv on purpose,
    //    so a mistake in one is unlikely to be repeated in the other.
    function automatic logic [31:0] ref_alu(input alu_op_e     f_op,
                                            input logic [31:0] f_a,
                                            input logic [31:0] f_b);
        logic [31:0] f_result;

        if (f_op == ALU_ADD) begin
            f_result = f_a + f_b;
        end else if (f_op == ALU_SUB) begin
            f_result = f_a - f_b;
        end else if (f_op == ALU_SLL) begin
            f_result = f_a << f_b[4:0];
        end else if (f_op == ALU_SLT) begin
            // Signs differ: the negative one is smaller. Signs match: unsigned compare is correct.
            f_result = {31'b0, ((f_a[31] != f_b[31]) ? f_a[31] : (f_a < f_b))};
        end else if (f_op == ALU_SLTU) begin
            // Top bits differ: the one with bit 31 set is larger. Otherwise compare the rest.
            f_result = {31'b0, ((f_a[31] != f_b[31]) ? f_b[31] : (f_a[30:0] < f_b[30:0]))};
        end else if (f_op == ALU_XOR) begin
            f_result = f_a ^ f_b;
        end else if (f_op == ALU_SRL) begin
            f_result = f_a >> f_b[4:0];
        end else if (f_op == ALU_SRA) begin
            // Shift in zeros, then set the vacated top bits to 1 for a negative value.
            f_result = f_a[31] ? ((f_a >> f_b[4:0]) | ~(32'hFFFFFFFF >> f_b[4:0]))
                            : (f_a >> f_b[4:0]);
        end else if (f_op == ALU_OR) begin
            f_result = f_a | f_b;
        end else if (f_op == ALU_AND) begin
            f_result = f_a & f_b;
        end else begin
            f_result = '0;
        end

        return f_result;
    endfunction


    // 3. Simulation
    initial begin
        logic [31:0] s_a, s_b;
        alu_op_e s_op;

        $dumpfile("build/alu_tb.vcd");
        $dumpvars(0, alu_tb);

        for (int i = 0; i < op.num(); i++) begin
            s_op = alu_op_e'(i);
            for (int j = 0; j < 1000; j++) begin
                s_a = $urandom();
                s_b = $urandom();
                check(s_op, s_a, s_b, ref_alu(s_op, s_a, s_b), "Random");
            end

            // Hand-written edge cases: expected values calculated by hand, not from ref_alu
            case (s_op)
                ALU_ADD: begin
                    check(s_op, 32'hFFFFFFFF, 32'h00000001, 32'h00000000, "ADD wraparound");
                    check(s_op, 32'h7FFFFFFF, 32'h00000001, 32'h80000000, "ADD signed overflow ignored");
                end
                ALU_SUB: begin
                    check(s_op, 32'h80000000, 32'h00000001, 32'h7FFFFFFF, "SUB 0x80000000 - 1 wraps");
                    check(s_op, 32'h00000000, 32'h00000001, 32'hFFFFFFFF, "SUB borrow");
                end
                ALU_SLL: begin
                    check(s_op, 32'h12345678, 32'h00000000, 32'h12345678, "SLL shift by 0");
                    check(s_op, 32'h00000001, 32'h0000001F, 32'h80000000, "SLL shift by 31");
                    check(s_op, 32'h12345678, 32'h00000020, 32'h12345678, "SLL b=32 uses only b[4:0]=0");
                    check(s_op, 32'h00000001, 32'hFFFFFFE1, 32'h00000002, "SLL upper bits of b ignored");
                end
                ALU_SLT: begin
                    check(s_op, 32'hFFFFFFFF, 32'h00000000, 32'h00000001, "SLT -1 < 0 signed");
                    check(s_op, 32'h80000000, 32'h7FFFFFFF, 32'h00000001, "SLT most negative < most positive");
                    check(s_op, 32'h00000005, 32'h00000005, 32'h00000000, "SLT equal is not less");
                end
                ALU_SLTU: begin
                    check(s_op, 32'hFFFFFFFF, 32'h00000000, 32'h00000000, "SLTU 0xFFFFFFFF not < 0 unsigned");
                    check(s_op, 32'h80000000, 32'h7FFFFFFF, 32'h00000000, "SLTU 0x80000000 not < 0x7FFFFFFF unsigned");
                end
                ALU_XOR: begin
                    check(s_op, 32'h12345678, 32'hFFFFFFFF, 32'hEDCBA987, "XOR with -1 is NOT");
                end
                ALU_SRL: begin
                    check(s_op, 32'h80000000, 32'h0000001F, 32'h00000001, "SRL zero-fill");
                end
                ALU_SRA: begin
                    check(s_op, 32'h80000000, 32'h0000001F, 32'hFFFFFFFF, "SRA sign-fill, shift by 31");
                    check(s_op, 32'h80000000, 32'h00000004, 32'hF8000000, "SRA sign-fill, shift by 4");
                    check(s_op, 32'h7FFFFFF0, 32'h00000004, 32'h07FFFFFF, "SRA positive value zero-fills");
                    check(s_op, 32'h80000000, 32'h00000000, 32'h80000000, "SRA shift by 0");
                end
                ALU_OR: begin
                    check(s_op, 32'hF0F0F0F0, 32'h0FF00FF0, 32'hFFF0FFF0, "OR bitwise");
                end
                ALU_AND: begin
                    check(s_op, 32'hF0F0F0F0, 32'h0FF00FF0, 32'h00F000F0, "AND bitwise");
                end
                default: $fatal(1, "unexpected operation number: %0d", i);
            endcase
        end
        

        if (error == 0) begin
            $display("PASS alu_tb");
        end else begin
            $fatal(1, "alu_tb: %0d check(s) failed", error);
        end

        $finish;
    end


endmodule
