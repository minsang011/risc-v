# imm_test.S - immediate-generator test vectors for task 1.7
# One instruction per case. Not meant to execute: only the encodings matter.
# Assemble:  riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -Ttext=0 -c imm_test.S -o imm_test.o
#            riscv64-unknown-elf-objdump -d imm_test.o
    .option norelax          # resolve branch/jump offsets in the assembler
    .text
    .globl _start
_start:
    # ---------------- I-type ----------------
    addi  x1, x0, -1            # imm = -1
    addi  x1, x0, 2047          # max positive
    addi  x1, x0, -2048         # min negative
    lw    x5, 8(x6)             # load offset
    jalr  x1, -4(x2)            # JALR uses I-type
    srai  x1, x2, 3             # funct7 sits in imm[11:5]: imm = 0x403
    # ---------------- S-type ----------------
    sw    x7, -4(x6)            # plan case
    sw    x7, 2047(x6)          # max positive
    sb    x7, -2048(x6)         # min negative
    sh    x7, 20(x6)            # only imm[4:0] nonzero
    sw    x7, 1234(x6)          # both fields nonzero
    # ---------------- B-type ----------------
    beq   x1, x2, . - 8         # plan case: backward branch
    bne   x1, x2, . + 8         # forward
    blt   x1, x2, . + 4094      # max positive
    bge   x1, x2, . - 4096      # min negative
    bltu  x1, x2, . + 2048      # only imm[11] set (comes from instr[7])
    bgeu  x1, x2, . + 30        # imm[4:1] pattern
    # ---------------- U-type ----------------
    lui   x1, 0xFFFFF           # plan case: top bit set
    lui   x1, 0x12345
    auipc x1, 0x80000           # only bit 31 set
    auipc x1, 0x1
    # ---------------- J-type ----------------
    jal   x1, . + 8             # forward
    jal   x1, . - 8             # backward
    jal   x0, . + 1048574       # max positive (+1 MiB - 2)
    jal   x0, . - 1048576       # min negative (-1 MiB)
    jal   x1, . + 2048          # only imm[11] set (comes from instr[20])
    jal   x1, . + 0x12344       # imm[19:12] pattern
