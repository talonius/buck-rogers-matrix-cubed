; textrend.asm -- the four glyph blitters TextRend's RenderChar dispatches to, one per displayMode: CgaGlyph (0),
; EgaGlyph (1), TandyGlyph (2) and VgaGlyph (3, mode 13h), linked into TextRend by {$L TEXTREND.OBJ}. Each draws one 8x8
; glyph into text cell (col, row) in ink fg where a glyph bit is set and paper bg where it is clear; a glyph row's most
; significant bit is its leftmost pixel.
;
; CgaGlyph, EgaGlyph and TandyGlyph return NEAR and VgaGlyph FAR, each popping its 10 bytes of arguments, so
; textrend.pas declares the first three under {$F-} and VgaGlyph under {$F+}. The first three draw the eight rows
; RenderChar copies into GDVars' glyphBits before calling them; VgaGlyph reads the glyph from the font itself.

DATA    SEGMENT WORD PUBLIC
        EXTRN   cgaTextColors:BYTE      ; GDConsts': the CGA color 0..3 of each text color
        EXTRN   glyphBits:BYTE          ; GDVars': the 8 rows of the glyph being drawn
        EXTRN   gameFont:DWORD          ; GDVars': far pointer to the loaded 8x8 font
DATA    ENDS

CODE    SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE, DS:DATA
        PUBLIC  CgaGlyph, EgaGlyph, TandyGlyph, VgaGlyph

; Arguments, in Pascal order (col, row, fg, bg, charIdx), the last nearest bp.
glyphCol  EQU  0Ch          ; CgaGlyph, EgaGlyph, TandyGlyph (NEAR): the text cell's column
glyphRow  EQU  0Ah          ; and row
glyphFg   EQU  08h          ; the color painted where a glyph bit is set
glyphBg   EQU  06h          ; the color painted where it is clear
vgaCol    EQU  0Eh          ; VgaGlyph (FAR): the same arguments two bytes higher
vgaRow    EQU  0Ch
vgaFg     EQU  0Ah
vgaBg     EQU  08h
vgaChar   EQU  06h          ; the glyph number, which only VgaGlyph reads

; ===========================================================================
; CgaGlyph -- displayMode 0: CGA 320x200 4-color, two-bank scanline interleave. Even scanlines at B800:0, odd at
; BA00:0; 80 bytes per scanline, so a character row is 4*80 = 320 bytes of each bank and a cell is 2 bytes wide (4
; pixels a byte). Each byte is built right to left, the colors rotating two bits a pixel.
; ===========================================================================
CgaGlyph LABEL NEAR
        push    bp
        mov     bp,sp                   ; BP addresses the arguments
        push    ss                      ; SS and DS saved and restored, though unchanged
        push    ds
        mov     ax,[bp+glyphRow]        ; di <- row*320 + col*2: the cell's first byte
        mov     bx,140h                 ;   in either bank
        mul     bx                      ; dx:ax = row*320
        mov     bx,[bp+glyphCol]
        shl     bx,1                    ; 2 bytes a cell
        add     ax,bx
        mov     di,ax
        xor     bx,bx                   ; bh = 0 for the table index
        mov     bl,[bp+glyphFg]         ; bx = the ink color number
        mov     dl,[bx+cgaTextColors]   ; dl <- ink color, in the low pixel's two bits
        mov     bl,[bp+glyphBg]         ; bx = the paper color number
        mov     dh,[bx+cgaTextColors]   ; dh <- paper color, likewise
        xor     bx,bx                   ; bx = glyph row 0..7
        mov     ah,1                    ; ah = the glyph bit being drawn, rightmost first
        mov     cx,4                    ; 4 scanline pairs = 8 scanlines
@@cga_pair:
        push    cx
        mov     cx,0B800h               ; --- even scanline: ES = CGA bank 0
        mov     es,cx
        mov     cx,2                    ; 2 bytes per cell
        inc     di                      ; start at the right byte, walk leftwards
@@cga_ev_byte:
        push    cx
        mov     cx,4                    ; 4 pixels per byte
        mov     al,0                    ; al accumulates the byte
