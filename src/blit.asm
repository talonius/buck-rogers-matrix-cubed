; blit.asm -- the assembly half of the Blit unit, linked into its code segment through {$L BLIT.OBJ}: the per-mode
; tile blitters that BlitTileCell and BlitTileClipped dispatch to, the scanline loops those blitters share, and the EGA
; and VGA line fills that Hline and Vline call.
;
; Every procedure is NEAR, called from inside the unit's own segment.  Arguments are in Pascal order, so the last one
; declared lies nearest bp.
;
; The row loops record what they draw in GDVars' four dirty-row tables, which Blit's FlushView copies to the
; screen.  They are named below as externals and reached through DS, which holds the data segment whenever a loop
; touches them.  Each table has 168 entries, one per view scanline.  Note: nothing bounds the row index, so a tile on
; rows 168..199 of a 200-row picture writes past each table into the next, and past dirtyRowLast into the variable
; after it.

        LOCALS

DATA    SEGMENT WORD PUBLIC
        EXTRN   dirtyRows:BYTE          ; GDVars': per view scanline, non-zero once drawn
        EXTRN   dirtyRowLeft:WORD       ; per scanline, the dirty span's left end on screen
        EXTRN   dirtyRowFirst:WORD      ; per scanline, the picture offset of the first dirty byte
        EXTRN   dirtyRowLast:WORD       ; per scanline, the picture offset of the last dirty byte
DATA    ENDS

VideoSeg     EQU 0A000h         ; EGA/VGA display memory
EgaRowBytes  EQU 40             ; one EGA plane scanline, 320 pixels at 8 per byte
VgaRowBytes  EQU 320            ; one mode-13h scanline, a byte per pixel
SeqIndex     EQU 3C4h           ; EGA sequencer index port, data at the next port
GcIndex      EQU 3CEh           ; EGA graphics controller index port, data at the next port
SeqMapMask   EQU 2              ; sequencer: the planes a write reaches
GcSetReset   EQU 0              ; graphics controller: the set/reset color
GcEnableSR   EQU 1              ; graphics controller: the planes set/reset drives
GcFunction   EQU 3              ; graphics controller: data rotate / function select
GcMode       EQU 5              ; graphics controller: write mode
GcBitMask    EQU 8              ; graphics controller: the pixels of a byte a write changes

; TImgBuf (Types') fields the blitters touch
imgHeight    EQU 00h            ; height: scanlines per frame
imgWidth     EQU 02h            ; width: 8-pixel cells per scanline
imgFrameSize EQU 12h            ; frameSize: bytes per frame
imgTransp    EQU 17h            ; transp: far pointer to the mask
imgData      EQU 1Bh            ; data: the pixels, inline after the header

; The cell blitters and the clipped blitters share one frame layout, and the row loops run inside it.  Each prologue
; reserves the frame twice; only the first reservation is used.
; Arguments:
argDest      EQU 04h            ; dest: PImgBuf, the picture drawn into
argGfx       EQU 08h            ; gfx:  PImgBuf, the tile set
cellTile     EQU 0Ch            ; cell blitters: tileIdx, the frame of gfx drawn
cellY        EQU 0Eh            ; cell blitters: screenY, in 8-scanline cells
cellX        EQU 10h            ; cell blitters: screenX, in cells
keyCellKey   EQU 0Eh            ; BlitCellVgaKeyed: transpColor
keyCellY     EQU 10h            ; BlitCellVgaKeyed: screenY
keyCellX     EQU 12h            ; BlitCellVgaKeyed: screenX
clipFlag     EQU 0Ch            ; clipped blitters: flag, bit 0 masked, bit 2 save what is covered
clipTile     EQU 0Eh            ; clipped blitters: tileIdx
clipY        EQU 10h            ; clipped blitters: screenY, in cells, may be negative
clipX        EQU 12h            ; clipped blitters: screenX, in cells, may be negative
argSave      EQU 14h            ; clipped blitters: the save-under buffer, a PImgBuf where covered pixels go
keyClipKey   EQU 10h            ; BlitClippedVga: transpColor
keyClipY     EQU 12h            ; BlitClippedVga: screenY
keyClipX     EQU 14h            ; BlitClippedVga: screenX
keyClipSave  EQU 16h            ; BlitClippedVga: under
; Locals:
maskPtr      EQU -04h           ; far pointer, copy of gfx^.transp
spanLeft     EQU -06h           ; value recorded into dirtyRowLeft
viewRow      EQU -08h           ; first scanline, indexes the dirty-row tables
rowCount     EQU -0Ah           ; scanlines to draw
destOff      EQU -0Ch           ; running offset into dest^.data
srcOff       EQU -0Eh           ; running offset into gfx^.data (and the mask)
rowBytes     EQU -10h           ; bytes copied per scanline
destSkip     EQU -12h           ; dest bytes right of the tile
leftBytes    EQU -14h           ; dest bytes left of the tile
skipRight    EQU -16h           ; tile bytes clipped off the right
skipLeft     EQU -18h           ; tile bytes clipped off the left
saveFlag     EQU -1Ah           ; byte: copy the covered pixels to the save-under buffer first
saveOff      EQU -1Ch           ; running offset into the save-under buffer's data
keyColor     EQU -1Ch           ; VGA keyed frame: byte, the transparent color
keySaveOff   EQU -1Eh           ; VGA keyed frame: saveOff, moved down past keyColor

; HlineEga, HlineVga, VlineEga and VlineVga: color, nearest bp, then the line's own coordinates
lineColor    EQU 04h            ; color
hlRow        EQU 06h            ; Hline*: row, the screen scanline
hlX2         EQU 08h            ; Hline*: x2, the last pixel
hlX1         EQU 0Ah            ; Hline*: x1, the first pixel
vlX          EQU 06h            ; Vline*: x, the pixel column
vlY2         EQU 08h            ; Vline*: y2, the last scanline
vlY1         EQU 0Ah            ; Vline*: y1, the first scanline

CODE    SEGMENT BYTE PUBLIC             ; no 'CODE' class: {$L} merges it into the unit's segment
        ASSUME  CS:CODE, DS:DATA
        PUBLIC  BlitCellCga, BlitCellCgaMasked, BlitClippedCga
        PUBLIC  BlitCellEga, BlitCellEgaMasked, BlitClippedEga
        PUBLIC  BlitCellTandy, BlitCellTandyMasked, BlitClippedTandy
        PUBLIC  BlitCellVga, BlitCellVgaKeyed, BlitClippedVga
        PUBLIC  HlineEga, VlineEga, HlineVga, VlineVga

; Each mode has a cell blitter, a masked cell blitter and a clipped blitter (BlitCellCga, BlitCellCgaMasked and
; BlitClippedCga for CGA, and likewise for EGA and Tandy).  The cell blitters draw tile tileIdx of gfx into dest at
; cell (screenX, screenY), whole or through the tile's mask; the clipped blitters do the same for a tile that may hang
; off dest's edges, and can first save the pixels it covers into the save-under buffer.  The display mode fixes the
; bytes per 8-pixel cell row: CGA 2, EGA 4, Tandy 4, VGA 8.  VGA has no mask; BlitCellVgaKeyed and BlitClippedVga key
; on a color instead, passed as one more argument.

BlitCellCga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        cld                             ; CopyRows's movsb walks upwards
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[bp+cellY]           ; ax = screenY, in 8-scanline cells
        mov     cl,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = screenY * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width (dx, the high word, is dropped)
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+cellX]           ; ax = screenX, in cells
        mov     [bp+leftBytes],ax       ; leftBytes = screenX, in cells for now
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]          ; ES:DI = gfx, the tile set
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft, the dirty span's left end
        shl     word ptr [bp+spanLeft],1 ; to bytes, 2 a cell
        mov     ax,es:[di+imgWidth]
        shl     ax,1                    ; to bytes, 2 a cell
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = scanlines to draw
        shl     word ptr [bp+leftBytes],1 ; leftBytes to bytes, 2 a cell
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize] ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+cellTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        mov     [bp+srcOff],ax          ; srcOff = the tile's first byte in gfx^.data
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; nothing is saved to under
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     word ptr [bp+skipRight],0 ; or on the right
        call    CopyRows                ; copy the rows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh                     ; near return, popping the arguments
