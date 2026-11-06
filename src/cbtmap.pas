{ The ground-combat map. It rebuilds the arena's occupancy (GDVars' cellCombatant, gridX and gridY), draws the 7x7-cell
  view of the arena -- terrain, with clouds and corpses drawn over the terrain they cover, combatant icons and the
  cursor -- scrolls it, probes the cells a combatant would step into, and animates a creature going down. The two
  palette routines are empty. The corpse list and the cloud list it reads are GDVars' downedCreatures and areaEffects;
  drawing waits on GDVars.mapVisible. }
{$O+,F+}
unit CbtMap;

interface

uses Types, C_Terr, GDConsts, GDVars, Blit, MapTiles, Music, TextRend, Crt, C_Dir, C_Ifc, C_Combat;

{ Gives the direction from one combatant's arena cell to another's.
  @param(src The combatant looked from.)
  @param(dst The combatant looked at.)
  @returns(The direction 0..7.) }
function DirectionToward(src, dst: Types.PCharRecord): Byte;

{ Gives the direction, clockwise from north, from one point to another: the first of the eight whose sector holds the
  second. The tests multiply by 106 or 618 and divide by 256: 106/256 and 618/256 approximate tan 22.5 and tan 67.5
  degrees.
  @param(x1 The column looked from.)
  @param(y1 The row looked from.)
  @param(x2 The column looked at.)
  @param(y2 The row looked at.)
  @returns(The direction 0..7.) }
function DirectionBetween(x1, y1, x2, y2: Integer): Byte;

{ Gives the terrain at an arena cell, seen through a cloud (one of CLOUD_TERRAINS) or a corpse (CORPSE_TERRAIN) to the
  terrain saved beneath it.
  @param(x The arena column.)
  @param(y The arena row.)
  @returns(The terrain.) }
function ResolveTerrain(x, y: ShortInt): Byte;

{ Sets the terrain at an arena cell: beneath every cloud cell and corpse on it, or on the arena itself when there is
  neither.
  @param(x The arena column.)
  @param(y The arena row.)
  @param(terrain The terrain.) }
procedure SetTerrain(x, y: ShortInt; terrain: Byte);

