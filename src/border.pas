{ The screen layouts: each Screen routine hides the mouse, clears the screen inside its frame and draws the frame from
  its frame script in GDConsts, runs of border tiles that Sym8x8's DrawBorderRun draws. ClearBox clears a rectangle of
  text cells in any display mode. Coordinates are text cells, 40 columns by 25 rows. }
{$O+,F+}
unit Border;

interface

{ Draws each run of a frame script.
  @param(script Runs (Types.TFrameRun) ended by FRAME_SCRIPT_END.) }
procedure DrawFrameSegments(var script);

{ Clears cells 0, 0 to 38, 22 and draws the main frame.
  @param(layout Unused.) }
procedure DrawWindowFrame(layout: Byte);

{ Clears inside the frame down to row 23 and draws the credits frame, one row taller than the main frame. }
procedure ScreenCredits;

{ Draws the text screen's frame through ScreenText, then the exploration screen's extra frame segments. }
procedure DrawExploreFrame;

{ Clears the screen inside the outer frame (columns 1..38, rows 1..22), draws the outer frame with a divider across row
  16, and records the text window below it, rows 17 to 22. }
procedure ScreenText;

{ Clears inside the frame down to row 21, draws the ship screen's frame and clears rows 23 and 24. }
procedure DrawShipFrame;

{ Clears inside the frame down to row 21, draws the ground combat frame, clears row 23, and sets the text window to
  column 23, rows 1 to 21. }
procedure DrawCombatFrame;

{ Clears the screen inside the outer frame (columns 1..38, rows 1..22), draws the outer frame, then draws the character
  sheet's frame script. }
procedure DrawCharViewFrame;

{ Clears rows 1..16 inside the outer frame and draws the outer frame. }
procedure DrawListFrame;

{ Clears a rectangle of text cells, corners included, to color 0 in the display mode's screen memory, with the mouse
  cursor hidden.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

implementation

uses Mouse, Types, C_Video, GDConsts, GDVars, Sym8x8, TextRend, C_Vm, C_Screen, C_Msg;

type
  { a frame script, read byte by byte }
  TScript = array[0..255] of Byte;
  TScreen = array[0..65534] of Byte;
  PScreen = ^TScreen;

var
  { The CGA and Tandy frame buffers as [scanline][byte] arrays, one per interleaved bank. }
  { CGA: even scanlines, then odd }
  cgaBank0: array[0..99] of Types.TCgaRow absolute $B800: 0000;
  cgaBank1: array[0..99] of Types.TCgaRow absolute $BA00: 0000;
  { Tandy: scanlines 0, 1, 2, 3 mod 4 }
  tandyBank0: array[0..49] of Types.TTandyRow absolute $B800: 0000;
  tandyBank1: array[0..49] of Types.TTandyRow absolute $BA00: 0000;
  tandyBank2: array[0..49] of Types.TTandyRow absolute $BC00: 0000;
  tandyBank3: array[0..49] of Types.TTandyRow absolute $BE00: 0000;

procedure DrawFrameSegments(var script);
var
  x1: Byte;
  y1: Byte;
  x2: Byte;
  y2: Byte;
  firstTile: Byte;
  lastTile: Byte;
  i: Byte;
begin
  GDVars.frameScriptDone := False;
  i := 0;
  repeat
    if TScript(script)[i] = C_Screen.FRAME_SCRIPT_END then
      GDVars.frameScriptDone := True
    else begin
      x1 := TScript(script)[i]; Inc(i);
      y1 := TScript(script)[i]; Inc(i);
      x2 := TScript(script)[i]; Inc(i);
      y2 := TScript(script)[i]; Inc(i);
      firstTile := TScript(script)[i]; Inc(i);
      lastTile := TScript(script)[i]; Inc(i);
      Sym8x8.DrawBorderRun(ShortInt(x1), ShortInt(y1), ShortInt(x2), ShortInt(y2), firstTile, lastTile);
    end;
  until GDVars.frameScriptDone;
end;

{ Draws the main frame from its frame script. }
procedure DrawOuterFrame;
begin
  Border.DrawFrameSegments(GDConsts.mainFrame);
end;

procedure DrawWindowFrame(layout: Byte);
begin
  Mouse.HideMouse;
  Border.ClearBox(0, 0, 38, 22);
  Border.DrawOuterFrame;
  Mouse.ShowMouse;
end;

{ Draws a divider across a row.
  @param(y The row.)
  @param(x1 The first column.)
  @param(x2 The last column.) }
procedure DrawHLine(y, x1, x2: Byte);
begin
  Sym8x8.DrawBorderRun(ShortInt(x1), ShortInt(y), ShortInt(x2), ShortInt(y), 9, 7);
end;

procedure ScreenCredits;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 23);
  Border.DrawFrameSegments(GDConsts.creditsFrame);
  Mouse.ShowMouse;
end;

procedure DrawExploreFrame;
begin
  Mouse.HideMouse;
  Border.ScreenText;
  Border.DrawFrameSegments(GDConsts.exploreFrame);
  Mouse.ShowMouse;
end;

procedure ScreenText;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 22);
  Border.DrawOuterFrame;
  Border.DrawHLine(16, 0, 39);
  GDVars.windowLeft := C_Msg.MESSAGE_LEFT;
  GDVars.windowTop := C_Msg.MESSAGE_TOP;
  GDVars.windowRight := C_Msg.MESSAGE_RIGHT;
  GDVars.windowBottom := C_Msg.MESSAGE_BOTTOM;
  Mouse.ShowMouse;
end;

procedure DrawShipFrame;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 21);
  Border.DrawFrameSegments(GDConsts.shipFrame);
  Border.ClearBox(0, 23, 39, 24);
  Mouse.ShowMouse;