BlitCellCga ENDP

BlitCellCgaMasked PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[bp+cellY]           ; ax = screenY, in 8-scanline cells
        mov     cl,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = screenY * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width (dx, the high word, is dropped)
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+cellX]           ; ax = screenX, in cells
        mov     [bp+leftBytes],ax       ; leftBytes = screenX, in cells for now
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]          ; ES:DI = gfx, the tile set
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft, the dirty span's left end
        shl     word ptr [bp+spanLeft],1 ; to bytes, 2 a cell
        mov     ax,es:[di+imgWidth]
        shl     ax,1                    ; to bytes, 2 a cell
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = scanlines to draw
        mov     ax,es:[di+imgTransp]
        mov     [bp+maskPtr],ax         ; maskPtr: the tile set's mask
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1 ; leftBytes to bytes, 2 a cell
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize] ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+cellTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        mov     [bp+srcOff],ax          ; srcOff = the tile's first byte in gfx^.data
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; nothing is saved to under
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     word ptr [bp+skipRight],0 ; or on the right
        call    MaskRows                ; draw the rows through the mask
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh                     ; near return, popping the arguments
BlitCellCgaMasked ENDP

BlitClippedCga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        cld                             ; CopyRows's movsb walks upwards
        push    ds                      ; the data segment again, kept past the lds below
        lds     si,[bp+argGfx]          ; DS:SI = gfx, the tile set
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[si+imgTransp]
        mov     [bp+maskPtr],ax         ; maskPtr: the tile set's mask
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]           ; ax = screenX, in cells, negative left of dest
        cmp     ax,8000h                ; unsigned above 8000h is negative
        jbe     @@xOnScreen             ; x >= 0 (8000h itself counts as on screen)
        mov     [bp+skipLeft],ax        ; skipLeft = x ...
        neg     word ptr [bp+skipLeft]  ; ... negated: the tile cells left of the edge
        mov     word ptr [bp+leftBytes],0 ; drawn from dest's left edge
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     [bp+leftBytes],ax       ; leftBytes = x, in cells for now
@@checkRight:
        add     ax,[si+imgWidth]        ; ax = x + tile width, the tile's right end
        cmp     es:[di+imgWidth],ax     ; does dest's width reach it?
        jae     @@rightFits             ; yes: nothing clipped on the right
        sub     ax,es:[di+imgWidth]     ; ax = the tile cells past the right edge
        mov     [bp+skipRight],ax       ; skipRight = those cells
        mov     word ptr [bp+destSkip],0 ; nothing of dest lies right of the tile
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0 ; nothing clipped on the right
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
@@clipTop:
        mov     ax,[bp+clipY]           ; ax = screenY, in cells, negative above dest
        cmp     ax,8000h                ; unsigned above 8000h is negative
        jbe     @@yOnScreen             ; y >= 0
        neg     ax                      ; ax = -y, the cells above the top edge
        mov     cx,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = the scanlines above the top edge
        mov     bx,[si+imgHeight]       ; bx = the tile's scanlines
        mov     [bp+rowCount],bx        ; rowCount = the tile's scanlines ...
        sub     [bp+rowCount],ax        ; ... less the hidden ones
        mov     bx,[si+imgWidth]        ; bx = the tile width, in cells
        mul     bx                      ; ax = the hidden scanlines * tile width
        mov     [bp+srcOff],ax          ; srcOff = past the hidden rows, in cells for now
        mov     word ptr [bp+destOff],0 ; drawn from dest's first byte
        mov     word ptr [bp+viewRow],0 ; and its first scanline
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0  ; nothing clipped at the top
        mov     cx,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = y * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]       ; plus the tile's scanlines: one past its bottom
        cmp     ax,es:[di+imgHeight]    ; within dest's scanlines?
        jbe     @@bottomFits            ; yes: every row is drawn
        mov     ax,es:[di+imgHeight]    ; ax = dest's scanlines
        sub     ax,[bp+viewRow]         ; less the first scanline
        mov     [bp+rowCount],ax        ; rowCount = the rows above dest's bottom
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = all of them
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]        ; clipped off the left entirely?
        jb      @@offView
        cmp     ax,[bp+skipRight]       ; clipped off the right entirely?
        jb      @@offView
        mov     ax,[bp+srcOff]          ; ax = the hidden rows' cells
        cmp     ax,[si+imgFrameSize]    ; past the whole frame: clipped off the top?
        ja      @@offView
        mov     ax,[bp+destOff]         ; ax = the first cell drawn in dest
        cmp     ax,es:[di+imgFrameSize] ; beyond dest's last byte?
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]       ; more than the tile has: a negative count
        ja      @@offView
        jmp     @@draw                  ; something is visible
@@offView:
        pop     ds                      ; discard the extra copy of DS
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; near return, popping the arguments
@@draw:
        mov     ax,[bp+leftBytes]       ; ax = leftBytes, in cells
        shl     ax,1                    ; to bytes, 2 a cell
        mov     [bp+leftBytes],ax       ; leftBytes in bytes
        mov     [bp+spanLeft],ax        ; spanLeft, the dirty span's left end, the same
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]        ; less the cells clipped on the left
        sub     ax,[bp+skipRight]       ; and on the right: the visible cells
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]          ; ax = the first visible byte of the tile's frame
        mov     [bp+saveOff],ax         ; saveOff = the same offset in the save-under buffer, without the frame
        mov     ax,[si+imgFrameSize]    ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+clipTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        add     [bp+srcOff],ax          ; srcOff += the tile's frame
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; no save unless the masked path asks
        pop     ds                      ; DS = the data segment again, for the dirty-row tables
        test    byte ptr [bp+clipFlag],1 ; flag bit 0: masked draw
        jne     @@masked                ; set: take that path
        call    CopyRows                ; clear: copy the rows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; near return, popping the arguments
@@masked:
        mov     byte ptr [bp+saveFlag],0 ; assume no save
        test    byte ptr [bp+clipFlag],4 ; flag bit 2: save the covered pixels first
        je      @@noSave                ; clear: keep saveFlag 0
        mov     byte ptr [bp+saveFlag],1 ; set: save them to the save-under buffer
@@noSave:
        call    MaskRows                ; draw the rows, through the mask
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; near return, popping the arguments
BlitClippedCga ENDP

; The EGA and Tandy procedures repeat the CGA ones at 4 bytes per cell (two shl's for CGA's one).  EGA records
; spanLeft in cells, before the scaling, where the others record bytes; FlushView's EGA arm reads it as a column.

BlitCellEga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        cld                             ; CopyRows's movsb walks upwards
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[bp+cellY]           ; ax = screenY, in 8-scanline cells
        mov     cl,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = screenY * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width (dx, the high word, is dropped)
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+cellX]           ; ax = screenX, in cells
        mov     [bp+leftBytes],ax       ; leftBytes = screenX, in cells for now
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]          ; ES:DI = gfx, the tile set
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft = screenX, left in cells: FlushView reads a column
        mov     ax,es:[di+imgWidth]
        shl     ax,1                    ; to bytes, 4 a cell
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = scanlines to draw
        shl     word ptr [bp+leftBytes],1 ; leftBytes to bytes, 4 a cell
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize] ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+cellTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        mov     [bp+srcOff],ax          ; srcOff = the tile's first byte in gfx^.data
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; nothing is saved to under
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     word ptr [bp+skipRight],0 ; or on the right
        call    CopyRows                ; copy the rows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh                     ; near return, popping the arguments