@@cga_ev_pix:
        test    [bx+glyphBits],ah       ; this pixel's glyph bit set?
        jz      @@cga_ev_paper          ; clear: paint paper
        or      al,dl                   ; set: ink
        jmp     short @@cga_ev_next
        nop                             ; never reached
@@cga_ev_paper:
        or      al,dh                   ; clear: paper
@@cga_ev_next:
        rol     dl,1                    ; move the ink to the next pixel's two bits
        rol     dl,1
        rol     dh,1                    ; and the paper
        rol     dh,1
        rol     ah,1                    ; next glyph bit, leftwards
        loop    @@cga_ev_pix
        mov     es:[di],al
        dec     di                      ; the byte to its left
        pop     cx
        loop    @@cga_ev_byte
        inc     bx                      ; next glyph row
        inc     di                      ; back to the cell's left byte
        mov     ah,1                    ; restart at the rightmost glyph bit
        mov     al,0
        mov     cx,0BA00h               ; --- odd scanline: ES = CGA bank 1
        mov     es,cx
        mov     cx,2
        inc     di                      ; start at the right byte
@@cga_od_byte:
        push    cx                      ; the odd scanline repeats the even one's loop
        mov     cx,4
        mov     al,0
@@cga_od_pix:
        test    [bx+glyphBits],ah
        jz      @@cga_od_paper
        or      al,dl
        jmp     short @@cga_od_next
        nop                             ; never reached
@@cga_od_paper:
        or      al,dh
@@cga_od_next:
        rol     dl,1
        rol     dl,1
        rol     dh,1
        rol     dh,1
        rol     ah,1
        loop    @@cga_od_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@cga_od_byte
        inc     bx                      ; next glyph row
        add     di,51h                  ; from the byte left of the cell to the cell's
        pop     cx                      ;   next scanline pair (80 + 1)
        loop    @@cga_pair
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah                     ; near return, dropping the 5 argument words

; ===========================================================================
; EgaGlyph -- displayMode 1: EGA 320x200x16 planar, always page 0 at A000:0, painted through the Graphics Controller in
; write mode 2: the byte written carries the color, one bit per plane, and Bit Mask (GC 8) picks the pixels it reaches.
; Each glyph row takes two AND read-modify-writes of display memory, whose read loads the latches: ink with the mask set
; to the row's bits, then paper with it complemented. The GC registers are put back to the BIOS defaults before
; returning.
; ===========================================================================
EgaGlyph LABEL NEAR
        push    bp                      ; frame for the arguments
        mov     bp,sp
        push    ss                      ; SS and DS saved and restored, though unchanged
        push    ds
        mov     ax,0A000h               ; the EGA display memory segment, page 0
        mov     es,ax
        mov     ax,[bp+glyphRow]        ; di <- row*320 + col: 8 scanlines of 40 bytes
        mov     bx,140h                 ;   a row, 1 byte a cell
        mul     bx                      ; dx:ax = row*320
        add     ax,[bp+glyphCol]
        mov     di,ax
        mov     dx,3CEh                 ; GC index port; each word out writes index, data
        mov     ax,0A05h                ; GC 5 Mode <- 0Ah (write mode 2, read mode 1)
        out     dx,ax
        mov     ah,0
        mov     al,3                    ; GC 3 Data Rotate <- 0 (replace)
        out     dx,ax
        mov     ax,7                    ; GC 7 Color Don't Care <- 0: reads return FF
        out     dx,ax
        xor     bx,bx                   ; bx = glyph row 0..7
        mov     cx,8                    ; 8 scanlines