{ Gives the offset of a cell of an icon of the given size.
  @param(size The icon's size.)
  @param(idx The icon's cell, 0..3.)
  @param(dx Receives the cell's column offset.)
  @param(dy Receives the cell's row offset.)
  @returns(False when size is 0 or the icon has no such cell.) }
function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;

{ Empty: the palette is left as it is for combat. }
procedure SetCombatPalette;

{ Empty: the palette is left as it is after combat. }
procedure SetNoncombatPalette;

{ Redraws an arena cell and the combatant on it.
  @param(x The arena column.)
  @param(y The arena row.) }
procedure RedrawArenaCell(x, y: ShortInt);

{ Rebuilds cellCombatant from each combatant's cell and icon size, and gridX and gridY. }
procedure BuildArenaArrays;

{ Gives the combatant slot and the terrain at an arena cell; 0 and 0 off the arena.
  @param(x The arena column.)
  @param(y The arena row.)
  @param(crIdx Receives the combatant's slot, or 0.)
  @param(terrIdx Receives the terrain.) }
procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);

{ Redraws the terrain under a combatant's icon, erasing it; with crIdx 0, under the icon on a view cell, or that cell
  alone when it holds none.
  @param(x The view column.)
  @param(y The view row.)
  @param(crIdx The combatant's slot, or 0.) }
procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);

{ Tells whether a view cell lies inside the 7x7 view.
  @param(x View column.)
  @param(y View row.)
  @returns(True when both coordinates lie inside the view.) }
function ViewCoordsValid(x, y: ShortInt): Boolean;

{ Tests whether a combatant's icon is in view.
  @param(cr The combatant.)
  @param(whole Non-zero: True only when every cell of the icon is in view; 0: True when any is.)
  @returns(True when the icon is in view as whole asks.) }
function CombatIconVisible(cr: Types.PCharRecord; whole: Byte): Boolean;

{ When the cell one dir step from (x, y) lies more than delta cells from the view's center on either axis, moves the
  center onto it along each axis where it is out of range, as far as the arena's edge allows, leaving an axis within
  delta unchanged (BuildViewBuffer), and redraws the combatants in view; then redraws (x, y) and draws the cursor on the
  stepped cell, kept on the arena.
  @param(x The arena column.)
  @param(y The arena row.)
  @param(delta 255 treats every axis the cell is off as out of range.)
  @param(dir A direction 0..7, or C_Dir.CENTER for no step.) }
procedure ScrollView(x, y: ShortInt; delta, dir: Byte);

{ Sets cr's facing to dir. While the map is visible it first scrolls the view to cr when its icon is not wholly in view,
  erases the icon when the facing turns between halves or frame or eraseOnly is non-zero, and redraws it in frame unless
  eraseOnly is non-zero.
  @param(cr The combatant.)
  @param(dir The new facing, 0..7.)
  @param(frame The icon frame drawn.)
  @param(eraseOnly Non-zero erases the icon without redrawing it.) }
procedure SetCreatureFacing(cr: Types.PCharRecord; dir, frame, eraseOnly: Byte);

{ Gives a combatant's arena column, from combatantCells[CombatSlot(cr)]. Note: for a creature not in creatures the slot
  is 0, below the table's range, and is read unchecked.
  @param(cr The combatant.)
  @returns(The column.) }
function CombatCellX(cr: Types.PCharRecord): ShortInt;

{ Gives a combatant's arena row, from combatantCells[CombatSlot(cr)]. Note: for a creature not in creatures the slot is
  0, below the table's range, and is read unchecked.
  @param(cr The combatant.)
  @returns(The row.) }
function CombatCellY(cr: Types.PCharRecord): ShortInt;

{ Gives a combatant's icon size, from combatantCells[CombatSlot(cr)]. Note: for a creature not in creatures the slot is
  0, below the table's range, and is read unchecked.
  @param(cr The combatant.)
  @returns(The icon size.) }
function GetIconSize(cr: Types.PCharRecord): Byte;

{ Finds a combatant's slot.
  @param(cr The combatant.)
  @returns(cr's slot in creatures, or 0.) }
function CombatSlot(cr: Types.PCharRecord): Byte;

{ Looks at the cells cr's icon would cover one dir step away.
  @param(cr The combatant.)
  @param(dir The direction, or C_Dir.CENTER for where it is.)
  @param(crIdx Another combatant's slot met there, or 0.)
  @param(terrIdx The costliest terrain met, 0 when a cell is off the arena or holds 0, or 23 (impassable) when cr has no
    icon cells.)
  @param(hasGas Set when a cell holds gas terrain.) }
procedure ProbeDirection(cr: Types.PCharRecord; dir: Byte; var crIdx, terrIdx, hasGas: Byte);

{ Outside ground combat, plays downedSound and pauses. In combat, plays the skull animation on cr's icon, leaves a
  corpse (corpse terrain, unless a cloud covers the cell) recording the terrain beneath unless cr is out of play, and
  takes cr off the map. Note: the check for a creature already down indexes the downed list by a counter that is not yet
  set, so it tests one arbitrary record.
  @param(cr The creature downed.) }
procedure CreatureDowned(cr: Types.PCharRecord);

{ In ground combat, puts cr's icon on an arena cell when it fits there: no other combatant, on the arena, passable. A
  move of a creature in play also clears its corpse records and, unless another corpse lies on (x, y), sets that cell to
  the terrain the last record saved (else the terrain probed there): right for a creature that rises where it fell.
  @param(cr The combatant.)
  @param(x The arena column.)
  @param(y The arena row.)
  @param(isMoving True for a move.)
  @returns(False, with cr off the map, when it does not fit; True outside combat.) }
function IsValidCreatureLoc(cr: Types.PCharRecord; x, y: Byte; isMoving: Boolean): Boolean;

{ While the map is visible, scrolls the view to cr (delta as ScrollView's), drawing a cursor of cr's icon size when
  isCursorShown is True.
  @param(cr The combatant centered on.)
  @param(delta As ScrollView's.)
  @param(isCursorShown True draws the cursor.) }
procedure DisplayMapViewCentered(cr: Types.PCharRecord; delta: Byte; isCursorShown: Boolean);

implementation

const
  { the iconFrames row CreatureDowned flashes over a downed creature }
  SKULL_ROW = 31;
  { the markers a lingering cloud lays: ResolveTerrain sees through a cell holding one to its cloud's underlyingTerrain,
    and CreatureDowned lays no corpse over one }
  CLOUD_TERRAINS = [C_Terr.CHAFF_TERRAIN, C_Terr.GAS_TERRAIN, C_Terr.AEROSOL_MIST_TERRAIN];

function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;
begin
  GetIconTileDelta := False;
  if size = 0 then Exit;
  dx := GDConsts.iconDelta[size, idx].dx;
  dy := GDConsts.iconDelta[size, idx].dy;
  if dx >= 0 then
    GetIconTileDelta := True;
end;

{ Recomputes every combatant's view position, gridX and gridY. }
procedure CalcGridDeltas;
var
  i: Byte;
begin
  for i := 1 to GDVars.combatantCount do begin
    GDVars.gridX[i] := GDVars.combatantCells[i].x - GDVars.combatArena^.viewOriginX;
    GDVars.gridY[i] := GDVars.combatantCells[i].y - GDVars.combatArena^.viewOriginY;
  end;
end;

procedure SetCombatPalette;
begin
end;

procedure SetNoncombatPalette;
begin
end;

{ Draws an arena cell into a view cell. A cloud or corpse cell (terrains 1..5) is drawn as the terrain beneath with its
  marker's icon frame over it; terrain 0 or past LAST_COMBAT_TERRAIN draws as terrain 21.
  @param(vcol The view column.)
  @param(vrow The view row.)
  @param(acol The arena column.)
  @param(arow The arena row.) }
procedure DrawTerrainCell(vcol, vrow, acol, arow: ShortInt);
var
  t: Byte;
  baseId: Byte;
  drawId: Byte;
  i: Byte;
  p: Types.PAreaEffect;
begin
  vcol := vcol * 3;
  vrow := vrow * 3;
  t := GDVars.combatArena^.cells[arow, acol];
  if (t > C_Terr.LAST_COMBAT_TERRAIN) or (t = 0) then t := 21;
  baseId := GDConsts.terrainInfo[t].tileId;
  if t <= C_Terr.CORPSE_TERRAIN then begin
    t := CbtMap.ResolveTerrain(acol, arow);
    drawId := GDConsts.terrainInfo[t].tileId;
    case t of
      { no cloud lays 3 }
      C_Terr.CHAFF_TERRAIN, C_Terr.GAS_TERRAIN, 3, C_Terr.AEROSOL_MIST_TERRAIN:
        begin
          p := GDVars.areaEffects;
          while p <> nil do begin
            for i := 1 to SizeOf(p^.active) do
              if (p^.active[i] <> 0) and (p^.x + GDConsts.dirStepX[GDConsts.cloudDir[i]] = acol) and
                  (p^.y + GDConsts.dirStepY[GDConsts.cloudDir[i]] = arow) then
                t := p^.underlyingTerrain[i];
            p := p^.next
          end
        end;
      C_Terr.CORPSE_TERRAIN:
        for i := 1 to GDVars.downedCount do
          if (GDVars.downedCreatures[i].x = acol) and (GDVars.downedCreatures[i].y = arow) then
            t := GDVars.downedCreatures[i].terrain
    end;
    if (t > C_Terr.LAST_COMBAT_TERRAIN) or (t = 0) then t := 21;
    drawId := GDConsts.terrainInfo[t].tileId;
    Blit.BlitTileCell(vcol, vrow, drawId, 0, GDVars.arenaTiles, GDVars.viewPicture);
    Blit.BlitTileCell(vcol, vrow, 0, 1, GDVars.iconFrames[(baseId shr 1) + 33, baseId and 1], GDVars.viewPicture)
  end else
    Blit.BlitTileCell(vcol, vrow, baseId, 0, GDVars.arenaTiles, GDVars.viewPicture)
end;

{ Redraws the cursor's cells at an arena cell that are in view, draws the cursor sprite over them while the cursor is
  shown, and redraws the combatant there.
  @param(x The arena column.)
  @param(y The arena row.) }
procedure DrawCursorCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
  c: Byte;
  t: Byte;
begin
  relX := x - GDVars.combatArena^.viewOriginX;
  relY := y - GDVars.combatArena^.viewOriginY;
  for i := 0 to SizeOf(GDConsts.iconDelta[1]) div SizeOf(Types.TIconCoordinateDelta) - 1 do
    if CbtMap.GetIconTileDelta(GDVars.combatArena^.cursorSize, i, tdx, tdy) then
      if CbtMap.ViewCoordsValid(relX + tdx, relY + tdy) then begin
        CbtMap.DrawTerrainCell(relX + tdx, relY + tdy, x + tdx, y + tdy);
        if GDVars.combatArena^.cursorShown then
          MapTiles.DrawIconAnimSprite(relX + tdx, relY + tdy, 0, 0, 32);
      end;
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.creatures[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.gridX[c], GDVars.gridY[c], GDVars.creatures[c]^.combatAddr^.direction, 0,
                                  GDVars.creatures[c]^.orderNumber);
end;

procedure RedrawArenaCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  c: Byte;
  t: Byte;
begin
  relX := x - GDVars.combatArena^.viewOriginX;
  relY := y - GDVars.combatArena^.viewOriginY;
  CbtMap.UpdateCombatMapTile(relX, relY, 0);
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.creatures[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.gridX[c], GDVars.gridY[c], GDVars.creatures[c]^.combatAddr^.direction, 0,
                                  GDVars.creatures[c]^.orderNumber);
end;

procedure BuildArenaArrays;
var
  i: Byte;
  j: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  FillChar(GDVars.cellCombatant, SizeOf(GDVars.cellCombatant), 0);
  for i := 1 to GDVars.combatantCount do
    if GDVars.combatantCells[i].size > 0 then begin
      for j := 0 to SizeOf(GDConsts.iconDelta[1]) div SizeOf(Types.TIconCoordinateDelta) - 1 do
        if CbtMap.GetIconTileDelta(GDVars.combatantCells[i].size, j, tdx, tdy) then
          GDVars.cellCombatant[GDVars.combatantCells[i].y + tdy, GDVars.combatantCells[i].x + tdx] := i;
      GDVars.gridX[i] := GDVars.combatantCells[i].x - GDVars.combatArena^.viewOriginX;
      GDVars.gridY[i] := GDVars.combatantCells[i].y - GDVars.combatArena^.viewOriginY;
    end;
end;

procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);
begin
  if (x >= 0) and (x <= SizeOf(GDVars.combatArena^.cells[0]) - 1) and (y >= 0) and
      (y <= SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) then begin
    terrIdx := GDVars.combatArena^.cells[y, x];
    crIdx := GDVars.cellCombatant[y, x];
  end else begin
    crIdx := 0;
    terrIdx := 0;
  end;
end;

procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);
var
  absX: ShortInt;
  absY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
  t: Byte;
  size: Byte;
begin
  if crIdx = 0 then begin
    absX := x + GDVars.combatArena^.viewOriginX;
    absY := y + GDVars.combatArena^.viewOriginY;
    CbtMap.GetArenaContents(absX, absY, crIdx, t);
  end;
  if crIdx > 0 then begin
    x := GDVars.gridX[crIdx];
    y := GDVars.gridY[crIdx];
    absX := x + GDVars.combatArena^.viewOriginX;
    absY := y + GDVars.combatArena^.viewOriginY;
    size := GDVars.combatantCells[crIdx].size;
    for i := 0 to SizeOf(GDConsts.iconDelta[1]) div SizeOf(Types.TIconCoordinateDelta) - 1 do
      if CbtMap.GetIconTileDelta(size, i, tdx, tdy) then
        if CbtMap.ViewCoordsValid(x + tdx, y + tdy) then
          CbtMap.DrawTerrainCell(x + tdx, y + tdy, absX + tdx, absY + tdy)
  end else if CbtMap.ViewCoordsValid(x, y) then
    CbtMap.DrawTerrainCell(x, y, absX, absY);
end;

function ViewCoordsValid(x, y: ShortInt): Boolean;
begin
  if (x < 0) or (x > 6) or (y < 0) or (y > 6) then
    ViewCoordsValid := False
  else
    ViewCoordsValid := True;
end;

function CombatIconVisible(cr: Types.PCharRecord; whole: Byte): Boolean;
var
  i: Byte;
  slot: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  visibleTiles: Integer;
begin
  CombatIconVisible := True;
  slot := CbtMap.CombatSlot(cr);
  if GDVars.combatantCells[slot].size = 0 then
    CombatIconVisible := False
  else
    for i := 0 to SizeOf(GDConsts.iconDelta[1]) div SizeOf(Types.TIconCoordinateDelta) - 1 do
      if CbtMap.GetIconTileDelta(GDVars.combatantCells[slot].size, i, tdx, tdy) then
        if not CbtMap.ViewCoordsValid(GDVars.gridX[slot] + tdx, GDVars.gridY[slot] + tdy) then begin
          CombatIconVisible := False;
          if whole <> 0 then Exit;
        end else begin
          CombatIconVisible := True;
          if whole = 0 then Exit;
        end;
end;

{ When (x, y) lies more than delta cells from the view's center on either axis (always, for delta 255), moves the center
  onto it along each axis where it is out of range, stopping at the arena's edge (center columns 3..last column - 3,
  rows 3..last row - 3), and redraws the view's terrain. Callers pass delta 0..3 or 255.
  @param(x The arena column.)
  @param(y The arena row.)
  @param(delta The distance from the center allowed before the view moves.)
  @returns(False, drawing nothing, when (x, y) lies within delta of the center on both axes, else True after the redraw;
    always True for delta 255. Note: from delta 79 up the ShortInt bounds center - delta and center + delta can wrap, so
    a large delta can redraw and return True even at the center.) }
function BuildViewBuffer(x, y: ShortInt; delta: Byte): Boolean;
var
  d: Byte;
  { Unused in this version; see the other implementations of this routine. }
  pixX: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  pixY: ShortInt;
  i: Byte;
  j: Byte;
  cX: ShortInt;
  cY: ShortInt;
  minX: ShortInt;
  maxX: ShortInt;
  minY: ShortInt;
  maxY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bufferIndex: Integer;
begin
  BuildViewBuffer := False;
  cX := GDVars.combatArena^.viewOriginX + 3;
  cY := GDVars.combatArena^.viewOriginY + 3;
  d := delta;
  if delta = 255 then
    d := 0;
  minX := cX - d;
  maxX := cX + d;
  minY := cY - d;
  maxY := cY + d;
  if (delta <> 255) and (x >= minX) and (x <= maxX)
     and (y >= minY) and (y <= maxY) then Exit;
  if x < minX then
    while (x < cX) and (cX > 3) do Dec(cX)
  else if x > maxX then
    while (x > cX) and (cX < SizeOf(GDVars.combatArena^.cells[0]) - 1 - 3) do Inc(cX);
  if y < minY then
    while (y < cY) and (cY > 3) do Dec(cY)
  else if y > maxY then
    while (y > cY) and (cY < SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1 - 3) do
      Inc(cY);
  GDVars.combatArena^.viewOriginX := cX - 3;
  GDVars.combatArena^.viewOriginY := cY - 3;
  cY := GDVars.combatArena^.viewOriginY;
  for j := 0 to 6 do begin
    cX := GDVars.combatArena^.viewOriginX;
    for i := 0 to 6 do begin
      CbtMap.DrawTerrainCell(i, j, cX, cY);
      Inc(cX);
    end;
    Inc(cY);
  end;
  CbtMap.CalcGridDeltas;
  BuildViewBuffer := True;
end;

procedure ScrollView(x, y: ShortInt; delta, dir: Byte);
var
  p: Types.PCharRecord;
  i: Byte;
  tx: ShortInt;
  ty: ShortInt;
begin
  tx := x + GDConsts.dirStepX[dir];
  ty := y + GDConsts.dirStepY[dir];
  if CbtMap.BuildViewBuffer(tx, ty, delta) then
    for i := 1 to GDVars.combatantCount do begin
      p := GDVars.creatures[i];
      if (p^.enabled <> 0) and (GDVars.combatantCells[i].size > 0) then
        if CbtMap.CombatIconVisible(p, 0) then
          MapTiles.DrawIconAnimSprite(GDVars.gridX[i], GDVars.gridY[i], p^.combatAddr^.direction, 0,
                                      p^.orderNumber);
    end;
  CbtMap.RedrawArenaCell(x, y);
  if not CbtMap.ViewCoordsValid(tx - GDVars.combatArena^.viewOriginX,
                                ty - GDVars.combatArena^.viewOriginY) then begin
    if tx > SizeOf(GDVars.combatArena^.cells[0]) - 1 then tx := SizeOf(GDVars.combatArena^.cells[0]) - 1;
    if tx < 0 then tx := 0;
    if ty > SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1 then
      ty := SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1;
    if ty < 0 then ty := 0;
  end;
  CbtMap.DrawCursorCell(tx, ty);
  Blit.FlushView;
end;

procedure SetCreatureFacing(cr: Types.PCharRecord; dir, frame, eraseOnly: Byte);
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(cr);
  if not CbtMap.CombatIconVisible(cr, 1) then
    if GDVars.mapVisible <> 0 then
      CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 3, C_Dir.CENTER);
  if (cr^.combatAddr^.direction div 4 <> dir div 4)
     or (frame <> 0) or (eraseOnly <> 0) then
    if GDVars.mapVisible <> 0 then
      CbtMap.UpdateCombatMapTile(0, 0, slot);
  cr^.combatAddr^.direction := dir;
  if eraseOnly = 0 then
    if CbtMap.CombatIconVisible(cr, 0) then
      if GDVars.mapVisible <> 0 then begin
        MapTiles.DrawIconAnimSprite(GDVars.gridX[slot], GDVars.gridY[slot], dir, frame, cr^.orderNumber);
        Blit.FlushView;
      end;
end;

function CombatCellX(cr: Types.PCharRecord): ShortInt;
begin
  CombatCellX := GDVars.combatantCells[CbtMap.CombatSlot(cr)].x;
end;

function CombatCellY(cr: Types.PCharRecord): ShortInt;
begin
  CombatCellY := GDVars.combatantCells[CbtMap.CombatSlot(cr)].y;
end;

function GetIconSize(cr: Types.PCharRecord): Byte;
begin
  GetIconSize := GDVars.combatantCells[CbtMap.CombatSlot(cr)].size;
end;

function CombatSlot(cr: Types.PCharRecord): Byte;
var
  isFound: Boolean;
  i: Byte;
begin
  isFound := False;
  CombatSlot := 0;
  i := 0;
  repeat
    Inc(i);
    if GDVars.creatures[i] = cr then
      isFound := True;
  until isFound or (i = GDVars.combatantCount);
  if isFound then
    CombatSlot := i;
end;

procedure ProbeDirection(cr: Types.PCharRecord; dir: Byte; var crIdx, terrIdx, hasGas: Byte);
var
  i: Byte;
  slot: Byte;
  c: Byte;
  t: Byte;
  best: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  crIdx := 0;
  terrIdx := 23;
  best := 1;
  hasGas := 0;
  slot := CbtMap.CombatSlot(cr);
  x := GDVars.combatantCells[slot].x;
  y := GDVars.combatantCells[slot].y;
  for i := 0 to SizeOf(GDConsts.iconDelta[1]) div SizeOf(Types.TIconCoordinateDelta) - 1 do
    if CbtMap.GetIconTileDelta(GDVars.combatantCells[slot].size, i, tdx, tdy) then begin
      nx := x + tdx + GDConsts.dirStepX[dir];
      ny := y + tdy + GDConsts.dirStepY[dir];
      CbtMap.GetArenaContents(nx, ny, c, t);
      if c = slot then
        c := 0;
      if c > 0 then
        crIdx := c;
      if t = C_Terr.GAS_TERRAIN then
        hasGas := 1;
      if (t = 0) or (terrIdx = 0) then
        terrIdx := 0
      else if GDConsts.terrainInfo[t].cost >= best then begin
        best := GDConsts.terrainInfo[t].cost;
        terrIdx := t;
      end;
    end;
end;

procedure CreatureDowned(cr: Types.PCharRecord);
var
  slot: Byte;
  k: Byte;
  frame: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  tileIndex: Integer;
begin
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then begin
    Music.SendSoundCommand(GDConsts.downedSound);
    TextRend.PauseOnly;
  end else begin
    k := 1;
    { Note: frame is not yet set here }
    while (k < 9) and (GDVars.downedCreatures[frame].character <> cr) do
      Inc(k);
    if k < 9 then Exit;
    slot := CbtMap.CombatSlot(cr);
    cellX := CbtMap.CombatCellX(cr);
    cellY := CbtMap.CombatCellY(cr);
    if not CbtMap.CombatIconVisible(cr, 1) then
      CbtMap.ScrollView(cellX, cellY, 3, C_Dir.CENTER);
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    Music.SendSoundCommand(GDConsts.downedSound);
    for frame := 0 to 8 do begin
      for k := 0 to SizeOf(GDConsts.iconDelta[1]) div SizeOf(Types.TIconCoordinateDelta) - 1 do
        if CbtMap.GetIconTileDelta(GDVars.combatantCells[slot].size, k, tdx, tdy) then
          if CbtMap.ViewCoordsValid(GDVars.gridX[slot] + tdx, GDVars.gridY[slot] + tdy) then
            Blit.BlitTileClipped((GDVars.gridX[slot] + tdx) * 3, (GDVars.gridY[slot] + tdy) * 3, 0, 5,
                                 GDVars.iconFrames[CbtMap.SKULL_ROW, frame mod 2], GDVars.viewPicture);
      Blit.FlushView;
      Delay(10);
    end;
    if cr^.combatAddr^.notPcNpc = 0 then begin
      frame := CbtMap.ResolveTerrain(cellX, cellY);
      Inc(GDVars.downedCount);
      GDVars.downedCreatures[GDVars.downedCount].terrain := frame;
      if not (GDVars.combatArena^.cells[cellY, cellX] in CbtMap.CLOUD_TERRAINS) then
        GDVars.combatArena^.cells[cellY, cellX] := C_Terr.CORPSE_TERRAIN;
      GDVars.downedCreatures[GDVars.downedCount].character := cr;
      GDVars.downedCreatures[GDVars.downedCount].x := cellX;
      GDVars.downedCreatures[GDVars.downedCount].y := cellY;
    end;
    TextRend.PauseOnly;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    GDVars.combatantCells[CbtMap.CombatSlot(cr)].size := 0;
    CbtMap.BuildArenaArrays;
    CbtMap.ScrollView(GDVars.combatArena^.viewOriginX + 3, GDVars.combatArena^.viewOriginY + 3, 3,
                      C_Dir.CENTER);
    cr^.combatAddr^.initiative := 0;
    cr^.combatAddr^.movement := 0;
    cr^.combatAddr^.guarding := 0;
  end;
end;

function IsValidCreatureLoc(cr: Types.PCharRecord; x, y: Byte; isMoving: Boolean): Boolean;
var
  slot: Byte;
  i: Byte;
  c: Byte;
  t: Byte;
  isFound: Boolean;
  { ProbeDirection's, not read here }
  hasGas: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    IsValidCreatureLoc := False;
    slot := CbtMap.CombatSlot(cr);
    GDVars.combatantCells[slot].size := cr^.iconDimensions and C_Combat.ICON_SIZE_MASK;
    GDVars.combatantCells[slot].x := x;
    GDVars.combatantCells[slot].y := y;
    CbtMap.ProbeDirection(cr, C_Dir.CENTER, c, t, hasGas);
    if (c <> 0) or (t = 0) or (GDConsts.terrainInfo[t].cost = C_Terr.IMPASSABLE) then
      GDVars.combatantCells[slot].size := 0
    else begin
      IsValidCreatureLoc := True;
      if isMoving then
        if cr^.combatAddr^.notPcNpc = 0 then begin
          for i := 1 to GDVars.downedCount do
            if GDVars.downedCreatures[i].character = cr then begin
              if GDVars.downedCreatures[i].terrain <> C_Terr.CORPSE_TERRAIN then
                t := GDVars.downedCreatures[i].terrain;
              FillChar(GDVars.downedCreatures[i], SizeOf(GDVars.downedCreatures[i]), 0);
            end;
          isFound := False;
          for i := 1 to GDVars.downedCount do
            if (GDVars.downedCreatures[i].character <> nil) and (GDVars.downedCreatures[i].x = x)
               and (GDVars.downedCreatures[i].y = y) then
              isFound := True;
          if not isFound then
            GDVars.combatArena^.cells[y, x] := t;
        end;
      CbtMap.BuildArenaArrays;
    end;
  end else
    IsValidCreatureLoc := True;
end;

procedure DisplayMapViewCentered(cr: Types.PCharRecord; delta: Byte; isCursorShown: Boolean);
begin
  GDVars.combatArena^.cursorShown := isCursorShown;
  GDVars.combatArena^.cursorSize := GDVars.combatantCells[CbtMap.CombatSlot(cr)].size;
  if GDVars.mapVisible <> 0 then
    CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), delta, C_Dir.CENTER);
  GDVars.combatArena^.cursorShown := False;
  GDVars.combatArena^.cursorSize := 1;
end;

function ResolveTerrain(x, y: ShortInt): Byte;
var
  t: Byte;
  i: Byte;
  p: Types.PAreaEffect;
begin
  t := GDVars.combatArena^.cells[y, x];
  if t in CbtMap.CLOUD_TERRAINS then begin
    p := GDVars.areaEffects;
    while p <> nil do begin
      for i := 1 to SizeOf(p^.active) do
        if (p^.active[i] <> 0) and (p^.x + GDConsts.dirStepX[GDConsts.cloudDir[i]] = x) and
            (p^.y + GDConsts.dirStepY[GDConsts.cloudDir[i]] = y) then
          t := p^.underlyingTerrain[i];
      p := p^.next
    end
  end else if t = C_Terr.CORPSE_TERRAIN then
    for i := 1 to GDVars.downedCount do
      if (GDVars.downedCreatures[i].x = x) and (GDVars.downedCreatures[i].y = y) then
        t := GDVars.downedCreatures[i].terrain;
  ResolveTerrain := t
end;

procedure SetTerrain(x, y: ShortInt; terrain: Byte);
var
  i: Byte;
  p: Types.PAreaEffect;
  isFound: Boolean;
begin
  isFound := False;
  p := GDVars.areaEffects;
  while p <> nil do begin
    for i := 1 to SizeOf(p^.active) do
      if (p^.active[i] <> 0) and (p^.x + GDConsts.dirStepX[GDConsts.cloudDir[i]] = x) and
          (p^.y + GDConsts.dirStepY[GDConsts.cloudDir[i]] = y) then begin
        p^.underlyingTerrain[i] := terrain;
        isFound := True
      end;
    p := p^.next
  end;
  for i := 1 to GDVars.downedCount do
    if (GDVars.downedCreatures[i].x = x) and (GDVars.downedCreatures[i].y = y) then begin
      GDVars.downedCreatures[i].terrain := terrain;
      isFound := True
    end;
  if not isFound then
    GDVars.combatArena^.cells[y, x] := terrain
end;

function DirectionBetween(x1, y1, x2, y2: Integer): Byte;
var
  d: Byte;
  isFound: Boolean;
  adx: Integer;
  ady: Integer;
begin
  adx := Abs(x2 - x1);
  ady := Abs(y2 - y1);
  d := 0;
  isFound := False;
  while not isFound do begin
    case d of
      C_Dir.NORTHEAST: isFound := (y2 < y1) and (x2 > x1) and ((618 * adx) div 256 >= ady) and
        ((106 * adx) div 256 <= ady);
      C_Dir.SOUTHEAST: isFound := (y2 > y1) and (x2 > x1) and ((618 * adx) div 256 >= ady) and
        ((106 * adx) div 256 <= ady);
      C_Dir.SOUTHWEST: isFound := (y2 > y1) and (x2 < x1) and ((618 * adx) div 256 >= ady) and
        ((106 * adx) div 256 <= ady);
      C_Dir.NORTHWEST: isFound := (y2 < y1) and (x2 < x1) and ((618 * adx) div 256 >= ady) and
        ((106 * adx) div 256 <= ady);
      C_Dir.NORTH: isFound := (y2 <= y1) and ((618 * adx) div 256 <= ady);
      C_Dir.EAST: isFound := (x2 >= x1) and ((106 * adx) div 256 >= ady);
      C_Dir.SOUTH: isFound := (y2 >= y1) and ((618 * adx) div 256 <= ady);
      C_Dir.WEST: isFound := (x2 <= x1) and ((106 * adx) div 256 >= ady)
    end;
    if not isFound then Inc(d)
  end;
  DirectionBetween := d
end;

function DirectionToward(src, dst: Types.PCharRecord): Byte;
begin
  DirectionToward := CbtMap.DirectionBetween(CbtMap.CombatCellX(src), CbtMap.CombatCellY(src), CbtMap.CombatCellX(dst),
                                             CbtMap.CombatCellY(dst))
end;

begin
end.
