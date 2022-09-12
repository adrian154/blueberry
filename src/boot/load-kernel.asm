; ==============================================================================
; load-kernel.asm: Load the kernel into memory
; ==============================================================================
; The bootloader is stored as a flat binary in a separate partition to make 
; locating and loading it as easy as possible for the space-constrained boot-
; sector. However, we take no such shortcuts for the kernel, which is stored
; as a file within a formatted partition. We need to implement a minimal file-
; system driver to find and load the kernel.
; 
; A lot of code in this file is reused from the bootsector; if you ever find
; that comments are sparse for something, go check bootsector.asm.

%include "mem-locations.asm"

BITS 16
SECTION .text

EXTERN envdata_drive_number
EXTERN exfat_detect
EXTERN exfat_load

GLOBAL load_kernel
GLOBAL read_sectors
GLOBAL sector_buf
GLOBAL DAP.sectors 
GLOBAL DAP.addr 
GLOBAL DAP.segment 
GLOBAL DAP.start_sector
GLOBAL os_part.start_sector

; This routine returns 0 in AX if successful, 1 if not. An error message is set
; in SI.
load_kernel:

    ; For starters, we need to identify which partition the kernel lives in.
    ; In the future, we could prompt the user about this, but for now I'm
    ; limited by my choice of tooling (i.e. parted), so we simply select the
    ; first partition with a GUID matching what parted defaults to.
    
    ; Load the number of partition entries
    mov ecx, DWORD [GPT_HEADER_LOAD_ADDR + 0x50]
    mov edx, GPT_ENTRIES_LOAD_ADDR
.loop:

    ; Compare partition type GUID
    mov eax, 0
.check_guid_loop:
    mov ebx, [edx + eax * 4]
    cmp [kernel_partition_type + eax * 4], ebx
    jne .next_partition
    inc eax 
    cmp eax, 4
    jl .check_guid_loop

    ; The partition matches; now we need to load the first sector, detect the
    ; filesystem, and invoke FS-specific code to load the kernel.
    mov [os_part.ptr], edx
    mov ebx, [edx + 0x20]
    mov DWORD [DAP.start_sector], ebx
    mov DWORD [os_part.start_sector], ebx
    mov WORD [DAP.sectors], 1
    mov WORD [DAP.addr], sector_buf
    call read_sectors
    jc .read_fail

    ; Detect FS
    call exfat_detect
    jcxz .nextfs_0
    call exfat_load
    ret

.nextfs_0:

    jmp .unknown_fs

.next_partition:

    ; exit condition
    dec ecx 
    test ecx, ecx 
    jz .no_partition_found

    ; Read field in GPT header to determine size of each partition entry
    ; Increment and loop
    add edx, [GPT_HEADER_LOAD_ADDR + 0x54]
    jmp .loop

.no_partition_found:
    mov ax, 1
    mov si, err_part_not_found
    ret 
.read_fail:
    mov ax, 1
    mov si, err_disk_read_fail
    ret 
.unknown_fs:
    mov ax, 1
    mov si, err_unknown_fs
    ret

; Trashes EAX, EDX, and SI
; Failure indicated by carry flag
read_sectors:
    mov ah, 0x42
    mov si, DAP 
    mov dl, [envdata_drive_number]
    int 0x13 
    ret

; Arguments are passed to INT 0x15 AH=0x42 through a struct (a "disk access
; packet")
DAP:
    db 0x10 ; size of struct = 16
    db 0    ; always zero
.sectors:
    dw 0 
.addr:
    dw 0
.segment:
    dw 0
.start_sector:
    dd 0
    dd 0 

; Store a pointer to the OS partition 
os_part:
    .ptr: dd 0
    .start_sector: dd 0

; Reserve 512 bytes to read sectors into
sector_buf times 512 db 0

; Error messages
err_part_not_found db `no OS partition was found\r\n`,0
err_disk_read_fail db `disk I/O failure\r\n`,0
err_unknown_fs db `unknown filesystem\r\n`,0

; The generic Linux partition GUID, 0FC63DAF-8483-4772-8E79-3D69D8477DE4
kernel_partition_type dd 0x0fc63daf, 0x47728483, 0x693d798e, 0xe47d47d8