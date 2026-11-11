# Design Decision


## Harvard
**Decision:** Harvard 
**Reason:** Because I want to make a single-cycle CPU, it is necessary to be capable to perform data read and write in a single cycle. Then a single data port would not make this possible. That's the reason why I chose Harvard architecture. 

## Reset PC
**Decision:** 0x0000_0000
**Reason:** By having the base 0, the index conversion in every instruction fetch gets a lot lighter. The instructions are often stored as array in IMEM, like mem[0:4095], which requires turning a memory address into index. If the PC is in base 0, simply dropping the last two bits will achieve it and we can simply do that by eaving bits [1:0] unconnected. Otherwise, we have to have the hardware circuit like adder to complete the conversion.

## FENCE
**Decision:** FENCE is not needed, NOP will replace it 
**Reason:** To keep a beauty of the simplicity of RISC-V, it's better to have a single core with no cache to achieve the hardware-level completion of memory ordering. 