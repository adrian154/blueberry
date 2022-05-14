; Certain memory locations are hardcoded into the bootsector/bootloader; I've
; gone and put them all in one file for quick reference.
GPT_HEADER_LOAD_ADDR  equ 0x7e00
GPT_ENTRIES_LOAD_ADDR equ 0x8000
BOOTLOADER_LOAD_ADDR  equ 0xc000