BlitCellEga ENDP

BlitCellEgaMasked PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        cld
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[bp+cellY]           ; ax = screenY, in 8-scanline cells
        mov     cl,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = screenY * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width (dx, the high word, is dropped)
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+cellX]           ; ax = screenX, in cells
        mov     [bp+leftBytes],ax       ; leftBytes = screenX, in cells for now
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]          ; ES:DI = gfx, the tile set
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft = screenX, left in cells: FlushView reads a column
        mov     ax,es:[di+imgWidth]
        shl     ax,1                    ; to bytes, 4 a cell
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = scanlines to draw
        mov     ax,es:[di+imgTransp]
        mov     [bp+maskPtr],ax         ; maskPtr: the tile set's mask
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1 ; leftBytes to bytes, 4 a cell
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize] ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+cellTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        mov     [bp+srcOff],ax          ; srcOff = the tile's first byte in gfx^.data
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; nothing is saved to under
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     word ptr [bp+skipRight],0 ; or on the right
        call    MaskRows                ; draw the rows through the mask
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh                     ; near return, popping the arguments
BlitCellEgaMasked ENDP

BlitClippedEga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        cld                             ; CopyRows's movsb walks upwards
        push    ds                      ; the data segment again, kept past the lds below
        lds     si,[bp+argGfx]          ; DS:SI = gfx, the tile set
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[si+imgTransp]
        mov     [bp+maskPtr],ax         ; maskPtr: the tile set's mask
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]           ; ax = screenX, in cells, negative left of dest
        cmp     ax,8000h                ; unsigned above 8000h is negative
        jbe     @@xOnScreen             ; x >= 0 (8000h itself counts as on screen)
        mov     [bp+skipLeft],ax        ; skipLeft = x ...
        neg     word ptr [bp+skipLeft]  ; ... negated: the tile cells left of the edge
        mov     word ptr [bp+leftBytes],0 ; drawn from dest's left edge
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     [bp+leftBytes],ax       ; leftBytes = x, in cells for now
@@checkRight:
        add     ax,[si+imgWidth]        ; ax = x + tile width, the tile's right end
        cmp     es:[di+imgWidth],ax     ; does dest's width reach it?
        jae     @@rightFits             ; yes: nothing clipped on the right
        sub     ax,es:[di+imgWidth]     ; ax = the tile cells past the right edge
        mov     [bp+skipRight],ax       ; skipRight = those cells
        mov     word ptr [bp+destSkip],0 ; nothing of dest lies right of the tile
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0 ; nothing clipped on the right
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
@@clipTop:
        mov     ax,[bp+clipY]           ; ax = screenY, in cells, negative above dest
        cmp     ax,8000h                ; unsigned above 8000h is negative
        jbe     @@yOnScreen             ; y >= 0
        neg     ax                      ; ax = -y, the cells above the top edge
        mov     cx,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = the scanlines above the top edge
        mov     bx,[si+imgHeight]       ; bx = the tile's scanlines
        mov     [bp+rowCount],bx        ; rowCount = the tile's scanlines ...
        sub     [bp+rowCount],ax        ; ... less the hidden ones
        mov     bx,[si+imgWidth]        ; bx = the tile width, in cells
        mul     bx                      ; ax = the hidden scanlines * tile width
        mov     [bp+srcOff],ax          ; srcOff = past the hidden rows, in cells for now
        mov     word ptr [bp+destOff],0 ; drawn from dest's first byte
        mov     word ptr [bp+viewRow],0 ; and its first scanline
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0  ; nothing clipped at the top
        mov     cx,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = y * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]       ; plus the tile's scanlines: one past its bottom
        cmp     ax,es:[di+imgHeight]    ; within dest's scanlines?
        jbe     @@bottomFits            ; yes: every row is drawn
        mov     ax,es:[di+imgHeight]    ; ax = dest's scanlines
        sub     ax,[bp+viewRow]         ; less the first scanline
        mov     [bp+rowCount],ax        ; rowCount = the rows above dest's bottom
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = all of them
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]        ; clipped off the left entirely?
        jb      @@offView
        cmp     ax,[bp+skipRight]       ; clipped off the right entirely?
        jb      @@offView
        mov     ax,[bp+srcOff]          ; ax = the hidden rows' cells
        cmp     ax,[si+imgFrameSize]    ; past the whole frame: clipped off the top?
        ja      @@offView
        mov     ax,[bp+destOff]         ; ax = the first cell drawn in dest
        cmp     ax,es:[di+imgFrameSize] ; beyond dest's last byte?
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]       ; more than the tile has: a negative count
        ja      @@offView
        jmp     @@draw                  ; something is visible
@@offView:
        pop     ds                      ; discard the extra copy of DS
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; near return, popping the arguments
@@draw:
        mov     ax,[bp+leftBytes]       ; ax = leftBytes, in cells
        mov     [bp+spanLeft],ax        ; spanLeft = leftBytes, left in cells: FlushView reads a column
        mov     ax,[bp+leftBytes]
        shl     ax,1                    ; to bytes, 4 a cell
        shl     ax,1
        mov     [bp+leftBytes],ax       ; leftBytes in bytes
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]        ; less the cells clipped on the left
        sub     ax,[bp+skipRight]       ; and on the right: the visible cells
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]          ; ax = the first visible byte of the tile's frame
        mov     [bp+saveOff],ax         ; saveOff = the same offset in under, without the frame
        mov     ax,[si+imgFrameSize]    ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+clipTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        add     [bp+srcOff],ax          ; srcOff += the tile's frame
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; no save unless the masked path asks
        pop     ds                      ; DS = the data segment again, for the dirty-row tables
        test    byte ptr [bp+clipFlag],1 ; flag bit 0: masked draw
        jne     @@masked                ; set: take that path
        call    CopyRows                ; clear: copy the rows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; near return, popping the arguments
@@masked:
        mov     byte ptr [bp+saveFlag],0 ; assume no save
        test    byte ptr [bp+clipFlag],4 ; flag bit 2: save the covered pixels first
        je      @@noSave                ; clear: keep saveFlag 0
        mov     byte ptr [bp+saveFlag],1 ; set: save them to under
@@noSave:
        call    MaskRows                ; draw the rows, through the mask
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; near return, popping the arguments
BlitClippedEga ENDP

BlitCellTandy PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        cld                             ; CopyRows's movsb walks upwards
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[bp+cellY]           ; ax = screenY, in 8-scanline cells
        mov     cl,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = screenY * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width (dx, the high word, is dropped)
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+cellX]           ; ax = screenX, in cells
        mov     [bp+leftBytes],ax       ; leftBytes = screenX, in cells for now
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]          ; ES:DI = gfx, the tile set
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft, the dirty span's left end
        shl     word ptr [bp+spanLeft],1 ; to bytes, 4 a cell
        shl     word ptr [bp+spanLeft],1
        mov     ax,es:[di+imgWidth]
        shl     ax,1                    ; to bytes, 4 a cell
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = scanlines to draw
        shl     word ptr [bp+leftBytes],1 ; leftBytes to bytes, 4 a cell
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize] ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+cellTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        mov     [bp+srcOff],ax          ; srcOff = the tile's first byte in gfx^.data
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; nothing is saved to under
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     word ptr [bp+skipRight],0 ; or on the right
        call    CopyRows                ; copy the rows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh                     ; near return, popping the arguments
BlitCellTandy ENDP

