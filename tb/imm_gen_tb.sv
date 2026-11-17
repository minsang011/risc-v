module imm_gen_tb;
    import rv32i_pkg::*;
    // Declaring variables and dut
    logic [31:7] instr;
    imm_type_e imm_type;
    logic [31:0] imm; 

    int error = 0;
    imm_gen dut(.*);

    // Helper task check()
    task automatic check(input logic [31:0] t_instr, input imm_type_e t_imm_type,
                         input logic [31:0] exp, input string what);
        // Drive values to DUT and wait to be updated
        instr = t_instr[31:7]; imm_type = t_imm_type;
        #1;
        if (imm !== exp) begin
            $display("ERROR, %h Type: %s, Expected: %h but actual: %h. Test: %s",
                     t_instr, t_imm_type.name(), exp, imm, what);
            error++;
        end
    endtask //automatic

    // Simulation
    initial begin
        $dumpfile("build/imm_gen_tb.vcd");
        $dumpvars(0, imm_gen_tb);

        check(32'hFFF00093, IMM_I, 32'hFFFFFFFF, "addi x1,x0,-1");
        check(32'h7FF00093, IMM_I, 32'h000007FF, "addi x1,x0,2047 (max)");
        check(32'h80000093, IMM_I, 32'hFFFFF800, "addi x1,x0,-2048 (min)");
        check(32'h00832283, IMM_I, 32'h00000008, "lw x5,8(x6)");
        check(32'hFFC100E7, IMM_I, 32'hFFFFFFFC, "jalr x1,-4(x2)");
        check(32'h40315093, IMM_I, 32'h00000403, "srai x1,x2,3 (funct7 in imm[11:5])");
        check(32'hFE732E23, IMM_S, 32'hFFFFFFFC, "sw x7,-4(x6)");
        check(32'h7E732FA3, IMM_S, 32'h000007FF, "sw x7,2047(x6) (max)");
        check(32'h80730023, IMM_S, 32'hFFFFF800, "sb x7,-2048(x6) (min)");
        check(32'h00731A23, IMM_S, 32'h00000014, "sh x7,20(x6) (imm[4:0] only)");
        check(32'h4C732923, IMM_S, 32'h000004D2, "sw x7,1234(x6) (both fields)");
        check(32'hFE208CE3, IMM_B, 32'hFFFFFFF8, "beq -8 (backward)");
        check(32'h00209463, IMM_B, 32'h00000008, "bne +8");
        check(32'h7E20CFE3, IMM_B, 32'h00000FFE, "blt +4094 (max)");
        check(32'h8020D063, IMM_B, 32'hFFFFF000, "bge -4096 (min)");
        check(32'h0020E0E3, IMM_B, 32'h00000800, "bltu +2048 (imm[11] from instr[7])");
        check(32'h0020FF63, IMM_B, 32'h0000001E, "bgeu +30");
        check(32'hFFFFF0B7, IMM_U, 32'hFFFFF000, "lui 0xFFFFF");
        check(32'h123450B7, IMM_U, 32'h12345000, "lui 0x12345");
        check(32'h80000097, IMM_U, 32'h80000000, "auipc 0x80000");
        check(32'h00001097, IMM_U, 32'h00001000, "auipc 0x1");
        check(32'h008000EF, IMM_J, 32'h00000008, "jal +8");
        check(32'hFF9FF0EF, IMM_J, 32'hFFFFFFF8, "jal -8 (backward)");
        check(32'h7FFFF06F, IMM_J, 32'h000FFFFE, "jal +1048574 (max)");
        check(32'h8000006F, IMM_J, 32'hFFF00000, "jal -1048576 (min)");
        check(32'h001000EF, IMM_J, 32'h00000800, "jal +2048 (imm[11] from instr[20])");
        check(32'h344120EF, IMM_J, 32'h00012344, "jal +0x12344");

        if (error == 0) begin
            $display("PASS imm_gen_tb");
        end else begin
            $fatal(1, "imm_gen_tb: %0d check(s) failed", error);
        end

        $finish();
    end

    
endmodule
