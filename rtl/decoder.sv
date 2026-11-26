// decoder.sv - RV32I decoder / main control (task 1.8)
//
// Turns one instruction into every control signal for the single-cycle datapath.
// Structure: (1) defaults = a harmless no-op, (2) override per opcode, with
// funct3/funct7 checks inside, (3) if the instruction is illegal, force every
// output back to its default so an illegal instruction cannot change any state.
//
// Operand-select encoding (from rv32i_pkg):
//   alu_src_a: ALU_A_RS1 (0) = rs1,  ALU_A_PC  (1) = PC
//   alu_src_b: ALU_B_RS2 (0) = rs2,  ALU_B_IMM (1) = immediate
//
// Branch and JAL targets are computed by the ALU (PC + imm); JALR's by rs1 + imm.
// The branch comparator reads rs1/rs2 directly, so the ALU is free for the target.
// Load/store width and branch condition are funct3, wired directly from instr[14:12].

//           ┌──────────────── next-PC logic ◀── branch, jump, jalr (+ comparator result)
//           ▼
//  PC ──▶ IMEM ──instr──▶ DECODER ──▶ (all control signals)
//  │                         │
//  │                    ┌────┴─────┐
//  │        instr ────▶ │ imm_gen  │◀── imm_type
//  │                    └────┬─────┘
//  │                         imm
//  │   ┌──────────┐          │
//  │   │ register │ rdata1 ─▶[mux A]◀── alu_src_a  (rs1 or PC)
//  └──▶│   file   │             │
//      │          │ rdata2 ─▶[mux B]◀── alu_src_b  (rs2 or imm)
//      │◀reg_write│             │
//      └────▲─────┘          ┌──▼──┐
//           │                │ ALU │◀── alu_op
//           │                └──┬──┘
//           │                   │ result (= address for loads/stores)
//           │              ┌────▼─────┐
//           │              │ data mem │◀── mem_read, mem_write
//           │              └────┬─────┘
//           │                   │
//           └────────────── [wb mux]◀── wb_sel  (ALU / MEM / PC+4 / IMM)

//  halt logic ◀── halt, illegal

