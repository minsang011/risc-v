module imem #(
    parameter DEPTH = 4096,
    parameter INIT_FILE = ""
)   (   
        // We are not using the upper bits in this depth, so need to make an exception
        /* verilator lint_off UNUSEDSIGNAL */
        input logic [31:0] pc,
        /* verilator lint_on UNUSEDSIGNAL */
        output logic [31:0] instr
    );
    
    localparam int IDX_W = $clog2(DEPTH);

    // From the decision, our memory starts at 0x00000000
    logic [31:0] mem [0:DEPTH-1];
    logic [11:0] idx;
    
    assign idx = pc[IDX_W+1:2];

    always_comb begin 
        instr = mem[idx];
    end

    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

endmodule

