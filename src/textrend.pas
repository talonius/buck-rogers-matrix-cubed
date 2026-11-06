{ The resident text unit: the 8x8 game font and a glyph blitter per display mode (textrend.asm), text on the 40x25 cell
  screen, word-wrapped message windows, the text window's lines, rectangle and screen clears, the status line's input
  and prompts, and number formatting. The punctuation a line may break after is GDConsts', and the rest of its state is
  GDVars' (the font, the cursor, the text window and the EGA page). }
{$O+,F+,S-,R-,V-,B-,I-,A-}
unit TextRend;

interface

uses Types, C_Screen, C_Video, GDConsts, GDVars, Crt, Dos, Mouse, DaxIo, GameIo, C_Vm,
  C_Ega, C_Keys;

{ Shows a label, '->' and a number at the top left, then PauseContinue.
  @param(source The label.)
  @param(value The number.) }
procedure DisplayValue(source: String; value: Integer);

{ Shows an EGA page (video BIOS function 5) and records its segment.
  @param(page The page shown.) }
procedure SetupEgaCurrentPage(page: Byte);

{ Points egaDrawSegment at an EGA page.
  @param(page The page drawn on.) }
procedure SetupEgaOtherPage(page: Byte);

{ Fills a rectangle of text cells, corners included, on an EGA page, through write mode 2.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(page The EGA page.)
  @param(color The fill color.) }
procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);

{ Loads the 8x8 game font (block 201 of 8X8D1.DAX) into gameFont; nothing happens when it is missing. }
procedure LoadGameFont;