end;

procedure DrawCombatFrame;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 21);
  Border.DrawFrameSegments(GDConsts.combatFrame);
  Border.ClearBox(0, 23, 39, 23);
  GDVars.windowLeft := 23;
  GDVars.windowTop := 1;
  { the same column as windowLeft: a one-column window }
  GDVars.windowRight := 23;
  GDVars.windowBottom := 21;
  Mouse.ShowMouse;
end;

procedure DrawCharViewFrame;
var
  { Unused in this version; see the other implementations of this routine. }
  frameScript: Pointer;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 22);
  Border.DrawOuterFrame;
  Border.DrawFrameSegments(GDConsts.characterSheetFrame);
  Mouse.ShowMouse;
end;

procedure DrawListFrame;
var
  { Unused in this version; see the other implementations of this routine. }
  row: Word;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 16);
  Border.DrawOuterFrame;
  Mouse.ShowMouse;
end;

procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  topLine: Word;
  bottomLine: Word;
  colOffset: Word;
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaColumnOffset: Word;
  line: Word;
  vgaOffset: Word;
  vgaLineBytes: Word;
begin
  Mouse.HideMouse;
  case GDVars.displayMode of
    C_Vm.CGA:
      begin
        topLine := ulRow * 4;
        bottomLine := lrRow * 4 + 3;
        rowBytes := (lrCol - ulCol + 1) * 2;
        for line := topLine to bottomLine do begin
          FillChar(cgaBank0[line][ulCol * 2], rowBytes, 0);
          FillChar(cgaBank1[line][ulCol * 2], rowBytes, 0);
        end;
      end;
    C_Vm.EGA:
      begin
        TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, 0);
        TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, 0);
      end;
    C_Vm.TANDY:
      begin
        topLine := ulRow * 2;
        bottomLine := lrRow * 2 + 1;
        colOffset := ulCol * 4;
        rowBytes := (lrCol - ulCol + 1) * 4;
        for line := topLine to bottomLine do begin
          FillChar(tandyBank0[line][colOffset], rowBytes, 0);
          FillChar(tandyBank1[line][colOffset], rowBytes, 0);
          FillChar(tandyBank2[line][colOffset], rowBytes, 0);
          FillChar(tandyBank3[line][colOffset], rowBytes, 0);
        end;
      end;
    C_Vm.VGA:
      begin
        vgaOffset := ulRow * 8 * SizeOf(Types.TVgaRow) + ulCol * 8;
        vgaLineBytes := (lrCol - ulCol + 1) * 8;
        for line := ulRow * 8 to (lrRow + 1) * 8 - 1 do begin
          FillChar(PScreen(C_Video.VGA_BASE + vgaOffset)^, vgaLineBytes, 0);
          Inc(vgaOffset, SizeOf(Types.TVgaRow));
        end;
      end;
  end;
  Mouse.ShowMouse;
end;

begin
end.
