// Reset entry: set up the stack, clear .bss, run main().
// The whole image already sits in RAM, so .data needs no copy.

    .section .text.start
    .global _start
_start:
    la   sp, _stack_top

    la   a0, _bss_start
    la   a1, _bss_end
1:  bgeu a0, a1, 2f
    sw   zero, 0(a0)
    addi a0, a0, 4
    j    1b
2:
    call main
3:  j    3b