BlitCellTandyMasked PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[bp+cellY]           ; ax = screenY, in 8-scanline cells
        mov     cl,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = screenY * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width (dx, the high word, is dropped)
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+cellX]           ; ax = screenX, in cells
        mov     [bp+leftBytes],ax       ; leftBytes = screenX, in cells for now
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]          ; ES:DI = gfx, the tile set
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft, the dirty span's left end
        shl     word ptr [bp+spanLeft],1 ; to bytes, 4 a cell
        shl     word ptr [bp+spanLeft],1
        mov     ax,es:[di+imgWidth]
        shl     ax,1                    ; to bytes, 4 a cell
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = scanlines to draw
        mov     ax,es:[di+imgTransp]
        mov     [bp+maskPtr],ax         ; maskPtr: the tile set's mask
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1 ; leftBytes to bytes, 4 a cell
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize] ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+cellTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        mov     [bp+srcOff],ax          ; srcOff = the tile's first byte in gfx^.data
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; nothing is saved to under
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     word ptr [bp+skipRight],0 ; or on the right
        call    MaskRows                ; draw the rows through the mask
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh                     ; near return, popping the arguments
BlitCellTandyMasked ENDP

BlitClippedTandy PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        cld                             ; CopyRows's movsb walks upwards
        push    ds                      ; the data segment again, kept past the lds below
        lds     si,[bp+argGfx]          ; DS:SI = gfx, the tile set
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[si+imgTransp]
        mov     [bp+maskPtr],ax         ; maskPtr: the tile set's mask
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]           ; ax = screenX, in cells, negative left of dest
        cmp     ax,8000h                ; unsigned above 8000h is negative
        jbe     @@xOnScreen             ; x >= 0 (8000h itself counts as on screen)
        mov     [bp+skipLeft],ax        ; skipLeft = x ...
        neg     word ptr [bp+skipLeft]  ; ... negated: the tile cells left of the edge
        mov     word ptr [bp+leftBytes],0 ; drawn from dest's left edge
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     [bp+leftBytes],ax       ; leftBytes = x, in cells for now
@@checkRight:
        add     ax,[si+imgWidth]        ; ax = x + tile width, the tile's right end
        cmp     es:[di+imgWidth],ax     ; does dest's width reach it?
        jae     @@rightFits             ; yes: nothing clipped on the right
        sub     ax,es:[di+imgWidth]     ; ax = the tile cells past the right edge
        mov     [bp+skipRight],ax       ; skipRight = those cells
        mov     word ptr [bp+destSkip],0 ; nothing of dest lies right of the tile
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0 ; nothing clipped on the right
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
@@clipTop:
        mov     ax,[bp+clipY]           ; ax = screenY, in cells, negative above dest
        cmp     ax,8000h                ; unsigned above 8000h is negative
        jbe     @@yOnScreen             ; y >= 0
        neg     ax                      ; ax = -y, the cells above the top edge
        mov     cx,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = the scanlines above the top edge
        mov     bx,[si+imgHeight]       ; bx = the tile's scanlines
        mov     [bp+rowCount],bx        ; rowCount = the tile's scanlines ...
        sub     [bp+rowCount],ax        ; ... less the hidden ones
        mov     bx,[si+imgWidth]        ; bx = the tile width, in cells
        mul     bx                      ; ax = the hidden scanlines * tile width
        mov     [bp+srcOff],ax          ; srcOff = past the hidden rows, in cells for now
        mov     word ptr [bp+destOff],0 ; drawn from dest's first byte
        mov     word ptr [bp+viewRow],0 ; and its first scanline
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0  ; nothing clipped at the top
        mov     cx,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = y * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]       ; plus the tile's scanlines: one past its bottom
        cmp     ax,es:[di+imgHeight]    ; within dest's scanlines?
        jbe     @@bottomFits            ; yes: every row is drawn
        mov     ax,es:[di+imgHeight]    ; ax = dest's scanlines
        sub     ax,[bp+viewRow]         ; less the first scanline
        mov     [bp+rowCount],ax        ; rowCount = the rows above dest's bottom
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = all of them
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]        ; clipped off the left entirely?
        jb      @@offView
        cmp     ax,[bp+skipRight]       ; clipped off the right entirely?
        jb      @@offView
        mov     ax,[bp+srcOff]          ; ax = the hidden rows' cells
        cmp     ax,[si+imgFrameSize]    ; past the whole frame: clipped off the top?
        ja      @@offView
        mov     ax,[bp+destOff]         ; ax = the first cell drawn in dest
        cmp     ax,es:[di+imgFrameSize] ; beyond dest's last byte?
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]       ; more than the tile has: a negative count
        ja      @@offView
        jmp     @@draw                  ; something is visible
@@offView:
        pop     ds                      ; discard the extra copy of DS
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; near return, popping the arguments
@@draw:
        mov     ax,[bp+leftBytes]       ; ax = leftBytes, in cells
        shl     ax,1                    ; to bytes, 4 a cell
        shl     ax,1
        mov     [bp+leftBytes],ax       ; leftBytes in bytes
        mov     [bp+spanLeft],ax        ; spanLeft, the dirty span's left end, the same
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]        ; less the cells clipped on the left
        sub     ax,[bp+skipRight]       ; and on the right: the visible cells
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]          ; ax = the first visible byte of the tile's frame
        mov     [bp+saveOff],ax         ; saveOff = the same offset in under, without the frame
        mov     ax,[si+imgFrameSize]    ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+clipTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        add     [bp+srcOff],ax          ; srcOff += the tile's frame
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; no save unless the masked path asks
        pop     ds                      ; DS = the data segment again, for the dirty-row tables
        test    byte ptr [bp+clipFlag],1 ; flag bit 0: masked draw
        jne     @@masked                ; set: take that path
        call    CopyRows                ; clear: copy the rows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; near return, popping the arguments
@@masked:
        mov     byte ptr [bp+saveFlag],0 ; assume no save
        test    byte ptr [bp+clipFlag],4 ; flag bit 2: save the covered pixels first
        je      @@noSave                ; clear: keep saveFlag 0
        mov     byte ptr [bp+saveFlag],1 ; set: save them to under
@@noSave:
        call    MaskRows                ; draw the rows, through the mask
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; near return, popping the arguments
BlitClippedTandy ENDP

; The scanline loops, entered from a blitter's frame with bx = viewRow, cx = rowCount and DS = the data segment.  Each
; marks its row dirty and widens the row's dirty range for FlushView.  CopyRows copies; MaskRows ANDs the mask in and
; ORs the tile over it.  Note: CopyRows never adds skipLeft or skipRight to srcOff, so a tile clipped at a side and
; drawn unmasked is read at the clipped width's stride; MaskRows adds both.  On an equal offset CopyRows rewrites the
; row's first and last entries and MaskRows leaves them (ja/jb against jae/jbe), so only CopyRows then rewrites
; dirtyRowLeft.

CopyRows PROC NEAR
        mov     byte ptr [bx+dirtyRows],1 ; mark scanline bx drawn
        shl     bx,1                    ; bx now indexes the Word tables
        mov     ax,[bp+leftBytes]       ; ax = the dest bytes left of the tile
        add     [bp+destOff],ax         ; destOff = the row's first byte drawn
        mov     ax,[bp+destOff]
        cmp     ax,[bx+dirtyRowFirst]   ; compare the row's recorded first byte
        ja      @@spanKnown             ; above it: the recorded span already starts earlier
        mov     [bx+dirtyRowFirst],ax   ; at or below: the new first byte
        mov     ax,[bp+spanLeft]        ; ax = the span's left end on screen
        mov     [bx+dirtyRowLeft],ax    ; recorded with it
@@spanKnown:
        push    ds                      ; keep DS past the lds
        lds     si,[bp+argGfx]          ; DS:SI = gfx
        les     di,[bp+argDest]         ; ES:DI = dest
        add     si,imgData              ; past the tile set's header
        add     si,[bp+srcOff]          ; to the tile row's first byte
        add     di,imgData              ; past dest's header
        add     di,[bp+destOff]         ; to the row's first byte drawn
        push    cx
        mov     cx,[bp+rowBytes]        ; cx = bytes in the row
        rep movsb                       ; copy the row
        pop     cx
        pop     ds                      ; DS = the data segment again
        mov     ax,[bp+rowBytes]
        add     [bp+srcOff],ax          ; srcOff past the row (skipLeft and skipRight are not added)
        add     [bp+destOff],ax         ; destOff past the row
        mov     ax,[bp+destOff]         ; ax = one past the row's last byte
        dec     ax                      ; ax = the row's last byte
        cmp     ax,[bx+dirtyRowLast]    ; compare the row's recorded last byte
        jb      @@endKnown              ; below it: the recorded span already ends later
        mov     [bx+dirtyRowLast],ax    ; at or above: the new last byte