@@ega_row:
        mov     ah,[bx+glyphBits]       ; ah = this row's bit pattern
        mov     al,8                    ; GC 8 Bit Mask <- glyph bits -> ink
        out     dx,ax
        mov     al,[bp+glyphFg]
        and     es:[di],al              ; latch, then write fg to the masked pixels
        not     ah                      ; complement -> the paper bits
        mov     al,8
        out     dx,ax
        mov     al,[bp+glyphBg]
        and     es:[di],al              ; write bg to them
        add     di,28h                  ; next scanline (320/8 = 40 bytes)
        inc     bx
        loop    @@ega_row
        mov     ax,5                    ; back to the defaults: GC 5 Mode := 0 (write mode 0)
        out     dx,ax
        mov     ax,0FF08h               ; GC 8 Bit Mask <- FF (all bits)
        out     dx,ax
        mov     ax,3                    ; GC 3 Data Rotate <- 0
        out     dx,ax
        mov     ax,0F07h                ; GC 7 Color Don't Care <- 0F
        out     dx,ax
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah                     ; near return, dropping the 5 argument words

; ===========================================================================
; TandyGlyph -- displayMode 2: Tandy/PCjr 320x200x16, four interleaved banks (B800/BA00/BC00/BE00), 160 bytes per
; scanline, 4 bits a pixel so a cell is 4 bytes wide. Four glyph rows are painted per outer pass, one per bank, and two
; passes paint the eight; the colors are taken raw, 4 bits each, and rotated a nibble a pixel. Banks 1-3 repeat bank
; 0's loop.
; ===========================================================================
TandyGlyph LABEL NEAR
        push    bp
        mov     bp,sp                   ; BP addresses the arguments
        push    ss                      ; SS and DS saved and restored, though unchanged
        push    ds
        mov     ax,[bp+glyphRow]        ; di <- row*320 + col*4: 2 scanlines of 160
        mov     bx,140h                 ;   bytes a row in each bank
        mul     bx                      ; dx:ax = row*320
        mov     bx,[bp+glyphCol]
        shl     bx,1
        shl     bx,1                    ; col*4: 4 bytes a cell
        add     ax,bx
        mov     di,ax
        mov     dl,[bp+glyphBg]         ; dl = paper color in the low nibble
        mov     dh,[bp+glyphFg]         ; dh = ink color
        xor     bx,bx                   ; bx = glyph row 0..7
        mov     ah,1                    ; ah = the glyph bit being drawn, rightmost first
        mov     cx,2                    ; 2 outer passes * 4 banks = 8 scanlines
@@tdy_pass:
        push    cx
        mov     cx,0B800h               ; --- bank 0
        mov     es,cx
        mov     cx,4                    ; 4 bytes per cell
        add     di,3                    ; start at the right byte, walk leftwards
@@tdy_b0_byte:
        push    cx
        mov     cx,2                    ; 2 pixels per byte
        mov     al,0                    ; al accumulates the byte
@@tdy_b0_pix:
        test    [bx+glyphBits],ah       ; this pixel's glyph bit set?
        jz      @@tdy_b0_paper          ; clear: paint paper
        or      al,dh                   ; set: ink
        jmp     short @@tdy_b0_next
        nop                             ; never reached
@@tdy_b0_paper:
        or      al,dl                   ; clear: paper
@@tdy_b0_next:
        push    cx                      ; cl is the rotate count for a moment
        mov     cx,4
        rol     dl,cl                   ; move both colors a nibble on: paper
        mov     cx,4
        rol     dh,cl                   ; and ink
        rol     ah,1                    ; next glyph bit, leftwards
        pop     cx                      ; restore the pixel count
        loop    @@tdy_b0_pix
        mov     es:[di],al
        dec     di                      ; the byte to its left
        pop     cx
        loop    @@tdy_b0_byte
        add     di,4                    ; back to the cell's right byte
        inc     bx                      ; next glyph row
        mov     cx,0BA00h               ; --- bank 1: bank 0's loop again
        mov     es,cx
        mov     cx,4
@@tdy_b1_byte:
        push    cx
        mov     cx,2
        mov     al,0
@@tdy_b1_pix:
        test    [bx+glyphBits],ah
        jz      @@tdy_b1_paper
        or      al,dh
        jmp     short @@tdy_b1_next
        nop                             ; never reached
@@tdy_b1_paper:
        or      al,dl
