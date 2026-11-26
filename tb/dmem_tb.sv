// dmem_tb.sv - data memory unit test (task 1.12)
//
// 1. Directed, hand-calculated: every load width at every aligned byte offset,
//    LB/LBU of 0x80, SB/SH at every offset leaving the other bytes unchanged,
//    and stores using only the LOW bits of wdata (spec 2.6).
// 2. Flags: misaligned and out_of_range loads return 0, misaligned and
//    out-of-range stores are blocked, and both flags stay 0 when re = we = 0.
// 3. Random: 5,000 aligned loads/stores of every width against a byte-level
//    shadow model (a different structure from the word-based RTL).
//
// Timing: inputs change on the falling edge; stores land on the rising edge.

module dmem_tb;
    import rv32i_pkg::*;

    localparam int DEPTH      = 4096;           // must match the DUT: 16 KiB
    localparam int MODEL_SIZE = 1024;           // bytes covered by the random test

    logic        clk, we, re;
    logic [2:0]  funct3;
    logic [31:0] addr, wdata, rdata;
    logic        misaligned, out_of_range;

    int error = 0;

    dmem #(.DEPTH(DEPTH)) dut (
        .clk          (clk),
        .we           (we),
        .re           (re),
        .funct3       (funct3),
        .wdata        (wdata),
        .addr        (addr),
        .rdata        (rdata),
        .misaligned   (misaligned),
        .out_of_range (out_of_range)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    // Store: drive on a falling edge, the write lands on the next rising edge
    task automatic store(input logic [31:0] t_addr, input logic [2:0] t_f3,
                         input logic [31:0] t_data);
        @(negedge clk);
        we = 1'b1; re = 1'b0; addr = t_addr; funct3 = t_f3; wdata = t_data;
        @(negedge clk);
        we = 1'b0;
    endtask

    // Load and compare. A legal load must also raise no flags.
    task automatic expect_load(input logic [31:0] t_addr, input logic [2:0] t_f3,
                               input logic [31:0] exp, input string what);
        we = 1'b0; re = 1'b1; addr = t_addr; funct3 = t_f3;
        #1;
        if (rdata !== exp || misaligned !== 1'b0 || out_of_range !== 1'b0) begin
            $display("ERROR %s: addr=%h f3=%b rdata=%h exp=%h mis=%b oor=%b",
                     what, t_addr, t_f3, rdata, exp, misaligned, out_of_range);
            error++;
        end
        re = 1'b0;
    endtask

    // Drive one access across a rising edge and check both flags.
    // A flagged load must return 0. A flagged store must not write; the caller
    // checks that with a load afterwards.
    task automatic expect_flags(input logic t_we, input logic t_re,
                                input logic [31:0] t_addr, input logic [2:0] t_f3,
                                input logic exp_mis, input logic exp_oor,
                                input string what);
        @(negedge clk);
        we = t_we; re = t_re; addr = t_addr; funct3 = t_f3; wdata = 32'hBADBAD00;
        #1;
        if (misaligned !== exp_mis || out_of_range !== exp_oor) begin
            $display("ERROR %s: addr=%h f3=%b we=%b re=%b mis=%b exp %b, oor=%b exp %b",
                     what, t_addr, t_f3, t_we, t_re, misaligned, exp_mis, out_of_range, exp_oor);
            error++;
        end
        if (t_re && (exp_mis || exp_oor) && rdata !== 32'h0) begin
            $display("ERROR %s: flagged load returned %h, expected 0", what, rdata);
            error++;
        end
        @(negedge clk);                       // the rising edge in between must not write
        we = 1'b0; re = 1'b0;
    endtask

    // ------------------------------------------------------------------
    // Byte-level shadow model for the random test (addresses 0 .. MODEL_SIZE-1)
    // ------------------------------------------------------------------
    logic [7:0] mb [0:MODEL_SIZE-1];

    // size = funct3[1:0]: 00 byte, 01 half, 10 word
    task automatic model_store(input int a, input logic [1:0] size, input logic [31:0] d);
        mb[a] = d[7:0];
        if (size != 2'b00) mb[a+1] = d[15:8];
        if (size == 2'b10) begin
            mb[a+2] = d[23:16];
            mb[a+3] = d[31:24];
        end
    endtask

    function automatic logic [31:0] model_load(input int a, input logic [2:0] t_f3);
        case (t_f3)
            F3_LD_LB:  return {{24{mb[a][7]}}, mb[a]};
            F3_LD_LBU: return {24'b0, mb[a]};
            F3_LD_LH:  return {{16{mb[a+1][7]}}, mb[a+1], mb[a]};
            F3_LD_LHU: return {16'b0, mb[a+1], mb[a]};
            default:   return {mb[a+3], mb[a+2], mb[a+1], mb[a]};   // LW
        endcase
    endfunction

    // Random aligned address for a size: funct3[1:0] = 00 byte, 01 half, 10 word
    function automatic int rand_addr(input logic [1:0] size);
        int a;
        a = int'($urandom_range(0, MODEL_SIZE - 1));
        if (size == 2'b01) a = a & ~1;
        if (size == 2'b10) a = a & ~3;
        return a;
    endfunction

    function automatic logic [2:0] rand_load_f3();
        case ($urandom_range(0, 4))
            0:       return F3_LD_LB;
            1:       return F3_LD_LH;
            2:       return F3_LD_LW;
            3:       return F3_LD_LBU;
            default: return F3_LD_LHU;
        endcase
    endfunction

    function automatic logic [2:0] rand_store_f3();
        case ($urandom_range(0, 2))
            0:       return F3_ST_SB;
            1:       return F3_ST_SH;
            default: return F3_ST_SW;
        endcase
    endfunction

    // ------------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------------
    initial begin
        int          a;
        logic [2:0]  f;
        logic [31:0] d;

        we = 1'b0; re = 1'b0; addr = '0; funct3 = '0; wdata = '0;

        $dumpfile("build/dmem_tb.vcd");
        $dumpvars(0, dmem_tb);

        // ---- 1. Every load width at every aligned offset of one word ----
        //      word at 0x100 = 0x80FF1234: bytes 0x103..0x100 = 80 FF 12 34
        store(32'h100, F3_ST_SW, 32'h80FF1234);
        expect_load(32'h100, F3_LD_LW,  32'h80FF1234, "LW");
        expect_load(32'h100, F3_LD_LB,  32'h00000034, "LB  off 0");
        expect_load(32'h101, F3_LD_LB,  32'h00000012, "LB  off 1");
        expect_load(32'h102, F3_LD_LB,  32'hFFFFFFFF, "LB  off 2 (0xFF sign-extends)");
        expect_load(32'h103, F3_LD_LB,  32'hFFFFFF80, "LB  of 0x80 -> 0xFFFFFF80");
        expect_load(32'h100, F3_LD_LBU, 32'h00000034, "LBU off 0");
        expect_load(32'h101, F3_LD_LBU, 32'h00000012, "LBU off 1");
        expect_load(32'h102, F3_LD_LBU, 32'h000000FF, "LBU off 2");
        expect_load(32'h103, F3_LD_LBU, 32'h00000080, "LBU of 0x80 -> 0x00000080");
        expect_load(32'h100, F3_LD_LH,  32'h00001234, "LH  off 0");
        expect_load(32'h102, F3_LD_LH,  32'hFFFF80FF, "LH  off 2 (sign-extends)");
        expect_load(32'h100, F3_LD_LHU, 32'h00001234, "LHU off 0");
        expect_load(32'h102, F3_LD_LHU, 32'h000080FF, "LHU off 2");

        // ---- 2. SB at every offset: only that byte changes, only wdata[7:0] is used ----
        store(32'h200, F3_ST_SW, 32'h11223344);
        store(32'h200, F3_ST_SB, 32'h123456AA);
        expect_load(32'h200, F3_LD_LW, 32'h112233AA, "SB off 0 leaves other bytes");
        store(32'h201, F3_ST_SB, 32'hFFFFFFBB);
        expect_load(32'h200, F3_LD_LW, 32'h1122BBAA, "SB off 1 leaves other bytes");
        store(32'h202, F3_ST_SB, 32'h000000CC);
        expect_load(32'h200, F3_LD_LW, 32'h11CCBBAA, "SB off 2 leaves other bytes");
        store(32'h203, F3_ST_SB, 32'h7F7F7FDD);
        expect_load(32'h200, F3_LD_LW, 32'hDDCCBBAA, "SB off 3 leaves other bytes");
        expect_load(32'h203, F3_LD_LB, 32'hFFFFFFDD, "LB of the stored byte");

        // ---- 3. SH at both offsets: only that half changes, only wdata[15:0] is used ----
        store(32'h300, F3_ST_SW, 32'h11223344);
        store(32'h300, F3_ST_SH, 32'hABCD5566);
        expect_load(32'h300, F3_LD_LW,  32'h11225566, "SH off 0 leaves upper half");
        store(32'h302, F3_ST_SH, 32'h99997788);
        expect_load(32'h300, F3_LD_LW,  32'h77885566, "SH off 2 leaves lower half");
        expect_load(32'h302, F3_LD_LH,  32'h00007788, "LH of the stored half");
        expect_load(32'h300, F3_LD_LHU, 32'h00005566, "LHU of the stored half");

        // ---- 4. Last word in memory ----
        store(32'h3FFC, F3_ST_SW, 32'hCAFEF00D);
        expect_load(32'h3FFC, F3_LD_LW, 32'hCAFEF00D, "LW last word");
        expect_load(32'h3FFF, F3_LD_LB, 32'hFFFFFFCA, "LB last byte");

        // ---- 5. Misaligned loads: flag set, rdata = 0 ----
        expect_flags(1'b0, 1'b1, 32'h101, F3_LD_LW, 1'b1, 1'b0, "LW  at 0x101 misaligned");
        expect_flags(1'b0, 1'b1, 32'h102, F3_LD_LW, 1'b1, 1'b0, "LW  at 0x102 misaligned");
        expect_flags(1'b0, 1'b1, 32'h103, F3_LD_LW, 1'b1, 1'b0, "LW  at 0x103 misaligned");
        expect_flags(1'b0, 1'b1, 32'h101, F3_LD_LH, 1'b1, 1'b0, "LH  at 0x101 misaligned");
        expect_flags(1'b0, 1'b1, 32'h103, F3_LD_LH, 1'b1, 1'b0, "LH  at 0x103 misaligned");
        expect_flags(1'b0, 1'b1, 32'h101, F3_LD_LHU, 1'b1, 1'b0, "LHU at 0x101 misaligned");
        expect_flags(1'b0, 1'b1, 32'h103, F3_LD_LHU, 1'b1, 1'b0, "LHU at 0x103 misaligned");

        // ---- 6. Misaligned stores: flag set, and memory unchanged ----
        expect_flags(1'b1, 1'b0, 32'h102, F3_ST_SW, 1'b1, 1'b0, "SW at 0x102 misaligned");
        expect_load(32'h100, F3_LD_LW, 32'h80FF1234, "misaligned SW did not write");
        expect_flags(1'b1, 1'b0, 32'h301, F3_ST_SH, 1'b1, 1'b0, "SH at 0x301 misaligned");
        expect_flags(1'b1, 1'b0, 32'h303, F3_ST_SH, 1'b1, 1'b0, "SH at 0x303 misaligned");
        expect_load(32'h300, F3_LD_LW, 32'h77885566, "misaligned SH did not write");

        // ---- 7. Out of range: flag set, loads return 0, stores do not wrap around ----
        store(32'h0, F3_ST_SW, 32'h55555555);                 // 0x4000 would wrap to row 0
        expect_flags(1'b1, 1'b0, 32'h00004000, F3_ST_SW, 1'b0, 1'b1, "SW at 0x4000 out of range");
        expect_load(32'h0, F3_LD_LW, 32'h55555555, "out-of-range SW did not wrap to 0x0");
        expect_flags(1'b1, 1'b0, 32'h80000000, F3_ST_SB, 1'b0, 1'b1, "SB at 0x80000000 out of range");
        expect_load(32'h0, F3_LD_LW, 32'h55555555, "out-of-range SB did not wrap to 0x0");
        expect_flags(1'b0, 1'b1, 32'h00004000, F3_LD_LW, 1'b0, 1'b1, "LW at 0x4000 out of range");
        expect_flags(1'b0, 1'b1, 32'hFFFFFFFC, F3_LD_LW, 1'b0, 1'b1, "LW at 0xFFFFFFFC out of range");
        expect_flags(1'b0, 1'b1, 32'h00004001, F3_LD_LW, 1'b1, 1'b1, "LW at 0x4001: both flags");

        // ---- 8. Flags are 0 when the instruction is not a load or store ----
        expect_flags(1'b0, 1'b0, 32'h00000101, F3_LD_LW, 1'b0, 1'b0, "re=we=0: no misaligned");
        expect_flags(1'b0, 1'b0, 32'h00004000, F3_LD_LW, 1'b0, 1'b0, "re=we=0: no out_of_range");

        // ---- 9. Random accesses against the byte-level model ----
        for (int i = 0; i < MODEL_SIZE; i += 4) begin          // fill the region first
            d = $urandom();
            store(32'(i), F3_ST_SW, d);
            model_store(i, 2'b10, d);
        end
        for (int n = 0; n < 5000; n++) begin
            if ($urandom_range(0, 1) == 0) begin
                f = rand_store_f3();
                a = rand_addr(f[1:0]);
                d = $urandom();
                store(32'(a), f, d);
                model_store(a, f[1:0], d);
            end else begin
                f = rand_load_f3();
                a = rand_addr(f[1:0]);
                expect_load(32'(a), f, model_load(a, f), "random");
            end
        end

        if (error == 0) $display("PASS dmem_tb");
        else            $fatal(1, "dmem_tb: %0d check(s) failed", error);
        $finish;
    end

endmodule
