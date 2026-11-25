module comparator 
    import rv32i_pkg::*;
    (
        input logic [31:0] rs1_data,
        input logic [31:0] rs2_data,
        input logic [2:0] funct3,
        output logic branch
    );

    always_comb begin
        case (funct3)
            F3_BR_BEQ: branch = (rs1_data == rs2_data) ? 1'b1 : 1'b0;
            F3_BR_BNE: branch = (rs1_data != rs2_data) ? 1'b1 : 1'b0;
            F3_BR_BLT: branch = (signed'(rs1_data) < signed'(rs2_data)) ? 1'b1 : 1'b0;
            F3_BR_BGE: branch = (signed'(rs1_data) >= signed'(rs2_data)) ? 1'b1 : 1'b0;
            F3_BR_BLTU: branch = (rs1_data < rs2_data) ? 1'b1 : 1'b0;
            F3_BR_BGEU: branch = (rs1_data >= rs2_data) ? 1'b1 : 1'b0;

            default: branch = 1'b0;
        endcase
    end

endmodule
