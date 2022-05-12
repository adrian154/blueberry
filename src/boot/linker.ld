OUTPUT_FORMAT("binary")
ENTRY(start)

. = 0xC000;

SECTIONS {
    .text : {
        *(.text)
    }
}