@@endKnown:
        mov     ax,[bp+destSkip]        ; ax = the dest bytes right of the tile
        add     [bp+destOff],ax         ; destOff = the next scanline's start
        shr     bx,1                    ; bx back to a scanline index
        inc     bx
        loop    CopyRows                ; until cx rows are drawn
        ret                             ; back to the calling blitter
CopyRows ENDP

MaskRows PROC NEAR
        mov     byte ptr [bx+dirtyRows],1 ; mark scanline bx drawn
        shl     bx,1                    ; bx now indexes the Word tables
        mov     ax,[bp+skipLeft]        ; ax = the tile's bytes left of the edge
        add     [bp+srcOff],ax          ; srcOff skips them
        mov     ax,[bp+leftBytes]       ; ax = the dest bytes left of the tile
        add     [bp+destOff],ax         ; destOff = the row's first byte drawn
        mov     ax,[bp+destOff]
        cmp     ax,[bx+dirtyRowFirst]   ; compare the row's recorded first byte
        jae     @@spanKnown             ; at or above it: the recorded span starts no later
        mov     [bx+dirtyRowFirst],ax   ; below: the new first byte
        mov     ax,[bp+spanLeft]        ; ax = the span's left end on screen
        mov     [bx+dirtyRowLeft],ax    ; recorded with it
@@spanKnown:
        push    ds                      ; keep DS past the lds instructions below
        les     di,[bp+argDest]         ; ES:DI = dest
        add     di,[bp+destOff]         ; to the row's first byte, less the header
        push    cx
        mov     cx,[bp+rowBytes]        ; cx = bytes in the row
@@pixel:
        cmp     byte ptr [bp+saveFlag],0 ; saving the covered pixels?
        je      @@noSave
        lds     si,[bp+argSave]         ; DS:SI = the save-under buffer
        add     si,[bp+saveOff]         ; to this byte's place in it
        mov     al,es:[di+imgData]      ; al = the dest byte about to be covered
        mov     [si+imgData],al         ; saved
@@noSave:
        lds     si,[bp+maskPtr]         ; DS:SI = the tile set's mask
        add     si,[bp+srcOff]          ; to the mask byte (the mask has no header)
        mov     ah,[si]                 ; ah = the mask byte: set bits keep dest
        lds     si,[bp+argGfx]          ; DS:SI = gfx
        add     si,[bp+srcOff]          ; to the tile byte, less the header
        mov     al,[si+imgData]         ; al = the tile byte, zero where masked
        and     es:[di+imgData],ah      ; clear the pixels the tile covers
        or      es:[di+imgData],al      ; and draw the tile over them
        inc     word ptr [bp+srcOff]
        inc     word ptr [bp+saveOff]
        inc     word ptr [bp+destOff]
        inc     di
        loop    @@pixel
        pop     cx
        pop     ds                      ; DS = the data segment again
        mov     ax,[bp+destOff]         ; ax = one past the row's last byte
        dec     ax                      ; ax = the row's last byte
        cmp     ax,[bx+dirtyRowLast]    ; compare the row's recorded last byte
        jbe     @@endKnown              ; at or below it: the recorded span ends no earlier
        mov     [bx+dirtyRowLast],ax    ; above: the new last byte
@@endKnown:
        mov     ax,[bp+destSkip]        ; ax = the dest bytes right of the tile
        add     [bp+destOff],ax         ; destOff = the next scanline's start
        mov     ax,[bp+skipRight]       ; ax = the tile's bytes past the right edge
        add     [bp+srcOff],ax          ; srcOff skips them
        add     [bp+saveOff],ax         ; and so does saveOff
        shr     bx,1                    ; bx back to a scanline index
        inc     bx
        dec     cx
        je      @@done
        jmp     MaskRows                ; the next row (too far back for loop)
@@done:
        ret                             ; back to the calling blitter
MaskRows ENDP

BlitCellVga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch                  ; reserve the frame of locals
        sub     sp,1Ch
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        cld                             ; CopyRowsVga's movsb walks upwards
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[bp+cellY]           ; ax = screenY, in 8-scanline cells
        mov     cl,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = screenY * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width (dx, the high word, is dropped)
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+cellX]           ; ax = screenX, in cells
        mov     [bp+leftBytes],ax       ; leftBytes = screenX, in cells for now
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]          ; ES:DI = gfx, the tile set
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft, the dirty span's left end
        shl     word ptr [bp+spanLeft],1 ; to bytes, 8 a cell
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1
        mov     ax,es:[di+imgWidth]
        shl     ax,1                    ; to bytes, 8 a cell
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = scanlines to draw
        shl     word ptr [bp+leftBytes],1 ; leftBytes to bytes, 8 a cell
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize] ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+cellTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        mov     [bp+srcOff],ax          ; srcOff = the tile's first byte in gfx^.data
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; nothing is saved to under
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     word ptr [bp+skipRight],0 ; or on the right
        call    CopyRowsVga             ; copy the rows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh                     ; near return, popping the arguments
BlitCellVga ENDP

; BlitCellVgaKeyed and BlitClippedVga take the transparent color as one more argument and draw through KeyRows, with
; keyColor and keySaveOff added to the frame.  Both still copy gfx^.transp into maskPtr, which KeyRows never reads.

BlitCellVgaKeyed PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh                  ; reserve the frame of locals
        sub     sp,1Eh
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ah,[bp+keyCellKey]      ; ah = transpColor, the color left undrawn
        mov     [bp+keyColor],ah        ; kept in the frame for KeyRows
        mov     ax,[bp+keyCellY]        ; ax = screenY, in 8-scanline cells
        mov     cl,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = screenY * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width (dx, the high word, is dropped)
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+keyCellX]        ; ax = screenX, in cells
        mov     [bp+leftBytes],ax       ; leftBytes = screenX, in cells for now
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]          ; ES:DI = gfx, the tile set
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+keyCellX]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft, the dirty span's left end
        shl     word ptr [bp+spanLeft],1 ; to bytes, 8 a cell
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1
        mov     ax,es:[di+imgWidth]
        shl     ax,1                    ; to bytes, 8 a cell
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = scanlines to draw
        mov     ax,es:[di+imgTransp]
        mov     [bp+maskPtr],ax         ; maskPtr: unused, KeyRows keys on a color
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1 ; leftBytes to bytes, 8 a cell
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize] ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+cellTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        mov     [bp+srcOff],ax          ; srcOff = the tile's first byte in gfx^.data
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; nothing is saved to under
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     word ptr [bp+skipRight],0 ; or on the right
        call    KeyRows                 ; draw the rows, skipping keyColor
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     10h                     ; near return, popping the arguments
BlitCellVgaKeyed ENDP

