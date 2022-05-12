BITS 16
ORG 0xc000

; quick and dirty stub because im sleeping soon :)
mov si, teststr
mov ah, 0x0e
cld
.loop:
    lodsb  
    test al, al 
    jz hang
    int 0x10 
    jmp .loop
hang:
    cli
    hlt
    jmp hang

teststr db "Hello World from the Blueberry Bootloader!",13,10,0