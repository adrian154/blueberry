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
EXTERN err_kernel_not_found

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

    ; EAX = cluster index
    mov eax, DWORD [sector_buf + 96]
.loop_cluster:

    ; load the cluster
    call load_cluster
    
    ; ES:DI = the cluster we just loaded
    pushf
    cli
    mov es, CLUSTER_LOAD_SEGMENT
    popf

    ; each directory entry is 32 bytes, making it easy to iterate over them
    mov di, CLUSTER_LOAD_OFFSET

.loop_dirent:

    ; if the first byte of the directory entry is zero, there are no more 
    ; entries
    mov ebx, BYTE [es:di]
    cmp ebx, 0
    je .not_found

    ; otherwise, check if it's a file
    cmp ebx, 0x85
    jne .continue_loop_dirent

.continue_loop_dirent:
    add di, 32

    ; check if DI has overflowed; if it has, stop reading the root directory.
    cmp di, 0
    je .not_found

.not_found:
    mov si, err_kernel_not_found
    stc
    ret

; Cluster may be too big to fit into memory all at once, so we read them sector
; by sector. The cluster index is in EBX and the sector offset within the 
; cluster is in ECX.
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