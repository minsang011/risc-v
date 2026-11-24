// decoder_tb.sv - table-driven test for the decoder (task 1.9)
//
// One row per instruction: a real encoding (from the assembler) and the full
// expected control vector, taken from the control table / spec, not from decoder.sv.
// Signals that don't matter for an instruction are expected at the decoder's
// default (no-op) value, as the control table specifies.
// After the table, random instruction words check properties that must hold for
// ANY input: no X outputs, illegal => all defaults, no impossible combinations.

module decoder_tb;
    import rv32i_pkg::*;

    localparam logic Y = 1'b1;
    localparam logic N = 1'b0;

    // DUT signals
    logic [31:0] instr;
    logic        reg_write, alu_src_a, alu_src_b, mem_read, mem_write;
    logic        branch, jump, jalr, halt, illegal;
    alu_op_e     alu_op;
    imm_type_e   imm_type;
    wb_sel_e     wb_sel;

    int error = 0;

    decoder dut (.*);

    // All outputs packed into one vector, in this order
    typedef logic [18:0] ctrl_t;

    function automatic ctrl_t vec(input logic      rw, a, b,
                                  input alu_op_e   op,
                                  input imm_type_e imm,
                                  input logic      mr, mw,
                                  input wb_sel_e   wb,
                                  input logic      br, j, jr, h, il);
        return {rw, a, b, op, imm, mr, mw, wb, br, j, jr, h, il};
    endfunction

    function automatic ctrl_t got_vec();
        return {reg_write, alu_src_a, alu_src_b, alu_op, imm_type, mem_read, mem_write,
                wb_sel, branch, jump, jalr, halt, illegal};
    endfunction

    // Print a control vector field by field
    task automatic show(input string label, input ctrl_t v);
        alu_op_e   s_op;
        imm_type_e s_imm;
        wb_sel_e   s_wb;
        s_op  = alu_op_e'(v[15:12]);
        s_imm = imm_type_e'(v[11:9]);
        s_wb  = wb_sel_e'(v[6:5]);
        $display("    %s rw=%b a=%s b=%s op=%s imm=%s mr=%b mw=%b wb=%s br=%b j=%b jalr=%b halt=%b ill=%b",
                 label, v[18], v[17] ? "PC " : "RS1", v[16] ? "IMM" : "RS2",
                 s_op.name(), s_imm.name(), v[8], v[7], s_wb.name(),
                 v[4], v[3], v[2], v[1], v[0]);
    endtask

    // Drive one instruction and compare every output
    task automatic check(input logic [31:0] word, input ctrl_t exp, input string what);
        ctrl_t got;
        instr = word;
        #1;
        got = got_vec();
        if (got !== exp) begin
            $display("ERROR %s (%h)", what, word);
            show("got:", got);
            show("exp:", exp);
            error++;
        end
    endtask

    // One of the 11 RV32I opcodes, for random words that reach the real decode arms
    function automatic logic [6:0] pick_opcode(input int k);
        case (k)
            0:       return OPC_LUI;
            1:       return OPC_AUIPC;
            2:       return OPC_JAL;
            3:       return OPC_JALR;
            4:       return OPC_BRANCH;
            5:       return OPC_LOAD;
            6:       return OPC_STORE;
            7:       return OPC_OPIMM;
            8:       return OPC_OP;
            9:       return OPC_MISCMEM;
            default: return OPC_SYSTEM;
        endcase
    endfunction

    initial begin
        ctrl_t got;

        $dumpfile("build/decoder_tb.vcd");
        $dumpvars(0, decoder_tb);

        //                                rw  alu_src_a   alu_src_b   alu_op     imm    mr mw wb_sel  br j  jr h  il
        // ---- All 37 user-level RV32I instructions + FENCE, ECALL, EBREAK, NOP ----
        check(32'h123450B7, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_U, N, N, WB_IMM, N, N, N, N, N), "lui ra, 0x12345");
        check(32'h00001097, vec(Y, ALU_A_PC,  ALU_B_IMM, ALU_ADD,  IMM_U, N, N, WB_ALU, N, N, N, N, N), "auipc ra, 0x1");
        check(32'h008000EF, vec(Y, ALU_A_PC,  ALU_B_IMM, ALU_ADD,  IMM_J, N, N, WB_PC4, N, Y, N, N, N), "jal ra, 0x10 <_start+0x10>");
        check(32'h004100E7, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_I, N, N, WB_PC4, N, Y, Y, N, N), "jalr ra, 0x4(sp)");
        check(32'h00208463, vec(N, ALU_A_PC,  ALU_B_IMM, ALU_ADD,  IMM_B, N, N, WB_ALU, Y, N, N, N, N), "beq ra, sp, 0x18 <_start+0x18>");
        check(32'h00209463, vec(N, ALU_A_PC,  ALU_B_IMM, ALU_ADD,  IMM_B, N, N, WB_ALU, Y, N, N, N, N), "bne ra, sp, 0x1c <_start+0x1c>");
        check(32'h0020C463, vec(N, ALU_A_PC,  ALU_B_IMM, ALU_ADD,  IMM_B, N, N, WB_ALU, Y, N, N, N, N), "blt ra, sp, 0x20 <_start+0x20>");
        check(32'h0020D463, vec(N, ALU_A_PC,  ALU_B_IMM, ALU_ADD,  IMM_B, N, N, WB_ALU, Y, N, N, N, N), "bge ra, sp, 0x24 <_start+0x24>");
        check(32'h0020E463, vec(N, ALU_A_PC,  ALU_B_IMM, ALU_ADD,  IMM_B, N, N, WB_ALU, Y, N, N, N, N), "bltu ra, sp, 0x28 <_start+0x28>");
        check(32'h0020F463, vec(N, ALU_A_PC,  ALU_B_IMM, ALU_ADD,  IMM_B, N, N, WB_ALU, Y, N, N, N, N), "bgeu ra, sp, 0x2c <_start+0x2c>");
        check(32'h00830283, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_I, Y, N, WB_MEM, N, N, N, N, N), "lb t0, 0x8(t1)");
        check(32'h00831283, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_I, Y, N, WB_MEM, N, N, N, N, N), "lh t0, 0x8(t1)");
        check(32'h00832283, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_I, Y, N, WB_MEM, N, N, N, N, N), "lw t0, 0x8(t1)");
        check(32'h00834283, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_I, Y, N, WB_MEM, N, N, N, N, N), "lbu t0, 0x8(t1)");
        check(32'h00835283, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_I, Y, N, WB_MEM, N, N, N, N, N), "lhu t0, 0x8(t1)");
        check(32'h00730223, vec(N, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_S, N, Y, WB_ALU, N, N, N, N, N), "sb t2, 0x4(t1)");
        check(32'h00731223, vec(N, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_S, N, Y, WB_ALU, N, N, N, N, N), "sh t2, 0x4(t1)");
        check(32'h00732223, vec(N, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_S, N, Y, WB_ALU, N, N, N, N, N), "sw t2, 0x4(t1)");
        check(32'hFFF10093, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "addi ra, sp, -0x1");
        check(32'hFFF12093, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_SLT,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "slti ra, sp, -0x1");
        check(32'hFFF13093, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_SLTU, IMM_I, N, N, WB_ALU, N, N, N, N, N), "sltiu ra, sp, -0x1");
        check(32'hFFF14093, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_XOR,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "xori ra, sp, -0x1");
        check(32'hFFF16093, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_OR,   IMM_I, N, N, WB_ALU, N, N, N, N, N), "ori ra, sp, -0x1");
        check(32'hFFF17093, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_AND,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "andi ra, sp, -0x1");
        check(32'h01F11093, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_SLL,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "slli ra, sp, 0x1f");
        check(32'h01F15093, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_SRL,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "srli ra, sp, 0x1f");
        check(32'h41F15093, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_SRA,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "srai ra, sp, 0x1f");
        check(32'h002081B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "add gp, ra, sp");
        check(32'h402081B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_SUB,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "sub gp, ra, sp");
        check(32'h002091B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_SLL,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "sll gp, ra, sp");
        check(32'h0020A1B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_SLT,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "slt gp, ra, sp");
        check(32'h0020B1B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_SLTU, IMM_I, N, N, WB_ALU, N, N, N, N, N), "sltu gp, ra, sp");
        check(32'h0020C1B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_XOR,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "xor gp, ra, sp");
        check(32'h0020D1B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_SRL,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "srl gp, ra, sp");
        check(32'h4020D1B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_SRA,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "sra gp, ra, sp");
        check(32'h0020E1B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_OR,   IMM_I, N, N, WB_ALU, N, N, N, N, N), "or gp, ra, sp");
        check(32'h0020F1B3, vec(Y, ALU_A_RS1, ALU_B_RS2, ALU_AND,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "and gp, ra, sp");
        check(32'h0FF0000F, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "fence iorw, iorw");
        check(32'h00000073, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, Y, N), "ecall");
        check(32'h00100073, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, Y, N), "ebreak");
        check(32'h00000013, vec(Y, ALU_A_RS1, ALU_B_IMM, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "addi zero, zero, 0x0");

        // ---- FENCE variants: all must decode as a NOP (spec 2.7) ----
        check(32'h8330000F, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "fence_tso");
        check(32'h0100000F, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "pause");
        check(32'h7FF0000F, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "fence_resv_fm");
        check(32'h0FF2828F, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "fence_rs1_rd");
        check(32'h0000000F, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, N), "fence_null");

        // ---- Illegal encodings: unused opcodes, bad funct3/funct7, other extensions ----
        check(32'h00000000, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_zero");
        check(32'hFFFFFFFF, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_ones");
        check(32'h00000001, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_compressed");
        check(32'h0000000B, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_custom0");
        check(32'h0820A1AF, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_amo");
        check(32'h002081BB, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_op32");
        check(32'h004110E7, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_jalr_f3");
        check(32'h0020A463, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_br_f3_010");
        check(32'h0020B463, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_br_f3_011");
        check(32'h00833283, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_ld");
        check(32'h00836283, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_lwu");
        check(32'h00837283, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_ld_f3_111");
        check(32'h00733223, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_sd");
        check(32'h00734223, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_st_f3_100");
        check(32'h03F11093, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_slli_f7");
        check(32'h03F15093, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_srli_f7");
        check(32'h43F15093, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_srai_f7");
        check(32'h022081B3, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_mul");
        check(32'h0220C1B3, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_div");
        check(32'h402091B3, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_sll_f7");
        check(32'h4020F1B3, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_and_f7");
        check(32'h042081B3, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_add_f7");
        check(32'h0000100F, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_fence_i");
        check(32'h0FF0200F, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_miscmem_f3");
        check(32'h30029073, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_csrrw");
        check(32'h30200073, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_mret");
        check(32'h10500073, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_wfi");
        check(32'h000000F3, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_ecall_rd");
        check(32'h00008073, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_ecall_rs1");
        check(32'h001000F3, vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD,  IMM_I, N, N, WB_ALU, N, N, N, N, Y), "ill_ebreak_rd");

        // ---- Random properties: 20,000 words, half with a valid opcode ----
        for (int n = 0; n < 20000; n++) begin
            instr = $urandom();
            if (n % 2 == 0) instr[6:0] = pick_opcode($urandom_range(0, 10));
            #1;
            got = got_vec();

            if ((^got) === 1'bx) begin
                $display("ERROR random %h: X on an output", instr);  show("got:", got);  error++;
            end
            if (illegal && got !== vec(N, ALU_A_RS1, ALU_B_RS2, ALU_ADD, IMM_I, N, N, WB_ALU, N, N, N, N, Y)) begin
                $display("ERROR random %h: illegal but outputs not all default", instr);  show("got:", got);  error++;
            end
            if (reg_write && mem_write) begin
                $display("ERROR random %h: writes both a register and memory", instr);  show("got:", got);  error++;
            end
            if (branch && jump) begin
                $display("ERROR random %h: both branch and jump", instr);  show("got:", got);  error++;
            end
            if (halt && (reg_write || mem_write || branch || jump)) begin
                $display("ERROR random %h: halt with side effects", instr);  show("got:", got);  error++;
            end
        end

        if (error == 0) $display("PASS decoder_tb");
        else            $fatal(1, "decoder_tb: %0d check(s) failed", error);
        $finish;
    end

endmodule