BlitClippedVga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh                  ; reserve the frame of locals
        sub     sp,1Eh
        push    ss
        push    ds                      ; the data segment, for the row loops' tables
        cld                             ; CopyRowsVga's movsb walks upwards
        push    ds                      ; the data segment again, kept past the lds below
        lds     si,[bp+argGfx]          ; DS:SI = gfx, the tile set
        les     di,[bp+argDest]         ; ES:DI = dest, the picture drawn into
        mov     ax,[si+imgTransp]
        mov     [bp+maskPtr],ax         ; maskPtr: unused, KeyRows keys on a color
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ah,[bp+keyClipKey]      ; ah = transpColor, the color left undrawn
        mov     [bp+keyColor],ah        ; kept in the frame for KeyRows
        mov     ax,[bp+keyClipX]        ; ax = screenX, in cells, negative left of dest
        cmp     ax,8000h                ; unsigned above 8000h is negative
        jbe     @@xOnScreen             ; x >= 0 (8000h itself counts as on screen)
        mov     [bp+skipLeft],ax        ; skipLeft = x ...
        neg     word ptr [bp+skipLeft]  ; ... negated: the tile cells left of the edge
        mov     word ptr [bp+leftBytes],0 ; drawn from dest's left edge
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0 ; nothing clipped on the left
        mov     [bp+leftBytes],ax       ; leftBytes = x, in cells for now
@@checkRight:
        add     ax,[si+imgWidth]        ; ax = x + tile width, the tile's right end
        cmp     es:[di+imgWidth],ax     ; does dest's width reach it?
        jae     @@rightFits             ; yes: nothing clipped on the right
        sub     ax,es:[di+imgWidth]     ; ax = the tile cells past the right edge
        mov     [bp+skipRight],ax       ; skipRight = those cells
        mov     word ptr [bp+destSkip],0 ; nothing of dest lies right of the tile
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0 ; nothing clipped on the right
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+keyClipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
@@clipTop:
        mov     ax,[bp+keyClipY]        ; ax = screenY, in cells, negative above dest
        cmp     ax,8000h                ; unsigned above 8000h is negative
        jbe     @@yOnScreen             ; y >= 0
        neg     ax                      ; ax = -y, the cells above the top edge
        mov     cx,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = the scanlines above the top edge
        mov     bx,[si+imgHeight]       ; bx = the tile's scanlines
        mov     [bp+rowCount],bx        ; rowCount = the tile's scanlines ...
        sub     [bp+rowCount],ax        ; ... less the hidden ones
        mov     bx,[si+imgWidth]        ; bx = the tile width, in cells
        mul     bx                      ; ax = the hidden scanlines * tile width
        mov     [bp+srcOff],ax          ; srcOff = past the hidden rows, in cells for now
        mov     word ptr [bp+destOff],0 ; drawn from dest's first byte
        mov     word ptr [bp+viewRow],0 ; and its first scanline
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0  ; nothing clipped at the top
        mov     cx,3                    ; shift count: 8 scanlines per cell
        shl     ax,cl                   ; ax = y * 8, the first scanline
        mov     [bp+viewRow],ax         ; viewRow: indexes the dirty-row tables
        mov     bx,es:[di+imgWidth]     ; bx = dest width, in cells
        mul     bx                      ; ax = viewRow * dest width
        mov     [bp+destOff],ax         ; destOff = the first scanline, in cells for now
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]       ; plus the tile's scanlines: one past its bottom
        cmp     ax,es:[di+imgHeight]    ; within dest's scanlines?
        jbe     @@bottomFits            ; yes: every row is drawn
        mov     ax,es:[di+imgHeight]    ; ax = dest's scanlines
        sub     ax,[bp+viewRow]         ; less the first scanline
        mov     [bp+rowCount],ax        ; rowCount = the rows above dest's bottom
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = all of them
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]        ; clipped off the left entirely?
        jb      @@offView
        cmp     ax,[bp+skipRight]       ; clipped off the right entirely?
        jb      @@offView
        mov     ax,[bp+srcOff]          ; ax = the hidden rows' cells
        cmp     ax,[si+imgFrameSize]    ; past the whole frame: clipped off the top?
        ja      @@offView
        mov     ax,[bp+destOff]         ; ax = the first cell drawn in dest
        cmp     ax,es:[di+imgFrameSize] ; beyond dest's last byte?
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]       ; more than the tile has: a negative count
        ja      @@offView
        jmp     @@draw                  ; something is visible
@@offView:
        pop     ds                      ; discard the extra copy of DS
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     16h                     ; near return, popping the arguments
@@draw:
        mov     ax,[bp+leftBytes]       ; ax = leftBytes, in cells
        shl     ax,1                    ; to bytes, 8 a cell
        shl     ax,1
        shl     ax,1
        mov     [bp+leftBytes],ax       ; leftBytes in bytes
        mov     [bp+spanLeft],ax        ; spanLeft, the dirty span's left end, the same
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]        ; less the cells clipped on the left
        sub     ax,[bp+skipRight]       ; and on the right: the visible cells
        shl     ax,1
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = bytes drawn per scanline
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]          ; ax = the first visible byte of the tile's frame
        mov     [bp+keySaveOff],ax      ; keySaveOff = the same offset in under, without the frame
        mov     ax,[si+imgFrameSize]    ; ax = the tile set's bytes per frame
        xor     bx,bx                   ; bx = 0, so that bl alone carries tileIdx
        mov     bl,[bp+clipTile]        ; bx = tileIdx, the frame drawn
        mul     bx                      ; ax = frameSize * tileIdx
        add     [bp+srcOff],ax          ; srcOff += the tile's frame
        mov     bx,[bp+viewRow]         ; bx = the first scanline, as the row loops take it
        mov     cx,[bp+rowCount]        ; cx = the scanlines, the row loops' counter
        mov     byte ptr [bp+saveFlag],0 ; no save unless the keyed path asks
        pop     ds                      ; DS = the data segment again, for the dirty-row tables
        test    byte ptr [bp+clipFlag],1 ; flag bit 0: keyed draw
        jne     @@keyed                 ; set: take that path
        call    CopyRowsVga             ; clear: copy the rows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     16h                     ; near return, popping the arguments
@@keyed:
        mov     byte ptr [bp+saveFlag],0 ; assume no save
        test    byte ptr [bp+clipFlag],4 ; flag bit 2: save the covered pixels first
        je      @@noSave                ; clear: keep saveFlag 0
        mov     byte ptr [bp+saveFlag],1 ; set: save them to under
@@noSave:
        call    KeyRows                 ; draw the rows, skipping keyColor
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     16h                     ; near return, popping the arguments
BlitClippedVga ENDP

; The VGA procedures' own row loops.  CopyRowsVga is CopyRows over again, instruction for instruction; KeyRows is
; MaskRows with the mask replaced by a test against keyColor and under and saveOff read from the keyed frame's slots.

CopyRowsVga PROC NEAR
        mov     byte ptr [bx+dirtyRows],1 ; mark scanline bx drawn
        shl     bx,1                    ; bx now indexes the Word tables
        mov     ax,[bp+leftBytes]       ; ax = the dest bytes left of the tile
        add     [bp+destOff],ax         ; destOff = the row's first byte drawn
        mov     ax,[bp+destOff]
        cmp     ax,[bx+dirtyRowFirst]   ; compare the row's recorded first byte
        ja      @@spanKnown             ; above it: the recorded span already starts earlier
        mov     [bx+dirtyRowFirst],ax   ; at or below: the new first byte
        mov     ax,[bp+spanLeft]        ; ax = the span's left end on screen
        mov     [bx+dirtyRowLeft],ax    ; recorded with it
@@spanKnown:
        push    ds                      ; keep DS past the lds
        lds     si,[bp+argGfx]          ; DS:SI = gfx
        les     di,[bp+argDest]         ; ES:DI = dest
        add     si,imgData              ; past the tile set's header
        add     si,[bp+srcOff]          ; to the tile row's first byte
        add     di,imgData              ; past dest's header
        add     di,[bp+destOff]         ; to the row's first byte drawn
        push    cx
        mov     cx,[bp+rowBytes]        ; cx = bytes in the row
        rep movsb                       ; copy the row
        pop     cx
        pop     ds                      ; DS = the data segment again
        mov     ax,[bp+rowBytes]
        add     [bp+srcOff],ax          ; srcOff past the row (skipLeft and skipRight are not added)
        add     [bp+destOff],ax         ; destOff past the row
        mov     ax,[bp+destOff]         ; ax = one past the row's last byte
        dec     ax                      ; ax = the row's last byte
        cmp     ax,[bx+dirtyRowLast]    ; compare the row's recorded last byte
        jb      @@endKnown              ; below it: the recorded span already ends later
        mov     [bx+dirtyRowLast],ax    ; at or above: the new last byte
