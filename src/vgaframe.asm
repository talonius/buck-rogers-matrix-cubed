; vgaframe.asm -- VgaFrame's two assembly routines, XorFrame and ExpandRleFrame, linked through
; {$L VGAFRAME.OBJ}.  Both are FAR Pascal procedures: the caller pushes the arguments left to right,
; so the last one sits nearest the return address, and each routine removes its own arguments with
; RET n.  Both save DS in DX, since Turbo Pascal needs its data segment back.

CODE    SEGMENT BYTE PUBLIC             ; TP's code segment name, so this joins the unit's code
        ASSUME  CS:CODE
        PUBLIC  XORFRAME, EXPANDRLEFRAME

; procedure XorFrame(src, dst, key: Pointer; count: Word)
XORFRAME PROC FAR
        push    bp
        mov     bp,sp
        cld
        mov     dx,ds                   ; keep the caller's DS
        les     si,[bp+10h]             ; ES:SI = src
        mov     cx,[bp+06h]             ; CX = count, the LOOP counter; 0 runs 65536 times
        mov     bx,0                    ; BX = byte index into all three buffers
        mov     ax,0                    ; AH stays 0; AL carries each byte
xor_loop:
        mov     al,es:[bx+si]           ; AL = src[i]
        lds     di,[bp+08h]             ; DS:DI = key, reloaded each byte since DS alternates
        xor     al,[bx+di]              ; AL = src[i] xor key[i]
        lds     di,[bp+0Ch]             ; DS:DI = dst
        mov     [bx+di],al              ; dst[i] = AL; dst may be src, since src[i] is already read
        inc     bx
        loop    xor_loop
        mov     ds,dx
        pop     bp
        ret     0Eh                     ; drop the three pointers and the count
XORFRAME ENDP

; procedure ExpandRleFrame(src, dst: Pointer; encodedBytes: Word)
; The code is a run of blocks, each led by a control byte c: c <= 7Fh copies the next c + 1 bytes,
; c > 7Fh repeats the next byte 257 - c times. BX counts the code bytes consumed.
EXPANDRLEFRAME PROC FAR
        push    bp
        mov     bp,sp
        cld                             ; MOVSB/STOSB/LODSB step forward
        mov     dx,ds                   ; keep the caller's DS
        lds     si,[bp+0Ch]             ; DS:SI = src, the code
        les     di,[bp+08h]             ; ES:DI = dst, the expanded frame
        mov     bx,0                    ; BX = code bytes consumed
        mov     ax,0                    ; AH stays 0, so AX is the control byte zero-extended
rle_next:
        cmp     bx,[bp+06h]             ; encodedBytes (SS-relative through BP, so DS=src does not matter)
        jae     rle_done                ; all the code consumed
        cmp     byte ptr [si],7Fh       ; control byte
        ja      rle_repeat              ; above 7Fh: a repeated run
        mov     al,[si]                 ; AX = c
        add     bx,ax                   ; consumed += c,
        inc     bx                      ; + 1 for the control byte,
        inc     bx                      ; + 1: c + 1 literals follow it
        mov     cx,ax                   ; CX = c
        inc     cx                      ; CX = c + 1 literal bytes
        inc     si                      ; past the control byte
        rep     movsb                   ; copy the literals from DS:SI to ES:DI
        jmp     rle_next
rle_repeat:
        inc     bx                      ; consumed += 1 for the control byte,
        inc     bx                      ; + 1 for the value
        mov     cx,100h                 ; CX = 256
        mov     al,[si]                 ; AX = c
        sub     cx,ax                   ; CX = 256 - c
        inc     cx                      ; CX = 257 - c repeats
        inc     si                      ; past the control byte
        lodsb                           ; AL = the value to repeat, SI past it
        rep     stosb                   ; store it CX times at ES:DI
        jmp     rle_next
rle_done:
        mov     ds,dx
        pop     bp
        ret     0Ah                     ; drop the two pointers and encodedBytes
EXPANDRLEFRAME ENDP

CODE    ENDS
        END
