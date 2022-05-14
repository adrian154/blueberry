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

%include "addresses.asm"

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

    ; Save the disk number for use later.
    mov BYTE [drive_number], dl

    ; Switch to VGA text mode, in case our current graphics mode is something
    ; else.
    call set_textmode

    ; Initialize COM1, which will allow us to log messages even when no screen
    ; is attached. The bootloader also makes use of the serial port.
    call init_serial

    ; Load the bootloader into memory and jump to it
    jmp load_bootloader

; SI is set to an error message before jumping to this label.
fail:
    mov ah, 0x0e ; INT 0x10 AH=0x0e: "teletype output" (print char to screen)
    cld
.loop:
    lodsb        ; load next char at DS:SI into AL 
    test al, al  ; check for null terminator
    jz hang
    int 0x10     ; print to screen

    ; If there's no serial port, loop immediately
    cmp BYTE [no_serial_port], 1
    je .loop

; CPU is much faster than serial; spin until tx buffer is empty 
.wait_serial_loop:
    mov bl, al
    mov dx, 0x3fd
    in al, dx
    test al, 0x20
    jz .wait_serial_loop

    ; write to serial and loop
    mov al, bl
    mov dx, 0x3f8
    out dx, al
    jmp .loop

; Hang execution after something has gone wrong.
hang:
    cli
    hlt
    jmp hang

set_textmode:
    xor ah, ah   ; INT 0x10 AH=0x00: set video mode 
    mov al, 0x03 ; AL = desired vieo mode
    int 0x10
    ret

; Set up COM1 at 9600 baud. 
; For more information about serial port initialization, see
; https://en.wikibooks.org/wiki/Serial_Programming/8250_UART_Programming 
init_serial:

    ; Ports 0x3f8 through 0x3ff control COM1. The first two ports behave diff-
    ; erently depending on whether the Divisor Latch Access Bit is set. We can
    ; set the DLAB by accessing the MSB of the Line Control Register through
    ; port 0x3fb.

    ; The serial controller runs at a maximum of 115200 baud, but we can divide
    ; its clock rate by an integer divisor to set a custom baud rate. To do this
    ; we first set the DLAB.
    mov dx, 0x3fb
    mov al, 0x80
    out dx, al

    ; 0x3f8 and 0x3f9 are the lower and upper bytes of the clock divisor, re-
    ; spectively, when DLAB is set. We use a divisor of 12 to get 9600 baud.
    mov dx, 0x3f8
    mov al, 12
    out dx, al

    mov dx, 0x3f9
    mov al, 0
    out dx, al

    ; There's still a couple things left to configure before we can start using
    ; the serial ports. We can write to the Line Control Register to set some
    ; serial transmission properties:
    ;     - 8 characters/bit
    ;     - one stop bit
    ;     - no parity bit
    ; This arrangement ("8n1") is pretty standard for serial communications
    ; today. Not that it matters since this code will probably never run on a
    ; real machine, anyways... but just in case ;)
    ;
    ; This also resets DLAB, since we're done setting the divisor.
    mov dx, 0x3fb
    mov al, 3
    out dx, al

    ; The FIFO control register apparently wasn't a thing on the original 8250.
    ; Weird. This port controls how data is buffered. We set the buffer to the
    ; maximum size (14 bytes) and clear the rx/tx buffers.
    mov dx, 0x3fa
    mov al, 0xc7
    out dx, al

    ; Set the port to loopback mode to test if it actually exists and works.
    ; The only reason we do this is because we don't want to wait on a non-
    ; existent serial port when logging a message.
    mov dx, 0x3fc
    mov al, 0x13
    out dx, al

    ; Write something to the port and read it back; if it doesn't match, assume
    ; that we cannot use the port.
    mov dx, 0x3f8
    mov al, 0x55
    out dx, al

    in al, dx
    cmp al, 0x55
    je .done

    ; Mark the port as unusable.
    mov BYTE [no_serial_port], 1
    ret

; If the port is good, disable loopback
.done:
    mov dx, 0x3fc
    mov al, 0x3
    out dx, al
    ret