@@endKnown:
        mov     ax,[bp+destSkip]        ; ax = the dest bytes right of the tile
        add     [bp+destOff],ax         ; destOff = the next scanline's start
        shr     bx,1                    ; bx back to a scanline index
        inc     bx
        loop    CopyRowsVga             ; until cx rows are drawn
        ret                             ; back to the calling blitter
CopyRowsVga ENDP

KeyRows PROC NEAR
        mov     byte ptr [bx+dirtyRows],1 ; mark scanline bx drawn
        shl     bx,1                    ; bx now indexes the Word tables
        mov     ax,[bp+skipLeft]        ; ax = the tile's bytes left of the edge
        add     [bp+srcOff],ax          ; srcOff skips them
        mov     ax,[bp+leftBytes]       ; ax = the dest bytes left of the tile
        add     [bp+destOff],ax         ; destOff = the row's first byte drawn
        mov     ax,[bp+destOff]
        cmp     ax,[bx+dirtyRowFirst]   ; compare the row's recorded first byte
        jae     @@spanKnown             ; at or above it: the recorded span starts no later
        mov     [bx+dirtyRowFirst],ax   ; below: the new first byte
        mov     ax,[bp+spanLeft]        ; ax = the span's left end on screen
        mov     [bx+dirtyRowLeft],ax    ; recorded with it
@@spanKnown:
        push    ds                      ; keep DS past the lds instructions below
        les     di,[bp+argDest]         ; ES:DI = dest
        add     di,[bp+destOff]         ; to the row's first byte, less the header
        push    cx
        mov     cx,[bp+rowBytes]        ; cx = bytes in the row
@@pixel:
        cmp     byte ptr [bp+saveFlag],0 ; saving the covered pixels?
        je      @@noSave
        lds     si,[bp+keyClipSave]     ; DS:SI = under
        add     si,[bp+keySaveOff]      ; to this byte's place in it
        mov     al,es:[di+imgData]      ; al = the dest byte about to be covered
        mov     [si+imgData],al         ; saved
@@noSave:
        lds     si,[bp+argGfx]          ; DS:SI = gfx
        add     si,[bp+srcOff]          ; to the tile byte, less the header
        mov     al,[si+imgData]         ; al = the tile pixel
        cmp     al,[bp+keyColor]        ; the transparent color?
        je      @@keyed                 ; yes: leave the dest pixel
        mov     es:[di+imgData],al      ; no: draw it
@@keyed:
        inc     word ptr [bp+srcOff]
        inc     word ptr [bp+keySaveOff]
        inc     word ptr [bp+destOff]
        inc     di
        loop    @@pixel
        pop     cx
        pop     ds                      ; DS = the data segment again
        mov     ax,[bp+destOff]         ; ax = one past the row's last byte
        dec     ax                      ; ax = the row's last byte
        cmp     ax,[bx+dirtyRowLast]    ; compare the row's recorded last byte
        jbe     @@endKnown              ; at or below it: the recorded span ends no earlier
        mov     [bx+dirtyRowLast],ax    ; above: the new last byte
@@endKnown:
        mov     ax,[bp+destSkip]        ; ax = the dest bytes right of the tile
        add     [bp+destOff],ax         ; destOff = the next scanline's start
        mov     ax,[bp+skipRight]       ; ax = the tile's bytes past the right edge
        add     [bp+srcOff],ax          ; srcOff skips them
        add     [bp+keySaveOff],ax      ; and so does keySaveOff
        shr     bx,1                    ; bx back to a scanline index
        inc     bx
        dec     cx
        je      @@done
        jmp     KeyRows                 ; the next row (too far back for loop)
@@done:
        ret                             ; back to the calling blitter
KeyRows ENDP

; HlineEga(x1,x2: Word; row,color: Byte) and VlineEga(y1,y2: Byte; x: Integer; color: Byte) -- Hline's and Vline's
; EGA arms (VmEga), drawn straight into display memory at A000:0.  Each puts its end points in order first (HlineEga by
; a signed compare, VlineEga by an unsigned one).  Set/reset writes color into all four planes; the bit-mask register
; picks the pixels, and a read first loads the latches so the pixels it leaves out keep their color.  The byte written
; is irrelevant: set/reset supplies every plane.

HlineEga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,0
        push    ss
        push    ds
        mov     ax,[bp+hlX1]
        cmp     ax,[bp+hlX2]            ; x1 against x2
        jle     @@ordered               ; already in order (a signed test)
        xchg    [bp+hlX2],ax            ; x2 = x1, ax = the old x2
        mov     [bp+hlX1],ax            ; x1 = the old x2
@@ordered:
        mov     dx,GcIndex
        mov     al,GcMode               ; select the mode register
        out     dx,al
        inc     dx
        mov     al,0                    ; write mode 0
        out     dx,al
        mov     dx,GcIndex
        mov     al,GcEnableSR           ; select enable set/reset
        out     dx,al
        inc     dx
        mov     al,0Fh                  ; set/reset drives all four planes
        out     dx,al
        mov     dx,GcIndex
        mov     al,GcSetReset           ; select set/reset
        out     dx,al
        inc     dx
        mov     al,[bp+lineColor]       ; the line color, one bit per plane
        out     dx,al
        mov     dx,GcIndex
        mov     al,GcFunction           ; select data rotate / function select
        out     dx,al
        inc     dx
        mov     al,0                    ; no rotate; replace
        out     dx,al
        mov     dx,SeqIndex
        mov     al,SeqMapMask           ; select the map mask
        out     dx,al
        inc     dx
        mov     al,0Fh                  ; writes reach all four planes
        out     dx,al
        cld                             ; stosb walks rightwards
        mov     ax,VideoSeg
        mov     es,ax                   ; ES = display memory
        mov     al,[bp+hlRow]           ; al = row, the scanline
        mov     bl,EgaRowBytes          ; bl = bytes per scanline
        mul     bl                      ; ax = row * 40
        mov     bx,[bp+hlX1]            ; bx = x1
        mov     cl,3                    ; shift count: 8 pixels per byte
        shr     bx,cl                   ; bx = x1's byte in the scanline
        add     ax,bx                   ; ax = x1's byte on screen
        mov     di,ax                   ; ES:DI = that byte
        mov     ax,[bp+hlX1]
        and     ax,7                    ; ax = x1's pixel within its byte
        je      @@span                  ; on a byte boundary: no left edge byte
        mov     bx,0FFh                 ; bl = every pixel of the byte ...
        mov     cl,al                   ; cl = the pixels left of x1
        shr     bx,cl                   ; ... from x1 on
        mov     dx,[bp+hlX1]
        and     dx,-8h                  ; x1 down to its byte boundary
        add     dx,8                    ; dx = the next byte boundary
        mov     [bp+hlX1],dx            ; x1 = that boundary, where the whole bytes start
        cmp     dx,[bp+hlX2]            ; does the line reach past this byte?
        jbe     @@leftMask              ; yes: keep the pixels to the byte end
        mov     cx,dx                   ; cx = the boundary ...
        sub     cx,[bp+hlX2]            ; ... less x2
        dec     cx                      ; cx = the pixels past x2 in the byte
        mov     ax,0FFh                 ; al = every pixel ...
        shl     ax,cl                   ; ... up to x2
        and     bl,al                   ; bl = the pixels from x1 to x2
@@leftMask:
        mov     dx,GcIndex
        mov     al,GcBitMask            ; select the bit mask
        out     dx,al
        inc     dx
        mov     al,bl                   ; the edge byte's pixels
        out     dx,al
        mov     al,es:[di]              ; read the byte: loads the latches, keeping the other pixels
        stosb                           ; write it (set/reset supplies the color); di to the next byte
