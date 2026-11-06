{ The 8x8 tile sets: Load8x8Set loads a set into a slot of GDVars.tileSets, Put8x8Sym draws a tile by its number, and
  DrawBorderRun draws a run of the border slot's tiles. Tile numbers run on through the slots, GDConsts.symSetFirst and
  symSetLast giving each slot's range; Put8x8Sym takes the first slot whose last tile reaches the number, so slot 0's
  range, 0 to 255, also covers slots 1 to 3's. }
{$O+,F+,I-,A-}
unit Sym8x8;

interface

{ Loads a tile set from 8x8d plus the data set's digit, or from borders for the border slot; a failed load stops the
  game.
  @param(fileId The record to load.)
  @param(slot The tile-set slot, 0 to 6; another slot does nothing.) }
procedure Load8x8Set(fileId, slot: Byte);

{ Draws a tile by its number; tile 0, a tile past the last slot's range, or one whose slot is not loaded draws nothing.
  @param(col The cell's column.)
  @param(row The cell's row.)
  @param(tile The tile's number, counted on through the slots.)
  @param(isInView Non-zero blits it into viewPicture; zero shows it on the screen.)
  @param(isMasked Passed to Blit's BlitTileCell as its flag, whose bit 0 asks for the masked draw.) }
procedure Put8x8Sym(col, row: ShortInt; tile: Word; isInView, isMasked: Byte);

{ Draws a horizontal or vertical run of border tiles on the screen. The third cell from each end is left undrawn, and a
  corner or junction tile also draws a join tile two cells off.
  @param(x1 The first cell's column.)
  @param(y1 The first cell's row.)
  @param(x2 The last cell's column.)
  @param(y2 The last cell's row.)
  @param(firstTile The first cell's tile, counted from the border slot's first.)
  @param(lastTile The last cell's tile, likewise.) }
procedure DrawBorderRun(x1, y1, x2, y2: ShortInt; firstTile, lastTile: Byte);

implementation

uses Blit, Types, C_Pic, GDConsts, GDVars, GameIo;

const
  { the tile-set slot holding the border tiles }
  BORDER_SLOT = 6;
  { EmitBorderCell's selector: SEL_SKIP draws nothing in the cell and moves on; SEL_STRAIGHT draws STRAIGHT_TILE plus
    direction, both counted from the border slot's first. }
  SEL_SKIP = 0;
  SEL_STRAIGHT = 1;
  SEL_FIRST = 2;
  SEL_LAST = 3;
  STRAIGHT_TILE = 4;
  { drawn two cells left or right of a corner or junction tile }
  HORIZONTAL_JOIN_TILE = 10;
  { drawn two cells above or below one }
  VERTICAL_JOIN_TILE = 11;

procedure Load8x8Set(fileId, slot: Byte);
var
  name: String[8];
  { Unused in this version; see the other implementations of this routine. }
  result: Word;
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  if GDVars.isDebugMode then
    WriteLn(GDVars.debugFile, 'slotnum = ', slot);
  if not (slot in [0..SizeOf(GDVars.tileSets) div SizeOf(Types.PImgBuf) - 1]) then Exit;
  if slot = Sym8x8.BORDER_SLOT then
    name := 'borders'
  else begin
    Str(GDVars.dataSet, name);
    name := '8x8d' + name
  end;
  Blit.LoadPic(name, fileId, True, C_Pic.KEY_COLOR, GDVars.tileSets[slot]);
  if GDVars.tileSets[slot] = nil then begin
    Blit.RestoreVideoMode;
    WriteLn(Output, 'Unable to load ', fileId, ' from ' + name);
    key := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame
  end;
  GameIo.FlushKeys
end;

procedure Put8x8Sym(col, row: ShortInt; tile: Word; isInView, isMasked: Byte);
var
  slot: Byte;
begin
  slot := 0;
  while GDConsts.symSetLast[slot] < tile do Inc(slot);
  if (tile = 0) or (slot > SizeOf(GDVars.tileSets) div SizeOf(Types.PImgBuf) - 1) then Exit;
  if GDVars.tileSets[slot] = nil then Exit;
  Dec(tile, GDConsts.symSetFirst[slot]);
  if isInView <> 0 then
    Blit.BlitTileCell(col, row, tile, isMasked, GDVars.tileSets[slot], GDVars.viewPicture)
  else begin
    with GDVars.tileSets[slot]^ do
      Move(data[tile * frameSize], GDVars.tileScratch^.data, frameSize);
    Blit.ShowPic(col, row, GDVars.tileScratch)
  end
end;

procedure DrawBorderRun(x1, y1, x2, y2: ShortInt; firstTile, lastTile: Byte);
var
  { 0 horizontal, 1 vertical }
  direction: Byte;
  remaining: ShortInt;

  { Draws the run's current cell as selector picks, with its join tiles, and steps to the next cell. }
  procedure EmitBorderCell(selector: Byte);
  var tile: ShortInt;
  begin
    case selector of
      Sym8x8.SEL_SKIP: tile := -1;
      Sym8x8.SEL_STRAIGHT: tile := direction + Sym8x8.STRAIGHT_TILE;
      Sym8x8.SEL_FIRST: tile := firstTile;
      Sym8x8.SEL_LAST: tile := lastTile
    end;
    if tile >= 0 then
      Sym8x8.Put8x8Sym(x1, y1, tile + GDConsts.symSetFirst[Sym8x8.BORDER_SLOT], 0, 0);
    if tile in [0, 3, 6, 8, 9] then
      Sym8x8.Put8x8Sym(x1 + 2, y1, GDConsts.symSetFirst[Sym8x8.BORDER_SLOT] + Sym8x8.HORIZONTAL_JOIN_TILE, 0, 0);
    if tile in [1, 2, 6, 7, 8] then
      Sym8x8.Put8x8Sym(x1 - 2, y1, GDConsts.symSetFirst[Sym8x8.BORDER_SLOT] + Sym8x8.HORIZONTAL_JOIN_TILE, 0, 0);
    if tile in [0, 1, 6, 7, 9] then
      Sym8x8.Put8x8Sym(x1, y1 + 2, GDConsts.symSetFirst[Sym8x8.BORDER_SLOT] + Sym8x8.VERTICAL_JOIN_TILE, 0, 0);
    if tile in [2, 3, 7, 8, 9] then
      Sym8x8.Put8x8Sym(x1, y1 - 2, GDConsts.symSetFirst[Sym8x8.BORDER_SLOT] + Sym8x8.VERTICAL_JOIN_TILE, 0, 0);
    if direction <> 0 then Inc(y1) else Inc(x1);
    Dec(remaining)
  end;

begin
  if y1 = y2 then begin
    direction := 0;
    if x1 > x2 then begin
      remaining := x1;
      x1 := x2;
      x2 := remaining
    end;
    remaining := x2 - x1 + 1
  end else begin
    direction := 1;
    if y1 > y2 then begin
      remaining := y1;
      y1 := y2;
      y2 := remaining
    end;
    remaining := y2 - y1 + 1
  end;
  EmitBorderCell(Sym8x8.SEL_FIRST);
  EmitBorderCell(Sym8x8.SEL_STRAIGHT);
  EmitBorderCell(Sym8x8.SEL_SKIP);
  while remaining > 3 do EmitBorderCell(Sym8x8.SEL_STRAIGHT);
  if remaining = 3 then EmitBorderCell(Sym8x8.SEL_SKIP);
  if remaining = 2 then EmitBorderCell(Sym8x8.SEL_STRAIGHT);
  if remaining = 1 then EmitBorderCell(Sym8x8.SEL_LAST)
end;

begin
end.
