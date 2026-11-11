// rv32i_pkg.sv - shared ISA constants and types for the RV32I core
// Source: RISC-V Unprivileged ISA (20260120), Table 72 (p. 584),
//         RV32I listing (pp. 585-586)

package rv32i_pkg;
  // Each module imports this package but uses only some of its constants,
  // so unused-parameter warnings here are expected.
  
  /* verilator lint_off UNUSEDPARAM */

  // ----------------------------------------------------------------
  // 1. Widths
  // ----------------------------------------------------------------
  localparam int XLEN = 32;

  // ----------------------------------------------------------------
  // 2. Major opcodes: instr[6:0]  (Table 72)
  // ----------------------------------------------------------------
  localparam logic [6:0] OPC_LOAD = 7'b0000011;
  localparam logic [6:0] OPC_MISCMEM = 7'b0001111;
  localparam logic [6:0] OPC_OPIMM = 7'b0010011;
  localparam logic [6:0] OPC_AUIPC = 7'b0010111;
  localparam logic [6:0] OPC_STORE = 7'b0100011;
  localparam logic [6:0] OPC_OP = 7'b0110011;
  localparam logic [6:0] OPC_LUI = 7'b0110111;
  localparam logic [6:0] OPC_BRANCH = 7'b1100011;
  localparam logic [6:0] OPC_JALR = 7'b1100111;
  localparam logic [6:0] OPC_JAL = 7'b1101111;
  localparam logic [6:0] OPC_SYSTEM = 7'b1110011;

  // ----------------------------------------------------------------
  // 3. funct3: instr[14:12]  (pp. 585-586)
  //    Prefix by group: the same bit patterns repeat across groups.
  // ----------------------------------------------------------------
  // Branch
  localparam logic [2:0] F3_BR_BEQ = 3'b000;
  localparam logic [2:0] F3_BR_BNE = 3'b001;
  localparam logic [2:0] F3_BR_BLT = 3'b100;
  localparam logic [2:0] F3_BR_BGE = 3'b101;
  localparam logic [2:0] F3_BR_BLTU = 3'b110;
  localparam logic [2:0] F3_BR_BGEU = 3'b111;

  // Load
  localparam logic [2:0] F3_LD_LB = 3'b000;
  localparam logic [2:0] F3_LD_LH = 3'b001;
  localparam logic [2:0] F3_LD_LW = 3'b010;
  localparam logic [2:0] F3_LD_LBU = 3'b100;
  localparam logic [2:0] F3_LD_LHU = 3'b101;

  // Store
  localparam logic [2:0] F3_ST_SB = 3'b000;
  localparam logic [2:0] F3_ST_SH = 3'b001;
  localparam logic [2:0] F3_ST_SW = 3'b010;

  // ALU (shared by OP and OP-IMM)
  localparam logic [2:0] F3_ALU_ADDSUB = 3'b000;
  localparam logic [2:0] F3_ALU_SLL = 3'b001;
  localparam logic [2:0] F3_ALU_SLT = 3'b010;
  localparam logic [2:0] F3_ALU_SLTU = 3'b011;
  localparam logic [2:0] F3_ALU_XOR = 3'b100;
  localparam logic [2:0] F3_ALU_SRLSRA = 3'b101;
  localparam logic [2:0] F3_ALU_OR = 3'b110;
  localparam logic [2:0] F3_ALU_AND = 3'b111;

  // ----------------------------------------------------------------
  // 4. funct7: instr[31:25]
  // ----------------------------------------------------------------
  localparam logic [6:0] F7_ALU_ADDSRL = 7'b0000000;
  localparam logic [6:0] F7_ALU_SUBSRA = 7'b0100000;


  // ----------------------------------------------------------------
  // 5. ALU operation (internal encoding, not defined by the ISA)
  // ----------------------------------------------------------------
  //typedef enum logic [3:0] { ALU_ADD } alu_op_e;
  // │       │    │     │       │          └─ 5. Type Identifier (The name of the type)
  // │       │    │     │       └─ 4. Enum Members / Labels (The names for the states)
  // │       │    │     └─ 3. Bit-Width Range (Total size allocation)
  // │       │    └─ 2. Base Data Type (Hardware simulation type)
  // │       └─ 1. Core Construct Type (Tells it to make a list of labels)
  // └─ Keyword (Tells the compiler: "We are defining a reusable custom type nickname")

  typedef enum logic [3:0] {
    ALU_ADD,
    ALU_SUB,
    ALU_SLL,
    ALU_SLT,
    ALU_SLTU,
    ALU_XOR,
    ALU_SRL,
    ALU_SRA, 
    ALU_OR,
    ALU_AND
  } alu_op_e;

  /* verilator lint_on UNUSEDPARAM */

endpackage : rv32i_pkg