@@span:
        mov     ax,[bp+hlX2]
        sub     ax,[bp+hlX1]            ; ax = x2 less x1, now the first whole-byte pixel
        js      @@restore               ; negative: nothing left to draw
        inc     ax                      ; ax = the pixels left to draw
        mov     bx,ax                   ; bx keeps that count
        mov     cl,3                    ; shift count: 8 pixels per byte
        shr     ax,cl                   ; ax = the whole bytes
        mov     cx,ax                   ; cx = the whole bytes, for rep
        mov     dx,GcIndex
        mov     al,GcBitMask            ; select the bit mask
        out     dx,al
        inc     dx
        mov     al,0FFh                 ; every pixel of the byte
        out     dx,al
        rep stosb                       ; fill the whole bytes
        and     bl,7                    ; bl = the pixels past the whole bytes
        je      @@restore               ; none: done
        mov     cl,bl                   ; cl = those pixels
        mov     bx,0FF00h               ; bh = every pixel ...
        shr     bx,cl                   ; ... shifted so bl holds the first cl pixels
        mov     dx,GcIndex
        mov     al,GcBitMask            ; select the bit mask
        out     dx,al
        inc     dx
        mov     al,bl                   ; the right edge byte's pixels
        out     dx,al
        mov     al,es:[di]              ; read the byte: loads the latches
        stosb                           ; write the right edge byte
@@restore:
        mov     dx,GcIndex
        mov     al,GcEnableSR           ; select enable set/reset
        out     dx,al
        inc     dx
        mov     al,0                    ; set/reset off: writes carry CPU data again
        out     dx,al
        mov     dx,GcIndex
        mov     al,GcBitMask            ; select the bit mask
        out     dx,al
        inc     dx
        mov     al,0FFh                 ; every pixel of a byte writable again
        out     dx,al
        pop     ds
        pop     ss
        pop     bp
        ret     8                       ; near return, popping the arguments
HlineEga ENDP

VlineEga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,0
        push    ss
        push    ds
        mov     al,[bp+vlY1]            ; al = y1
        cmp     al,[bp+vlY2]            ; y1 against y2
        jbe     @@ordered               ; already in order
        xchg    [bp+vlY2],al            ; y2 = y1, al = the old y2
        mov     [bp+vlY1],al            ; y1 = the old y2
@@ordered:
        mov     dx,GcIndex
        mov     al,GcMode               ; select the mode register
        out     dx,al
        inc     dx
        mov     al,0                    ; write mode 0
        out     dx,al
        mov     dx,GcIndex
        mov     al,GcEnableSR           ; select enable set/reset
        out     dx,al
        inc     dx
        mov     al,0Fh                  ; set/reset drives all four planes
        out     dx,al
        mov     dx,GcIndex
        mov     al,GcSetReset           ; select set/reset
        out     dx,al
        inc     dx
        mov     al,[bp+lineColor]       ; the line color, one bit per plane
        out     dx,al
        mov     dx,GcIndex
        mov     al,GcFunction           ; select data rotate / function select
        out     dx,al
        inc     dx
        mov     al,0                    ; no rotate; replace
        out     dx,al
        mov     dx,SeqIndex
        mov     al,SeqMapMask           ; select the map mask
        out     dx,al
        inc     dx
        mov     al,0Fh                  ; writes reach all four planes
        out     dx,al
        cld
        mov     ax,VideoSeg
        mov     es,ax                   ; ES = display memory
        mov     al,[bp+vlY1]            ; al = y1, the first scanline
        mov     bl,EgaRowBytes          ; bl = bytes per scanline
        mul     bl                      ; ax = y1 * 40
        mov     bx,[bp+vlX]
        mov     cl,3                    ; shift count: 8 pixels per byte
        shr     bx,cl                   ; bx = x's byte in the scanline
        add     ax,bx                   ; ax = the first pixel's byte on screen
        mov     di,ax                   ; ES:DI = that byte
        mov     cx,[bp+vlX]
        and     cl,7                    ; cl = x's pixel within its byte
        mov     bx,80h                  ; bl = the byte's leftmost pixel ...
        shr     bx,cl                   ; ... moved to x's
        mov     dx,GcIndex
        mov     al,GcBitMask            ; select the bit mask
        out     dx,al
        inc     dx
        mov     al,bl                   ; x's pixel alone
        out     dx,al
        sub     ch,ch                   ; ch = 0: cx is the Byte count below
        mov     cl,[bp+vlY2]            ; cl = y2
        sub     cl,[bp+vlY1]            ; less y1
        inc     cl                      ; cx = the line's scanlines
@@pixel:
        mov     al,es:[di]              ; read the byte: loads the latches
        mov     es:[di],al              ; write it: set/reset colors the masked pixel
        add     di,EgaRowBytes          ; the same byte on the next scanline
        loop    @@pixel                 ; until every scanline is drawn
        mov     dx,GcIndex
        mov     al,GcEnableSR           ; select enable set/reset
        out     dx,al
        inc     dx
        mov     al,0                    ; set/reset off: writes carry CPU data again
        out     dx,al
        mov     dx,GcIndex
        mov     al,GcBitMask            ; select the bit mask
        out     dx,al
        inc     dx
        mov     al,0FFh                 ; every pixel of a byte writable again
        out     dx,al
        pop     ds
        pop     ss
        pop     bp
        ret     8                       ; near return, popping the arguments
VlineEga ENDP

; HlineVga(x1,x2: Word; row,color: Byte) and VlineVga(y1,y2: Word; x: Integer; color: Byte) -- Hline's and Vline's
; VGA arms (VmVga, BIOS mode 13h), one byte per pixel at A000:0.  Neither orders its end points: they take x1 <= x2 and
; y1 <= y2.

HlineVga PROC NEAR
        push    bp
        mov     bp,sp
        cld                             ; stosb walks rightwards
        push    ds
        mov     bx,VgaRowBytes          ; bx = bytes per scanline
        xor     ax,ax                   ; ax = 0, so that al alone carries row
        mov     al,[bp+hlRow]           ; ax = row
        mul     bx                      ; ax = row * 320
        add     ax,[bp+hlX1]            ; plus x1: the first pixel
        mov     di,ax                   ; ES:DI will address it
        mov     ax,VideoSeg
        mov     es,ax                   ; ES = display memory
        xor     ax,ax
        mov     al,[bp+lineColor]       ; al = color
        mov     cx,[bp+hlX2]            ; cx = x2
        inc     cx
        sub     cx,[bp+hlX1]            ; less x1: the pixels to fill
        rep stosb                       ; fill the run
        pop     ds
        pop     bp
        ret     8                       ; near return, popping the arguments
HlineVga ENDP

VlineVga PROC NEAR
        push    bp
        mov     bp,sp
        cld                             ; stosb steps di forwards
        push    ds
        mov     bx,VgaRowBytes          ; bx = bytes per scanline
        mov     ax,[bp+vlY1]            ; ax = y1
        mul     bx                      ; ax = y1 * 320
        add     ax,[bp+vlX]             ; plus x: the first pixel
        mov     di,ax                   ; ES:DI will address it
        mov     ax,VideoSeg
        mov     es,ax                   ; ES = display memory
        xor     ax,ax
        mov     al,[bp+lineColor]       ; al = color
        mov     cx,[bp+vlY2]            ; cx = y2
        inc     cx
        sub     cx,[bp+vlY1]            ; less y1: the line's scanlines
@@pixel:
        stosb                           ; draw the pixel; di one past it
        add     di,VgaRowBytes-1        ; the same column on the next scanline
        loop    @@pixel                 ; until every scanline is drawn
        pop     ds
        pop     bp
        ret     8                       ; near return, popping the arguments
VlineVga ENDP

CODE    ENDS
        END
