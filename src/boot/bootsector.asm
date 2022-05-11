; ==============================================================================
; bootsector.asm: the Blueberry bootsector
; ==============================================================================
; The bootsector is the first piece of code in our OS that is executed after the
; computer boots. It lives in the first sector of the boot disk. On boot, the
; BIOS loads the bootsector into memory at physical address 0x7c00, with DL set
; to the disk number of the drive which the system was booted from. From there
; begins the long, arduous journey towards a userspace environment. Since the
; bootsector is very limited in size, it doesn't do a lot; its main responsi-
; bility is loading the bootloader from the disk, which will allow us to set up
; the environment for the kernel.

BITS 16
ORG 0x7c00

; We know that the bootsector is located at 0x7c00 in physical memory, but there
; are several possibilities for the actual value of CS:IP. We can make sure that
; the processor is executing from 0x0000:0x7c00 with a far jump.
jmp 0x0000:start
start:

    ; Disable interrupts while we're setting up the stack and segment registers.
    ; Otherwise, things could get hairy.
    cli

    ; Set all segment registers to zero
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Set up a temporary stack right below the bootsector. This region is usu-
    ; ally free.
    mov ss, ax
    mov sp, 0x7bff

    ; Push the disk number onto the stack so that the bootloader can pass it to
    ; the kernel later.
    push dx

    ; Switch to VGA text mode, in case our current graphics mode is something
    ; else.
    call set_textmode

; If something goes wrong, hang the system.
hang:
    cli
    hlt
    jmp hang

set_textmode:
    xor ah, ah      ; INT 0x10 AH=0x00: set video mode 
    mov al, 0x03    ; AL = desired vieo mode
    int 0x10
    ret

; Pad out to 512 bytes
TIMES 510-($-$$) db 0

; Some BIOSes compare the last two bytes of the bootsector to 55 AA when de-
; termining whether a disk is bootable, so just in case:
dw 0xAA55