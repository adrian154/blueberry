; ==============================================================================
; exfat.asm: find and load the kernel from an exFAT filesystem
; ==============================================================================

BITS 16
SECTION .text

EXTERN read_sectors
EXTERN sector_buf
EXTERN DAP.sectors 
EXTERN DAP.addr 
EXTERN DAP.segment 
EXTERN DAP.start_sector
EXTERN os_part.start_sector

GLOBAL exfat_detect
GLOBAL exfat_load

; magic numbers identifying the fs
EXFAT_MAGIC_0 equ 0x41465845
EXFAT_MAGIC_1 equ 0x20202054

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

    ; calculate offset of root directory relative to the start of the cluster heap 
    mov eax, DWORD [sector_buf + 96]
    sub eax, 2
    mov cl, [sector_buf + 109]
    shl eax, cl

    ; add cluster heap offset and volume start offset
    add eax, DWORD [sector_buf + 88]
    mov ebx, [os_part.start_sector]
    add eax, ebx

    

    cli
    hlt
    ret 