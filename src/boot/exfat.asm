; ==============================================================================
; exfat.asm: find and load the kernel from an exFAT filesystem
; ==============================================================================

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
    call load_cluster
    cli
    hlt

    ; calculate FAT offset

; Load cluster at index `eax` into cluster_buf
load_cluster:
    
    ; sector = (cluster_index - 2) << SectorsPerClusterShift + ClusterHeapOffset + PartitionOffset
    sub eax, 2
    mov cl, [sector_buf + 109]
    shl eax, cl
    add eax, DWORD [sector_buf + 88]
    mov ebx, [os_part.start_sector]
    add eax, ebx

    ; calculate # of sectors per cluster
    mov ebx, 1
    shl ebx, cl

    mov DWORD [DAP.start_sector], eax
    mov DWORD [DAP.sectors], ebx
    mov WORD [DAP.segment], CLUSTER_LOAD_SEGMENT
    mov WORD [DAP.addr], CLUSTER_LOAD_OFFSET
    call read_sectors
    mov si, err_disk_read_fail
    ret