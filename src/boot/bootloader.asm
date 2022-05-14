; ==============================================================================
; bootloader.asm: the Blueberry bootloader
; ==============================================================================
; The bootloader is the second piece of code run after the bootsector. It is re-
; sponsible for a number of tasks in preparation for the kernel:
;
;    - Enable the A20 line
;    - Obtain a memory map from the BIOS
;    - Parse the fs and load the kernel
;    - Set up a simple GDT
;    - Enter protected mode
;
; As you can see, the bootloader requires much more sophistication than can be
; fit in 512 bytes, which is why we perform bootloading in two stages.
;
; Because the bootloader has so much more functionality, each file is assembled
; independently and linked into a final binary according to the linker script.
; Therefore, we don't need ORG directives in the individual files.

BITS 16
SECTION .text

%include "mem_locations.asm"

GLOBAL start
EXTERN envdata_drive_number
EXTERN envdata_gpt_header_ptr
EXTERN envdata_gpt_table_ptr
EXTERN enable_a20
EXTERN get_mmap_e820

start:

    ; Save the drive number
    pop si
    mov dl, [si]
    mov [envdata_drive_number], dl

    ; Initialize other envdata fields
    mov DWORD [envdata_gpt_header_ptr], GPT_HEADER_LOAD_ADDR
    mov DWORD [envdata_gpt_table_ptr], GPT_ENTRIES_LOAD_ADDR

    ; Print a welcome message ;)
    mov si, str_welcome
    call print

    ; Enable the A20 gate, this is crucial to accessing all available memory.
    call enable_a20
    test cx, cx
    jnz .a20_fail

    ; Retrieve a memory map for use by the kernel
    call get_mmap_e820
    test ax, ax
    jz .e820_fail

    jmp hang

.a20_fail:
    mov si, err_a20_not_enabled
    call print 
    jmp hang
.e820_fail:
    mov si, err_get_mmap_failed
    call print 
hang:
    cli
    hlt
    jmp hang

; A simple print routine, very similar to what we use to display error messages
; in the bootsector. Redundant comments are omitted; look at `fail` in
; bootsector.asm for an explanation of this code.
print:
    mov ah, 0x0e
    cld
.loop:
    lodsb 
    test al, al
    jz .done
    int 0x10
.wait_serial_loop:
    mov bl, al
    mov dx, 0x3fd
    in al, dx
    test al, 0x20
    jz .wait_serial_loop
    mov al, bl
    mov dx, 0x3f8
    out dx, al
    jmp .loop
.done:
    ret

; The pointer to the drive number as passed by the bootsector
drive_number_ptr dw 0

; Strings and error messages
str_welcome db `hello from the blueberry bootloader!\r\n`,0
err_a20_not_enabled db `failed to enable the A20 line\r\n`,0
err_get_mmap_failed db `memory map could not be retrieved from BIOS\r\n`,0