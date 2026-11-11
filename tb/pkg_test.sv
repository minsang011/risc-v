// pkg_test.sv - Task 1.1 unit test for rv32i_pkg
//
// Checks that the package compiles and imports on both simulators, and that every
// opcode / funct3 / funct7 constant matches the field of a real RV32I encoding.
// Expected words were encoded from the RV32I listing (spec pp. 585-586).
// Before trusting them, confirm a few against your own objdump output.
//
// Run:  make unit TB=pkg_test TOOL=icarus
//       make unit TB=pkg_test TOOL=verilator
//       make lint TB=pkg_test

module pkg_test;
  import rv32i_pkg::*;

  int errors = 0;

  // ------------------------------------------------------------------
  // Field checkers: compare one instruction field against a package
  // constant. !== so an X/Z constant counts as a mismatch.
  // ------------------------------------------------------------------
  task automatic chk_opc(input string name, input logic [31:0] instr,
                         input logic [6:0] exp);
    if (instr[6:0] !== exp) begin
      $display("FAIL %s (%h) opcode: instr[6:0]=%b, constant=%b", name, instr, instr[6:0], exp);
      errors++;
    end
  endtask

  task automatic chk_f3(input string name, input logic [31:0] instr,
                        input logic [2:0] exp);
    if (instr[14:12] !== exp) begin
      $display("FAIL %s (%h) funct3: instr[14:12]=%b, constant=%b", name, instr, instr[14:12], exp);
      errors++;
    end
  endtask

  task automatic chk_f7(input string name, input logic [31:0] instr,
                        input logic [6:0] exp);
    if (instr[31:25] !== exp) begin
      $display("FAIL %s (%h) funct7: instr[31:25]=%b, constant=%b", name, instr, instr[31:25], exp);
      errors++;
    end
  endtask

  // ------------------------------------------------------------------
  // Exercises a case statement on the enum type, the same way the ALU
  // will. Returns the member's position, or -1 if no arm matched.
  // ------------------------------------------------------------------
  function automatic int op_index(input alu_op_e op);
    case (op)
      ALU_ADD:  return 0;
      ALU_SUB:  return 1;
      ALU_SLL:  return 2;
      ALU_SLT:  return 3;
      ALU_SLTU: return 4;
      ALU_XOR:  return 5;
      ALU_SRL:  return 6;
      ALU_SRA:  return 7;
      ALU_OR:   return 8;
      ALU_AND:  return 9;
      default:  return -1;
    endcase
  endfunction

  task automatic chk_op(input string name, input alu_op_e op, input int exp);
    if (op_index(op) != exp) begin
      $display("FAIL alu_op_e %s: case arm %0d, expected %0d", name, op_index(op), exp);
      errors++;
    end
  endtask

  initial begin
    // ---------------- Widths ----------------
    if (XLEN != 32) begin
      $display("FAIL XLEN = %0d, expected 32", XLEN);
      errors++;
    end
    if ($bits(alu_op_e) != 4) begin
      $display("FAIL alu_op_e is %0d bits, expected 4", $bits(alu_op_e));
      errors++;
    end

    // ---------------- Opcodes: one instruction per major opcode ----------------
    chk_opc("lw x5,0(x6)",     32'h00032283, OPC_LOAD);
    chk_opc("fence",           32'h0ff0000f, OPC_MISCMEM);
    chk_opc("addi x1,x0,-1",   32'hfff00093, OPC_OPIMM);
    chk_opc("auipc x1,0x1",    32'h00001097, OPC_AUIPC);
    chk_opc("sw x7,4(x6)",     32'h00732223, OPC_STORE);
    chk_opc("add x3,x1,x2",    32'h002081b3, OPC_OP);
    chk_opc("lui x1,0x12345",  32'h123450b7, OPC_LUI);
    chk_opc("beq x1,x2,+8",    32'h00208463, OPC_BRANCH);
    chk_opc("jalr x1,0(x2)",   32'h000100e7, OPC_JALR);
    chk_opc("jal x1,+8",       32'h008000ef, OPC_JAL);
    chk_opc("ecall",           32'h00000073, OPC_SYSTEM);

    // ---------------- funct3: branch ----------------
    chk_f3("beq",  32'h00208463, F3_BR_BEQ);
    chk_f3("bne",  32'h00209463, F3_BR_BNE);
    chk_f3("blt",  32'h0020c463, F3_BR_BLT);
    chk_f3("bge",  32'h0020d463, F3_BR_BGE);
    chk_f3("bltu", 32'h0020e463, F3_BR_BLTU);
    chk_f3("bgeu", 32'h0020f463, F3_BR_BGEU);

    // ---------------- funct3: load ----------------
    chk_f3("lb",  32'h00030283, F3_LD_LB);
    chk_f3("lh",  32'h00031283, F3_LD_LH);
    chk_f3("lw",  32'h00032283, F3_LD_LW);
    chk_f3("lbu", 32'h00034283, F3_LD_LBU);
    chk_f3("lhu", 32'h00035283, F3_LD_LHU);

    // ---------------- funct3: store ----------------
    chk_f3("sb", 32'h00730223, F3_ST_SB);
    chk_f3("sh", 32'h00731223, F3_ST_SH);
    chk_f3("sw", 32'h00732223, F3_ST_SW);

    // ---------------- funct3: ALU, OP (R-type) ----------------
    chk_f3("add",  32'h002081b3, F3_ALU_ADDSUB);
    chk_f3("sub",  32'h402081b3, F3_ALU_ADDSUB);
    chk_f3("sll",  32'h002091b3, F3_ALU_SLL);
    chk_f3("slt",  32'h0020a1b3, F3_ALU_SLT);
    chk_f3("sltu", 32'h0020b1b3, F3_ALU_SLTU);
    chk_f3("xor",  32'h0020c1b3, F3_ALU_XOR);
    chk_f3("srl",  32'h0020d1b3, F3_ALU_SRLSRA);
    chk_f3("sra",  32'h4020d1b3, F3_ALU_SRLSRA);
    chk_f3("or",   32'h0020e1b3, F3_ALU_OR);
    chk_f3("and",  32'h0020f1b3, F3_ALU_AND);

    // ---------------- funct3: ALU, OP-IMM shares the same values ----------------
    chk_f3("addi", 32'hfff00093, F3_ALU_ADDSUB);
    chk_f3("srai", 32'h40315093, F3_ALU_SRLSRA);

    // ---------------- funct7 ----------------
    chk_f7("add",  32'h002081b3, F7_ALU_ADDSRL);
    chk_f7("sub",  32'h402081b3, F7_ALU_SUBSRA);
    chk_f7("srl",  32'h0020d1b3, F7_ALU_ADDSRL);
    chk_f7("sra",  32'h4020d1b3, F7_ALU_SUBSRA);
    chk_f7("srai", 32'h40315093, F7_ALU_SUBSRA);

    // ---------------- ALU-op enum: every member reaches its own case arm ----------------
    chk_op("ALU_ADD",  ALU_ADD,  0);
    chk_op("ALU_SUB",  ALU_SUB,  1);
    chk_op("ALU_SLL",  ALU_SLL,  2);
    chk_op("ALU_SLT",  ALU_SLT,  3);
    chk_op("ALU_SLTU", ALU_SLTU, 4);
    chk_op("ALU_XOR",  ALU_XOR,  5);
    chk_op("ALU_SRL",  ALU_SRL,  6);
    chk_op("ALU_SRA",  ALU_SRA,  7);
    chk_op("ALU_OR",   ALU_OR,   8);
    chk_op("ALU_AND",  ALU_AND,  9);

    // ---------------- Result ----------------
    if (errors == 0) $display("PASS pkg_test");
    else             $fatal(1, "pkg_test: %0d check(s) failed", errors);
    $finish;
  end

endmodule
