{ The 3-D view: loading a map's four planes from GEO<n>.DAX and the wall art from WALLDEF<n>.DAX, looking up a square's
  walls, barriers and event, and drawing the view -- the backdrop, then the wall slices from two squares ahead back to
  the party's own -- or, in automap mode, the 11x11 automap. GDConsts.viewSlotGeom says where the view draws each wall
  slot; the rest of its state lives in GDVars (geoMap, wallDefs, wallSets, the colors, backdropPictures, viewPalette,
  automapOn and partyPosition). wallSlices reads GDVars' wallDefs as slices. }
{$O+,F+,I-}
unit View3D;

interface

{ Sets the 3-D view's sky, horizon and floor colors.
  @param(cSky The sky's color.)
  @param(cHorz1 The horizon's upper band's color.)
  @param(cHorz2 The horizon's lower band's color.)
  @param(cFloor The floor's color.) }
procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);

{ Gives the wall on one side of a square. Off the map it gives 0 in scripts NO_ECL_SCRIPT and UNWRAPPED_MAP_SCRIPT and
  wraps around elsewhere. Note: a diagonal (odd) facing leaves the result undefined.
  @param(x The square's column.)
  @param(y The square's row.)
  @param(facing The side: C_Dir.NORTH, C_Dir.EAST, C_Dir.SOUTH or C_Dir.WEST.)
  @returns(The wall type, 0 for none.) }
function GetWallType(x, y: ShortInt; facing: Byte): Byte;

{ Gives the barrier on one side of a square. Off the map as GetWallType.
  @param(x The square's column.)
  @param(y The square's row.)
  @param(facing The side.)
  @returns(The barrier plane's two bits for that side, or 1 when that side has no wall.) }
function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;

{ Gives a square's event byte. Off the map as GetWallType.
  @param(x The square's column.)
  @param(y The square's row.)
  @returns(The event byte.) }
function GetMapEvent(x, y: ShortInt): Byte;

{ Draws the automap in automap mode; otherwise the backdrop and the walls from two squares ahead of x, y back to the
  party's square, then flushes the view.
  @param(x The party's column.)
  @param(y The party's row.)
  @param(facing The party's facing.) }
procedure Display3DMapView(x, y: ShortInt; facing: Byte);

{ Loads a wall set from WALLDEF<n> into the wall banks after bank wsSlot, its tiles into tile-set slot wsSlot and its
  backdrops, marks the view palette stale, copies DAC colors $20..$B3 into viewPalette, and records the set in
  wallSets[wsSlot]. A missing set, or one whose whole banks overflow the four, stops the game; a wsSlot above 3 does
  nothing. Note: the overflow test ignores a partial trailing bank, and the bank allocation holds only three banks, so a
  set reaching bank 4 writes past it (see wallDefs).
  @param(fileId The wall set's record.)
  @param(wsSlot The wall-set slot, 0 to 3.) }
procedure LoadWallSet(fileId, wsSlot: Byte);

{ Loads a map from GEO<n> into geoMap and records its id in zone 0; a map that is not a header and four planes stops the
  game.
  @param(mapId The map's record.) }
procedure Load3DMap(mapId: Byte);

implementation

uses Blit, Sym8x8, DaxIo, GameIo, Types, C_Ecl, GDConsts, GDVars, C_Dir, C_Pic;

const
  { the script whose map the lookups do not wrap: a square off it is empty, as with C_Ecl.NO_ECL_SCRIPT }
  UNWRAPPED_MAP_SCRIPT = 80;
  { tile-set slot 4's first tile, GDConsts.symSetFirst[4]: the automap square with no walls; 1, 2, 4 and 8 added for its
    north, east, south and west walls }
  AUTO_MAP_WALL_TILE = 256;
  { the party's arrow for facing 0; facing div 2 adds to it }
  AUTO_MAP_PARTY_TILE = View3D.AUTO_MAP_WALL_TILE + 16;

type
  { A GEO<n>.DAX record as loaded. }
  TGeoRecord = record
    { Never read. }
    header: Word;
    planes: Types.TGeoMap
  end;
  { the four WALLDEF banks as twenty 156-cell wall slices }
  TWallSlices = array[1..20, 0..155] of Byte;
  PWallSlices = ^TWallSlices;

var
  { the WALLDEF banks as slices, by wall type }
  wallSlices: PWallSlices absolute GDVars.wallDefs;

{ Draws the 11x11 automap around the party: a square's tile is 256 plus 1, 2, 4 and 8 for its north, east, south and
  west walls, and the party's is 272 + facing div 2.
  @param(x The party's column.)
  @param(y The party's row.)
  @param(facing The party's facing.) }
procedure DrawAutoMap(x, y: ShortInt; facing: Byte);
var
  pwx: ShortInt;
  pwy: ShortInt;
  wx: ShortInt;
  wy: ShortInt;
  xLo: ShortInt;
  yLo: ShortInt;
  mx: ShortInt;
  my: ShortInt;
  sym: Word;
  { Unused in this version; see the other implementations of this routine. }
  symbolText: String;
begin
  { keep the 11x11 window on the 16x16 map }
  xLo := x - 5;
  if xLo < 0 then xLo := 0;
  if xLo > 5 then xLo := 5;
  pwx := x - xLo;
  yLo := y - 5;
  if yLo < 0 then yLo := 0;
  if yLo > 5 then yLo := 5;
  pwy := y - yLo;
  for wy := 0 to 10 do begin
    my := wy + yLo;
    for wx := 0 to 10 do begin
      mx := wx + xLo;
      sym := View3D.AUTO_MAP_WALL_TILE;
      if View3D.GetWallType(mx, my, C_Dir.NORTH) > 0 then Inc(sym);
      if View3D.GetWallType(mx, my, C_Dir.EAST) > 0 then Inc(sym, 2);
      if View3D.GetWallType(mx, my, C_Dir.SOUTH) > 0 then Inc(sym, 4);
      if View3D.GetWallType(mx, my, C_Dir.WEST) > 0 then Inc(sym, 8);
      Sym8x8.Put8x8Sym(wx + 3 - 1, wy + 3 - 1, sym, 1, 0);
    end;
  end;
  Sym8x8.Put8x8Sym(pwx + 3 - 1, pwy + 3 - 1, facing div 2 + View3D.AUTO_MAP_PARTY_TILE, 1, 0);
  Blit.FlushView;
end;

procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);
begin
  GDVars.skyColor := cSky;
  GDVars.horizonColor1 := cHorz1;
  GDVars.horizonColor2 := cHorz2;
  GDVars.floorColor := cFloor;
end;

{ Fills the sky, horizon and floor bands of viewPicture and draws the backdrop over them: backdropPictures[0] while bit
  $80 of partyPosition.mapEvent is set, else [1]. }
procedure DrawBackdrop;
var
  { Unused in this version; see the other implementations of this routine. }
  hour: Word;
  baseX: Byte;
  baseY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  colW: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rowH: Byte;
begin
  Blit.FillPicRect(2, 16, 11, 44, GDVars.skyColor, GDConsts.packedColorMap, GDVars.viewPicture);
  Blit.FillPicRect(2, 60, 11, 2, GDVars.horizonColor2, GDConsts.packedColorMap, GDVars.viewPicture);
  Blit.FillPicRect(2, 62, 11, 42, GDVars.floorColor, GDConsts.packedColorMap, GDVars.viewPicture);
  baseX := 2;
  baseY := 2;
  colW := 12;
  rowH := 12;
  if (GDVars.partyPosition.mapEvent and $80) <> 0 then begin
    if GDVars.backdropPictures[0] <> nil then
      Blit.BlitTileClipped(baseX, baseY, 0, 0, GDVars.backdropPictures[0], GDVars.viewPicture)
  end else if GDVars.backdropPictures[1] <> nil then
    Blit.BlitTileClipped(baseX, baseY, 0, 0, GDVars.backdropPictures[1], GDVars.viewPicture)
end;

{ Draws a wall slot's rectangle of a wall type's slice, skipping empty cells and cells outside the 11x11 view.
  @param(x The view column of its top left.)
  @param(y The view row of its top left.)
  @param(wallType The wall type.)
  @param(slot The wall slot.) }
procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);
var
  colLim: Integer;
  rowLim: Integer;
  col: Integer;
  row: Integer;
  cell: Byte;
begin
  cell := GDConsts.viewSlotGeom.start[slot];
  colLim := GDConsts.viewSlotGeom.cols[slot] + x - 1;
  rowLim := GDConsts.viewSlotGeom.rows[slot] + y - 1;
  for row := y to rowLim do
    for col := x to colLim do begin
      if (row >= 0) and (row <= 10) and (col >= 0) and (col <= 10) and (wallSlices^[wallType][cell] > 0) then
        Sym8x8.Put8x8Sym(col + 3 - 1, row + 3 - 1, wallSlices^[wallType][cell], 1, 1);
      Inc(cell);
    end;
end;

{ Tests a square against the map.
  @param(x The square's column.)
  @param(y The square's row.)
  @returns(True when the square is on the 16x16 map.) }
function Valid3DCoords(x, y: ShortInt): Boolean;
begin
  if (x > SizeOf(GDVars.geoMap^.wallsNE[0]) - 1) or (x < 0) or
      (y > SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1) or (y < 0) then
    Valid3DCoords := False
  else
    Valid3DCoords := True;
end;

function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;
var
  b: Byte;
begin
  if not View3D.Valid3DCoords(x, y) and
      ((GDVars.eclId = C_Ecl.NO_ECL_SCRIPT) or (GDVars.eclId = View3D.UNWRAPPED_MAP_SCRIPT)) then
    GetBarrierType := 0
  else begin
    if x > SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then x := 0
    else if x < 0 then x := SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
    if y > SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then y := 0
    else if y < 0 then y := SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
    b := 1;
    if View3D.GetWallType(x, y, facing) > 0 then
      case facing of
        C_Dir.WEST: b := (GDVars.geoMap^.barriers[y][x] and $C0) shr 6;
        C_Dir.SOUTH: b := (GDVars.geoMap^.barriers[y][x] and $30) shr 4;
        C_Dir.EAST: b := (GDVars.geoMap^.barriers[y][x] and $0C) shr 2;
        C_Dir.NORTH: b := GDVars.geoMap^.barriers[y][x] and $03;
      end;
    GetBarrierType := b;
  end;
end;

function GetWallType(x, y: ShortInt; facing: Byte): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and
      ((GDVars.eclId = C_Ecl.NO_ECL_SCRIPT) or (GDVars.eclId = View3D.UNWRAPPED_MAP_SCRIPT)) then
    GetWallType := 0
  else begin
    if x > SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then x := 0
    else if x < 0 then x := SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
    if y > SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then y := 0
    else if y < 0 then y := SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
    case facing of
      C_Dir.NORTH: GetWallType := (GDVars.geoMap^.wallsNE[y][x] and $F0) shr 4;
      C_Dir.EAST: GetWallType := GDVars.geoMap^.wallsNE[y][x] and $0F;
      C_Dir.SOUTH: GetWallType := (GDVars.geoMap^.wallsSW[y][x] and $F0) shr 4;
      C_Dir.WEST: GetWallType := GDVars.geoMap^.wallsSW[y][x] and $0F;
    end;
  end;
end;

function GetMapEvent(x, y: ShortInt): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and
      ((GDVars.eclId = C_Ecl.NO_ECL_SCRIPT) or (GDVars.eclId = View3D.UNWRAPPED_MAP_SCRIPT)) then
    GetMapEvent := 0
  else begin
    if x > SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then x := 0
    else if x < 0 then x := SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
    if y > SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then y := 0;
    if y < 0 then y := SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
    GetMapEvent := GDVars.geoMap^.events[y][x];
  end;
end;

procedure Display3DMapView(x, y: ShortInt; facing: Byte);
var
  fL: Byte;
  fR: Byte;
  fB: Byte;
  cxPos: Integer;
  cyPos: Integer;
  dxF: Integer;
  dyF: Integer;
  wx: Integer;
  wy: Integer;
  side: Byte;
  symOfs: Integer;
  dist: Byte;
  wallFront: Byte;
  wallSide: Byte;
  { Unused in this version; see the other implementations of this routine. }
  wallBack: Byte;
  prevWall: Byte;
begin
  if GDVars.automapOn <> 0 then
    View3D.DrawAutoMap(x, y, facing)
  else begin
    View3D.DrawBackdrop;
    fL := (facing + 6) mod 8;
    fB := (facing + 4) mod 8;
    fR := (facing + 2) mod 8;
    cxPos := x;
    cyPos := y;
    dxF := GDConsts.dirStepX[facing];
    dyF := GDConsts.dirStepY[facing];
    dist := 2;
    Inc(cxPos, dist * dxF);
    Inc(cyPos, dist * dyF);
    repeat
      case dist of
        2: begin
          wx := cxPos; wy := cyPos; side := 0; symOfs := 0; prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if not View3D.Valid3DCoords(wx, wy) and (View3D.GetWallType(wx, wy, fR) = 0) then
              prevWall := 0;
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs + 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[0] + symOfs, GDConsts.viewSlotGeom.yRow[0], wallFront, 0);
            end else begin
              if (prevWall > 0) and
                  (View3D.GetWallType(wx - GDConsts.dirStepX[fL], wy - GDConsts.dirStepY[fL], fL) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs + 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side); Dec(symOfs, 2);
            wx := wx + GDConsts.dirStepX[fL]; wy := wy + GDConsts.dirStepY[fL];
          end;
          wx := cxPos; wy := cyPos; side := 0; symOfs := 0; prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if not View3D.Valid3DCoords(wx, wy) and (View3D.GetWallType(wx, wy, fL) = 0) then
              prevWall := 0;
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs - 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[0] + symOfs, GDConsts.viewSlotGeom.yRow[0], wallFront, 0);
            end else begin
              if (prevWall > 0) and
                  (View3D.GetWallType(wx - GDConsts.dirStepX[fR], wy - GDConsts.dirStepY[fR], fR) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs - 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side); Inc(symOfs, 2);
            wx := wx + GDConsts.dirStepX[fR]; wy := wy + GDConsts.dirStepY[fR];
          end;
          wx := cxPos; wy := cyPos; side := 0; symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[1] + symOfs, GDConsts.viewSlotGeom.yRow[1], wallSide, 1)
              else
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[1] + symOfs - 1, GDConsts.viewSlotGeom.yRow[1],
                                     wallSide, 1);
            Inc(side); Dec(symOfs, 2);
            wx := wx + GDConsts.dirStepX[fL]; wy := wy + GDConsts.dirStepY[fL];
          end;
          wx := cxPos; wy := cyPos; side := 0; symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[2] + symOfs, GDConsts.viewSlotGeom.yRow[2], wallSide, 2)
              else
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[2] + symOfs + 1, GDConsts.viewSlotGeom.yRow[2],
                                     wallSide, 2);
            Inc(side); Inc(symOfs, 2);
            wx := wx + GDConsts.dirStepX[fR]; wy := wy + GDConsts.dirStepY[fR];
          end;
        end;
        1: begin
          wx := cxPos + GDConsts.dirStepX[fL];
          wx := wx + GDConsts.dirStepX[fL];
          wy := cyPos + GDConsts.dirStepY[fL];
          wy := wy + GDConsts.dirStepY[fL];
          side := 0;
          symOfs := -6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[3] + symOfs, GDConsts.viewSlotGeom.yRow[3], wallFront, 3);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[4] + symOfs, GDConsts.viewSlotGeom.yRow[4], wallSide, 4);
            Inc(side); Inc(symOfs, 3);
            wx := wx + GDConsts.dirStepX[fR]; wy := wy + GDConsts.dirStepY[fR];
          end;
          wx := cxPos + GDConsts.dirStepX[fR];
          wx := wx + GDConsts.dirStepX[fR];
          wy := cyPos + GDConsts.dirStepY[fR];
          wy := wy + GDConsts.dirStepY[fR];
          side := 0;
          symOfs := 6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[3] + symOfs, GDConsts.viewSlotGeom.yRow[3], wallFront, 3);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[5] + symOfs, GDConsts.viewSlotGeom.yRow[5], wallSide, 5);
            Inc(side); Dec(symOfs, 3);
            wx := wx + GDConsts.dirStepX[fL]; wy := wy + GDConsts.dirStepY[fL];
          end;
        end;
        0: begin
          wx := cxPos + GDConsts.dirStepX[fL];
          wy := cyPos + GDConsts.dirStepY[fL];
          side := 0;
          symOfs := -7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[6] + symOfs, GDConsts.viewSlotGeom.yRow[6], wallFront, 6);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[7] + symOfs, GDConsts.viewSlotGeom.yRow[7], wallSide, 7);
            Inc(side); Inc(symOfs, 7);
            wx := wx + GDConsts.dirStepX[fR]; wy := wy + GDConsts.dirStepY[fR];
          end;
          wx := cxPos + GDConsts.dirStepX[fR];
          wy := cyPos + GDConsts.dirStepY[fR];
          side := 0;
          symOfs := 7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[6] + symOfs, GDConsts.viewSlotGeom.yRow[6], wallFront, 6);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[8] + symOfs, GDConsts.viewSlotGeom.yRow[8], wallSide, 8);
            Inc(side); Dec(symOfs, 7);
            wx := wx + GDConsts.dirStepX[fL]; wy := wy + GDConsts.dirStepY[fL];
          end;
        end;
      end;
      cxPos := cxPos + GDConsts.dirStepX[fB];
      cyPos := cyPos + GDConsts.dirStepY[fB];
      Dec(dist);
    until dist = 255;
    Blit.FlushView;
  end;
end;

{ Loads a wall set's backdrops from BACK<n>: backdropPictures[1] from picture fileId + $80 and [0] from fileId.
  @param(fileId The wall set's record.) }
procedure LoadBackdrop(fileId: Byte);
var
  numStr: String[1];
  fileName: String[5];
begin
  Str(GDVars.dataSet, numStr);
  fileName := 'back' + numStr;
  Blit.LoadPic(fileName, fileId + $80, False, GDVars.skyColor, GDVars.backdropPictures[1]);
  Blit.LoadPic(fileName, fileId, False, GDVars.skyColor, GDVars.backdropPictures[0])
end;

procedure LoadWallSet(fileId, wsSlot: Byte);
var
  sizeRead: Word;
  data: Types.PByteArr;
  offset: Word;
  { Unused in this version; see the other implementations of this routine. }
  symOfs: Word;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  i: Word;
  { Unused in this version; see the other implementations of this routine. }
  col: Integer;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if wsSlot > 3 then Exit;
  Str(GDVars.dataSet, numStr);
  DaxIo.LoadDax('WALLDEF' + numStr, '.dax', fileId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead div SizeOf(Types.TWallDef) + wsSlot > 4) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load ', fileId, ' from WALLDEF' + numStr + '.');
    ch := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  symOfs := GDConsts.symSetFirst[wsSlot] - GDConsts.symSetFirst[1];
  offset := 0;
  i := 1;
  repeat
    Move(data^[offset], GDVars.wallDefs^[wsSlot + i], SizeOf(Types.TWallDef));
    Inc(offset, SizeOf(Types.TWallDef));
    Inc(i);
  until offset >= sizeRead;
  FreeMem(data, sizeRead);
  count := i - 1;
  Sym8x8.Load8x8Set(fileId, wsSlot);
  GDVars.viewPaletteStale := 1;
  View3D.LoadBackdrop(fileId);
  Blit.ShadowPaletteEntries(C_Pic.WALL_DAC_FIRST, C_Pic.WALL_DAC_COUNT, GDVars.viewPalette);
  GDVars.wallSets[wsSlot].fileId := fileId;
  GDVars.wallSets[wsSlot].slot := wsSlot;
end;

procedure Load3DMap(mapId: Byte);
var
  sizeRead: Word;
  data: Types.PByteArr;
  offset: Word;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  Str(GDVars.dataSet, numStr);
  DaxIo.LoadDax('GEO' + numStr, '.dax', mapId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead <> SizeOf(TGeoRecord)) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load geo in Load3DMap.');
    ch := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  offset := SizeOf(TGeoRecord) - SizeOf(Types.TGeoMap);
  Move(data^[offset], GDVars.geoMap^.wallsNE, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.geoMap^.wallsSW, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.geoMap^.events, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.geoMap^.barriers, SizeOf(Types.TGeoPlane));
  FreeMem(data, sizeRead);
  GDVars.zone0^.mapId := mapId;
end;

begin
end.