@@tdy_b1_next:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@tdy_b1_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@tdy_b1_byte
        add     di,4
        inc     bx
        mov     cx,0BC00h               ; --- bank 2: the same loop
        mov     es,cx
        mov     cx,4
@@tdy_b2_byte:
        push    cx
        mov     cx,2
        mov     al,0
@@tdy_b2_pix:
        test    [bx+glyphBits],ah
        jz      @@tdy_b2_paper
        or      al,dh
        jmp     short @@tdy_b2_next
        nop                             ; never reached
@@tdy_b2_paper:
        or      al,dl
@@tdy_b2_next:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@tdy_b2_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@tdy_b2_byte
        add     di,4
        inc     bx
        mov     cx,0BE00h               ; --- bank 3: the same loop
        mov     es,cx
        mov     cx,4
@@tdy_b3_byte:
        push    cx
        mov     cx,2
        mov     al,0
@@tdy_b3_pix:
        test    [bx+glyphBits],ah
        jz      @@tdy_b3_paper
        or      al,dh
        jmp     short @@tdy_b3_next
        nop                             ; never reached
@@tdy_b3_paper:
        or      al,dl
@@tdy_b3_next:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@tdy_b3_pix
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@tdy_b3_byte
        inc     bx                      ; next glyph row
        add     di,0A1h                 ; from the byte left of the cell to the cell's
        pop     cx                      ;   next scanline in bank 0 (160 + 1)
        dec     cx                      ; not `loop`: the pass is beyond its reach
        jz      @@tdy_done              ; both passes done
        jmp     @@tdy_pass
@@tdy_done:
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah                     ; near return, dropping the 5 argument words

; ===========================================================================
; VgaGlyph -- displayMode 3: mode 13h, 320x200 at one byte a pixel in A000:0. It reads glyph vgaChar from gameFont
; itself and writes each pixel's color byte.
; ===========================================================================
VgaGlyph LABEL FAR
        push    bp
        mov     bp,sp                   ; BP addresses the arguments
        cld                             ; stosb walks forwards
        push    ds                      ; saved: lds points DS at the font
        lds     si,[gameFont]           ; DS:SI = the font
        xor     ax,ax                   ; clear ah for the glyph number
        mov     al,[bp+vgaChar]
        mov     bx,8                    ; 8 bytes a glyph
        mul     bx                      ; ax = its offset in the font
        add     si,ax                   ; DS:SI = the glyph
        mov     bx,140h                 ; di <- (row*320 + col)*8: 8 scanlines of 320
        mov     ax,[bp+vgaRow]          ;   bytes a row, 8 bytes a cell
        mul     bx                      ; dx:ax = row*320
        add     ax,[bp+vgaCol]
        mov     bx,8                    ; 8 pixels a cell
        mul     bx                      ; ax = the cell's first pixel
        mov     di,ax
        mov     ax,0A000h
        mov     es,ax                   ; ES = mode 13h video memory
        mov     cx,8                    ; 8 glyph rows
        xor     ax,ax                   ; ah stays 0 for the word test below
@@vga_row:
        push    cx
        mov     cx,8                    ; 8 pixels a row
        mov     bx,80h                  ; bx = the pixel's bit, leftmost first
@@vga_pix:
        mov     al,[si]
        and     ax,bx                   ; this pixel's bit set?
        cmp     ax,0                    ; (the whole word: ah is 0)
        jne     @@vga_ink               ; set: paint ink
        mov     al,[bp+vgaBg]           ; clear bit: paper
        stosb                           ; write it and step di
        jmp     short @@vga_next
        nop                             ; never reached
@@vga_ink:
        mov     al,[bp+vgaFg]           ; set bit: ink
        stosb
@@vga_next:
        shr     bx,1                    ; next bit, rightwards
        loop    @@vga_pix
        pop     cx
        inc     si                      ; the glyph's next row
        add     di,138h                 ; next scanline (320 - 8)
        loop    @@vga_row
        pop     ds                      ; restore the caller's DS
        pop     bp
        retf    0Ah                     ; far return, dropping the 5 argument words

CODE    ENDS
        END
