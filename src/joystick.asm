; joystick.asm -- ReadJoystick, the game-port sampling routine of the Joystick unit, linked by {$L JOYSTICK.OBJ} in
; joystick.pas; TP merges the CODE segment into the unit's code segment.
;
; Game port 201h: bits 0-3 are the axis one-shots (stick 1 X, Y; stick 2 X, Y), which read 1 while timing after any
; write to the port; bits 4-7 are the buttons (stick 1 buttons 1, 2; stick 2 buttons 1, 2), which read 0 while pressed.
; An axis position is the number of reads until its bit falls.
;
; function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean; far; result in AL. RET 14 pops the
; arguments, which lie in Pascal order, the last one declared nearest BP.
BUTTONS EQU     DWORD PTR [BP+6]        ; @buttons, far
YAXIS   EQU     DWORD PTR [BP+10]       ; @yRaw, far
XAXIS   EQU     DWORD PTR [BP+14]       ; @xRaw, far
STICK   EQU     BYTE PTR [BP+18]        ; joy: the stick, 1 or 2

CODE    SEGMENT BYTE PUBLIC 'CODE'
        ASSUME  CS:CODE

        PUBLIC  ReadJoystick            ; joystick.pas declares it external

ReadJoystick    PROC    FAR
        PUSH    BP
        MOV     BP,SP
        CMP     STICK,1                 ; joy must be 1 or 2
        JE      J_have
        CMP     STICK,2
        JE      J_have
        MOV     AL,0                    ; bad joy -> False, port untouched
        POP     BP
        RET     14
J_have:
        MOV     AH,1                    ; AH = the stick's X-axis bit: bit 0 for stick 1
        XOR     BX,BX
        CMP     STICK,2
        JNE     J_fire
        SHL     AH,1                    ; bit 2 for stick 2
        SHL     AH,1
J_fire:
        MOV     BX,1                    ; BX counts reads: the axis position
        XOR     CX,CX                   ; CX = 0: LOOP allows 65536 reads
        MOV     AL,0FFH                 ; any value will do
        MOV     DX,201H                 ; the game port
        OUT     DX,AL                   ; any write fires all four one-shots
J_waitX:
        IN      AL,DX
        NOT     AL                      ; a lapsed axis bit now reads 1
        TEST    AL,AH                   ; X lapsed?
        JNE     J_gotX
        INC     BX
        LOOP    J_waitX
        MOV     AL,0                    ; X never lapsed -> False
        POP     BP
        RET     14
; The spin makes up the reads a count falls short of 1FFFh, so that each axis takes about the same time whatever its
; position.
J_gotX:
        MOV     CX,1FFFH
        SUB     CX,BX                   ; CX = 1FFFh - count; borrow when the count is larger
        JB      J_storeX                ; count above 1FFFh: no spin
J_settleX:
        LOOP    J_settleX
J_storeX:
        LES     DI,XAXIS
        MOV     ES:[DI],BX              ; the count to xRaw
        SHL     AH,1                    ; AH = the same stick's Y-axis bit
        XOR     CX,CX
J_drainY:
        IN      AL,DX                   ; wait for Y's one-shot from the first write
        NOT     AL
        TEST    AL,AH
        JNE     J_fireY
        LOOP    J_drainY
        MOV     AL,0                    ; Y never lapsed -> False
        POP     BP
        RET     14
J_fireY:
        MOV     BX,1                    ; restart the count for Y
        XOR     CX,CX
        MOV     AL,0FFH
        OUT     DX,AL                   ; fire the one-shots again to time Y
J_waitY:
        IN      AL,DX
        NOT     AL
        TEST    AL,AH                   ; Y lapsed?
        JNE     J_gotY
        INC     BX
        LOOP    J_waitY
        MOV     AL,0                    ; Y never lapsed -> False
        POP     BP
        RET     14
; Note: this JB goes to X's store. A Y count above 1FFFh then overwrites xRaw, AH moves up to the next port bit, and
; that bit is timed as Y. On that path the comments on SHR AH,1 and J_waitB below do not hold.
J_gotY:
        MOV     CX,1FFFH                ; spin 1FFFh minus the count, as for X
        SUB     CX,BX
        JB      J_storeX                ; Note: to X's store (see above)
J_settleY:
        LOOP    J_settleY
        LES     DI,YAXIS
        MOV     ES:[DI],BX              ; the count to yRaw
        SHR     AH,1                    ; AH = the X-axis bit again
        XOR     CX,CX
J_waitB:
        IN      AL,DX                   ; wait for X's one-shot from the second write
        NOT     AL                      ; buttons now read 1 while pressed
        TEST    AL,AH
        JNE     J_gotB                  ; AL keeps this read's button bits
        LOOP    J_waitB
        MOV     AL,0                    ; X never lapsed -> False
        POP     BP
        RET     14
J_gotB:
        MOV     CX,4
        SHR     AL,CL                   ; button bits 4-7 down to bits 0-3
        LES     DI,BUTTONS
        MOV     ES:[DI],AL              ; the four button bits to buttons
        MOV     AL,1                    ; success -> True
        POP     BP
        RET     14
ReadJoystick    ENDP

CODE    ENDS
        END
