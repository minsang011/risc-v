    .section .text
    .globl _start
_start:
    addi x1, x0, 5        # I-type
    addi x2, x0, 7
    add  x3, x1, x2       # R-type
    sw   x3, 0(x0)        # S-type
loop:
    j    loop             # J-type (jal x0, 0)