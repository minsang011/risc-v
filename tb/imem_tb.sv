// imem_tb.sv - instruction memory load test (task 1.13)
//
// The DUT loads build/<prog>.hex (objcopy -> hexdump -> $readmemh).
// The expected words come from build/<prog>.expect, extracted from objdump's
// disassembly of the .elf. The two files are made by different tools, so this
// checks the whole chain: word order, endianness, $readmemh, and pc -> row indexing.
// Every instruction in the program is checked (the plan requires at least the first 4).
//
// Build both files first:  make build/smoke.hex build/smoke.expect

module imem_tb;

    // Change both if your Phase 0 program has a different name
    localparam HEX_FILE = "build/smoke.hex";
    localparam EXP_FILE = "build/smoke.expect";
    localparam int    DEPTH    = 4096;

    logic [31:0] pc, instr;
    logic [31:0] expected [0:DEPTH-1];

    int error = 0;

    imem #(.DEPTH(DEPTH), .INIT_FILE(HEX_FILE)) dut (
        .pc    (pc),
        .instr (instr)
    );

    initial begin
        int          fd, n;
        logic [31:0] w;

        $dumpfile("build/imem_tb.vcd");
        $dumpvars(0, imem_tb);

        // Read objdump's instruction words, one per line
        fd = $fopen(EXP_FILE, "r");
        if (fd == 0) $fatal(1, "imem_tb: cannot open %s (run: make %s)", EXP_FILE, EXP_FILE);
        n = 0;
        while (n < DEPTH && $fscanf(fd, "%h", w) == 1) begin
            expected[n] = w;
            n++;
        end
        $fclose(fd);
        if (n < 4) $fatal(1, "imem_tb: only %0d words in %s, need at least 4", n, EXP_FILE);

        // Instruction i lives at byte address 4*i
        for (int i = 0; i < n; i++) begin
            pc = 32'(4 * i);
            #1;
            if (instr !== expected[i]) begin
                $display("ERROR pc=%h: imem=%h objdump=%h", pc, instr, expected[i]);
                error++;
            end
        end

        if (error == 0) $display("PASS imem_tb");
        else            $fatal(1, "imem_tb: %0d of %0d word(s) differ", error, n);
        $display("checked %0d instruction word(s) against objdump", n);
        $finish;
    end

endmodule