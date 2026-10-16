/* Everything lives in the 8 KB on-chip RAM starting at address 0. */

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 8K
}

ENTRY(_start)

SECTIONS
{
    .text : {
        *(.text.start)
        *(.text .text.*)
        *(.rodata .rodata.* .srodata .srodata.*)
    } > RAM

    .data : {
        *(.data .data.* .sdata .sdata.*)
    } > RAM

    .bss (NOLOAD) : {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
