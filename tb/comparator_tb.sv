module comparator_tb;
    import rv32i_pkg::*;

    logic [31:0] rs1_data, rs2_data;
    logic [2:0]  funct3;
    logic        taken;

    int error = 0;

    comparator dut (.*);

    // 1. Reference model
    function automatic logic ref_comp(input logic [31:0] t_rs1_data, input logic [31:0] t_rs2_data,
                                      input logic [2:0]  t_funct3);
        logic t_taken;

        case (t_funct3)
            F3_BR_BEQ:  t_taken = (t_rs1_data == t_rs2_data) ? 1'b1 : 1'b0;
            F3_BR_BNE:  t_taken = (t_rs1_data != t_rs2_data) ? 1'b1 : 1'b0;
            F3_BR_BLT:  t_taken = (int'(t_rs1_data) <  int'(t_rs2_data)) ? 1'b1 : 1'b0;
            F3_BR_BGE:  t_taken = (int'(t_rs1_data) >= int'(t_rs2_data)) ? 1'b1 : 1'b0;
            F3_BR_BLTU: t_taken = ({1'b0, t_rs1_data} <  {1'b0, t_rs2_data}) ? 1'b1 : 1'b0;
            F3_BR_BGEU: t_taken = ({1'b0, t_rs1_data} >= {1'b0, t_rs2_data}) ? 1'b1 : 1'b0;
            default:    t_taken = 1'b0;
        endcase

        return t_taken;
    endfunction

    // 2. Checker
    task automatic check(input logic [31:0] t_rs1_data, input logic [31:0] t_rs2_data,
                         input logic [2:0]  t_funct3,   input logic exp_taken, input string what);
        // Drive arguments to the DUT
        rs1_data = t_rs1_data; rs2_data = t_rs2_data; funct3 = t_funct3;
        #1; // Wait for the combinational output to settle
        if (taken !== exp_taken) begin
            $display("ERROR %s: f3=%b rs1=%h rs2=%h got=%b exp=%b",
                     what, t_funct3, t_rs1_data, t_rs2_data, taken, exp_taken);
            error++;
        end
    endtask

    // 3. Edge operands: zero, one, max positive, min negative, -1
    function automatic logic [31:0] edge_val(input int i);
        case (i)
            0:       return 32'h0000_0000;
            1:       return 32'h0000_0001;
            2:       return 32'h7FFF_FFFF;
            3:       return 32'h8000_0000;
            default: return 32'hFFFF_FFFF;
        endcase
    endfunction

    // 4. 25% edge value, 75% fully random (pure random almost never hits equality or the sign boundary)
    function automatic logic [31:0] rand_operand();
        if ($urandom_range(0, 3) == 0) return edge_val($urandom_range(0, 4));
        else                           return $urandom();
    endfunction

    function automatic logic [2:0] rand_branch_f3();
        case ($urandom_range(0, 5))
            0:       return F3_BR_BEQ;
            1:       return F3_BR_BNE;
            2:       return F3_BR_BLT;
            3:       return F3_BR_BGE;
            4:       return F3_BR_BLTU;
            default: return F3_BR_BGEU;
        endcase
    endfunction

    // 5. Simulation
    initial begin
        logic [31:0] a, b;
        logic [2:0]  f;

        $dumpfile("build/comparator_tb.vcd");
        $dumpvars(0, comparator_tb);

        // 1. Hand-calculated: equal, less, greater, and signed vs unsigned disagreement
        //    (expected values written by hand, independent of ref_comp)
        check(32'hFFFFFFFF, 32'hFFFFFFFF, F3_BR_BEQ,  1'b1, "BEQ equal negatives");
        check(32'hFFFFFFFF, 32'hFFFFFFFF, F3_BR_BNE,  1'b0, "BNE equal negatives");
        check(32'h80000000, 32'h00000001, F3_BR_BLT,  1'b1, "BLT -2^31 < 1 signed");
        check(32'h80000000, 32'h00000001, F3_BR_BLTU, 1'b0, "BLTU 2^31 > 1 unsigned");
        check(32'h80000000, 32'h00000001, F3_BR_BGE,  1'b0, "BGE -2^31 not >= 1");
        check(32'h80000000, 32'h00000001, F3_BR_BGEU, 1'b1, "BGEU 2^31 >= 1");
        check(32'h00000001, 32'hFFFFFFFF, F3_BR_BLT,  1'b0, "BLT 1 not < -1");
        check(32'h00000001, 32'hFFFFFFFF, F3_BR_BLTU, 1'b1, "BLTU 1 < 0xFFFFFFFF");
        check(32'h00000005, 32'h00000005, F3_BR_BLT,  1'b0, "BLT equal is not less");
        check(32'h00000005, 32'h00000005, F3_BR_BGE,  1'b1, "BGE equal counts");
        check(32'h00000005, 32'h00000005, F3_BR_BLTU, 1'b0, "BLTU equal is not less");
        check(32'h00000005, 32'h00000005, F3_BR_BGEU, 1'b1, "BGEU equal counts");
        check(32'h00000005, 32'h00000005, 3'b010,     1'b0, "invalid funct3 010");
        check(32'h00000005, 32'h00000005, 3'b011,     1'b0, "invalid funct3 011");

        // 2. Every edge pair x all 8 funct3 values, against the reference model
        //    (covers equality incl. negative, sign boundary, and invalid 010/011 -> 0)
        for (int i = 0; i < 5; i++)
            for (int j = 0; j < 5; j++)
                for (int k = 0; k < 8; k++) begin
                    a = edge_val(i); b = edge_val(j); f = k[2:0];
                    check(a, b, f, ref_comp(a, b, f), "edge pair");
                end

        // 3. Random
        for (int n = 0; n < 2000; n++) begin
            a = rand_operand(); b = rand_operand(); f = rand_branch_f3();
            check(a, b, f, ref_comp(a, b, f), "random");
        end

        // 4. Summary
        if (error == 0) $display("PASS comparator_tb");
        else            $fatal(1, "FAIL: %0d check(s) failed", error);
        $finish;
    end

endmodule
