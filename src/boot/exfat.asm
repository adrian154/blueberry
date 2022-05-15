; ==============================================================================
; exfat.asm: find and load the kernel from an exFAT filesystem
; ==============================================================================

EXTERN read_sectors
EXTERN sector_buf
EXTERN DAP.sectors 
EXTERN DAP.addr 
EXTERN DAP.segment 
EXTERN DAP.start_sector
EXTERN os_part_length
EXTERN os_part_start_sector

GLOBAL exfat_detect
GLOBAL exfat_load

; Inspect the sector in `sector_buf` and determine if it's the beginning of an
; exFAT-formatted volume.
exfat_detect:

exfat_load: