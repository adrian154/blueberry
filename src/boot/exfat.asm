; ==============================================================================
; exfat.asm: find and load the kernel from an exFAT filesystem
; ==============================================================================
;
; LIMITATIONS
;     - The kernel file name must be no more than 15 characters in length. 
;

%include "mem-locations.asm"

BITS 16
SECTION .text

EXTERN read_sectors
EXTERN sector_buf
EXTERN DAP.sectors 
EXTERN DAP.addr 
EXTERN DAP.segment 
EXTERN DAP.start_sector
EXTERN os_part.start_sector
EXTERN err_disk_read_fail
EXTERN err_kernel_not_found

GLOBAL exfat_detect
GLOBAL exfat_load

; magic numbers identifying the fs
EXFAT_MAGIC_0 equ 0x41465845
EXFAT_MAGIC_1 equ 0x20202054

; directory entry types 
DIRENT_FILE       equ 0x85
DIRENT_STREAM_EXT equ 0xc0
DIRENT_FILENAME   equ 0xc1

; directory entry loop states
STATE_WANT_FILE      equ 0
STATE_NEED_STREAMEXT equ 1
STATE_NEED_FILENAME  equ 2

kernel_filename db `blueberry.bin`
KERNEL_FILENAME_LEN equ 13

; Inspect the sector in `sector_buf` and determine if it's the beginning of an
; exFAT-formatted volume. If the partition is an exFAT volume, return 1 in CX;
; otherwise, 0.
exfat_detect:
    cmp WORD [sector_buf + 3], EXFAT_MAGIC_0
    jne .not_match
    cmp WORD [sector_buf + 7], EXFAT_MAGIC_1
    jne .not_match 
    mov cx, 1
    ret
.not_match:
    mov cx, 0
    ret

exfat_load:

    ; EBX = cluster index
    mov ebx, DWORD [sector_buf + 96]
    mov BYTE [state], STATE_WANT_FILE

.loop_cluster:

    ; calculate first sector in cluster -> eax
    ; cluster indexes start from 2
    mov eax, ebx
    sub eax, 2
    mov cl, [sector_buf + 109]
    shl eax, cl
    add eax, DWORD [sector_buf + 88]
    mov ecx, [os_part.start_sector]
    add eax, ecx

.loop_sector_in_cluster

    ; load sector
    push eax 
    mov DWORD [DAP.start_sector], eax
    mov DWORD [DAP.sectors], 1
    mov WORD [DAP.addr], sector
    call read_sectors
    mov si, err_disk_read_fail
    jc .fail 
    pop eax

    ; loop over directory entries
    mov di, sector
.loop_dirent:

    ; look at type of directory entry
    mov ecx, BYTE [es:di]

    ; 0 = no more entries
    cmp ecx, 0
    je .not_found

    cmp BYTE [state], STATE_WANT_FILE
    je .check_is_file:

    cmp BYTE [state], STATE_NEED_STREAMEXT
    je .check_is_streamext

    ; state == STATE_NEED_FILENAME

.check_is_file:
    cmp ecx, DIRENT_FILE
    jne .continue_loop_dirent
    mov BYTE [state], STATE_NEED_STREAMEXT
    jmp .continue_loop_dirent

.check_is_streamext:
    cmp ecx, DIRENT_STREAM_EXT
    mov si, err_invalid_file
    jne .fail
    mov BYTE [state], STATE_NEED_FILENAME
    
    ; copy dirent
    xor ecx, ecx
    mov si, streamext_dirent
.copy_streamext_loop:
    mov edx, DWORD [di + ecx]
    mov DWORD [si], edx
    add ecx, 4
    cmp ecx, 8
    je .continue_loop_dirent
    jmp .copy_streamext_loop
    
.continue_loop_dirent:
    inc eax

    ; check if we've reached the end of the cluster
    mov cl, [sector_buf + 109]
    mov edx, eax
    shl edx, cl
    shr edx, cl
    test edx, edx
    jz .exit_loop_sector_in_cluster
    jmp .loop_dirent

.exit_loop_sector_in_cluster:

.kernel_found: 

.not_found:
    mov si, err_kernel_not_found
.fail:
    ret

; directory entry loop state
state db 0
streamext_dirent times 32 db 0

; temporary sector buffer
sector times 512 db 0

; kernel file name

; error messages
err_invalid_file db `exFAT: invalid file\r\n`,0