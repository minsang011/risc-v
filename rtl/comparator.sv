module comparator 
    import rv32i_pkg::*;
    (
        input logic [31:0] rs1_data,
        input logic [31:0] rs2_data,
        input logic [2:0] funct3,
        output logic taken
    );

    always_comb begin
        case (funct3)
            F3_BR_BEQ: taken = (rs1_data == rs2_data) ? 1'b1 : 1'b0;
            F3_BR_BNE: taken = (rs1_data != rs2_data) ? 1'b1 : 1'b0;
            F3_BR_BLT: taken = (signed'(rs1_data) < signed'(rs2_data)) ? 1'b1 : 1'b0;
            F3_BR_BGE: taken = (signed'(rs1_data) >= signed'(rs2_data)) ? 1'b1 : 1'b0;
            F3_BR_BLTU: taken = (rs1_data < rs2_data) ? 1'b1 : 1'b0;
            F3_BR_BGEU: taken = (rs1_data >= rs2_data) ? 1'b1 : 1'b0;

            default: taken = 1'b0;
        endcase
    end

endmodule