module decoder
    import rv32i_pkg::*;
    (
        input  logic [XLEN-1:0] instr,
        output logic            reg_write,
        output logic            alu_src_a,
        output logic            alu_src_b,
        output alu_op_e         alu_op,
        output imm_type_e       imm_type,
        output logic            mem_read,
        output logic            mem_write,
        output wb_sel_e         wb_sel,
        output logic            branch,
        output logic            jump,
        output logic            jalr,
        output logic            halt,
        output logic            illegal
    );

    // Exact encodings of the only two valid SYSTEM instructions (spec 2.8)
    localparam logic [31:0] INSTR_ECALL  = 32'h0000_0073;
    localparam logic [31:0] INSTR_EBREAK = 32'h0010_0073;

    // Instruction fields
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    always_comb begin
        // ---------------- 1. Defaults: a no-op ----------------
        reg_write = 1'b0;
        alu_src_a = ALU_A_RS1;
        alu_src_b = ALU_B_RS2;
        alu_op    = ALU_ADD;
        imm_type  = IMM_I;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_sel    = WB_ALU;
        branch    = 1'b0;
        jump      = 1'b0;
        jalr      = 1'b0;
        halt      = 1'b0;
        illegal   = 1'b0;

        // ---------------- 2. Override per opcode ----------------
        case (opcode)
            // LUI: rd = imm (written directly, ALU not used)
            OPC_LUI: begin
                reg_write = 1'b1;
                imm_type  = IMM_U;
                wb_sel    = WB_IMM;
            end

            // AUIPC: rd = PC + imm
            OPC_AUIPC: begin
                reg_write = 1'b1;
                alu_src_a = ALU_A_PC;
                alu_src_b = ALU_B_IMM;
                imm_type  = IMM_U;
                wb_sel    = WB_ALU;
            end

            // JAL: rd = PC + 4, target = PC + imm. Every encoding is valid.
            OPC_JAL: begin
                reg_write = 1'b1;
                alu_src_a = ALU_A_PC;
                alu_src_b = ALU_B_IMM;
                imm_type  = IMM_J;
                wb_sel    = WB_PC4;
                jump      = 1'b1;
            end

            // JALR: rd = PC + 4, target = (rs1 + imm) with bit 0 cleared later
            OPC_JALR: begin
                reg_write = 1'b1;
                alu_src_b = ALU_B_IMM;
                imm_type  = IMM_I;
                wb_sel    = WB_PC4;
                jump      = 1'b1;
                jalr      = 1'b1;
                if (funct3 != 3'b000) illegal = 1'b1;
            end

            // Branches: comparator decides taken; ALU computes target = PC + imm
            OPC_BRANCH: begin
                alu_src_a = ALU_A_PC;
                alu_src_b = ALU_B_IMM;
                imm_type  = IMM_B;
                branch    = 1'b1;
                case (funct3)
                    F3_BR_BEQ, F3_BR_BNE, F3_BR_BLT,
                    F3_BR_BGE, F3_BR_BLTU, F3_BR_BGEU: ;   // valid
                    default: illegal = 1'b1;              // 010, 011
                endcase
            end

            // Loads: rd = mem[rs1 + imm]
            OPC_LOAD: begin
                reg_write = 1'b1;
                alu_src_b = ALU_B_IMM;
                imm_type  = IMM_I;
                mem_read  = 1'b1;
                wb_sel    = WB_MEM;
                case (funct3)
                    F3_LD_LB, F3_LD_LH, F3_LD_LW,
                    F3_LD_LBU, F3_LD_LHU: ;                // valid
                    default: illegal = 1'b1;              // 011, 110, 111
                endcase
            end

            // Stores: mem[rs1 + imm] = rs2 (rs2 goes to memory directly)
            OPC_STORE: begin
                alu_src_b = ALU_B_IMM;
                imm_type  = IMM_S;
                mem_write = 1'b1;
                case (funct3)
                    F3_ST_SB, F3_ST_SH, F3_ST_SW: ;        // valid
                    default: illegal = 1'b1;              // 011, 1xx
                endcase
            end

            // OP-IMM: rd = rs1 op imm. funct7 is checked ONLY for shifts;
            // for the others, instr[31:25] are immediate bits (no SUBI).
            OPC_OPIMM: begin
                reg_write = 1'b1;
                alu_src_b = ALU_B_IMM;
                imm_type  = IMM_I;
                wb_sel    = WB_ALU;
                case (funct3)
                    F3_ALU_ADDSUB: alu_op = ALU_ADD;
                    F3_ALU_SLT:    alu_op = ALU_SLT;
                    F3_ALU_SLTU:   alu_op = ALU_SLTU;
                    F3_ALU_XOR:    alu_op = ALU_XOR;
                    F3_ALU_OR:     alu_op = ALU_OR;
                    F3_ALU_AND:    alu_op = ALU_AND;
                    F3_ALU_SLL: begin
                        alu_op = ALU_SLL;
                        if (funct7 != F7_ALU_ADDSRL) illegal = 1'b1;
                    end
                    F3_ALU_SRLSRA: begin
                        if      (funct7 == F7_ALU_ADDSRL) alu_op  = ALU_SRL;
                        else if (funct7 == F7_ALU_SUBSRA) alu_op  = ALU_SRA;
                        else                              illegal = 1'b1;
                    end
                    default: illegal = 1'b1;              // unreachable: all 8 covered
                endcase
            end

            // OP: rd = rs1 op rs2. funct7 must be 0000000, or 0100000 for SUB/SRA.
            OPC_OP: begin
                reg_write = 1'b1;
                wb_sel    = WB_ALU;
                case (funct3)
                    F3_ALU_ADDSUB: begin
                        if      (funct7 == F7_ALU_ADDSRL) alu_op  = ALU_ADD;
                        else if (funct7 == F7_ALU_SUBSRA) alu_op  = ALU_SUB;
                        else                              illegal = 1'b1;
                    end
                    F3_ALU_SRLSRA: begin
                        if      (funct7 == F7_ALU_ADDSRL) alu_op  = ALU_SRL;
                        else if (funct7 == F7_ALU_SUBSRA) alu_op  = ALU_SRA;
                        else                              illegal = 1'b1;
                    end
                    F3_ALU_SLL: begin
                        alu_op = ALU_SLL;
                        if (funct7 != F7_ALU_ADDSRL) illegal = 1'b1;
                    end
                    F3_ALU_SLT: begin
                        alu_op = ALU_SLT;
                        if (funct7 != F7_ALU_ADDSRL) illegal = 1'b1;
                    end
                    F3_ALU_SLTU: begin
                        alu_op = ALU_SLTU;
                        if (funct7 != F7_ALU_ADDSRL) illegal = 1'b1;
                    end
                    F3_ALU_XOR: begin
                        alu_op = ALU_XOR;
                        if (funct7 != F7_ALU_ADDSRL) illegal = 1'b1;
                    end
                    F3_ALU_OR: begin
                        alu_op = ALU_OR;
                        if (funct7 != F7_ALU_ADDSRL) illegal = 1'b1;
                    end
                    F3_ALU_AND: begin
                        alu_op = ALU_AND;
                        if (funct7 != F7_ALU_ADDSRL) illegal = 1'b1;
                    end
                    default: illegal = 1'b1;              // unreachable: all 8 covered
                endcase
            end

            // FENCE: a no-op. Only funct3 is checked; fm, pred, succ, rs1 and rd
            // are ignored (spec 2.7), so FENCE.TSO, PAUSE and reserved variants
            // all decode the same way. funct3 001 (FENCE.I) is Zifencei, not RV32I.
            OPC_MISCMEM: begin
                if (funct3 != 3'b000) illegal = 1'b1;
            end

            // ECALL / EBREAK: halt (docs/decisions.md). Anything else under
            // SYSTEM (CSR instructions, MRET, WFI, ...) is not RV32I.
            OPC_SYSTEM: begin
                if (instr == INSTR_ECALL || instr == INSTR_EBREAK) halt    = 1'b1;
                else                                                illegal = 1'b1;
            end

            // Any other opcode: extensions, custom, reserved, compressed
            default: illegal = 1'b1;
        endcase

        // ---------------- 3. Illegal: undo every override ----------------
        // An illegal instruction must not write registers or memory or change
        // the PC. Restoring all defaults also keeps the outputs predictable.
        if (illegal) begin
            reg_write = 1'b0;
            alu_src_a = ALU_A_RS1;
            alu_src_b = ALU_B_RS2;
            alu_op    = ALU_ADD;
            imm_type  = IMM_I;
            mem_read  = 1'b0;
            mem_write = 1'b0;
            wb_sel    = WB_ALU;
            branch    = 1'b0;
            jump      = 1'b0;
            jalr      = 1'b0;
            halt      = 1'b0;
        end
    end

endmodule
