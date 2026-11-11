module alu
    import rv32i_pkg::*;
    (
        input logic [31:0] a,
        input logic [31:0] b,
        input alu_op_e op,
        output logic [31:0] result
    );

    always_comb begin
        case(op) 
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_SLL: result = a << b[4:0];
            ALU_SLT: result = ($signed(a)<$signed(b)) ? 1 : 0;
            ALU_SLTU: result = ($unsigned(a)<$unsigned(b)) ? 1 : 0;
            ALU_XOR: result = a ^ b;
            ALU_SRL: result = a >> b[4:0];
            ALU_SRA: result = $signed(a) >>> b[4:0];
            ALU_OR: result = a | b;
            ALU_AND: result = a & b;

            default: result = 'd0; // 'd10-15 not used
        endcase
    end


endmodule
