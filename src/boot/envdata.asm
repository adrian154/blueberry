; ==============================================================================
; envdata.asm: boot environment data passed to the kernel
; ==============================================================================
; It's often advantageous to obtain information about the system while we're in
; Real Mode. We pass this info in a struct to the kernel.

GLOBAL envdata_struct
GLOBAL envdata_drive_number
GLOBAL envdata_mmap_num_entries
GLOBAL envdata_mmap_ptr
GLOBAL envdata_gpt_header_ptr
GLOBAL envdata_gpt_table_ptr

envdata_struct:
    envdata_drive_number     db 0
    envdata_mmap_num_entries dd 0
    envdata_mmap_ptr         dd 0
    envdata_gpt_header_ptr   dd 0
    envdata_gpt_table_ptr    dd 0
