
; At this point, the most convenient way to load the kernel is to rely on BIOS
; interrupts. Conventionally this would involve fuddling with CHS but I have
; *zero* interest in doing that, so instead we'll rely on the less widely su-
; pported (but still commonplace) BIOS "extensions" which support LBA-based ad-
; dressing.  
load_bootloader:
    mov ah, 0x42                    ; INT 0x10 AH=0x42: extended read
    mov si, .disk_access_packet     ; We pass arguments through a struct
    int 0x13
    ret


.disk_access_packet:
    db 0x10