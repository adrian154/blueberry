; ==============================================================================
; e820.asm: retrieve a memory map through BIOS
; ==============================================================================
; The kernel needs information about how much memory is available and where it's
; located to function properly. This information is difficult to obtain in
; protected mode but readily available in real mode through the BIOS, so we task
; the bootloader with asking the BIOS to provide a memory map.
;
; There are a lot of BIOS functions which provide information about the layout
; of memory, but we only use one method, INT 0x15 AX=0xe820, which is generally
; the most robust, feature-complete, and widely available. Still, there may be
; edge cases such as empty memory maps being returned, but we leave handling of
; those abnormalities to the kernel.

BITS 16
SECTION .text

E820_MAGIC equ 0x534D4150
MMAP_ENTRY_SIZE equ 24

EXTERN envdata_mmap_ptr 
EXTERN envdata_mmap_num_entries
GLOBAL get_mmap_e820

; Each call to INT 0x15 AX=0xe820 results in one memory map entry being written
; to a user-supplied buffer. EBX is also populated with a "continuation" value,
; which we provide in the next call to get the next memory map entry. See
; http://www.uruk.org/orig-grub/mem64mb.html
;
; This routine returns success with 1 in AX, 0 on failure.
get_mmap_e820:
    mov DWORD [envdata_mmap_ptr], mmap_base
    mov di, mmap_base           ; memory map entries are written to ES:DI
    xor ebx, ebx                ; initial continuation value is zero
.loop:
    mov eax, 0xe820             ; function code
    mov ecx, MMAP_ENTRY_SIZE    ; prevent BIOS from truncating entries
    mov edx, E820_MAGIC         ; required magic number
    int 0x15

    ; The carry flag indicates that either the last entry was reached or an
    ; error occurred. We only treat carry being set as an error if it occurs
    ; on the first call
    jc .carry

    ; After each call, EAX should be set to the magic value
    cmp eax, E820_MAGIC
    jne .failed 

    ; Check ECX, which contains the number of bytes written. Some BIOSes don't
    ; support the ACPI field in memory map entries, whose LSB indicates whether
    ; the entry should be ignored. We obviously don't want to leave this as
    ; zero since it will result in the kernel ignoring important entries, so if
    ; <24 bytes were written manually set this to 1.
    cmp ecx, 24
    jl .set_acpi_field
.acpi_continue:

    ; Increment # of entries and buffer pointer
    inc DWORD [envdata_mmap_num_entries]
    add di, MMAP_ENTRY_SIZE

    ; If a continuation value of zero is indicated, that means that we've
    ; read all available memory map entries.
    test ebx, ebx
    jz .done

    ; Otherwise, continue.
    jmp .loop

.done:
    mov ax, 1
    ret

.carry:
    cmp DWORD [envdata_mmap_num_entries], 0
    je .failed
    jmp .done

.failed:
    mov ax, 0
    ret

.set_acpi_field:
    mov DWORD [es:di + 20], 1
    jmp .acpi_continue

; Save 1KiB for the memory map
mmap_base times 1024 db 0