; At this point, the most convenient way to load the kernel is to rely on BIOS
; interrupts. I'm using the LBA BIOS extensions for disk IO because I really
; don't want to work with CHS addressing.
load_bootloader:

    ; Set DL again.
    mov dl, [drive_number]

    ; Read the GPT into memory
    mov ah, 0x42    ; INT 0x10 AH=0x42: extended read
    mov si, .DAP    ; arguments are passed through a "disk access packet"
    int 0x13
    mov si, err_disk_read_fail
    jc fail         ; carry set on failure

    ; Check the magic number; the first 8 bytes of the GPT are "EFI PART"
    ; This is about all we do with the partition table header, though we keep
    ; it in memory for the OS to use later on.
    mov si, err_bad_gpt_header
    mov eax, [GPT_HEADER_LOAD_ADDR]
    cmp eax, 0x20494645
    jne fail
    mov eax, [GPT_HEADER_LOAD_ADDR + 4]
    cmp eax, 0x54524150
    jne fail

    ; Load the partition table. While it probably only spans 1 or 2 sectors,
    ; it's easier to just read the maximum possible size of the table (32s)
    mov WORD [.DAP_addr], GPT_ENTRIES_LOAD_ADDR
    mov DWORD [.DAP_start_sector], 2
    mov WORD [.DAP_sectors], 32
    mov ah, 0x42 ; each call trashes AH
    mov si, .DAP
    int 0x13 
    mov si, err_disk_read_fail
    jc fail

    ; The number of partition entries is stored in a field in the GPT header
    ; Loop over entries in the partition table and try to identify the "boot
    ; partition"
    mov ecx, DWORD [GPT_ENTRIES_LOAD_ADDR + 0x50]
    mov edx, GPT_ENTRIES_LOAD_ADDR
.loop:

    ; Check if the partition type GUID matches the BIOS Boot Partition type.
    mov eax, 0
.check_part_type_loop:
    mov ebx, [edx + eax * 4]
    cmp [loader_partition_type + eax * 4], ebx
    jne .next

    ; loop condition
    inc eax
    cmp eax, 4
    jl .check_part_type_loop

    ; If execution has reached here, we've found a matching partition!
    ; Now all that's left for us to do is read the start/end addresses, load
    ; the bootloader into memory, and jump to it.
    ; LIMITATION: 48-bit LBA truncated here in horrible ways!
    mov eax, [edx + 0x28]
    mov ebx, [edx + 0x20]
    sub eax, ebx
    mov WORD [.DAP_sectors], ax
    mov WORD [.DAP_start_sector], bx
    mov WORD [.DAP_addr], BOOTLOADER_LOAD_ADDR
    
    ; Set up for BIOS call to load bootloader into memory
    mov ah, 0x42
    mov si, .DAP
    mov dl, [drive_number]
    int 0x13
    mov si, err_disk_read_fail
    jc fail

    ; Pass the bootloader the location of drive_number via the stack, and then
    ; jump to the bootloader!
    push drive_number
    jmp BOOTLOADER_LOAD_ADDR

.next:

    ; loop exit condition
    dec ecx
    test ecx, ecx
    jz fail
  
    ; A field in the GPT header tells us the size of each partition entry.
    ; This value is unlikely to not be 128, but just in case.
    add edx, [GPT_HEADER_LOAD_ADDR + 0x54]
    jmp .loop

.DAP:
    db 0x10 ; size of struct = 16
    db 0x00 ; (always zero)
.DAP_sectors:
    dw 0x0001 
.DAP_addr:
    dw GPT_HEADER_LOAD_ADDR
.DAP_segment:
    dw 0x0000
.DAP_start_sector:
    dd 1
    dd 0 ; upper 32 bits of LBA start addr, we keep this zero 
         ; this field might actually be 16 bits--I've read some conflicting
         ; documentation--but that's the beauty of little-endian numbers:
         ; it doesn't really matter, in our case.

; Store the drive number in a known location that can be passed to the boot-
; loader later on
drive_number db 0

; Remember whether there's a working serial port
no_serial_port db 0

; A couple of null-terminated error messages, for debugging's sake
err_disk_read_fail db "disk I/O failure",0
err_bad_gpt_header db "invalid GPT header",0

; The BIOS boot partition type
; I'm serious. This is the actual value of the GUID.
loader_partition_type db "Hah!IdontNeedEFI"

; Pad out to 512 bytes
TIMES 510-($-$$) db 0

; Some BIOSes compare the last two bytes of the bootsector to 55 AA when de-
; termining whether a disk is bootable, so just in case:
dw 0xAA55