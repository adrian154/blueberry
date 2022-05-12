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

GPT_HEADER_LOAD_ADDR  equ 0x7e00
GPT_ENTRIES_LOAD_ADDR equ 0x8000

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

    ; Load the bootloader into memory and jump to it
    jmp load_bootloader

; If something goes wrong, hang the system.
hang:
    cli
    hlt
    jmp hang

set_textmode:
    xor ah, ah   ; INT 0x10 AH=0x00: set video mode 
    mov al, 0x03 ; AL = desired vieo mode
    int 0x10
    ret

; At this point, the most convenient way to load the kernel is to rely on BIOS
; interrupts. I'm using the LBA BIOS extensions for disk IO because I really
; don't want to work with CHS addressing.
load_bootloader:

    ; Read the GPT into memory
    mov ah, 0x42    ; INT 0x10 AH=0x42: extended read
    mov si, .DAP    ; arguments are passed through a "disk access packet"
    int 0x13
    
    ; Check the magic number; the first 8 bytes of the GPT are "EFI PART"
    mov eax, [0x7e00]
    cmp eax, 0x20494645
    jne hang
    mov eax, [0x7e04]
    cmp eax, 0x54524150
    jne hang

    ; Load the partition table
    mov WORD [.DAP_addr], GPT_ENTRIES_LOAD_ADDR
    mov DWORD [.DAP_start_sector], 2
    mov ah, 0x42 ; int 0x13 might trash AX, I'm not really sure.
    int 0x13 

    

.DAP:
    db 0x10 ; size of struct = 16
    db 0x00 ; (always zero)
.DAP_sectors:      dw 0x0001 
.DAP_addr:         dw GPT_HEADER_LOAD_ADDR
.DAP_segment:      dw 0x0000
.DAP_start_sector: dd 1
    dw 0 ; upper 16 bits of LBA start addr

; Pad out to 512 bytes
TIMES 510-($-$$) db 0

; Some BIOSes compare the last two bytes of the bootsector to 55 AA when de-
; termining whether a disk is bootable, so just in case:
dw 0xAA55