{ Draws a string from a text cell through RenderChar, with the mouse hidden. A col or row past 39 draws nothing and
  returns with the mouse still hidden. Note: the row is checked against the last column, not the last row.
  @param(col Text column of the first character.)
  @param(row Text row.)
  @param(fg The text's color.)
  @param(bg The background's color.)
  @param(source The text.) }
procedure DisplayString(col, row, fg, bg: Byte; source: String);

{ Draws a character repeatedly from a text cell rightwards; nothing is drawn when the first cell is off the screen or no
  font is loaded.
  @param(col Text column of the first character.)
  @param(row Text row.)
  @param(fg The glyph's color.)
  @param(bg The background's color.)
  @param(count How many times.)
  @param(ch The character, or the glyph number.)
  @param(ascii Non-zero takes `ch` as a character, upper-cased, and draws the font glyph of its code mod 64; zero takes
    `ch` as the glyph number.) }
procedure RenderChar(col, row, fg, bg, count, ch, ascii: Byte);

{ Writes source into the window ulCol, ulRow to lrCol, lrRow from the text cursor, wrapping at spaces and after the
  punctuation in breakChars, and waiting on PauseContinue when the window fills. A cursor outside the window starts at
  its top left. A window corner off the screen writes nothing and leaves the mouse hidden. Note: lrRow is checked
  against the last column, not the last row.
  @param(ulCol The window's left column.)
  @param(ulRow The window's top row.)
  @param(lrCol The window's right column.)
  @param(lrRow The window's bottom row.)
  @param(fg The text's color.)
  @param(bg The background's color.)
  @param(clearFirst Clears the window first.)
  @param(source The text.) }
procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: String);

{ Fills cells from a text cell rightwards with a color. A starting cell off the 40x25 screen draws nothing and leaves
  the mouse hidden; only that cell is tested.
  @param(col The first cell's column.)
  @param(row The cells' row.)
  @param(color The fill color.)
  @param(count The number of cells.) }
procedure PrintSpaces(col, row, color, count: Byte);

{ Reads up to maxLen characters on the status line after query, until Enter or Escape; in the demo it stops after the
  first key, for which it still waits. The keypad's keys give digits.
  @param(query The prompt.)
  @param(fg The text's color.)
  @param(bg The background's color.)
  @param(maxLen The most characters taken.)
  @returns(The text upper-cased, without trailing spaces.) }
function ReadString(query: Types.TString40; fg, bg, maxLen: Byte): Types.TString40;

{ Asks with ReadString until the answer is empty or digits that fit a LongInt.
  @param(query The prompt.)
  @param(fg The text's color.)
  @param(bg The background's color.)
  @returns(The number, 0 for an empty answer.) }
function ReadNumber(query: Types.TString40; fg, bg: Byte): LongInt;

{ Shows a message on the status line and waits for Enter or Escape, then, after a mouse click, for the buttons' release.
  @param(fg The text's color.)
  @param(bg The background's color.)
  @param(msg The message.) }
procedure DisplayAndPause(fg, bg: Byte; msg: Types.TString40);

{ Reads the time of day.
  @returns(The time since midnight in hundredths of a second.) }
function GetTicks: LongInt;

{ Clears the whole screen in the display mode's memory: both CGA banks, both EGA pages, the VGA frame or the four Tandy
  banks. }
procedure ClearScreen;

{ Fills a rectangle of text cells, corners included, in any display mode (both EGA pages).
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(color The fill color.) }
procedure FillRect(ulCol, ulRow, lrCol, lrRow, color: Byte);

{ Shows a message on the status line for PauseOnly's delay, then clears the line.
  @param(msg The message.)
  @param(fg The text's color.)
  @param(bg The background's color.) }
procedure PrintAndPause(msg: Types.TString40; fg, bg: Byte);

{ Waits zone 0's messageSpeed tenths of a second. }
procedure PauseOnly;

{ FillRect in color 0.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);

{ Clears the text window in its color and starts its lines again at the top. }
procedure ClearTextWindow;

{ Sets the text window and clears it.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(color The window's color.) }
procedure SetTextWindow(ulCol, ulRow, lrCol, lrRow, color: Byte);

{ Writes a message as the text window's next line, splitting it at a space when it is wider than the window. A window
  whose lines are no longer pending is cleared first; a full one waits on PauseContinue, if lines are pending, and is
  cleared.
  @param(fg The text's color.)
  @param(msg The message.) }
procedure DisplayWindowText(fg: Byte; msg: String);

{ Drains any keys already pressed, waits for the player with the continue prompt on the status line, then clears the
  line. }
procedure PauseContinue;

{ Shows 'Loading...Please Wait' in light green on the status line, clearing the rest of it. }
procedure DisplayLoading;

{ Shows 'Saving...Please Wait' in light green on the status line, clearing the rest of it. }
procedure DisplaySaving;

{ Clears the status line. }
procedure ClearStatusLine;

{ Formats a byte in decimal.
  @param(value The number.)
  @returns(Its digits.) }
function ByteToString(value: Byte): String;

{ Formats a word in decimal.
  @param(value The number.)
  @returns(Its digits.) }
function WordToString(value: Word): String;

{ Formats a number in decimal with a comma every three digits. Note: past nine digits the leading ones are dropped, so
  1234567890 gives ',234,567,890'.
  @param(value The number.)
  @returns(The digits with commas.) }
function CommaLongToString(value: LongInt): String;

{ Right-aligns a string in place, putting spaces in front of it until it is targetLen long.
  @param(source The TString40 aligned.)
  @param(targetLen The length it is aligned to.) }
procedure RightAlignString(var source; targetLen: Byte);

implementation

const
  { INT 10h function: shows display page AL }
  BIOS_SET_ACTIVE_PAGE = $05;
  { the screen's last row }
  LAST_ROW = 24;
  { EGA Graphics Controller register indices, named after the EGA's registers }
  GC_SET_RESET_REG = 0;
  GC_ENABLE_SET_RESET_REG = 1;
  GC_COLOR_COMPARE_REG = 2;
  GC_DATA_ROTATE_REG = 3;
  GC_COLOR_DONT_CARE_REG = 7;
  GC_BIT_MASK_REG = 8;
  { Mode register value, write mode 2: a write fills each plane from the color's bits }
  GC_WRITE_MODE_2 = 2;
  { the Insert key's scan code, keypad 0 with Num Lock off }
  KEY_INS = #82;

type
  { a CGA scanline, 2 bytes a text cell }
  TCgaCellRow = array[0..39] of Word;
var
  { CGA: even scanlines, then odd }
  cgaBank0: array[0..99] of TCgaCellRow absolute $B800: $0000;
  cgaBank1: array[0..99] of TCgaCellRow absolute $BA00: $0000;
  { Tandy: scanlines 0, 1, 2, 3 mod 4 }
  tandyBank0: array[0..49] of Types.TTandyRow absolute $B800: $0000;
  tandyBank1: array[0..49] of Types.TTandyRow absolute $BA00: $0000;
  tandyBank2: array[0..49] of Types.TTandyRow absolute $BC00: $0000;
  tandyBank3: array[0..49] of Types.TTandyRow absolute $BE00: $0000;
  vgaScreen: array[0..63999] of Byte absolute $A000: $0000;

{ textrend.asm's glyph blitters, one per display mode. }
{$F-}
{$L TEXTREND.OBJ}
{ Draws one 8x8 glyph on CGA from the rows RenderChar staged in glyphBits.
  @param(col The text cell's column.)
  @param(row The text cell's row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(charIdx Unused.) }
procedure CgaGlyph(col, row: Word; fg, bg, charIdx: Byte); external;

{ Draws one 8x8 glyph on EGA page 0 from the rows RenderChar staged in glyphBits.
  @param(col The text cell's column.)
  @param(row The text cell's row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(charIdx Unused.) }
procedure EgaGlyph(col, row: Word; fg, bg, charIdx: Byte); external;

{ Draws one 8x8 glyph on Tandy from the rows RenderChar staged in glyphBits.
  @param(col The text cell's column.)
  @param(row The text cell's row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(charIdx Unused.) }
procedure TandyGlyph(col, row: Word; fg, bg, charIdx: Byte); external;

{$F+}
{ Draws one 8x8 glyph in VGA mode 13h, reading it from the font.
  @param(col The text cell's column.)
  @param(row The text cell's row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(charIdx The glyph number.) }
procedure VgaGlyph(col, row: Word; fg, bg, charIdx: Byte); external;

procedure DisplayValue(source: String; value: Integer);
var
  numberText: String[8];
begin
  Str(value:0, numberText);
  TextRend.DisplayString(0, 0, Black, White, source + '->' + numberText + '...');
  TextRend.PauseContinue;
end;

{ Resets the EGA graphics controller (registers 0 to 5 to 0, color don't-care $0F, bit mask $FF) and enables writes to
  the four planes. }
procedure ResetEgaGc;
begin
  Port[C_Ega.GC_ADDR_PORT] := TextRend.GC_SET_RESET_REG; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := TextRend.GC_ENABLE_SET_RESET_REG; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := TextRend.GC_COLOR_COMPARE_REG; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := TextRend.GC_DATA_ROTATE_REG; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_READ_MAP_REG; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG; Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
  Port[C_Ega.GC_ADDR_PORT] := TextRend.GC_COLOR_DONT_CARE_REG; Port[C_Ega.GC_DATA_PORT] := $0F;
  Port[C_Ega.GC_ADDR_PORT] := TextRend.GC_BIT_MASK_REG; Port[C_Ega.GC_DATA_PORT] := $FF;
  Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG; Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
end;

procedure SetupEgaCurrentPage(page: Byte);
begin
  GDVars.regs.ah := TextRend.BIOS_SET_ACTIVE_PAGE; GDVars.regs.al := page; Intr($10, Registers(GDVars.regs));
  GDVars.egaShownSegment := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

procedure SetupEgaOtherPage(page: Byte);
begin
  GDVars.egaDrawSegment := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);
var
  savedPage: Byte;
  off: Word;
  rows: Word;
  i: Word;
begin
  savedPage := GDVars.egaDrawPage;
  off := Word(ulRow) * SizeOf(Types.TEgaRow) * 8 + ulCol;
  rows := (lrRow - ulRow + 1) * 8 - 1;
  TextRend.SetupEgaOtherPage(page); TextRend.ResetEgaGc;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG; Port[C_Ega.GC_DATA_PORT] := TextRend.GC_WRITE_MODE_2;
  for i := 0 to rows do begin
    { EGA display memory }
    FillChar(Mem[GDVars.egaDrawSegment: off], lrCol - ulCol + 1, color);
    Inc(off, SizeOf(Types.TEgaRow));
  end;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG; Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
  GDVars.egaDrawPage := savedPage;
  TextRend.SetupEgaOtherPage(GDVars.egaDrawPage);
end;

procedure LoadGameFont;
var
  size: Word;
  data: Types.PByteArr;
begin
  DaxIo.LoadDax('8X8d1', '.dax', 201, size, data);
  if size = 0 then Exit;
  Move(data^, GDVars.gameFont^, size);
  FreeMem(data, size);
end;

procedure RenderChar(col, row, fg, bg, count, ch, ascii: Byte);
var
  i: Byte;
  idx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  dstOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  cnt: Word;
  { Unused in this version; see the other implementations of this routine. }
  colBase: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaWord: Word;
  { Unused in this version; see the other implementations of this routine. }
  tandyPx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  k: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  bank: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outerRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  plane: Byte;
begin
  if (col > C_Screen.LAST_COLUMN) or (row > TextRend.LAST_ROW) or (GDVars.gameFont = nil) then Exit;
  if ascii <> 0 then idx := Ord(UpCase(Chr(ch))) mod 64 else idx := ch;
  Move(GDVars.gameFont^[idx], GDVars.glyphBits, SizeOf(GDVars.glyphBits));
  case GDVars.displayMode of
    C_Vm.CGA: for i := 1 to count do begin
         TextRend.CgaGlyph(col, row, fg, bg, idx); Inc(col)
       end;
    C_Vm.EGA: for i := 1 to count do begin
         TextRend.EgaGlyph(col, row, fg, bg, idx); Inc(col)
       end;
    C_Vm.TANDY: for i := 1 to count do begin
         TextRend.TandyGlyph(col, row, fg, bg, idx); Inc(col)
       end;
    C_Vm.VGA: for i := 1 to count do begin
         TextRend.VgaGlyph(col, row, fg, bg, idx); Inc(col)
       end;
  end;
end;

procedure PrintSpaces(col, row, color, count: Byte);
begin
  Mouse.HideMouse;
  { col and row are Bytes, so the < 0 tests never hold. }
  if (col < 0) or (col > C_Screen.LAST_COLUMN) or (row < 0) or (row > TextRend.LAST_ROW) then Exit;
  TextRend.RenderChar(col, row, color, color, count, 32, 1);
  Mouse.ShowMouse;
end;

procedure DisplayString(col, row, fg, bg: Byte; source: String);
var
  len: Byte;
  i: Byte;
begin
  Mouse.HideMouse;
  { Note: row against the last column }
  if (col > C_Screen.LAST_COLUMN) or (row > C_Screen.LAST_COLUMN) then Exit;
  len := Length(source);
  for i := 1 to len do begin
    TextRend.RenderChar(col, row, fg, bg, 1, Ord(source[i]), 1); Inc(col)
  end;
  Mouse.ShowMouse;
end;

procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: String);
var
  len: Byte;
  { Unused in this version; see the other implementations of this routine. }
  width: Byte;
  idx: Byte;
  lineEnd: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lineStart: Byte;

  { Draws source[idx..lineEnd] from the cursor, pausing after each character while message delay is on. }
  procedure PrintCharInWindow;
  begin
    while idx <= lineEnd do begin
      TextRend.RenderChar(GDVars.cursorColumn, GDVars.cursorRow, fg, bg, 1, Ord(source[idx]), 1);
      if GDVars.messageDelay <> 0 then Delay(GDVars.zone0^.messageSpeed * 3);
      Inc(idx); Inc(GDVars.cursorColumn);
    end;
  end;

  { Moves idx past the spaces that start the next line. }
  procedure FindNewIndex;
  begin
    while (idx < len) and (source[idx] = ' ') do Inc(idx);
  end;
begin
  Mouse.HideMouse;
  { Note: lrRow against the last column }
  if (ulCol > C_Screen.LAST_COLUMN) or (ulRow > TextRend.LAST_ROW) or (lrCol > C_Screen.LAST_COLUMN) or
      (lrRow > C_Screen.LAST_COLUMN) then Exit;
  if (GDVars.cursorColumn < ulCol) or (GDVars.cursorColumn > lrCol) or (GDVars.cursorRow < ulRow) or
      (GDVars.cursorRow > lrRow) then begin
    GDVars.cursorColumn := ulCol; GDVars.cursorRow := ulRow;
  end;
  if clearFirst then begin
    TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow); GDVars.cursorColumn := ulCol; GDVars.cursorRow := ulRow;
  end;
  idx := 1;
  len := Length(source);
  if len = 0 then begin Mouse.ShowMouse; Exit end;
  width := lrCol - ulCol + 1;
  repeat
    lineEnd := idx;
    while (lineEnd < len) and (source[lineEnd] in GDConsts.breakChars) do Inc(lineEnd);
    while (lineEnd < len) and not (source[lineEnd] in GDConsts.breakChars) and (source[lineEnd] <> ' ') do Inc(lineEnd);
    if source[lineEnd] <> ' ' then
      while (lineEnd + 1 < len) and (source[lineEnd + 1] in GDConsts.breakChars) do Inc(lineEnd);
    if lineEnd - idx + GDVars.cursorColumn > lrCol then begin
      if (lineEnd - idx + GDVars.cursorColumn = lrCol) and (source[lineEnd] = ' ') then begin
        Dec(lineEnd);
        PrintCharInWindow;
      end;
      GDVars.cursorColumn := ulCol;
      Inc(GDVars.cursorRow);
      FindNewIndex;
      if (GDVars.cursorRow > lrRow) and (idx < len) then begin
        GDVars.cursorColumn := ulCol;
        GDVars.cursorRow := ulRow;
        TextRend.PauseContinue;
        GameIo.FlushKeys;
        TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
        PrintCharInWindow;
      end;
    end else
      PrintCharInWindow;
  until idx > len;
  if GDVars.cursorColumn > lrCol then begin
    GDVars.cursorColumn := ulCol;
    Inc(GDVars.cursorRow)
  end;
  Mouse.ShowMouse;
end;

function ReadString(query: Types.TString40; fg, bg, maxLen: Byte): Types.TString40;
var
  col: Byte;
  len: Byte;
  typed: String;
  key: Char;
begin
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, C_Screen.TEXT_COLUMNS);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, fg, bg, query);
  col := Length(query);
  typed := '';
  repeat
    TextRend.PrintSpaces(col + 1, C_Screen.STATUS_ROW, White, 1);
    key := ReadKey;
    if key = #0 then begin
      key := ReadKey;
      { the keypad's scan codes (C_Keys' cursor keys, and KEY_INS) give digits }
      case key of
        C_Keys.HOME: key := '7';
        C_Keys.UP: key := '8';
        C_Keys.PAGE_UP: key := '9';
        C_Keys.LEFT: key := '4';
        { Note: scan code 32 (Alt-D), not keypad 5's 76 }
        #32: key := '5';
        C_Keys.RIGHT: key := '6';
        C_Keys.END_KEY: key := '1';
        C_Keys.DOWN: key := '2';
        C_Keys.PAGE_DOWN: key := '3';
        TextRend.KEY_INS: key := '0';
      else
        key := #0
      end
    end;
    len := Length(typed);
    case key of
      ' ': if (len <> 0) and (len < maxLen) then begin
             typed := typed + ' ';
             Inc(col);
             TextRend.DisplayString(col, C_Screen.STATUS_ROW, White, Black, ' ')
           end;
      '!'..'z': if len < maxLen then begin
                   typed := typed + key;
                   Inc(col);
                   TextRend.DisplayString(col, C_Screen.STATUS_ROW, White, Black, key)
                 end;
      C_Keys.BACKSPACE: if len > 0 then begin
            typed := Copy(typed, 1, len - 1);
            TextRend.PrintSpaces(col, C_Screen.STATUS_ROW, Black, 2);
            Dec(col)
          end
    end;
  until (key = C_Keys.ENTER) or (key = C_Keys.ESCAPE) or GDVars.demoMode;
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, C_Screen.TEXT_COLUMNS);
  len := Length(typed);
  while typed[len] = ' ' do Dec(len);
  typed := Copy(typed, 1, len);
  for col := 1 to len do typed[col] := UpCase(typed[col]);
  ReadString := typed;
end;

function ReadNumber(query: Types.TString40; fg, bg: Byte): LongInt;
var
  isAllDigits: Boolean;
  value: LongInt;
  numStr: String[10];
  err: Integer;
begin
  repeat
    numStr := TextRend.ReadString(query, fg, bg, 10);
    value := 0;
    err := 0;
    isAllDigits := True;
    if Length(numStr) > 0 then begin
      GDVars.loopIndex := 1;
      while (GDVars.loopIndex <= Length(numStr)) and isAllDigits do begin
        isAllDigits := numStr[GDVars.loopIndex] in ['0'..'9'];
        Inc(GDVars.loopIndex)
      end;
      if isAllDigits then begin
        Val(numStr, value, err);
        if err = 0 then
          { the first test never holds for a LongInt }
          if (value > MaxLongInt) or (value < 0) then err := 1
      end else
        err := 1
    end
  until err = 0;
  ReadNumber := value
end;

procedure DisplayAndPause(fg, bg: Byte; msg: Types.TString40);
var
  c: Char;
  dir: Integer;
  x: Integer;
  y: Integer;
begin
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, C_Screen.TEXT_COLUMNS);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, fg, bg, msg);
  repeat
    c := GameIo.ReadGameKey
  until c in [C_Keys.ENTER, C_Keys.ESCAPE];
  if GDVars.isMouseClick then
    repeat
      Mouse.GetMouse(dir, x, y)
    until dir = 0
end;

function GetTicks: LongInt;
var
  h: Word;
  m: Word;
  s: Word;
  hs: Word;
begin
  GetTime(h, m, s, hs);
  GetTicks := LongInt(h) * 360000 + LongInt(m) * 6000 + LongInt(s) * 100 + hs;
end;

procedure ClearScreen;
begin
  case GDVars.displayMode of
    C_Vm.CGA: begin
         FillChar(cgaBank1, SizeOf(cgaBank1), 0);
         FillChar(cgaBank0, SizeOf(cgaBank0), 0);
       end;
    C_Vm.EGA: begin
         TextRend.FillRectEga(0, 0, C_Screen.LAST_COLUMN, TextRend.LAST_ROW, 0, 0);
         TextRend.FillRectEga(0, 0, C_Screen.LAST_COLUMN, TextRend.LAST_ROW, 1, 0);
       end;
    C_Vm.VGA: FillChar(vgaScreen, SizeOf(vgaScreen), 0);
    C_Vm.TANDY: begin
         FillChar(tandyBank0, SizeOf(tandyBank0), 0); FillChar(tandyBank1, SizeOf(tandyBank1), 0);
         FillChar(tandyBank2, SizeOf(tandyBank2), 0); FillChar(tandyBank3, SizeOf(tandyBank3), 0)
       end;
  end;
end;

procedure PrintAndPause(msg: Types.TString40; fg, bg: Byte);
begin
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, C_Screen.TEXT_COLUMNS);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, fg, bg, msg);
  TextRend.PauseOnly;
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, C_Screen.TEXT_COLUMNS);
end;

procedure PauseOnly;
begin
  Delay(GDVars.zone0^.messageSpeed * 100)
end;

procedure FillRect(ulCol, ulRow, lrCol, lrRow, color: Byte);
var
  y0: Word;
  yEnd: Word;
  x0: Word;
  count: Word;
  i: Word;
  videoOff: Word;
  scratch: Word;
  colorPat: Byte;
begin
  Mouse.HideMouse;
  case GDVars.displayMode of
    C_Vm.CGA: begin
      y0 := ulRow * 4; yEnd := lrRow * 4 + 3;
      count := (lrCol - ulCol + 1) * 2;
      { Note: the lookups are nested backwards: color's fill word indexes cgaTextColors }
      for i := y0 to yEnd do begin
        FillChar(cgaBank0[i][ulCol], count, GDConsts.cgaTextColors[GDConsts.cgaFillWords[color]]);
        FillChar(cgaBank1[i][ulCol], count, GDConsts.cgaTextColors[GDConsts.cgaFillWords[color]]);
      end;
    end;
    C_Vm.EGA: begin
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, color);
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, color);
    end;
    C_Vm.VGA: begin
      videoOff := Word(ulRow) * 8 * SizeOf(Types.TVgaRow) + Word(ulCol) * 8;
      scratch := (lrCol - ulCol + 1) * 8;
      for i := ulRow * 8 to (lrRow + 1) * 8 - 1 do begin
        FillChar(Types.PByteArr(C_Video.VGA_BASE + LongInt(videoOff))^, scratch, color);
        Inc(videoOff, SizeOf(Types.TVgaRow));
      end;
    end;
    C_Vm.TANDY: begin
      y0 := ulRow * 2; yEnd := lrRow * 2 + 1;
      x0 := ulCol * 4; count := (lrCol - ulCol + 1) * 4;
      colorPat := color + (color shl 4);
      for i := y0 to yEnd do begin
        FillChar(tandyBank0[i][x0], count, colorPat);
        FillChar(tandyBank1[i][x0], count, colorPat);
        FillChar(tandyBank2[i][x0], count, colorPat);
        FillChar(tandyBank3[i][x0], count, colorPat);
      end;
    end;
  end;
  Mouse.ShowMouse;
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);
begin TextRend.FillRect(ulCol, ulRow, lrCol, lrRow, 0) end;

procedure ClearTextWindow;
begin
  GDVars.textLeft := GDVars.windowLeft;
  GDVars.windowTextRow := GDVars.windowTop;
  TextRend.FillRect(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                GDVars.windowColor);
  GDVars.windowTextPending := 0
end;

procedure SetTextWindow(ulCol, ulRow, lrCol, lrRow, color: Byte);
begin
  GDVars.windowLeft := ulCol;
  GDVars.windowTop := ulRow;
  GDVars.windowRight := lrCol;
  GDVars.windowBottom := lrRow;
  GDVars.windowColor := color;
  TextRend.ClearTextWindow
end;

procedure DisplayWindowText(fg: Byte; msg: String);
var splitAt: Integer;
begin
  if Length(msg) > GDVars.windowRight - GDVars.windowLeft + 1 then begin
    splitAt := GDVars.windowRight - 1;
    while msg[splitAt] <> ' ' do Dec(splitAt);
    if splitAt < 0 then splitAt := GDVars.windowRight - 1;
    TextRend.DisplayWindowText(fg, Copy(msg, 0, splitAt - 1));
    TextRend.DisplayWindowText(fg, Copy(msg, splitAt + 1, Length(msg) - splitAt))
  end else begin
    if (GDVars.windowTextRow > GDVars.windowTop) and (GDVars.windowTextPending = 0) then
      TextRend.ClearTextWindow
    else if GDVars.windowTextRow > GDVars.windowBottom then begin
        if GDVars.windowTextPending <> 0 then TextRend.PauseContinue;
        TextRend.ClearTextWindow
    end;
    TextRend.DisplayString(GDVars.textLeft, GDVars.windowTextRow, fg, GDVars.windowColor, msg);
    GDVars.windowTextPending := 1;
    Inc(GDVars.windowTextRow)
  end
end;

procedure PauseContinue;
begin
  GameIo.FlushKeys;
  TextRend.DisplayAndPause(Black, White, GDConsts.continuePrompt);
  TextRend.ClearRect(0, C_Screen.STATUS_ROW, C_Screen.LAST_COLUMN, C_Screen.STATUS_ROW)
end;

procedure DisplayLoading;
begin
  TextRend.ClearRect(21, C_Screen.STATUS_ROW, C_Screen.LAST_COLUMN, C_Screen.STATUS_ROW);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, 'Loading...Please Wait')
end;

procedure DisplaySaving;
begin
  TextRend.ClearRect(20, C_Screen.STATUS_ROW, C_Screen.LAST_COLUMN, C_Screen.STATUS_ROW);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, 'Saving...Please Wait')
end;

procedure ClearStatusLine;
begin
  TextRend.ClearRect(0, C_Screen.STATUS_ROW, C_Screen.LAST_COLUMN, C_Screen.STATUS_ROW)
end;

function ByteToString(value: Byte): String;
var s: String;
begin Str(value, s); ByteToString := s end;

function WordToString(value: Word): String;
var s: String;
begin Str(value, s); WordToString := s end;

function CommaLongToString(value: LongInt): String;
var
  source: String;
  resultText: String;
  len: Byte;
begin
  Str(value, source);
  len := Length(source);
  if len > 3 then begin
    resultText := ',' + Copy(source, len - 2, 3);
    if len > 6 then begin
      resultText := ',' + Copy(source, len - 5, 3) + resultText;
      if len > 9 then
        resultText := ',' + Copy(source, len - 8, 3) + resultText
      else
        resultText := Copy(source, 1, len - 6) + resultText
    end else
      resultText := Copy(source, 1, len - 3) + resultText
  end else
    resultText := source;
  CommaLongToString := resultText
end;

procedure RightAlignString(var source; targetLen: Byte);
begin
  while Length(Types.TString40(source)) < targetLen do
    Types.TString40(source) := ' ' + Types.TString40(source)
end;

begin
end.
