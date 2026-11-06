{ Pictures in the display mode's layout (TImgBuf): loading them from .DAX files, mirroring, recoloring and filling them,
  copying them to and from the screen, drawing tiles and lines, the VGA palette, and flushing viewPicture's dirty rows
  to the screen. Every tile-drawing leaf, and the EGA and VGA arms of Hline and Vline, are in blit.asm.
  GDVars.displayMode picks one of four paths: CGA, EGA, Tandy, or VGA in mode 13h. VGA keeps no transparency mask; its
  keyed blits test the picture's transparent color instead.

  The pictures are TImgBuf; the CGA line colors are GDConsts', and the rest of its state is GDVars'. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Blit;

interface

uses DaxIo, Types, C_Video, GDConsts, GDVars, Dos, GameIo, Mouse, C_Vm, C_Ega;

type
  { An 8-pixel chunk as stored in a picture: one byte per pixel. }
  TChunk = array[0..7] of Byte;

{ Returns the transparency mask of an 8-pixel chunk.
  @param(transpColor The color that is transparent.)
  @param(chunk The chunk's eight pixels, one byte each.)
  @returns(A bit set for each pixel equal to transpColor, bit 7 for chunk[0] down to bit 0 for chunk[7].) }
function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;

{ Gives the CGA color of a palette index.
  @param(color The palette index.)
  @param(map Unused: a leftover packed color map, never read.)
  @returns(The CGA color 0..3.) }
function SrcNibble(color: Byte; map: Types.TColorMap): Byte;

{ Switches the display to a BIOS video mode, remembering the mode it replaces so RestoreVideoMode can go back. The BIOS
  result is not checked, so an unsupported mode fails silently while the current-mode bookkeeping still records it.
  @param(mode BIOS INT 10h mode number to select.) }
procedure SetVideoMode(mode: Byte);

{ Returns to the mode that was current before the last SetVideoMode call. That call saves the mode it replaces, so two
  calls in a row toggle between two modes. }
procedure RestoreVideoMode;

{ Reverses the bit order of a byte, reflecting eight EGA pixels (one plane byte or mask byte) left to right.
  @param(value Byte to reflect.)
  @returns(The byte with bits 0..7 swapped with bits 7..0.) }
function MirrorBits(value: Byte): Byte;

{ Reverses the order of the eight 2-bit CGA pixels packed in a word, reflecting them left to right.
  @param(value Two CGA pixel bytes of one cell.)
  @returns(The word with its pixel order reversed.) }
function MirrorPairs(value: Word): Word;

{ Swaps the two 4-bit Tandy pixels of a byte, reflecting them left to right.
  @param(value Byte holding two pixels.)
  @returns(The byte with its nibbles exchanged.) }
function MirrorNibbles(value: Byte): Byte;

{ Allocates a zero-filled picture: the header, then the frames at the mode's bytes per 8-pixel row (CGA 2, VGA 8, EGA
  and Tandy 4).
  @param(height The picture's height in scanlines.)
  @param(width The picture's width in 8-pixel columns.)
  @param(count The number of frames.)
  @param(flag Bit 0 also allocates a zero-filled mask the size of the frames, outside VGA mode.)
  @param(pic Receives the picture.) }
procedure AllocPic(height, width, count: Word; flag: Byte; var pic: Types.PImgBuf);

{ Frees a picture's mask, frameSize * count bytes, and its block, allocSize bytes, and sets pic to nil; a nil pic is
  left alone.
  @param(pic The picture freed.) }
procedure FreePic(var pic: Types.PImgBuf);

{ Turns a loaded .DAX picture into a picture buffer. It loads the header's colors into the picture palette from the
  header's first slot and builds the color tables: the nibble table always, then the palette CGA table when the header
  fills slots $20..$8F exactly, else the nibble CGA table, recording which of the two is in use. The pixels that follow
  the tables are then decoded.
  @param(data The loaded record.)
  @param(hasMask Bit 0 asks for a mask.)
  @param(transpColor The transparent color.)
  @param(needsAlloc True allocates a fresh picture; False (LoadPic's choice in VGA mode) makes the loaded buffer itself
    the picture, without a mask, sized as loaded.)
  @param(loadedSize The loaded buffer's size.)
  @param(pic Receives the picture.) }
procedure PreparePic(var data: Types.PByteArr; hasMask: Byte; transpColor: Byte; needsAlloc: Boolean;
                     loadedSize: Word; var pic: Types.PImgBuf);

{ Frees any picture already held, loads a record of a .dax archive and builds the picture from it; outside the 256-color
  mode the loaded buffer is then freed. The keyboard is flushed after a successful load only.
  @param(name The archive's name.)
  @param(fileId The record.)
  @param(hasMask Asks for a transparency mask, outside the 256-color mode.)
  @param(transpColor The transparent color.)
  @param(pic Receives the picture.) }
procedure LoadPic(name: String; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);

{ Writes a picture into another mirrored left to right, mask included, after copying its colorMap: CGA words through
  MirrorPairs, EGA plane bytes through MirrorBits, Tandy bytes through MirrorNibbles, VGA bytes as they are.
  @param(src The picture mirrored.)
  @param(dst Receives the mirror image.) }
procedure MirrorPic(src, dst: Types.PImgBuf);

{ Copies a screen area, the picture's size, into a picture.
  @param(col The area's left text column.)
  @param(row The area's top text row.)
  @param(pic Receives the area.) }
procedure GrabPic(col, row: Integer; pic: Types.PImgBuf);

{ Copies a picture to the screen. EGA writes one byte per plane per column, selecting each plane through the Sequencer
  Map Mask, and re-enables all four planes afterward.
  @param(screenX The left text column.)
  @param(screenY The top text row.)
  @param(pic The picture shown.) }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);

{ Decodes a picture's frames of source pixels, one byte a pixel, into its layout for the display mode, and builds the
  mask when the picture has one. CGA takes four 2-bit pixels a byte through SrcNibble and cgaPixelColors, the mask
  cgaPixelMasks bits for the transparent pixels; EGA sets each pixel's bit in the planes of its paletteNibbles color,
  the group's ComputeMask byte filling all four mask bytes; Tandy takes two 4-bit pixels a byte through paletteNibbles,
  its mask comparing those nibbles with transpColor; VGA copies each frame as it is. Note: in Tandy mode, after each
  frame the mask pass rescans every byte written so far, not just that frame's. With transpColor 0 that is not
  idempotent: a byte whose low nibble alone matches has $F added to its mask at each later rescan, and from the second
  one the mask's bit 4 clears part of the high pixel.
  @param(imgData The source pixels.)
  @param(srcOff Where they start in imgData; advanced past them.)
  @param(hasMask Unused.)
  @param(transpColor The transparent color.)
  @param(pic The picture decoded into.) }
procedure ExpandPicFrames(imgData: Types.PByteArr; var srcOff: Word; hasMask: Byte; transpColor: Byte;
                          pic: Types.PImgBuf);

{ Draws a horizontal line on a scanline. CGA and Tandy are drawn here; EGA and VGA go to blit.asm. Of the Pascal arms
  only CGA puts x1 and x2 in order; HlineEga orders them itself, HlineVga does not.
  @param(x1 The first pixel column.)
  @param(x2 The last pixel column.)
  @param(row The scanline.)
  @param(color The line's color.) }
procedure Hline(x1, x2: Word; row, color: Byte);

{ Draws a vertical line at a pixel column. Of the Pascal arms only CGA puts y1 and y2 in order; VlineEga orders them
  itself, VlineVga does not. Note: in CGA mode, when y1 = y2 the odd bank is skipped whatever the row's parity, so a
  one-pixel line on an odd scanline draws nothing.
  @param(y1 The first scanline.)
  @param(y2 The last scanline.)
  @param(x The pixel column.)
  @param(color The line's color.) }
procedure Vline(y1, y2: Byte; x: Integer; color: Byte);

{ Draws a tile of a graphic into a buffer at a text cell.
  @param(screenX The left text column.)
  @param(screenY The top text row.)
  @param(tileIdx The tile, a frame of gfx.)
  @param(flag Bit 0 asks for the masked draw, which is taken when gfx has a mask, and in VGA mode whether it has one or
    not.)
  @param(gfx The graphic.)
  @param(dest The buffer drawn into.) }
procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ Draws a tile that may hang off dest's edges; the assembly routines read flag themselves.
  @param(screenX The left text column; may be negative.)
  @param(screenY The top text row; may be negative.)
  @param(tileIdx The tile, a frame of gfx.)
  @param(flag Bit 0 asks for the masked draw; only then does bit 2 save the covered pixels into saveUnder first.)
  @param(gfx The graphic.)
  @param(dest The buffer drawn into.) }
procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ In the 256-color mode, copies entries of the picture palette into the same entries of another palette.
  @param(startIdx The first entry.)
  @param(count The number of entries.)
  @param(dest The palette copied into.) }
procedure ShadowPaletteEntries(startIdx: Byte; count: Word; var dest: Types.TPalette256);

{ In VGA mode, loads DAC registers from a palette (video BIOS function 1012h).
  @param(startIdx The first register.)
  @param(count The number of registers.)
  @param(src The palette.) }
procedure SetDacPalette(startIdx, count: Word; src: Types.TPalette256);

{ Copies a tile of an icon into a frame of the moving combat icon, mirrored when asked, together with its mask, when it
  has one, and its key color. Mirroring goes through a scratch image of 24 rows by 3 cells, the combat icon size, which
  has a mask outside the 256-color mode. Note: the key color always comes from the icon's own image, even in the
  mirrored case.
  @param(kind The icon animation row.)
  @param(tileIdx The icon's tile.)
  @param(frame The frame of the moving icon filled.)
  @param(isMirrored Set to mirror the tile.) }
procedure CopyIconTile(kind, tileIdx, frame: Byte; isMirrored: Boolean);

{ Builds the moving combat icon's four frames from an icon's tiles 0 and 1: tile 0, tile 0 mirrored, tile 1 mirrored and
  tile 1, so the second half of the cycle walks the other way.
  @param(kind The icon animation row.) }
procedure BuildIconFrames(kind: Byte);

{ Fills a rectangle of a picture with a color and marks the rows it touched in the span tables for FlushView. Columns
  are clipped to the picture (x may be negative), and rows are clipped at its bottom when y >= 0. Note: a negative y
  fills rows 0 to lastRow, the Word height - Abs(y), with no bottom clip; once Abs(y) passes height that Word wraps, and
  the loop runs 65537 + height - Abs(y) rows. Nothing bounds the row to the span tables' 168 entries either: rows
  168..199 of a 200-row picture write into the next table.
  @param(x The left pixel column.)
  @param(y The top row.)
  @param(width The width in pixels.)
  @param(height The height in rows.)
  @param(color The fill color.)
  @param(colorMap Passed on to SrcNibble in CGA mode, which never reads it.)
  @param(pic The picture filled.) }
procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImgBuf);

{ Replaces colors in a frame of a picture: for each of the 16 pairs whose colors differ, pixels of fromColors[i] become
  toColors[i]. The frames are copied into a scratch picture, changed there and copied back. With isDithered set, CGA and
  Tandy replace a matching pixel one time in four, and EGA through a random mask with about a quarter of its bits set;
  VGA does not dither, and skips a pair whose from color equals the scratch picture's transparentColor, which AllocPic
  leaves 0. Note: VGA tests the scratch copy at pic's offset, which for frame > 0 lies past the scratch copy's frames.
  And each pass of the color loop sets the frame count again against pic^, where frame is no longer negative, so one
  frame is remapped and copied back even when frame was negative.
  @param(fromColors The colors replaced.)
  @param(toColors Their replacements.)
  @param(frame The frame, 0 when it is negative.)
  @param(isDithered Replaces a matching pixel about one time in four, outside VGA mode.)
  @param(pic The picture.) }
procedure RemapPic(fromColors, toColors: Types.TPalette16; frame: Integer; isDithered: Boolean;
                   pic: Types.PImgBuf);

{ Copies viewPicture's dirty spans to the screen between HideMouse and ShowMouse and resets the span tables. View row n
  is screen scanline n + 8, and a row's span lands dirtyRowLeft bytes past the scanline's first 8-pixel column.
  dirtyRowLeft is not reset: each writer stores it together with a lowered dirtyRowFirst, so a marked row's value is
  current. EGA takes two passes: it writes each span's plane bytes into the off-screen page at A200, then moves every
  span to A000 in write mode 1, so that the latches carry all four planes. Note: a tile or rectangle on rows 168..199
  spills into the next table (see dirtyRows). }
procedure FlushView;

implementation

type
  PByte = ^Byte;

  { The header of a .DAX picture as loaded: lastPaletteEntry + 1 RGB triples follow it, then the packed color tables
    PreparePic reads, then the pixels. In VGA mode PreparePic turns the loaded buffer itself into the TImgBuf. }
  PDaxHeader = ^TDaxHeader;
  TDaxHeader = record
    { becomes TImgBuf.height }
    hdrH: Byte;
    { becomes TImgBuf.width }
    hdrW: Byte;
    { copied to TImgBuf.hdrC }
    hdrC: Word;
    { copied to TImgBuf.hdrD }
    hdrD: Word;
    { frames }
    hdrCount: Word;
    { where the picture's colors start in the palette }
    firstPaletteSlot: Byte;
    { palette entries in the header, less one }
    lastPaletteEntry: Byte
  end;

const
  { EGA page 1, where FlushView stages the rows }
  EGA_OFFSCREEN_SEG = $A200;
  { the Graphics Controller's Mode register value, write mode 1: a write stores the latched planes }
  GC_WRITE_MODE_1 = 1;
  { INT 10h function: palette and DAC registers, by subfunction in AL }
  BIOS_PALETTE = $10;
  { its subfunction that loads CX DAC registers from BX on, from ES:DX }
  BIOS_SET_DAC_BLOCK = $12;

var
  { The two interleaved CGA banks as arrays of scanlines. Hline and Vline address the screen through a far ^Byte built
    from these, not through Mem[seg:ofs]. }
  cgaEvenBank: array[0..99] of Types.TCgaRow absolute $B800: $0000;
  cgaOddBank: array[0..99] of Types.TCgaRow absolute $BA00: $0000;

{ The assembly routines in blit.asm, called near. The clipped ones take saveUnder, then the public caller's parameters
  in the same order. }
{$F-}
{$L BLIT.OBJ}
{ Draws a frame of a graphic opaque into a CGA buffer (two bytes per cell) at a character-cell position, unclipped, and
  marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellCga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into a CGA
  buffer (two bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellCgaMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic into a CGA buffer (two bytes per cell) at a character-cell position, clipped against the
  edges of dest, opaque or masked as flag asks, and marks the touched scanlines dirty for FlushView. A frame lying
  entirely off dest is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of flag set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedCga(under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                         dest: Types.PImgBuf); external;

{ Draws a frame of a graphic opaque into an EGA buffer (four plane bytes per cell) at a character-cell position,
  unclipped, and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellEga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into an EGA
  buffer (four plane bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellEgaMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic into an EGA buffer (four plane bytes per cell) at a character-cell position, clipped
  against the edges of dest, opaque or masked as flag asks, and marks the touched scanlines dirty for FlushView. A frame
  lying entirely off dest is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows out of
  step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of flag set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedEga(under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                         dest: Types.PImgBuf); external;

{ Draws a frame of a graphic opaque into a Tandy buffer (four bytes per cell) at a character-cell position, unclipped,
  and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellTandy(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into a Tandy
  buffer (four bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellTandyMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic into a Tandy buffer (four bytes per cell) at a character-cell position, clipped against the
  edges of dest, opaque or masked as flag asks, and marks the touched scanlines dirty for FlushView. A frame lying
  entirely off dest is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of flag set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedTandy(under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                           dest: Types.PImgBuf); external;

{ Draws a frame of a graphic opaque into a 256-color buffer (eight bytes per cell) at a character-cell position,
  unclipped, and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellVga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic into a 256-color buffer (eight bytes per cell) at a character-cell position, unclipped,
  keeping the background where a pixel has the transparent color, and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(transpColor The color left out.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellVgaKeyed(screenX, screenY: Integer; transpColor, tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic into a 256-color buffer (eight bytes per cell) at a character-cell position, clipped
  against the buffer's edges, opaque or keyed on the transparent color as the flags ask, and marks the touched scanlines
  dirty for FlushView. A frame lying entirely off the buffer is skipped. Note: an opaque frame cut at the left or right
  edge is drawn with its rows out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing keyed with bit 2 of the flags set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(transpColor The color left out when drawing keyed.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(flag Bit 0 selects keyed drawing; bit 2 saves the covered bytes when drawing keyed.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedVga(under: Types.PImgBuf; screenX, screenY: Integer; transpColor, tileIdx, flag: Byte; gfx,
                         dest: Types.PImgBuf); external;

{ Hline's EGA arm, drawn straight into display memory at A000:0 through set/reset; it puts its end points in order.
  @param(x1 The first pixel column.)
  @param(x2 The last pixel column.)
  @param(row The scanline.)
  @param(color The line's color.) }
procedure HlineEga(x1, x2: Word; row, color: Byte); external;

{ Hline's VGA arm, one byte per pixel at A000:0; it takes x1 <= x2.
  @param(x1 The first pixel column.)
  @param(x2 The last pixel column.)
  @param(row The scanline.)
  @param(color The line's color.) }
procedure HlineVga(x1, x2: Word; row, color: Byte); external;

{ Vline's EGA arm, drawn straight into display memory at A000:0 through set/reset; it puts its end points in order.
  @param(y1 The first scanline.)
  @param(y2 The last scanline.)
  @param(x The pixel column.)
  @param(color The line's color.) }
procedure VlineEga(y1, y2: Byte; x: Integer; color: Byte); external;

{ Vline's VGA arm, one byte per pixel at A000:0; it takes y1 <= y2, as Words.
  @param(y1 The first scanline.)
  @param(y2 The last scanline.)
  @param(x The pixel column.)
  @param(color The line's color.) }
procedure VlineVga(y1, y2: Word; x: Integer; color: Byte); external;
{$F+}

function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;
var
  mask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  transpHigh: Byte;
  bit: Byte;
  i: Byte;
begin
  mask := 0;
  bit := $80;
  for i := 0 to SizeOf(chunk) - 1 do begin
    if chunk[i] = transpColor then Inc(mask, bit);
    bit := bit shr 1;
  end;
  ComputeMask := mask;
end;

function SrcNibble(color: Byte; map: Types.TColorMap): Byte;
begin
  if GDVars.paletteMode <> 0 then
    SrcNibble := GDVars.paletteCgaColors[color]
  else
    SrcNibble := GDVars.nibbleCgaColors[GDVars.paletteNibbles[color]];
end;

procedure SetVideoMode(mode: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  oldMode: Word;
begin
  GDVars.savedVideoMode := GDVars.curVideoMode;
  GDVars.regs.ah := C_Video.BIOS_SET_VIDEO_MODE;
  GDVars.regs.al := mode;
  Intr($10, Registers(GDVars.regs));
  GDVars.curVideoMode := mode;
end;

procedure RestoreVideoMode;
begin
  Blit.SetVideoMode(GDVars.savedVideoMode);
end;

procedure PreparePic(var data: Types.PByteArr; hasMask: Byte; transpColor: Byte; needsAlloc: Boolean;
                     loadedSize: Word; var pic: Types.PImgBuf);
var
  i: Byte;
  j: Byte;
  picHeight: Byte;
  picWidth: Byte;
  { named apart from the TImgBuf fields the with block below writes them to }
  picOriginX: Word;
  picOriginY: Word;
  paletteCount: Word;
  firstPaletteSlot: Byte;
  picCount: Word;
  { Note: never written, so pic^.colorMap receives garbage }
  colorMapScratch: Types.TColorMap;
  { cursor through the header, then ExpandPicFrames' srcOff }
  readOfs: Word;
  { Unused in this version; see the other implementations of this routine. }
  colorTables: array[1..513] of Byte;
  frameSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  chunk: array[1..8] of Byte;
begin
  Move(PDaxHeader(data)^.hdrH, picHeight, SizeOf(picHeight));
  Move(PDaxHeader(data)^.hdrW, picWidth, SizeOf(picWidth));
  Move(PDaxHeader(data)^.hdrC, picOriginX, SizeOf(picOriginX));
  Move(PDaxHeader(data)^.hdrD, picOriginY, SizeOf(picOriginY));
  Move(PDaxHeader(data)^.hdrCount, picCount, SizeOf(picCount));
  Move(PDaxHeader(data)^.firstPaletteSlot, firstPaletteSlot, SizeOf(firstPaletteSlot));
  paletteCount := PDaxHeader(data)^.lastPaletteEntry + 1;

  Move(data^[SizeOf(TDaxHeader)], GDVars.picturePalette[firstPaletteSlot, 0],
       paletteCount * SizeOf(Types.TRgb));
  readOfs := paletteCount * SizeOf(Types.TRgb) + SizeOf(TDaxHeader);
  { Two 4-bit colors per packed byte, high nibble first. }
  for i := 0 to (paletteCount div 2) - 1 do begin
    GDVars.paletteNibbles[Word(firstPaletteSlot) + Word(i) * 2] := data^[readOfs] shr 4;
    GDVars.paletteNibbles[Word(firstPaletteSlot) + Word(i) * 2 + 1] := data^[readOfs] and $F;
    Inc(readOfs);
  end;

  { Four 2-bit CGA colors per packed byte, high pair first. }
  if (firstPaletteSlot = $20) and (paletteCount = 112) then begin
    { paletteCgaColors entries 0..15 }
    for i := 0 to 3 do begin
      for j := 0 to 3 do
        GDVars.paletteCgaColors[Word(i) * 4 + Word(j)] := (data^[readOfs] shr (6 - j * 2)) and 3;
      Inc(readOfs);
    end;
    { then the header's own slots, from firstPaletteSlot }
    for i := 0 to (paletteCount div 4) - 1 do begin
      for j := 0 to 3 do
        GDVars.paletteCgaColors[Word(firstPaletteSlot) + Word(i) * 4 + Word(j)] :=
          (data^[readOfs] shr (6 - j * 2)) and 3;
      Inc(readOfs);
    end;
    GDVars.paletteMode := 1;
  end else begin
    { nibbleCgaColors entries 0..15 }
    for i := 0 to SizeOf(GDVars.nibbleCgaColors) div 4 - 1 do begin
      for j := 0 to 3 do
        GDVars.nibbleCgaColors[Word(i) * 4 + Word(j)] := (data^[readOfs] shr (6 - j * 2)) and 3;
      Inc(readOfs);
    end;
    GDVars.paletteMode := 0;
  end;

  if needsAlloc then
    Blit.AllocPic(picHeight, picWidth, picCount, hasMask, pic)
  else begin
    { The loaded buffer becomes the picture. }
    frameSize := picHeight * picWidth * 8;
    pic := Types.PImgBuf(data);
    pic^.height := picHeight;
    pic^.width := picWidth;
    pic^.frameSize := frameSize;
    pic^.count := picCount;
    pic^.transp := nil;
    pic^.allocSize := loadedSize;
  end;

  with pic^ do begin
    hdrC := picOriginX;
    hdrD := picOriginY;
    transparentColor := transpColor;
    colorMap := colorMapScratch;
  end;

  Blit.ExpandPicFrames(data, readOfs, hasMask, transpColor, pic);
end;

procedure LoadPic(name: String; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);
var
  dataSize: Word;
  { passed straight on to PreparePic }
  data: Types.PByteArr;
begin
  if pic <> nil then
    Blit.FreePic(pic);
  DaxIo.LoadDax(name, '.dax', fileId, dataSize, data);
  if dataSize = 0 then Exit;
  Blit.PreparePic(data, Byte(hasMask), transpColor, GDVars.displayMode <> C_Vm.VGA, dataSize, pic);
  if GDVars.displayMode <> C_Vm.VGA then
    FreeMem(data, dataSize);
  GameIo.FlushKeys;
end;

procedure ExpandPicFrames(imgData: Types.PByteArr; var srcOff: Word; hasMask: Byte; transpColor: Byte;
                          pic: Types.PImgBuf);
var
  chunk: TChunk;
  frame: Word;
  col: Word;
  row: Word;
  dstOff: Word;
  maskOff: Word;
  mask: Byte;
  k: Byte;
  j: Byte;
  bit: Byte;
  { EGA's plane counter }
  plane: Byte;
  { the pixel's 4-bit color, looked up once before the plane loop }
  color: Byte;
  { Unused in this version; see the other implementations of this routine. }
  vgaPalette: array[1..769] of Byte;
begin
  if pic = nil then Exit;
  with pic^ do begin
  dstOff := 0;
  maskOff := 0;
  case GDVars.displayMode of
    C_Vm.CGA:
      begin
        for frame := 1 to count do
          for row := 0 to height - 1 do
            for col := 0 to width - 1 do begin
                    Move(imgData^[srcOff], chunk, SizeOf(chunk));
                    if transp <> nil then begin
                      mask := Blit.ComputeMask(transpColor, chunk);
                      bit := $80;
                      for j := 1 to 2 do begin
                        for k := 4 to 7 do begin
                          if (bit and mask) > 0 then
                            transp^[maskOff] := transp^[maskOff] or GDConsts.cgaPixelMasks[k];
                          bit := bit shr 1;
                        end;
                        Inc(maskOff);
                      end;
                    end;
                    for k := 0 to SizeOf(GDConsts.cgaPixelColors[0]) - 1 do
                      data[dstOff] := data[dstOff] or
                        GDConsts.cgaPixelColors[Blit.SrcNibble(chunk[k], colorMap)][k];
                    if transp <> nil then
                      data[dstOff] := data[dstOff] and not transp^[maskOff - 2];
                    Inc(dstOff);
                    for k := 4 to 4 + SizeOf(GDConsts.cgaPixelColors[0]) - 1 do
                      data[dstOff] := data[dstOff] or
                        GDConsts.cgaPixelColors[Blit.SrcNibble(chunk[k], colorMap)][k - 4];
                    if transp <> nil then
                      data[dstOff] := data[dstOff] and not transp^[maskOff - 1];
                    Inc(dstOff);
                    Inc(srcOff, SizeOf(chunk));
                  end;
      end;
    C_Vm.EGA:
      begin
        for frame := 1 to count do
          for row := 0 to height - 1 do
            for col := 0 to width - 1 do begin
                    Move(imgData^[srcOff], chunk, SizeOf(chunk));
                    if transp <> nil then
                      FillChar(transp^[dstOff], 4, Blit.ComputeMask(transpColor, chunk));
                    bit := $80;
                    for k := 0 to SizeOf(chunk) - 1 do begin
                      color := GDVars.paletteNibbles[chunk[k]];
                      for plane := 0 to SizeOf(GDConsts.egaPlaneBits) - 1 do
                        if (GDConsts.egaPlaneBits[plane] and color) > 0 then
                          data[dstOff + plane] := data[dstOff + plane] or bit;
                      bit := bit shr 1;
                    end;
                    if transp <> nil then
                      for plane := 0 to 3 do
                        data[dstOff + plane] := data[dstOff + plane] and not transp^[dstOff];
                    Inc(dstOff, 4);
                    Inc(srcOff, SizeOf(chunk));
                  end;
      end;
    C_Vm.TANDY:
      begin
        for frame := 1 to count do begin
            for col := 0 to frameSize - 1 do begin
                data[dstOff] :=
                  (GDVars.paletteNibbles[imgData^[srcOff]] shl 4) + GDVars.paletteNibbles[imgData^[srcOff + 1]];
                Inc(dstOff);
                Inc(srcOff, 2);
              end;
            if transp <> nil then
              for col := 0 to dstOff - 1 do begin
                  if (data[col] shr 4) = transpColor then
                    transp^[col] := $F0;
                  if (data[col] and $F) = transpColor then
                    Inc(transp^[col], $F);
                  data[col] := data[col] and not transp^[col];
                end;
          end;
      end;
    C_Vm.VGA:
      begin
        for frame := 1 to count do begin
            Move(imgData^[srcOff], data[dstOff], frameSize);
            Inc(dstOff, frameSize);
            Inc(srcOff, frameSize);
          end;
      end;
  end;
  end;
end;

procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  leftSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rightSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  srcOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  destOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  lastRow: Word;
  { Unused in this version; see the other implementations of this routine. }
  y: Byte;
  useMask: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  maskOff: Word;
begin
  useMask := (flag and 1 <> 0) and ((gfx^.transp <> nil) or (GDVars.displayMode = C_Vm.VGA));
  case GDVars.displayMode of
    C_Vm.CGA: if useMask then Blit.BlitCellCgaMasked(screenX, screenY, tileIdx, gfx, dest)
       else Blit.BlitCellCga(screenX, screenY, tileIdx, gfx, dest);
    C_Vm.EGA: if useMask then Blit.BlitCellEgaMasked(screenX, screenY, tileIdx, gfx, dest)
       else Blit.BlitCellEga(screenX, screenY, tileIdx, gfx, dest);
    C_Vm.TANDY: if useMask then Blit.BlitCellTandyMasked(screenX, screenY, tileIdx, gfx, dest)
       else Blit.BlitCellTandy(screenX, screenY, tileIdx, gfx, dest);
    C_Vm.VGA: if useMask then Blit.BlitCellVgaKeyed(screenX, screenY, gfx^.transparentColor, tileIdx, gfx, dest)
       else Blit.BlitCellVga(screenX, screenY, tileIdx, gfx, dest);
  end;
end;

procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  clipLeft: Word;
  { Unused in this version; see the other implementations of this routine. }
  clipRight: Word;
  { Unused in this version; see the other implementations of this routine. }
  leftSkip: Word;
  { Unused in this version; see the other implementations of this routine. }
  rightSkip: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskClipLeft: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskClipRight: Word;
  { Unused in this version; see the other implementations of this routine. }
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  srcOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  destOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  saveOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  lastRow: Word;
  { Unused in this version; see the other implementations of this routine. }
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskOff: Word;
begin
  case GDVars.displayMode of
    C_Vm.CGA: Blit.BlitClippedCga(GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
    C_Vm.EGA: Blit.BlitClippedEga(GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
    C_Vm.TANDY: Blit.BlitClippedTandy(GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
    C_Vm.VGA: Blit.BlitClippedVga(GDVars.saveUnder, screenX, screenY, gfx^.transparentColor, tileIdx, flag, gfx,
                                    dest);
  end;
end;

function MirrorBits(value: Byte): Byte;
var
  mirrored: Byte;
begin
  mirrored := value shl 7;
  Inc(mirrored, (value and 2) shl 5);
  Inc(mirrored, (value and 4) shl 3);
  Inc(mirrored, (value and 8) shl 1);
  Inc(mirrored, (value and $10) shr 1);
  Inc(mirrored, (value and $20) shr 3);
  Inc(mirrored, (value and $40) shr 5);
  Inc(mirrored, (value and $80) shr 7);
  MirrorBits := mirrored;
end;

function MirrorPairs(value: Word): Word;
var
  mirrored: Word;
begin
  mirrored := (value and GDConsts.cgaPixelMasks[7]) shl 14;
  Inc(mirrored, (value and GDConsts.cgaPixelMasks[6]) shl 10);
  Inc(mirrored, (value and GDConsts.cgaPixelMasks[5]) shl 6);
  Inc(mirrored, (value and GDConsts.cgaPixelMasks[4]) shl 2);
  Inc(mirrored, (value and GDConsts.cgaPixelMasks[3]) shr 2);
  Inc(mirrored, (value and GDConsts.cgaPixelMasks[2]) shr 6);
  Inc(mirrored, (value and GDConsts.cgaPixelMasks[1]) shr 10);
  Inc(mirrored, (value and GDConsts.cgaPixelMasks[0]) shr 14);
  MirrorPairs := mirrored;
end;

function MirrorNibbles(value: Byte): Byte;
var
  mirrored: Byte;
begin
  mirrored := value shl 4;
  Inc(mirrored, (value and $F0) shr 4);
  MirrorNibbles := mirrored;
end;

procedure MirrorPic(src, dst: Types.PImgBuf);
var
  dstOff: Word;
  srcOff: Word;
  rowStart: Word;
  rowBytes: Word;
  col: Word;
  row: Word;
  plane: Byte;
  cell: Word;
begin
  if (src = nil) or (dst = nil) then Exit;
  with src^ do begin
  Move(colorMap, dst^.colorMap, SizeOf(Types.TColorMap));
  case GDVars.displayMode of
    { CGA: words, through MirrorPairs }
    C_Vm.CGA:
      begin
        rowBytes := width * SizeOf(cell);
        srcOff := rowBytes - SizeOf(cell);
        dstOff := 0;
          for row := 1 to height do begin
            rowStart := dstOff;
            { Note: width - 1 is a Word, so a zero width wraps instead of skipping the loop. }
            for col := 0 to width - 1 do begin
                Move(data[srcOff - dstOff + rowStart], cell, SizeOf(cell));
                cell := Blit.MirrorPairs(cell);
                Move(cell, dst^.data[dstOff], SizeOf(cell));
                if transp <> nil then begin
                  Move(transp^[srcOff - dstOff + rowStart], cell, SizeOf(cell));
                  cell := Blit.MirrorPairs(cell);
                  Move(cell, dst^.transp^[dstOff], SizeOf(cell));
                end;
                Inc(dstOff, SizeOf(cell));
              end;
            Inc(srcOff, rowBytes);
          end;
      end;
    { EGA: four plane bytes per column, each through MirrorBits }
    C_Vm.EGA:
      begin
        rowBytes := width * 4;
        srcOff := rowBytes - 4;
        dstOff := 0;
          for row := 1 to height do begin
            rowStart := dstOff;
              for col := 1 to width do begin
                for plane := 0 to 3 do begin
                  dst^.data[dstOff + plane] := Blit.MirrorBits(data[srcOff - dstOff + rowStart + plane]);
                  if transp <> nil then
                    dst^.transp^[dstOff + plane] := Blit.MirrorBits(transp^[srcOff - dstOff + rowStart + plane]);
                end;
                Inc(dstOff, 4);
              end;
            Inc(srcOff, rowBytes);
          end;
      end;
    { Tandy: bytes, through MirrorNibbles }
    C_Vm.TANDY:
      begin
        rowBytes := width * 4;
        srcOff := rowBytes - 1;
        dstOff := 0;
          for row := 1 to height do begin
            rowStart := dstOff;
              for col := 1 to rowBytes do begin
                dst^.data[dstOff] := Blit.MirrorNibbles(data[srcOff - dstOff + rowStart]);
                if transp <> nil then
                  dst^.transp^[dstOff] := Blit.MirrorNibbles(transp^[srcOff - dstOff + rowStart]);
                Inc(dstOff);
              end;
            Inc(srcOff, rowBytes);
          end;
      end;
    { VGA: plain bytes, and no mask }
    C_Vm.VGA:
      begin
        rowBytes := width * 8;
        srcOff := rowBytes - 1;
        dstOff := 0;
          for row := 1 to height do begin
            rowStart := dstOff;
              for col := 1 to rowBytes do begin
                dst^.data[dstOff] := data[srcOff - dstOff + rowStart];
                Inc(dstOff);
              end;
            Inc(srcOff, rowBytes);
          end;
      end;
  end;
  end;
end;

procedure GrabPic(col, row: Integer; pic: Types.PImgBuf);
var
  c: Integer;
  r: Integer;
  colOff: Word;
  firstRow: Word;
  colEnd: Word;
  lastRow: Word;
  screenOff: Integer;
  rowBytes: Word;
  dataOffset: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  with pic^ do begin
  case GDVars.displayMode of
    { CGA: one Move per scanline, at 2 bytes per column }
    C_Vm.CGA:
      begin
        rowBytes := width * 2;
        dataOffset := 0;
        firstRow := Word(row) * 8;
        lastRow := firstRow + height - 1;
        colOff := Word(col) * 2;
        for r := firstRow to lastRow do begin
          Move(Mem[GDVars.cgaRowSegments[r]: colOff], pic^.data[dataOffset], rowBytes);
          Inc(dataOffset, rowBytes);
        end;
      end;
    { EGA: one byte per plane per column. Each plane is read through the graphics controller's read map select (index
      4), with the mode register (index 5) set to 0; both are reset afterwards. }
    C_Vm.EGA:
      begin
        dataOffset := 0;
        firstRow := Word(row) * 8;
        lastRow := firstRow + height - 1;
        colOff := Word(col);
        colEnd := colOff + width - 1;
        Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
        Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
        Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_READ_MAP_REG;
        for r := firstRow to lastRow do begin
          for c := colOff to colEnd do
            for plane := 0 to 3 do begin
              Port[C_Ega.GC_DATA_PORT] := plane;
              pic^.data[dataOffset] := Mem[C_Video.EGA_VIDEO_SEG: LongInt(GDVars.egaRowOffsets[r]) + c];
              Inc(dataOffset);
            end;
        end;
        Port[C_Ega.GC_DATA_PORT] := 0;
        Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
        Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
      end;
    { VGA: one screen offset, stepped a row at a time }
    C_Vm.VGA:
      begin
        screenOff := row * 8 * SizeOf(Types.TVgaRow) + col * 8;
        dataOffset := 0;
        rowBytes := width * 8;
        firstRow := Word(row) * 8;
        lastRow := firstRow + height - 1;
        for r := firstRow to lastRow do begin
          Move(Pointer(LongInt(C_Video.EGA_VIDEO_SEG) shl 16 + Word(screenOff))^, pic^.data[dataOffset], rowBytes);
          Inc(dataOffset, rowBytes);
          Inc(screenOff, SizeOf(Types.TVgaRow));
        end;
      end;
    { Tandy: as CGA, at 4 bytes per column }
    C_Vm.TANDY:
      begin
        rowBytes := width * 4;
        dataOffset := 0;
        firstRow := Word(row) * 8;
        lastRow := firstRow + height - 1;
        colOff := Word(col) * 4;
        for r := firstRow to lastRow do begin
          Move(Mem[GDVars.tandyRowSegments[r]: colOff], pic^.data[dataOffset], rowBytes);
          Inc(dataOffset, rowBytes);
        end;
      end;
  end;
  end;
end;

procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
  col: Integer;
  row: Integer;
  colOff: Word;
  firstRow: Word;
  colEnd: Word;
  lastRow: Word;
  rowBytes: Word;
  srcOff: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  with pic^ do begin
  case GDVars.displayMode of
    { CGA: one Move per scanline, at 2 bytes per column }
    C_Vm.CGA:
      begin
        rowBytes := width * 2;
        srcOff := 0;
        firstRow := Word(screenY) * 8;
        lastRow := firstRow + height - 1;
        colOff := Word(screenX) * 2;
        for row := firstRow to lastRow do begin
          Move(pic^.data[srcOff], Mem[GDVars.cgaRowSegments[row]: colOff], rowBytes);
          Inc(srcOff, rowBytes);
        end;
      end;
    { EGA: one byte per plane per column }
    C_Vm.EGA:
      begin
        srcOff := 0;
        firstRow := Word(screenY) * 8;
        lastRow := firstRow + height - 1;
        colOff := Word(screenX);
        colEnd := colOff + width - 1;
        Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG;
        for row := firstRow to lastRow do begin
          for col := colOff to colEnd do
            for plane := 0 to SizeOf(GDConsts.egaPlaneBits) - 1 do begin
              Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBits[plane];
              Mem[C_Video.EGA_VIDEO_SEG: LongInt(GDVars.egaRowOffsets[row]) + col] := pic^.data[srcOff];
              Inc(srcOff);
            end;
        end;
        Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
      end;
    { Tandy: as CGA, at 4 bytes per column }
    C_Vm.TANDY:
      begin
        rowBytes := width * 4;
        srcOff := 0;
        firstRow := Word(screenY) * 8;
        lastRow := firstRow + height - 1;
        colOff := Word(screenX) * 4;
        for row := firstRow to lastRow do begin
          Move(pic^.data[srcOff], Mem[GDVars.tandyRowSegments[row]: colOff], rowBytes);
          Inc(srcOff, rowBytes);
        end;
      end;
    { VGA: the address recomputed each row }
    C_Vm.VGA:
      begin
        rowBytes := width * 8;
        srcOff := 0;
        firstRow := Word(screenY) * 8;
        lastRow := firstRow + height - 1;
        colOff := Word(screenX) * 8;
        for row := firstRow to lastRow do begin
          Move(pic^.data[srcOff], Mem[C_Video.EGA_VIDEO_SEG: colOff + row * SizeOf(Types.TVgaRow)], rowBytes);
          Inc(srcOff, rowBytes);
        end;
      end;
  end;
  end;
end;

procedure FlushView;
var
  row: Word;
  srcOff: Word;
  dstOff: Word;
  dstBase: Word;
  { Unused in this version; see the other implementations of this routine. }
  plane: Word;
  { Unused in this version; see the other implementations of this routine. }
  spanBuf: array[1..256] of Byte;
begin
  Mouse.HideMouse;
  case GDVars.displayMode of
    C_Vm.CGA:
      for row := 0 to SizeOf(GDVars.dirtyRows) - 1 do
        if GDVars.dirtyRows[row] <> 0 then
          Move(GDVars.viewPicture^.data[GDVars.dirtyRowFirst[row]],
               Mem[GDVars.cgaRowSegments[row + 8]: GDVars.dirtyRowLeft[row] + 2],
               GDVars.dirtyRowLast[row] - GDVars.dirtyRowFirst[row] + 1);
    C_Vm.EGA:
      begin
        Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG;
        for row := 0 to SizeOf(GDVars.dirtyRows) - 1 do
          if GDVars.dirtyRows[row] <> 0 then begin
            dstBase := GDVars.egaRowOffsets[row + 8] + GDVars.dirtyRowLeft[row] + 1;
            Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBits[0];
            srcOff := GDVars.dirtyRowFirst[row];
            dstOff := dstBase;
            repeat
              Mem[Blit.EGA_OFFSCREEN_SEG: dstOff] := GDVars.viewPicture^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff);
            until srcOff > GDVars.dirtyRowLast[row];
            Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBits[1];
            srcOff := GDVars.dirtyRowFirst[row] + 1;
            dstOff := dstBase;
            repeat
              Mem[Blit.EGA_OFFSCREEN_SEG: dstOff] := GDVars.viewPicture^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff);
            until srcOff > GDVars.dirtyRowLast[row];
            Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBits[2];
            srcOff := GDVars.dirtyRowFirst[row] + 2;
            dstOff := dstBase;
            repeat
              Mem[Blit.EGA_OFFSCREEN_SEG: dstOff] := GDVars.viewPicture^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff);
            until srcOff > GDVars.dirtyRowLast[row];
            Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBits[3];
            srcOff := GDVars.dirtyRowFirst[row] + 3;
            dstOff := dstBase;
            repeat
              Mem[Blit.EGA_OFFSCREEN_SEG: dstOff] := GDVars.viewPicture^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff);
            until srcOff > GDVars.dirtyRowLast[row];
          end;
        Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
        dstOff := GDVars.egaRowOffsets[8] + 1;
        Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
        Port[C_Ega.GC_DATA_PORT] := Blit.GC_WRITE_MODE_1;
        for row := 0 to SizeOf(GDVars.dirtyRows) - 1 do begin
          if GDVars.dirtyRows[row] <> 0 then
            Move(Mem[Blit.EGA_OFFSCREEN_SEG: dstOff + GDVars.dirtyRowLeft[row]],
                 Mem[C_Video.EGA_VIDEO_SEG: dstOff + GDVars.dirtyRowLeft[row]],
                 (GDVars.dirtyRowLast[row] - GDVars.dirtyRowFirst[row]) div 4 + 1);
          Inc(dstOff, SizeOf(Types.TEgaRow));
        end;
        Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
      end;
    C_Vm.TANDY:
      for row := 0 to SizeOf(GDVars.dirtyRows) - 1 do
        if GDVars.dirtyRows[row] <> 0 then
          Move(GDVars.viewPicture^.data[GDVars.dirtyRowFirst[row]],
               Mem[GDVars.tandyRowSegments[row + 8]: GDVars.dirtyRowLeft[row] + 4],
               GDVars.dirtyRowLast[row] - GDVars.dirtyRowFirst[row] + 1);
    C_Vm.VGA:
      for row := 0 to SizeOf(GDVars.dirtyRows) - 1 do
        if GDVars.dirtyRows[row] <> 0 then
          Move(GDVars.viewPicture^.data[GDVars.dirtyRowFirst[row]],
               Pointer(LongInt(C_Video.EGA_VIDEO_SEG) shl 16 + (row + 8) * SizeOf(Types.TVgaRow) +
                 GDVars.dirtyRowLeft[row] + 8)^, GDVars.dirtyRowLast[row] - GDVars.dirtyRowFirst[row] +
                 1);
  end;
  FillChar(GDVars.dirtyRows, SizeOf(GDVars.dirtyRows), 0);
  FillChar(GDVars.dirtyRowFirst, SizeOf(GDVars.dirtyRowFirst), $FF);
  FillChar(GDVars.dirtyRowLast, SizeOf(GDVars.dirtyRowLast), 0);
  Mouse.ShowMouse;
end;

procedure RemapPic(fromColors, toColors: Types.TPalette16; frame: Integer; isDithered: Boolean;
                   pic: Types.PImgBuf);
var
  srcOff: Word;
  dstOff: Word;
  { frames to work on; named apart from TImgBuf's count, which the with blocks leave visible }
  nFrames: Byte;
  col: Word;
  row: Word;
  match: Byte;
  planeMask: array[0..3] of Byte;
  plane: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cellByte: Byte;
  pixPos: Byte;
  rowBytes: Word;
  fromHigh: Byte;
  toHigh: Byte;
  pairIdx: Byte;
  scratchPic: Types.PImgBuf;
begin
  if pic = nil then Exit;
  with pic^ do begin
    if frame < 0 then begin
      frame := 0;
      nFrames := count;
    end else
      nFrames := 1;
    srcOff := Word(frame * frameSize);
  end;
  dstOff := 0;

  Blit.AllocPic(pic^.height, pic^.width, nFrames, 0, scratchPic);
  scratchPic^.colorMap := pic^.colorMap;
  Move(pic^.data[srcOff], scratchPic^.data[dstOff], scratchPic^.frameSize * scratchPic^.count);

  for pairIdx := 0 to SizeOf(fromColors) - 1 do begin
    { the frame setup again: see the note above }
    with pic^ do begin
      if frame < 0 then begin
        frame := 0;
        nFrames := count;
      end else
        nFrames := 1;
      srcOff := Word(frame * frameSize);
    end;
    dstOff := 0;
    if fromColors[pairIdx] <> toColors[pairIdx] then begin
      with Types.PImgBuf(scratchPic)^ do begin
      case GDVars.displayMode of
        C_Vm.CGA:
          begin
            rowBytes := width * 2;
            for GDVars.loopIndex := ShortInt(frame) to nFrames + frame - 1 do begin
                for row := 1 to height do begin
                    for col := 1 to rowBytes do begin
                        for pixPos := 0 to SizeOf(GDConsts.cgaPixelColors[0]) - 1 do begin
                          if (pic^.data[srcOff] and GDConsts.cgaPixelMasks[pixPos + 4]) =
                              GDConsts.cgaPixelColors[Blit.SrcNibble(fromColors[pairIdx], colorMap), pixPos] then
                            if (not isDithered) or (isDithered and (Random(4) = 0)) then
                              data[dstOff] := (data[dstOff] and not GDConsts.cgaPixelMasks[pixPos + 4]) or
                                GDConsts.cgaPixelColors[Blit.SrcNibble(toColors[pairIdx], colorMap), pixPos];
                        end;
                        Inc(srcOff);
                        Inc(dstOff);
                      end;
                  end;
            end;
          end;
        C_Vm.EGA:
          begin
            { planeMask is $FF for each plane whose bit fromColors[pairIdx] lacks and 0 for each it has, so data xor
              planeMask marks the matching bits }
            for plane := 0 to SizeOf(planeMask) - 1 do
              if (fromColors[pairIdx] and GDConsts.egaPlaneBits[plane]) > 0 then
                planeMask[plane] := 0
              else
                planeMask[plane] := $FF;
            for GDVars.loopIndex := ShortInt(frame) to nFrames + frame - 1 do begin
                for row := 1 to height do begin
                    for col := 1 to width do begin
                        { One byte chained through the planes: the dither seed, then each plane's match ANDed in, so a
                          bit survives only where all four planes match. }
                        if isDithered then
                          match := Random(256) and Random(256)
                        else
                          match := $FF;
                        for plane := 0 to SizeOf(planeMask) - 1 do
                          match := (pic^.data[srcOff + plane] xor planeMask[plane])
                                       and match;
                        { set the matching bits in the planes toColors[pairIdx] has, clear them in the rest }
                        for plane := 0 to SizeOf(planeMask) - 1 do begin
                          if (toColors[pairIdx] and GDConsts.egaPlaneBits[plane]) > 0 then
                            data[dstOff + plane] := data[dstOff + plane] or match
                          else
                            data[dstOff + plane] := data[dstOff + plane] and not match;
                        end;
                        Inc(srcOff, 4);
                        Inc(dstOff, 4);
                      end;
                  end;
            end;
          end;
        C_Vm.TANDY:
          begin
            rowBytes := width * 4;
            { both colors moved into the high nibble for the high-nibble test and write }
            fromHigh := fromColors[pairIdx] shl 4;
            toHigh := toColors[pairIdx] shl 4;
            for GDVars.loopIndex := ShortInt(frame) to nFrames + frame - 1 do begin
                for row := 1 to height do begin
                    for col := 1 to rowBytes do begin
                        if (pic^.data[srcOff] and $F0) = fromHigh then
                          if (not isDithered) or (isDithered and (Random(4) = 0)) then
                            data[dstOff] := (data[dstOff] and $0F) or toHigh;
                        if (pic^.data[srcOff] and $0F) = fromColors[pairIdx] then
                          if (not isDithered) or (isDithered and (Random(4) = 0)) then
                            data[dstOff] := (data[dstOff] and $F0) or toColors[pairIdx];
                        Inc(srcOff);
                        Inc(dstOff);
                      end;
                  end;
            end;
          end;
        C_Vm.VGA:
          begin
            rowBytes := width * 8;
            for GDVars.loopIndex := ShortInt(frame) to nFrames + frame - 1 do begin
                for row := 1 to height do begin
                    for col := 1 to rowBytes do begin
                        if (data[srcOff] = fromColors[pairIdx]) and (fromColors[pairIdx] <> transparentColor) then
                          data[dstOff] := toColors[pairIdx];
                        Inc(srcOff);
                        Inc(dstOff);
                      end;
                  end;
            end;
          end;
      end;
      end;
    end;
  end;

  with pic^ do
    Move(scratchPic^.data[0], data[frame * frameSize], nFrames * frameSize);
  Blit.FreePic(scratchPic);
end;

procedure AllocPic(height, width, count: Word; flag: Byte; var pic: Types.PImgBuf);
var
  frameSize: Word;
  totalSize: Word;
  cellSize: Byte;
begin
  case GDVars.displayMode of
    C_Vm.CGA: cellSize := 2;
    C_Vm.VGA: cellSize := 8;
  else
    cellSize := 4;
  end;
  frameSize := height * width * cellSize;
  totalSize := frameSize * count;
  GetMem(pic, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
  FillChar(pic^, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)), 0);
  pic^.height := height;
  pic^.width := width;
  pic^.frameSize := frameSize;
  pic^.count := count;
  pic^.allocSize := totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data));
  if (flag and 1 > 0) and (GDVars.displayMode <> C_Vm.VGA) then begin
    GetMem(pic^.transp, totalSize);
    FillChar(pic^.transp^, totalSize, 0);
  end;
end;

procedure FreePic(var pic: Types.PImgBuf);
begin
  if pic = nil then
    Exit;
  with pic^ do begin
    if transp <> nil then
      FreeMem(transp, frameSize * count);
    FreeMem(pic, allocSize);
    pic := nil;
  end;
end;

procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImgBuf);
var
  cellSize: Word;
  clipLeft: Word;
  clipRight: Word;
  clampedX: Word;
  rightMargin: Word;
  runLen: Word;
  lastRow: Word;
  dstOff: Word;
  row: Word;
  planeMask: array[0..3] of Byte;
  absRow: Word;
  screenOfs: Word;
  plane: Byte;
begin
  if pic = nil then Exit;

  if x < 0 then begin
    clipLeft := Abs(x);
    clampedX := 0;
  end else begin
    clipLeft := 0;
    clampedX := x;
  end;

  if x + width > pic^.width then begin
    clipRight := x + width - pic^.width;
    rightMargin := 0;
  end else begin
    clipRight := 0;
    rightMargin := pic^.width - (x + width);
  end;

  if y < 0 then begin
    dstOff := 0;
    absRow := 0;
    lastRow := height - Abs(y);
  end else begin
    absRow := y;
    dstOff := absRow * pic^.width;
    lastRow := height - 1;
    if y + height > pic^.height then
      lastRow := pic^.height - 1 - y
    else
      lastRow := height - 1;
  end;

  case GDVars.displayMode of
    C_Vm.CGA, C_Vm.TANDY, C_Vm.VGA:
      begin
        case GDVars.displayMode of
          C_Vm.CGA: cellSize := 2;
          C_Vm.TANDY: cellSize := 4;
          C_Vm.VGA: cellSize := 8;
        end;
        runLen := (width - clipLeft - clipRight) * cellSize;
        clampedX := clampedX * cellSize;
        rightMargin := rightMargin * cellSize;
        dstOff := dstOff * cellSize;
        screenOfs := clampedX;
        for row := 0 to lastRow do begin
          GDVars.dirtyRows[absRow] := 1;
          Inc(dstOff, clampedX);
          if GDVars.dirtyRowFirst[absRow] > dstOff then begin
            GDVars.dirtyRowLeft[absRow] := screenOfs;
            GDVars.dirtyRowFirst[absRow] := dstOff;
          end;
          case GDVars.displayMode of
            C_Vm.CGA: FillChar(pic^.data[dstOff], runLen, GDConsts.cgaColorFill[Blit.SrcNibble(color, colorMap)]);
            C_Vm.TANDY: FillChar(pic^.data[dstOff], runLen, GDConsts.tandyColorFill[color]);
            C_Vm.VGA: FillChar(pic^.data[dstOff], runLen, color);
          end;
          Inc(dstOff, runLen);
          if dstOff - 1 > GDVars.dirtyRowLast[absRow] then
            GDVars.dirtyRowLast[absRow] := dstOff - 1;
          Inc(dstOff, rightMargin);
          Inc(absRow);
        end;
      end;
    C_Vm.EGA:
      begin
        screenOfs := clampedX;
        runLen := width - clipLeft - clipRight;
        clampedX := clampedX * 4;
        rightMargin := rightMargin * 4;
        dstOff := dstOff * 4;
        FillChar(planeMask, SizeOf(planeMask), 0);
        for plane := 0 to SizeOf(planeMask) - 1 do
          if (GDConsts.egaPlaneBits[plane] and color) > 0 then
            planeMask[plane] := $FF;
        for row := 0 to lastRow do begin
          GDVars.dirtyRows[absRow] := 1;
          Inc(dstOff, clampedX);
          if GDVars.dirtyRowFirst[absRow] > dstOff then begin
            GDVars.dirtyRowLeft[absRow] := screenOfs;
            GDVars.dirtyRowFirst[absRow] := dstOff;
          end;
          for GDVars.loopIndex := 1 to runLen do begin
            Move(planeMask, pic^.data[dstOff], SizeOf(planeMask));
            Inc(dstOff, SizeOf(planeMask));
          end;
          if dstOff - 1 > GDVars.dirtyRowLast[absRow] then
            GDVars.dirtyRowLast[absRow] := dstOff - 1;
          Inc(dstOff, rightMargin);
          Inc(absRow);
        end;
      end;
  end;
end;

procedure ShadowPaletteEntries(startIdx: Byte; count: Word; var dest: Types.TPalette256);
begin
  if GDVars.displayMode <> C_Vm.VGA then Exit;
  Move(GDVars.picturePalette[startIdx, 0], dest[startIdx, 0], count * SizeOf(Types.TRgb));
end;

procedure SetDacPalette(startIdx, count: Word; src: Types.TPalette256);
var
  { Unused in this version; see the other implementations of this routine. }
  runLength: Word;
  videoRegs: Registers;
begin
  if GDVars.displayMode <> C_Vm.VGA then Exit;
  videoRegs.BX := startIdx;
  videoRegs.CX := count;
  videoRegs.ES := Seg(src);
  videoRegs.DX := Ofs(src) + startIdx * SizeOf(Types.TRgb);
  videoRegs.AH := Blit.BIOS_PALETTE;
  videoRegs.AL := Blit.BIOS_SET_DAC_BLOCK;
  Intr($10, videoRegs);
end;

procedure Hline(x1, x2: Word; row, color: Byte);
var
  colorPattern: Byte;
  mask: Byte;
  notMask: Byte;
  byteCol: Byte;
  rowHalf: Byte;
  midCount: ShortInt;
  p: PByte;
  t: Word;
begin
  case GDVars.displayMode of
    C_Vm.CGA:
      begin
        if x1 > x2 then begin t := x1; x1 := x2; x2 := t; end;
        rowHalf := row shr 1;
        byteCol := x1 shr 2;
        colorPattern := Lo(GDConsts.cgaFillWords[GDConsts.cgaLineColors[color and $F]]);
        if (row and 1) = 0 then
          p := PByte(LongInt(@cgaEvenBank[rowHalf]) + byteCol)
        else
          p := PByte(LongInt(@cgaOddBank[rowHalf]) + byteCol);
        if (x1 and 3) <> 0 then begin
          mask := $FF shr ((x1 and 3) * 2);
          x1 := (byteCol + 1) shl 2;
          if x2 < x1 then
            mask := mask and ($FF shl ((3 - (x2 and 3)) * 2));
          notMask := mask xor $FF;
          p^ := (notMask and p^) or (mask and colorPattern);
          p := PByte(LongInt(p) + 1);
        end;
        midCount := (x2 + 1 - x1) shr 2;
        if midCount >= 0 then begin
          FillChar(p^, midCount, colorPattern);
          if (x2 and 3) <> 3 then begin
            p := PByte(midCount + LongInt(p));
            mask := $FF shl ((3 - (x2 and 3)) * 2);
            notMask := mask xor $FF;
            p^ := (notMask and p^) or (mask and colorPattern);
          end;
        end;
      end;
    C_Vm.EGA: Blit.HlineEga(x1, x2, row, color);
    C_Vm.TANDY:
      begin
        byteCol := x1 div 2;
        colorPattern := color or (color shl 4);
        if Byte(x1 and 1) <> 0 then begin
          Mem[GDVars.tandyRowSegments[row]: byteCol] := (Mem[GDVars.tandyRowSegments[row]: byteCol] and $F0) or
            (colorPattern and $F);
          Inc(LongInt(p));
          Inc(byteCol);
        end;
        midCount := (x2 - x1 + 1) div 2;
        if midCount > 0 then
          FillChar(Mem[GDVars.tandyRowSegments[row]: byteCol], midCount, colorPattern);
        Inc(byteCol, midCount);
        if Byte(x2 and 1) = 0 then
          Mem[GDVars.tandyRowSegments[row]: byteCol] := (Mem[GDVars.tandyRowSegments[row]: byteCol] and $F) or
            (colorPattern and $F0);
      end;
    C_Vm.VGA: Blit.HlineVga(x1, x2, row, color);
  end;
end;

procedure Vline(y1, y2: Byte; x: Integer; color: Byte);
var
  mask: Byte;
  notMask: Byte;
  colorPattern: Byte;
  topHalf: Byte;
  botHalf: Byte;
  byteCol: Byte;
  rowIdx: Byte;
  p: PByte;
begin
  case GDVars.displayMode of
    C_Vm.CGA:
      begin
        if y1 > y2 then begin rowIdx := y1; y1 := y2; y2 := rowIdx; end;
        byteCol := Byte(Word(x) shr 2);
        mask := $C0 shr ((Word(x) and 3) * 2);
        notMask := mask xor $FF;
        colorPattern := Lo(GDConsts.cgaFillWords[GDConsts.cgaLineColors[color and $F]]);
        { even bank }
        topHalf := (Word(y1) + 1) shr 1;
        botHalf := y2 shr 1;
        p := PByte(LongInt(@cgaEvenBank[topHalf]) + byteCol);
        for rowIdx := topHalf to botHalf do begin
          p^ := (p^ and notMask) or (colorPattern and mask);
          p := PByte(LongInt(p) + SizeOf(Types.TCgaRow));
        end;
        { odd bank, skipped for a single-row line }
        if y1 <> y2 then begin
          topHalf := y1 shr 1;
          botHalf := (Word(y2) - 1) shr 1;
          p := PByte(LongInt(@cgaOddBank[topHalf]) + byteCol);
          for rowIdx := topHalf to botHalf do begin
            p^ := (p^ and notMask) or (colorPattern and mask);
            p := PByte(LongInt(p) + SizeOf(Types.TCgaRow));
          end;
        end;
      end;
    C_Vm.EGA: Blit.VlineEga(y1, y2, x, color);
    C_Vm.TANDY:
      begin
        byteCol := Byte(Word(x) div 2);
        colorPattern := color or (color shl 4);
        if Byte(Word(x) and 1) <> 0 then begin
          mask := $F0;
          notMask := $0F;
        end else begin
          mask := $0F;
          notMask := $F0;
        end;
        while y1 <= y2 do begin
          Mem[GDVars.tandyRowSegments[y1]: byteCol] := (Mem[GDVars.tandyRowSegments[y1]: byteCol] and mask)
            or (notMask and colorPattern);
          Inc(y1);
        end;
      end;
    C_Vm.VGA: Blit.VlineVga(y1, y2, x, color);
  end;
end;

procedure CopyIconTile(kind, tileIdx, frame: Byte; isMirrored: Boolean);
var
  tmp: Types.PImgBuf;
  frameSize: Word;
  frameOfs: Word;
begin
  frameSize := GDVars.movingIcon^.frameSize;
  frameOfs := frame * frameSize;
  if isMirrored then begin
    Blit.AllocPic(24, 3, 1, 1, tmp);
    Blit.MirrorPic(GDVars.iconFrames[kind, tileIdx], tmp);
    Move(tmp^.data, GDVars.movingIcon^.data[frameOfs], frameSize);
    GDVars.movingIcon^.transparentColor := GDVars.iconFrames[kind, tileIdx]^.transparentColor;
    if tmp^.transp <> nil then
      Move(tmp^.transp^[0], GDVars.movingIcon^.transp^[frameOfs], frameSize);
    Blit.FreePic(tmp);
  end else begin
    Move(GDVars.iconFrames[kind, tileIdx]^.data, GDVars.movingIcon^.data[frameOfs], frameSize);
    GDVars.movingIcon^.transparentColor := GDVars.iconFrames[kind, tileIdx]^.transparentColor;
    if GDVars.iconFrames[kind, tileIdx]^.transp <> nil then
      Move(GDVars.iconFrames[kind, tileIdx]^.transp^[0], GDVars.movingIcon^.transp^[frameOfs], frameSize);
  end;
end;

procedure BuildIconFrames(kind: Byte);
begin
  Blit.CopyIconTile(kind, 0, 0, False);
  Blit.CopyIconTile(kind, 0, 1, True);
  Blit.CopyIconTile(kind, 1, 2, True);
  Blit.CopyIconTile(kind, 1, 3, False);
end;

begin
end.
