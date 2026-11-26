module dmem #(
    parameter DEPTH = 4096 // size of mem is 16KiB (4 bytes * 4096)
)   (
        input logic we, re, // mem_write and mem_read signal from decoder
        input logic clk,
        input logic [2:0] funct3,
        input logic [31:0] wdata, // sr2 data when store
        input logic [31:0] addr, // rs1 + imm from ALU
        output logic [31:0] rdata, 
        output logic misaligned, // flag for when there is misalinged address
        output logic out_of_range // flag that memory address is out or range
    );
    import rv32i_pkg::*;

// ---------------------------- Diagram of RAM ---------------------
//
//                  32 bit lines (one per bit of a word)
//                  │ │ │ │ ... │ │ │ │
//  row index ──▶ ┌───────────────────────┐
//  (addr[13:2])  │ row 0:  32 bits        │
//    decoder ───▶│ row 1:  32 bits        │
//   turns on     │ row 2:  32 bits ◀──────── selected row
//   ONE row      │ ...                    │
//                │ row 4095: 32 bits      │
//                └───────────────────────┘
//                  ▼ ▼ ▼ ▼ ... ▼ ▼ ▼ ▼
//                  32 bits out, all at once
//
// ------------------------------------------------------------------

// ------------------------------------------------------------------
// Address split and load alignment
//
//   addr = rs1 + imm  (full byte address from the ALU, used for loads AND stores)
//
//   addr bits:  [31:14]  unused (beyond 16 KiB)
//               [13:2]   idx = row (word) number   = addr / 4
//               [1:0]    off = byte lane in the row = addr % 4
//
//   off comes ONLY from the address, never from the operation.
//   It is the remainder of the WHOLE address (rs1 + imm), not of imm alone:
//     lh x5, 2(x10) with x10 = 0x102 -> addr 0x104 -> off = 0
//
//   Which lanes each access uses (little-endian: lane 0 = bits [7:0]):
//
//     off | word (lw/sw) | half (lh/lhu/sh) | byte (lb/lbu/sb)
//     ----+--------------+------------------+-----------------
//      0  | lanes 0-3    | lanes 0-1        | lane 0
//      1  | misaligned   | misaligned       | lane 1
//      2  | misaligned   | lanes 2-3        | lane 2
//      3  | misaligned   | misaligned       | lane 3
//
//   For every ALIGNED access, off is exactly the lane where the data starts.
//   So shifting the row right by 8*off puts the wanted data at bit 0:
//     byte -> shifted[7:0]   (sign bit shifted[7])
//     half -> shifted[15:0]  (sign bit shifted[15])
//     word -> shifted[31:0]  (off is always 0, so the shift does nothing)
//   Misaligned cells are caught by the misaligned flag (fatal error).
// ------------------------------------------------------------------

    // Index total reachable addresses
    localparam int IDX_W = $clog2(DEPTH); 

    logic [31:0] mem [0:DEPTH-1]; // 32 bits == 4 bytes == 1 word. 1 word per row. 
    logic [IDX_W-1:0] idx; // Tell at which row this address is located
    logic [1:0] off; // 4 bytes(1 word) per row, used it to choose what byte to use

    assign idx = addr[IDX_W+1:2]; // Tell at which row that the data of this addr is mapped
    assign off = addr[1:0]; // Choosing one from it
    assign out_of_range = (we||re) && |addr[31:IDX_W+2];
    // misaligned can be determined only by off value. Applies both load and store
    assign misaligned = (we||re) && ((funct3[1:0]==2'b10 && off!=0)     // Word
                        || (funct3[1:0]==2'b01 && off[0])); // Half


    logic [31:0] shifted;

    always_comb begin
        shifted = mem[idx] >> (8 * off); // Take a look at the diagram aboe if not understandable
        if (misaligned || out_of_range) rdata = '0;
        else begin
            case (funct3)
                F3_LD_LB: rdata = {{24{shifted[7]}}, shifted[7:0]};
                F3_LD_LH: rdata = {{16{shifted[15]}}, shifted[15:0]};
                F3_LD_LW: rdata = shifted;
                F3_LD_LBU: rdata = {24'(0), shifted[7:0]};
                F3_LD_LHU: rdata = {16'(0), shifted[15:0]};
                default: rdata = '0;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (we && !misaligned && !out_of_range) begin
            case (funct3)
                F3_ST_SB: mem[idx][8*off +: 8] <= wdata[7:0];
                F3_ST_SH: mem[idx][8*off +: 16] <= wdata[15:0];
                F3_ST_SW: mem[idx] <= wdata;
                default: ;
            endcase
        end
    end
    
endmodule
