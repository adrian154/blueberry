; ==============================================================================
; a20.asm: try various methods to enable the A20 line
; ==============================================================================
; The A20 gate is exemplary of the weird historical quirks that make x86 such a
; challenging platform to write *robust* systems code for. Basically, back in
; the pre-286 days, the CPU only had 20 physical address lines. However, 
; there are a couple segment:offset addresses which map to physical addresses
; above 2^20=1M. Unfortunately, some programs had been written to rely on the
; "truncating" behavior exhibited by systems with only 20 address lines when
; accessing memory above 1M. To maintain compatibility with these systems, IBM
; added logic to their PC AT to hold the 20th address line at zero to maintain
; compatibility with older processors. 
;
; Obviously, we don't want this. Entering protected mode with the A20 gate still
; off will cause an unlimited amount of bizarre behavior. However, turning on
; the A20 gate is surprisingly hard to get right 100% of the time. Over the
; years, systems manufacturers have created *many* ways to enable the A20 line
; none of which are guaranteed to work everywhere. This is one of those things
; that EFI will take care of for you, but we're writing a legacy BIOS-based
; system in 2022 for some reason, so, uh.. 
;
; It's worth noting that from what I can tell, on many Intel processors in the
; past 10 years the A20 line can no longer be masked off. The nightmare is
; finally coming to an end...

BITS 16
SECTION .text

GLOBAL enable_a20

; We try various methods of enabling the A20 gate, in order of likelihood of
; success. 
enable_a20:

    ; Very likely that A20 gate is on already.
    call check_a20
    jcxz .done

    ; The BIOS may have a call for enabling A20.
    call bios_enable_a20
    call check_a20
    jcxz .done

    ; Originally, the IBM engineers routed the A20 line through the keyboard
    ; controller because it had a spare pin available. This method may be worth
    ; a shot.
    call kbc_enable_a20
    call check_a20
    jcxz .done

    ; Try the "fast A20". Apparently this has a tendency to crash machines which
    ; don't support this method, so we use it as a last resort.
    call set_a20_fast 
    call check_a20
    jcxz .done

.done:
    ret

bios_enable_a20:
    mov ax, 0x2401 ; INT 0x15 AX=0x2401: enable A20 gate
    int 0x15       ; We don't check if the BIOS indicated success, we can do
    ret            ; that by ourselves.

kbc_enable_a20:
    pushf
    cli

    ; Disable the first PS/2 port
    call .wait_write
    mov al, 0xad 
    out 0x64, al

    ; Send the command indicating that we want to read the controller output
    ; port. This is one of several values that can be accessed through IO port
    ; 0x60.
    call .wait_write 
    mov al, 0xd0
    out 0x64, al

    ; Read the controller output port. Bit 1 of this register controls the A20
    ; gate.
    call .wait_read 
    in al, 0x60
    or al, 2 ; set bit 1 
    push ax  ; don't overwrite the value while addressing ports

    ; Send the command to write the controller output port.
    call .wait_write 
    mov al, 0xd1
    out 0x64, al

    ; Send the new value.
    call .wait_write 
    pop ax 
    mov 0x60, al

    ; Re-enable the PS/2 port we disabled earlier.
    call .wait_write 
    mov al, 0xae
    out 0x64, al

    popf 
    ret 

; The keyboard controller can be slow; spin until the status register on port
; 0x64 indicates that we can write by clearing bit 1.
.wait_write:
    in al, 0x64
    test al, 2
    jnz .wait_write
    ret 

; Likewise, wait for bit 0 of the status register to become 0 (output buffer
; empty) before reading
.wait_read:
    in al, 0x64
    test al, 1
    jnz .wait_read
    ret

; We can reliably test whether the A20 line is enabled by checking if address
; truncation happens. This routine returns 0 in CX if the A20 line is enabled
; and 1 if it is not. It's meant for use with JCXZ.
;
; Instead of writing memory to a test location and reading it back, which risks
; poking some weird memory mapped region, we simply use the magic number at the
; end of our bootsector, which has the benefit of being in a known location with
; a known value.
check_a20:

    ; Save segments
    pushf
    push es
    push di 
    cli

    ; ES:DI = 0xFFFF:0x7e0e
    ; This maps to 0x107dfe if the A20 line is on and 0x7dfe if it is not
    mov ax, 0xffff
    mov es, ax 
    mov di, 0x7e0e

    ; Read and compare
    cmp WORD [es:di], 0xaa55
    mov cx, 1
    je .cleanup
    xor cx, cx

.cleanup:
    pop di
    pop es 
    popf
    ret