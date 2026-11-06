{ Draws and erases the party's cursor on the wilderness picture, the cell at column partyX + 1, row partyY + 1 of zone
  0. Explore erases it before a wilderness step and draws it after; EclVm draws it over a big picture shown in the
  wilderness. Both routines act only while GDVars.viewActive is set. The unit owns no storage. }
{$O+,F+}
unit MapCurs;

interface

{ When the view is active, saves the party's cell, draws the cursor picture through its mask over a copy of it, shows
  that, and resets the dirty-span tables (the first-row table to $FF, the rest to 0); otherwise does nothing. }
procedure DrawCursor;

{ When the view is active, shows the saved cell back over the party's cell; otherwise does nothing. }
procedure RestoreCursorBackground;

implementation

uses Blit, GDVars;

procedure DrawCursor;
begin
  if GDVars.viewActive <> 0 then begin
    Blit.GrabPic(GDVars.zone0^.partyX + 1, GDVars.zone0^.partyY + 1, GDVars.savedWildernessCell);
    Blit.BlitTileCell(0, 0, 0, 0, GDVars.savedWildernessCell, GDVars.wildernessCursorCell);
    Blit.BlitTileCell(0, 0, 0, 1, GDVars.cursorPicture, GDVars.wildernessCursorCell);
    Blit.ShowPic(GDVars.zone0^.partyX + 1, GDVars.zone0^.partyY + 1, GDVars.wildernessCursorCell);
    FillChar(GDVars.dirtyRows, SizeOf(GDVars.dirtyRows), 0);
    FillChar(GDVars.dirtyRowLeft, SizeOf(GDVars.dirtyRowLeft), 0);
    FillChar(GDVars.dirtyRowFirst, SizeOf(GDVars.dirtyRowFirst), $FF);
    FillChar(GDVars.dirtyRowLast, SizeOf(GDVars.dirtyRowLast), 0)
  end
end;

procedure RestoreCursorBackground;
begin
  if GDVars.viewActive = 0 then Exit;
  Blit.ShowPic(GDVars.zone0^.partyX + 1, GDVars.zone0^.partyY + 1, GDVars.savedWildernessCell)
end;

begin
end.
