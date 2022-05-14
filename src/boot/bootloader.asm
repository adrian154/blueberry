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

%include "addresses.asm"

GLOBAL start
EXTERN envdata_drive_number

start:

    ; Save the drive number
    pop si
    mov dl, [si]
    mov [envdata_drive_number], dl

    ; Print a welcome message ;)
    mov si, str_welcome
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
str_welcome db 'hello from the blueberry bootloader!\r\n',0