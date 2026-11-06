{ Setting up a ground combat. CombatStart frees the non-combat pictures, lays the arena -- a dungeon arena built map
  square by map square around the party from its walls, or a wilderness arena scattered from terrainProfiles -- places
  each combatant on its team's placement grids, and hands the map to the combat display. The placement state (quadFree
  and each team's origin, first-pass length and facing quarter) and the wall kinds of the map square being laid are
  GDVars', and the tables it places, tiles and scatters by GDConsts'. }
{$O+,F+,I-}
unit CombatSt;

interface

{ Sets up a ground combat and shows the combat interface centered on the first enabled party-side combatant. }
procedure CombatStart;

implementation

uses Types, C_Combat, C_Npc, C_Pic, C_Terr, GDConsts, GDVars, MapTiles, Debug,
  Portrait, Blit, View3D, CharHlp, CbtMap, CbtActs, TextRend, GameIo, CharGen, OrbitMap, Crt, C_Dir, C_Ifc, C_Area,
  C_Side, C_Screen;

const
  { the iconDimensions bits that hold the icon's size }
  ICON_SIZE_LOW_BITS = $07;

{ Saves RandSeed for RestoreRandom and seeds the generator.
  @param(seed The new seed.) }
procedure ReseedRandom(seed: LongInt);
begin
  GDVars.savedSeed := RandSeed;
  RandSeed := seed;
end;

{ Puts back the RandSeed ReseedRandom saved. }
procedure RestoreRandom;
begin
  RandSeed := GDVars.savedSeed;
end;

{ Plots a terrain value plus 1 at a spot of the current map cell's skewed block, inside the arena.
  @param(px Column within the block.)
  @param(py Row within the block.)
  @param(pv Terrain id less 1.) }
procedure PlotCell(px, py, pv: Byte);
var
  col: ShortInt;
  row: ShortInt;
begin
  col := GDVars.arenaOX * 6 + GDVars.arenaOY * 5 + 21 + px;
  row := (GDVars.arenaOY * 5 + 10) + py;
  if (col >= 0) and (col <= SizeOf(GDVars.combatArena^.cells[0]) - 1) and (row >= 0) and
      (row <= SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) then
    GDVars.combatArena^.cells[row][col] := pv + 1;
end;

{ Scatters tiles at random along the north and east walls (wall kind 1) of the map square being laid, onto its floor
  cells (terrain 7 or 45).
  @param(mode The area's kind flags; bit $08 picks the second tile set.) }
procedure ScatterWallTiles(mode: Byte);
var
  i: Byte;
  j: Byte;

  { PlotCell, onto a floor cell (terrain 7 or 45) only. }
  procedure PlaceTileOn(px, py, pv: Byte);
  var
    col: Integer;
    row: Integer;
  begin
    col := GDVars.arenaOX * 6 + GDVars.arenaOY * 5 + 21 + px;
    row := (GDVars.arenaOY * 5 + 10) + py;
    { Note: the first upper-bound test checks row against the arena's last column where col was meant, so col is never
      bounded above. }
    if (col >= 0) and (row <= SizeOf(GDVars.combatArena^.cells[0]) - 1) and (row >= 0) and
        (row <= SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) then
      if GDVars.combatArena^.cells[row][col] in [7, 45] then
        CombatSt.PlotCell(px, py, pv);
  end;
begin
  if (mode and 8) = 0 then begin
    if GDVars.wallNorth = 1 then
      for i := 4 to 6 do
        if Random(10) < 3 then
          PlaceTileOn(i, 2, Random(2) + 51);
    if GDVars.wallEast = 1 then
      if GDVars.squareVariant <> 0 then begin
        for j := 2 to 4 do begin
          if Random(10) < 5 then
            case Random(3) of
              0: if Random(10) < 8 then begin
                   PlaceTileOn(j + 4, j, 46);
                   if Random(10) < 5 then PlaceTileOn(j + 3, j, 47);
                 end;
              1: if Random(10) < 8 then begin
                   PlaceTileOn(j + 4, j, 49);
                   if Random(10) < 5 then PlaceTileOn(j + 3, j, 47);
                 end;
              2: if Random(10) < 8 then begin
                   PlaceTileOn(j + 4, j, 50);
                   if Random(10) < 5 then PlaceTileOn(j + 3, j, 47);
                 end;
            end else
            case Random(6) of
              0: if Random(10) < 8 then PlaceTileOn(j + 4, j, 45);
              1: if Random(10) < 8 then PlaceTileOn(j + 4, j, 46);
              2: if Random(10) < 8 then PlaceTileOn(j + 4, j, 48);
              3: if Random(10) < 8 then PlaceTileOn(j + 4, j, 49);
              4: if Random(10) < 8 then PlaceTileOn(j + 4, j, 53);
              5: if Random(10) < 8 then PlaceTileOn(j + 4, j, 54);
            end;
        end;
      end else
        for j := 2 to 4 do
          if Random(10) < 8 then
            case Random(2) of
              0: PlaceTileOn(j + 4, j, 45);
              1: PlaceTileOn(j + 4, j, 54);
            end;
  end else begin
    if GDVars.wallNorth = 1 then
      if GDVars.squareVariant <> 0 then begin
        for i := 4 to 6 do
          if Random(10) < 8 then
            case Random(6) of
              0: PlaceTileOn(i, 2, 59);
              1: PlaceTileOn(i, 2, 60);
              2: PlaceTileOn(i, 2, 62);
              3: PlaceTileOn(i, 2, 63);
              4: PlaceTileOn(i, 2, 66);
              5: PlaceTileOn(i, 2, 68);
            end;
      end else
        for i := 4 to 6 do
          if Random(10) < 8 then
            case Random(3) of
              0: PlaceTileOn(i, 2, 62);
              1: PlaceTileOn(i, 2, 66);
              2: PlaceTileOn(i, 2, 67);
            end;
    if GDVars.wallEast = 1 then
      if GDVars.squareVariant <> 0 then begin
        for j := 2 to 4 do
          if Random(10) < 8 then
            case Random(6) of
              0: PlaceTileOn(j + 4, j, 61);
              1: PlaceTileOn(j + 4, j, 62);
              2: PlaceTileOn(j + 4, j, 65);
              3: PlaceTileOn(j + 4, j, 66);
              4: PlaceTileOn(j + 4, j, 67);
              5: begin
                   PlaceTileOn(j + 4, j, 63);
                   if Random(10) < 5 then PlaceTileOn(j + 3, j, 64);
                 end;
            end;
      end else
        { Note: lays along the north row (i, 2); the other east-wall branches use (j + 4, j) }
        for i := 4 to 6 do
          if Random(10) < 8 then
            case Random(3) of
              0: PlaceTileOn(i, 2, 62);
              1: PlaceTileOn(i, 2, 66);
              2: PlaceTileOn(i, 2, 67);
            end;
  end;
end;

{ Gives the wall kind between a map square and its neighbor: each side's GetWallKind, or-ed. Off the 16x16 map a side
  counts as 1, except east and west along the party's row.
  @param(x The map square's column.)
  @param(y The map square's row.)
  @param(dir The direction of the neighbor.)
  @returns(0 with no wall, 1 or 3 by the walls' barrier types.) }
function WallBetween(x, y: ShortInt; dir: Byte): Byte;
var
  nearSide: Byte;
  farSide: Byte;
  opposite: Byte;

  { The wall kind on a square's facing side: 0 with no wall, 1 for barrier type 0, 3 for any other barrier type. }
  function GetWallKind(cellX, cellY: ShortInt; facing: Byte): Byte;
  begin
    if (cellX >= 0) and (cellX <= SizeOf(GDVars.geoMap^.wallsNE[0]) - 1) and (cellY >= 0) and
        (cellY <= SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1) then begin
      if View3D.GetBarrierType(cellX, cellY, facing) = 0 then
        GetWallKind := 1
      else if View3D.GetWallType(cellX, cellY, facing) = 0 then
        GetWallKind := 0
      else
        GetWallKind := 3;
    end else begin
      if (cellY = GDVars.partyPosition.mapY) and ((facing = C_Dir.EAST) or (facing = C_Dir.WEST)) then
        GetWallKind := 0
      else
        GetWallKind := 1;
    end;
  end;

begin
  opposite := (dir + 4) mod 8;
  nearSide := GetWallKind(x, y, dir);
  farSide := GetWallKind(x + GDConsts.dirStepX[dir], y + GDConsts.dirStepY[dir], opposite);
  WallBetween := nearSide or farSide;
end;

{ Fills the arena with floor (terrain 7 for area kinds $88 and $82, else 45), scatters random tile groups when mode has
  bit $40, and lays each map square within 6 columns and 2 rows of the party from its walls. The generator is seeded
  with the ECL script's id, so one script draws the same sequence.
  @param(mode The area's kind.) }
procedure BuildDungeonArena(mode: Byte);
var
  mapX: ShortInt;
  mapY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  cornerIndex: Integer;

  { Lays the square's west-wall tiles: a diagonal run of three rows for kind 1, a group of seven tiles for kind 3. }
  procedure PlaceWestWall;
  var
    i: Byte;
  begin
    case GDVars.wallWest of
      1: for i := 2 to 4 do begin
           CombatSt.PlotCell(i - 1, i, 27);
           CombatSt.PlotCell(i, i, 28);
           CombatSt.PlotCell(i + 1, i, 26);
         end;
      3: begin
           CombatSt.PlotCell(1, 2, 27);
           CombatSt.PlotCell(2, 2, 29);
           CombatSt.PlotCell(3, 2, 34);
           CombatSt.PlotCell(2, 3, 37);
           CombatSt.PlotCell(3, 3, 38);
           CombatSt.PlotCell(4, 4, 35);
           CombatSt.PlotCell(5, 4, 36);
         end;
    end;
  end;

  { Lays a two-by-two block of north-wall tiles for kind 1. }
  procedure PlaceNorthWall;
  begin
    case GDVars.wallNorth of
      1: begin
           CombatSt.PlotCell(3, 0, 24);
           CombatSt.PlotCell(4, 0, 24);
           CombatSt.PlotCell(3, 1, 25);
           CombatSt.PlotCell(4, 1, 25);
         end;
    end;
  end;

  { Lays the square's corner tiles by the walls that meet at each corner, then a kind-3 north wall's tiles. }
  procedure PlaceCornerTiles;
  var
    j: Byte;
    i: Byte;
    state: Byte;
  begin
    state := 0;
    if GDVars.wallNorth <> 0 then Inc(state);
    if GDVars.wallWest <> 0 then Inc(state, 2);
    if CombatSt.WallBetween(mapX - 1, mapY, C_Dir.NORTH) <> 0 then Inc(state, 4);
    if CombatSt.WallBetween(mapX, mapY - 1, C_Dir.WEST) <> 0 then Inc(state, 8);
    if state > 0 then
      for i := 0 to SizeOf(GDConsts.leftWallTiles[1]) div SizeOf(GDConsts.leftWallTiles[1, 0]) - 1 do
        for j := 1 to SizeOf(GDConsts.leftWallTiles[1, 0]) do
          if GDConsts.leftWallTiles[state, i, j] < 255 then
            CombatSt.PlotCell(j, i, GDConsts.leftWallTiles[state, i, j]);

    state := 0;
    if CombatSt.WallBetween(mapX + 1, mapY, C_Dir.NORTH) <> 0 then Inc(state);
    if GDVars.wallEast <> 0 then Inc(state, 2);
    if GDVars.wallNorth <> 0 then Inc(state, 4);
    if CombatSt.WallBetween(mapX, mapY - 1, C_Dir.EAST) <> 0 then Inc(state, 8);
    if state > 0 then
      for i := 0 to SizeOf(GDConsts.rightWallTiles[1]) div SizeOf(GDConsts.rightWallTiles[1, 0]) - 1 do
        for j := 5 to 5 + SizeOf(GDConsts.rightWallTiles[1, 0]) - 1 do
          if GDConsts.rightWallTiles[state, i, j] < 255 then
            CombatSt.PlotCell(j, i, GDConsts.rightWallTiles[state, i, j]);

    if GDVars.wallNorth = 3 then begin
      CombatSt.PlotCell(2, 0, 30);
      if GDVars.wallWest = 0 then CombatSt.PlotCell(2, 1, 32)
                      else CombatSt.PlotCell(2, 1, 42);
      if CombatSt.WallBetween(mapX, mapY - 1, C_Dir.EAST) = 0 then CombatSt.PlotCell(5, 0, 31)
                                                         else CombatSt.PlotCell(5, 0, 43);
      CombatSt.PlotCell(5, 1, 33);
    end;
    if CombatSt.WallBetween(mapX, mapY - 1, C_Dir.EAST) = 3 then
      if GDVars.wallNorth = 0 then CombatSt.PlotCell(5, 0, 39)
                       else CombatSt.PlotCell(5, 0, 41);
  end;

  { Lays the four-tile group 55..58 on about half of the map squares. }
  procedure ScatterRandomTiles;
  begin
    for GDVars.arenaOY := -2 to 2 do
      for GDVars.arenaOX := -6 to 6 do
        if Random(2) = 0 then begin
          CombatSt.PlotCell(4, 2, 55);
          CombatSt.PlotCell(5, 2, 56);
          CombatSt.PlotCell(5, 3, 57);
          CombatSt.PlotCell(6, 3, 58);
        end;
  end;

begin
  CombatSt.ReseedRandom(GDVars.eclId);
  if (mode = $88) or (mode = $82) then
    FillChar(GDVars.combatArena^.cells, SizeOf(GDVars.combatArena^.cells), 7)
  else
    FillChar(GDVars.combatArena^.cells, SizeOf(GDVars.combatArena^.cells), 45);
  if (mode and $40) <> 0 then
    ScatterRandomTiles;
  for GDVars.arenaOY := -2 to 2 do
    for GDVars.arenaOX := -6 to 6 do begin
      mapX := GDVars.partyPosition.mapX + GDVars.arenaOX;
      mapY := GDVars.partyPosition.mapY + GDVars.arenaOY;
      GDVars.wallWest := CombatSt.WallBetween(mapX, mapY, C_Dir.WEST);
      GDVars.wallNorth := CombatSt.WallBetween(mapX, mapY, C_Dir.NORTH);
      GDVars.wallEast := CombatSt.WallBetween(mapX, mapY, C_Dir.EAST);
      GDVars.wallSouth := CombatSt.WallBetween(mapX, mapY, C_Dir.SOUTH);
      PlaceWestWall;
      PlaceNorthWall;
      PlaceCornerTiles;
      GDVars.squareVariant := View3D.GetMapEvent(mapX, mapY) and $40;
      CombatSt.ScatterWallTiles(mode);
    end;
  CombatSt.RestoreRandom;
end;

{ Gives every UNSET_TERRAIN cell a terrain.
  @param(base The terrain given.)
  @param(spread Above 0, adds a roll of 0..spread - 1 to each cell's terrain.) }
procedure FillUnsetTerrain(base, spread: Byte);
var
  col: Byte;
  row: Byte;
  value: Byte;
begin
  for col := 0 to SizeOf(GDVars.combatArena^.cells[0]) - 1 do
    for row := 0 to SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1 do
      if GDVars.combatArena^.cells[row][col] = C_Terr.UNSET_TERRAIN then begin
        value := base;
        if spread > 0 then
          Inc(value, CharHlp.RollDice(1, spread) - 1);
        GDVars.combatArena^.cells[row][col] := value;
      end;
end;

{ Runs terrainProfiles[profileKind] count times: each run that passes its chance plots a rolled number of tiles, each
  with its pair tile, around a center.
  @param(profileKind The terrainProfiles row.)
  @param(count The number of runs.) }
procedure BuildWilderness(profileKind, count: Byte);
var
  iter: Byte;
  remaining: Byte;
  isFirstPlot: Boolean;
  plotScatter: Byte;
  variance: Byte;
  plotTile: Byte;
  plotPairTile: Byte;
  centerX: Byte;
  centerY: Byte;
  distance: Real;
  angle: Real;
  plotClearance: Byte;

  { True for an arena cell still unset or holding ground 89, 90, 91, 108 or 109. }
  function IsTerrainOpen(x, y: ShortInt): Boolean;
  begin
    if (x < 0) or (x > SizeOf(GDVars.combatArena^.cells[0]) - 1) or (y < 0) or
        (y > SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) then
      IsTerrainOpen := False
    else
      IsTerrainOpen := GDVars.combatArena^.cells[y][x] in [C_Terr.UNSET_TERRAIN, 89, 90, 91, 108, 109];
  end;

  { True when the cells within plotClearance of (centerX, centerY), or the center and its pair, are open. }
  function IsPlacementOpen: Boolean;
  var
    isAllOpen: Boolean;
    dx: ShortInt;
    dy: ShortInt;
  begin
    if plotClearance > 0 then begin
      isAllOpen := True;
      for dx := -plotClearance to plotClearance do
        for dy := -plotClearance to plotClearance do
          isAllOpen := isAllOpen and IsTerrainOpen(centerX + dx, centerY + dy);
      IsPlacementOpen := isAllOpen;
    end else if not IsTerrainOpen(centerX, centerY) then
      IsPlacementOpen := False
    else if plotPairTile <> C_Terr.UNSET_TERRAIN then begin
      if (GDConsts.terrainProfiles[profileKind].flags and C_Terr.PROFILE_PAIR_BELOW) <> 0 then
        IsPlacementOpen := IsTerrainOpen(centerX, centerY + 1)
      else
        IsPlacementOpen := IsTerrainOpen(centerX + 1, centerY);
    end else
      IsPlacementOpen := True;
  end;
begin
  with GDConsts.terrainProfiles[profileKind] do
    for iter := 1 to count do
      if CharHlp.PercentileRoll(chance) then begin
        remaining := CharHlp.RollDice(diceCount, diceSides);
        isFirstPlot := True;
        plotScatter := scatter;
        plotClearance := clearance;
        if (flags and C_Terr.PROFILE_KEEP_CENTER) = 0 then begin
          GDVars.randomCenterX := CharHlp.RollDice(1, SizeOf(GDVars.combatArena^.cells[0])) - 1;
          GDVars.randomCenterY :=
            CharHlp.RollDice(1, SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0])) - 1;
        end;
        if scatterBonus > 0 then
          Inc(plotScatter, CharHlp.RollDice(1, scatterBonus));
        if GDVars.scatterOverride > 0 then
          plotScatter := GDVars.scatterOverride;
        while remaining > 0 do begin
          if isFirstPlot or ((flags and C_Terr.PROFILE_ONE_ROLL) = 0) then begin
            plotTile := tile;
            if tileVariance > 0 then
              variance := CharHlp.RollDice(1, tileVariance) - 1
            else
              variance := 0;
            if (flags and C_Terr.PROFILE_DOUBLE_VARIANCE) <> 0 then variance := variance * 2;
            Inc(plotTile, variance);
            plotPairTile := pairTile;
            if pairTile <> C_Terr.UNSET_TERRAIN then
              if (flags and C_Terr.PROFILE_PAIR_FOLLOWS) <> 0 then
                Inc(plotPairTile, variance)
              else begin
                if pairVariance > 0 then
                  variance := CharHlp.RollDice(1, pairVariance) - 1
                else
                  variance := 0;
                if (flags and C_Terr.PROFILE_DOUBLE_VARIANCE) <> 0 then variance := variance * 2;
                Inc(plotPairTile, variance);
              end;
            isFirstPlot := False;
          end;
          if plotScatter > 0 then begin
            if (flags and C_Terr.PROFILE_FIXED_SCATTER) <> 0 then
              distance := plotScatter
            else
              distance := CharHlp.RollDice(1, plotScatter + 1) - 1;
            angle := Random * 2 * Pi;
            centerX := Trunc(distance * Cos(angle));
            centerY := Trunc(distance * Sin(angle));
            Inc(centerX, GDVars.randomCenterX);
            Inc(centerY, GDVars.randomCenterY);
          end else begin
            centerX := GDVars.randomCenterX;
            centerY := GDVars.randomCenterY;
          end;
          if IsPlacementOpen then begin
            GDVars.combatArena^.cells[centerY][centerX] := plotTile;
            if plotPairTile <> C_Terr.UNSET_TERRAIN then begin
              if (flags and C_Terr.PROFILE_PAIR_BELOW) <> 0 then Inc(centerY)
                                                  else Inc(centerX);
              if (centerY <= SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) and
                  (centerX <= SizeOf(GDVars.combatArena^.cells[0]) - 1) then
                GDVars.combatArena^.cells[centerY][centerX] := plotPairTile;
            end;
          end;
          Dec(remaining);
        end;
      end;
end;

{ Fills the arena with unset terrain, runs the profiles zone 0's wilderness terrain names (10 higher when the area
  kind's low nibble is 8), and gives the cells still unset their tiles. }
procedure BuildWildernessArena;
var
  terrain: Byte;
begin
  FillChar(GDVars.combatArena^.cells, SizeOf(GDVars.combatArena^.cells), C_Terr.UNSET_TERRAIN);
  terrain := GDVars.zone0^.terrain;
  if (GDVars.zone0^.areaType and $F) = 8 then Inc(terrain, 10);
  GDVars.scatterOverride := -1;
  case terrain of
  1, 8, 9:
  begin
    CombatSt.BuildWilderness(6, 6);
    CombatSt.BuildWilderness(1, 8);
    CombatSt.BuildWilderness(3, 1);
    CombatSt.BuildWilderness(4, 2);
    CombatSt.BuildWilderness(5, 2);
    CombatSt.BuildWilderness(8, 2);
  end;
  2:
  begin
    CombatSt.BuildWilderness(1, 6);
    CombatSt.BuildWilderness(3, 1);
    CombatSt.BuildWilderness(4, 1);
    CombatSt.BuildWilderness(5, 1);
    CombatSt.BuildWilderness(7, 5);
    CombatSt.BuildWilderness(8, 1);
  end;
  3:
  begin
    CombatSt.BuildWilderness(2, 1);
    CombatSt.BuildWilderness(4, 3);
    CombatSt.BuildWilderness(7, 10);
    CombatSt.BuildWilderness(10, 1);
    CombatSt.BuildWilderness(9, 5);
    CombatSt.BuildWilderness(22, 1);
  end;
  4:
  begin
    CombatSt.BuildWilderness(10, 10);
    CombatSt.BuildWilderness(2, 1);
    CombatSt.BuildWilderness(3, 1);
    CombatSt.BuildWilderness(4, 1);
    CombatSt.BuildWilderness(7, 3);
    CombatSt.BuildWilderness(9, 10);
    CombatSt.BuildWilderness(22, 2);
  end;
  5:
  begin
    CombatSt.BuildWilderness(10, 10);
    CombatSt.BuildWilderness(2, 1);
    CombatSt.BuildWilderness(3, 1);
    CombatSt.BuildWilderness(4, 1);
    CombatSt.BuildWilderness(7, 10);
    CombatSt.BuildWilderness(9, 15);
    CombatSt.BuildWilderness(22, 3);
  end;
  7, 6:
  begin
    CombatSt.BuildWilderness(1, 1);
    CombatSt.BuildWilderness(2, 2);
    CombatSt.BuildWilderness(3, 1);
    CombatSt.BuildWilderness(4, 1);
    CombatSt.BuildWilderness(7, 2);
    CombatSt.BuildWilderness(8, 1);
    CombatSt.BuildWilderness(9, 1);
  end;
  11, 20:
  begin
    CombatSt.BuildWilderness(13, 2);
    CombatSt.BuildWilderness(14, 1);
    CombatSt.BuildWilderness(16, 1);
    CombatSt.BuildWilderness(14, 2);
    CombatSt.BuildWilderness(18, 3);
    CombatSt.BuildWilderness(12, 2);
  end;
  12, 18:
  begin
    CombatSt.BuildWilderness(11, 4);
    CombatSt.BuildWilderness(12, 4);
    CombatSt.BuildWilderness(13, 2);
    CombatSt.BuildWilderness(18, 2);
    CombatSt.BuildWilderness(15, 12);
  end;
  13, 19:
  begin
    CombatSt.BuildWilderness(11, 3);
    CombatSt.BuildWilderness(12, 3);
    CombatSt.BuildWilderness(13, 2);
    CombatSt.BuildWilderness(14, 2);
    CombatSt.BuildWilderness(18, 4);
    CombatSt.BuildWilderness(15, 8);
  end;
  14, 21:
  begin
    for GDVars.loopIndex := 1 to 6 do begin
      GDVars.scatterOverride := CharHlp.RollDice(1, 4) + 2;
      CombatSt.BuildWilderness(14, 1);
      CombatSt.BuildWilderness(16, 1);
      CombatSt.BuildWilderness(19, 1);
    end;
    GDVars.scatterOverride := -1;
    CombatSt.BuildWilderness(20, 4);
    CombatSt.BuildWilderness(21, 4);
    CombatSt.BuildWilderness(12, 1);
    CombatSt.BuildWilderness(13, 1);
  end;
  15:
  begin
    CombatSt.BuildWilderness(12, 2);
    CombatSt.BuildWilderness(13, 4);
    CombatSt.BuildWilderness(17, 3);
    CombatSt.BuildWilderness(18, 7);
    CombatSt.BuildWilderness(11, 1);
  end;
  16:
  begin
    CombatSt.BuildWilderness(13, 1);
    CombatSt.BuildWilderness(17, 1);
    CombatSt.BuildWilderness(18, 8);
  end;
  17:
  begin
    CombatSt.BuildWilderness(11, 2);
    CombatSt.BuildWilderness(12, 4);
    CombatSt.BuildWilderness(13, 2);
    CombatSt.BuildWilderness(18, 4);
    CombatSt.BuildWilderness(15, 6);
  end;
  else
    TextRend.DisplayValue('Cant identify wild terrain', 0);
  end;
  if terrain < 10 then
    CombatSt.FillUnsetTerrain(108, 2)
  else if terrain in [15, 16] then
    CombatSt.FillUnsetTerrain(91, 0)
  else
    CombatSt.FillUnsetTerrain(89, 2);
end;

{ Allocates combatArena, loads the tile set zone 0's area kind names (marscom, venuscom, lotek, hitek), builds the
  wilderness or dungeon arena for it, and copies picturePalette's entries $20..$3F into combatPalette (VGA). }
procedure LoadCombatTileSet;
var
  region: Byte;
begin
  New(GDVars.combatArena);
  GDVars.combatArena^.cursorShown := False;
  GDVars.combatArena^.cursorSize := 1;
  GDVars.combatArena^.distMode := 0;
  region := GDVars.zone0^.areaType;
  case region of
    C_Area.MARS_WILDERNESS:
    begin
      MapTiles.Load24x24Set('marscom', 1, 1, 52);
      CombatSt.BuildWildernessArena;
    end;
    C_Area.VENUS_WILDERNESS:
    begin
      MapTiles.Load24x24Set('venuscom', 1, 1, 52);
      CombatSt.BuildWildernessArena;
    end;
    $88, $82:
    begin
      MapTiles.Load24x24Set('lotek', 1, 0, 53);
      CombatSt.BuildDungeonArena(region);
    end;
    else begin
      MapTiles.Load24x24Set('hitek', 1, 0, 53);
      CombatSt.BuildDungeonArena(region);
    end;
  end;
  Blit.ShadowPaletteEntries($20, 32, GDVars.combatPalette);
end;

{ Rebuilds each listed creature's stats and gives it a cleared combat state. Members past zone1's partyCount are out of
  play, and an out-of-play party-side member whose npc morale (the bits below NON_PLAYER_FLAG) is 0 or above 102 gets
  zone1's moraleBase + NON_PLAYER_FLAG. }
procedure InitCreatureCombatData;
var
  p: Types.PCharRecord;
  cnt: Byte;
  t: Byte;
begin
  p := GDVars.partyHead;
  cnt := 0;
  while p <> nil do begin
    CharHlp.RecalcStats(p);
    Inc(cnt);
    New(p^.combatAddr);
    FillChar(p^.combatAddr^, SizeOf(Types.TCombatRec), 0);
    if cnt > GDVars.zone1^.partyCount then p^.combatAddr^.notPcNpc := 1;
    t := p^.npc and not C_Npc.NON_PLAYER_FLAG;
    if (p^.side = C_Side.TEAM) and (p^.combatAddr^.notPcNpc = 1) and ((t = 0) or (t > 102)) then
      p^.npc := GDVars.zone1^.moraleBase + C_Npc.NON_PLAYER_FLAG;
    p := p^.nextCharAddr;
  end;
end;

{ Tests a placement-grid cell against the grid.
  @param(qx The cell's column.)
  @param(qy The cell's row.)
  @returns(True when the cell is off the 11x6 placement grid on both axes.) }
function QuadFullyOff(qx, qy: ShortInt): Boolean;
begin
  if ((qx >= 0) and (qx < SizeOf(GDVars.quadFree[0][0][0]))) or
      ((qy >= 0) and (qy < SizeOf(GDVars.quadFree[0][0]) div SizeOf(GDVars.quadFree[0][0][0]))) then
    QuadFullyOff := False
  else
    QuadFullyOff := True;
end;

{ Puts slot's combatant on cell (qx, qy) of its team's ring placement grid laid at map square (baseQX, baseQY) from the
  party, when that cell is open and the combatant fits there; the grid cell is then marked taken unless the combatant is
  disabled in a solo combat. Note: the combatant's cell is moved there even when it does not fit.
  @param(slot The combatant's slot in the creature table.)
  @param(qx The grid cell's column.)
  @param(qy The grid cell's row.)
  @param(baseQX The map square's column offset from the party.)
  @param(baseQY The map square's row offset from the party.)
  @param(ring The placement ring.)
  @returns(True when it fits.) }
function TryPlaceAt(slot: Byte; qx, qy, baseQX, baseQY: ShortInt; ring: Byte): Boolean;
var
  crIdx: Byte;
  terrIdx: Byte;
  hasGas: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tries: array[1..2] of Byte;
begin
  if (qx < 0) or (qy < 0) or (qx > SizeOf(GDVars.quadFree[0][0][0]) - 1) or
      (qy > SizeOf(GDVars.quadFree[0][0]) div SizeOf(GDVars.quadFree[0][0][0]) - 1) or
          (GDVars.quadFree[GDVars.team][ring][qy][qx] = 0) then
    TryPlaceAt := False
  else begin
    GDVars.combatantCells[slot].x := qx + baseQX * 6 + baseQY * 5 + 22;
    GDVars.combatantCells[slot].y := qy + baseQY * 5 + 10;
    CbtMap.ProbeDirection(GDVars.creatures[slot], C_Dir.CENTER, crIdx, terrIdx, hasGas);
    if (crIdx = 0) and (terrIdx > 0) and (GDConsts.terrainInfo[terrIdx].cost < C_Terr.IMPASSABLE) then begin
      TryPlaceAt := True;
      if (GDVars.creatures[slot]^.enabled <> 0) or
          ((GDVars.creatures[slot]^.enabled = 0) and (GDVars.soloCombat = 0)) then
        GDVars.quadFree[GDVars.team][ring][qy][qx] := 0;
    end else
      TryPlaceAt := False;
  end;
end;

{ Walks the team's placement rings out from its origin, in zigzag legs, for a cell TryPlaceAt accepts.
  @param(slot The combatant's slot in the creature table.)
  @returns(True when placed, False when the rings ran out.) }
function FindPlacement(slot: Byte): Boolean;
var
  isPlaced: Boolean;
  isFirstPass: Boolean;
  hasGivenUp: Boolean;
  isOffGrid: Boolean;
  isOpen: Boolean;
  state: Byte;
  { direction 0..7 from the origin to the map square a ring is tried in }
  dir: Byte;
  { the quarter the current ring faces }
  quad: Byte;
  k: Byte;
  stepX: ShortInt;
  stepY: ShortInt;
  { the origin's map square, whose walls decide the rings }
  wallX: ShortInt;
  wallY: ShortInt;
  legShift: Byte;
  legLen: Byte;
  { the map square, from the party, the current ring's grid is laid at }
  baseQX: Byte;
  baseQY: Byte;
  tries: Byte;
  ring: Byte;
  legX: ShortInt;
  legY: ShortInt;
  qx: ShortInt;
  qy: ShortInt;
begin
  isFirstPass := True;
  hasGivenUp := False;
  state := 1;
  legShift := 0;
  ring := 0;
  baseQX := GDVars.placeX[GDVars.team];
  baseQY := GDVars.placeY[GDVars.team];
  repeat
    quad := GDConsts.facingDirections[GDVars.teamDir[GDVars.team], ring] div 2;
    case state of
      1: begin
           stepX := GDConsts.dirStepX[GDConsts.quarterDirections[(quad + 2) mod 4]];
           stepY := GDConsts.dirStepY[GDConsts.quarterDirections[(quad + 2) mod 4]];
           legX := GDConsts.ringStartColumns[ring > 0, quad] + stepX * legShift;
           legY := GDConsts.ringStartRows[ring > 0, quad] + stepY * legShift;
           qx := legX;
           qy := legY;
           legLen := 1;
           state := 2;
           tries := 1;
         end;
      2: begin
           stepX := GDConsts.dirStepX[GDConsts.quarterDirections[(quad + 1) mod 4]];
           stepY := GDConsts.dirStepY[GDConsts.quarterDirections[(quad + 1) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 3;
           Inc(tries);
         end;
      3: begin
           stepX := GDConsts.dirStepX[GDConsts.quarterDirections[(quad + 3) mod 4]];
           stepY := GDConsts.dirStepY[GDConsts.quarterDirections[(quad + 3) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 2;
           Inc(legLen);
           Inc(tries);
         end;
    end;
    if (qx < 0) or (qy < 0) or (qx > SizeOf(GDVars.quadFree[0][0][0]) - 1) or
        (qy > SizeOf(GDVars.quadFree[0][0]) div SizeOf(GDVars.quadFree[0][0][0]) - 1) then
      isOffGrid := True
    else isOffGrid := False;
    if state > 1 then begin
      if (isOffGrid and not CombatSt.QuadFullyOff(qx, qy)) or isFirstPass and (tries >= GDVars.teamRows[GDVars.team]) or
          not isFirstPass and (tries > 11) then begin
        Inc(legShift);
        if (GDVars.team = C_Side.TEAM) and Odd(GDVars.teamDir[C_Side.TEAM]) and (ring = 0) and (legShift = 1) then begin
          wallX := GDVars.placeX[GDVars.team] + GDVars.partyPosition.mapX;
          wallY := GDVars.placeY[GDVars.team] + GDVars.partyPosition.mapY;
          isOpen := False;
          for k := 1 to SizeOf(GDConsts.ringBlockDirections[0]) - 1 do begin
            dir := GDConsts.ringBlockDirections[GDVars.teamDir[GDVars.team], k];
            if (GDVars.interfaceState = C_Ifc.WILDERNESS) or (CombatSt.WallBetween(wallX, wallY,
                dir) = 0) then isOpen := True;
          end;
          if isOpen then Inc(legShift);
        end;
        state := 1;
        isFirstPass := False;
      end;
    end;
    if isOffGrid then
      if CombatSt.QuadFullyOff(qx, qy) then begin
        isPlaced := False;
        state := 0;
        while (ring < SizeOf(GDVars.quadFree[0]) div SizeOf(GDVars.quadFree[0][0]) - 1) and (state <> 1) do begin
          Inc(ring);
          wallX := GDVars.placeX[GDVars.team] + GDVars.partyPosition.mapX;
          wallY := GDVars.placeY[GDVars.team] + GDVars.partyPosition.mapY;
          dir := GDConsts.ringBlockDirections[GDVars.teamDir[GDVars.team], ring];
          if (GDVars.interfaceState = C_Ifc.WILDERNESS) or
              (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then begin
            baseQX := GDVars.placeX[GDVars.team] + GDConsts.dirStepX[dir];
            baseQY := GDVars.placeY[GDVars.team] + GDConsts.dirStepY[dir];
            legShift := 0;
            state := 1;
          end;
        end;
        if state <> 1 then hasGivenUp := True;
      end;
    if not isOffGrid then
      isPlaced := CombatSt.TryPlaceAt(slot, qx, qy, baseQX, baseQY, ring);
  until isPlaced or hasGivenUp;
  if hasGivenUp then FindPlacement := False else FindPlacement := True;
end;

{ Places every creature on the party list, each team facing the other, the hostiles coming from each direction
  monsterApproach names in turn. A downed creature placed leaves a corpse record in downedCreatures; an out-of-play
  creature that finds no place is removed. }
procedure PlaceAllCreatures;
var
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  slot: Byte;
  rangeSet: Byte;
  { counted but unused }
  placedCount: Byte;
  removedCount: Byte;
  originalFacing: Byte;
  lastFacing: Byte;
  approachQuarter: Byte;
  px: ShortInt;
  py: ShortInt;
  facing: Byte;
  approachCount: Byte;
  isPlaced: Boolean;

  { Unless the facing is the one last laid, lays the teams' origins and facings and the rings' open cells. }
  procedure InitOccupancy;
  var
    ring: Byte;
    qx: ShortInt;
    qy: ShortInt;
    distance: Byte;
  begin
    if (GDVars.zone1^.monsterDistance = 0) and (GDVars.partyPosition.facing <> originalFacing) then
      distance := 1
    else
      distance := GDVars.zone1^.monsterDistance;
    if GDVars.demoMode then
      distance := 2;
    if GDVars.partyPosition.facing = lastFacing then Exit;
    lastFacing := GDVars.partyPosition.facing;
    GDVars.teamDir[C_Side.TEAM] := GDVars.partyPosition.facing div 2;
    GDVars.placeX[C_Side.HOSTILE] := GDConsts.dirStepX[GDVars.partyPosition.facing] * distance +
      GDVars.placeX[C_Side.TEAM];
    GDVars.placeY[C_Side.HOSTILE] := GDConsts.dirStepY[GDVars.partyPosition.facing] * distance +
      GDVars.placeY[C_Side.TEAM];
    GDVars.teamDir[C_Side.HOSTILE] := (GDVars.partyPosition.facing + 4) mod 8 div 2;
    for GDVars.team := C_Side.TEAM to C_Side.HOSTILE do
      for ring := 0 to SizeOf(GDVars.quadFree[0]) div SizeOf(GDVars.quadFree[0][0]) - 1 do begin
        if ring = 1 then rangeSet := 4 else rangeSet := GDVars.teamDir[GDVars.team];
        for qy := 0 to SizeOf(GDVars.quadFree[0][0]) div SizeOf(GDVars.quadFree[0][0][0]) - 1 do
          for qx := 0 to SizeOf(GDVars.quadFree[0][0][0]) - 1 do
            if (qx < GDConsts.columnRanges[rangeSet, qy].lo) or (qx > GDConsts.columnRanges[rangeSet, qy].hi) then
              GDVars.quadFree[GDVars.team][ring][qy][qx] := 0
            else
              GDVars.quadFree[GDVars.team][ring][qy][qx] := 1;
      end;
  end;
begin
  originalFacing := GDVars.partyPosition.facing;
  lastFacing := 255;
  approachQuarter := 0;
  CharHlp.CountTeams;
  removedCount := 0;
  placedCount := 0;
  for slot := 1 to C_Combat.MAX_COMBATANTS do
    GDVars.combatantCells[slot].size := 0;
  FillChar(GDVars.cellCombatant, SizeOf(GDVars.cellCombatant), 0);
  GDVars.placeX[C_Side.TEAM] := 0;
  GDVars.placeY[C_Side.TEAM] := 0;
  GDVars.teamRows[C_Side.TEAM] := (GDVars.teamCounts[C_Side.TEAM] + 1) div 2;
  approachCount := 0;
  if (GDVars.monsterApproach and $F) = 0 then
    Inc(approachCount)
  else begin
    if (GDVars.monsterApproach and 1) <> 0 then Inc(approachCount);
    if (GDVars.monsterApproach and 2) <> 0 then Inc(approachCount);
    if (GDVars.monsterApproach and 4) <> 0 then Inc(approachCount);
    if (GDVars.monsterApproach and 8) <> 0 then Inc(approachCount);
  end;
  approachCount := approachCount * 2;
  GDVars.teamRows[C_Side.HOSTILE] := (GDVars.teamCounts[C_Side.HOSTILE] + approachCount - 1) div approachCount;
  InitOccupancy;
  slot := 1;
  GDVars.combatantCount := 1;
  prev := GDVars.partyHead;
  p := GDVars.partyHead;
  while p <> nil do begin
    GameIo.DiscardPendingKeys;
    GDVars.creatures[slot] := p;
    GDVars.team := p^.side;
    GDVars.combatantCells[slot].slot := slot;
    GDVars.combatantCells[slot].size := p^.iconDimensions and CombatSt.ICON_SIZE_LOW_BITS;
    if GDVars.monsterApproach <> 0 then begin
      if p^.side = C_Side.TEAM then
        GDVars.partyPosition.facing := originalFacing
      else begin
        repeat
          approachQuarter := (approachQuarter + 1) and 3
        until Byte((1 shl approachQuarter) and GDVars.monsterApproach) <> 0;
        GDVars.partyPosition.facing := approachQuarter * 2;
      end;
      InitOccupancy;
    end;
    facing := GDVars.partyPosition.facing;
    if p^.side = C_Side.HOSTILE then facing := (facing + 4) mod 8;
    p^.combatAddr^.direction := GDConsts.quarterDirections[facing div 2];
    if (GDVars.soloCombat <> 0) and (p^.enabled = 0) then
      isPlaced := False
    else
      isPlaced := CombatSt.FindPlacement(slot);
    if isPlaced then begin
      prev := p;
      if p^.enabled = 0 then begin
        GDVars.combatantCells[slot].size := 0;
        if p^.combatAddr^.notPcNpc = 0 then begin
          px := GDVars.combatantCells[slot].x;
          py := GDVars.combatantCells[slot].y;
          Inc(GDVars.downedCount);
          GDVars.downedCreatures[GDVars.downedCount].terrain := CbtMap.ResolveTerrain(px, py);
          GDVars.combatArena^.cells[py][px] := C_Terr.CORPSE_TERRAIN;
          GDVars.downedCreatures[GDVars.downedCount].character := p;
          GDVars.downedCreatures[GDVars.downedCount].x := px;
          GDVars.downedCreatures[GDVars.downedCount].y := py;
        end;
      end;
      CbtMap.BuildArenaArrays;
      Inc(slot);
      Inc(GDVars.combatantCount);
      Inc(placedCount);
    end else begin
      GDVars.combatantCells[slot].size := 0;
      if p^.combatAddr^.notPcNpc = 1 then begin
        Inc(removedCount);
        GDVars.creatures[slot] := nil;
        GDVars.currentCharacter := p;
        CharGen.RemoveCreature(True, False);
        p := prev;
      end else begin
        prev := p;
        Inc(slot);
        Inc(GDVars.combatantCount);
      end;
    end;
    p := p^.nextCharAddr;
  end;
  prev^.nextCharAddr := nil;
  GDVars.partyPosition.facing := originalFacing;
end;

procedure CombatStart;
var
  { Unused in this version; see the other implementations of this routine. }
  savedFlags: array[1..10] of Byte;
  p: Types.PCharRecord;
begin
  GDVars.messageDelay := 0;
  Portrait.FreeAnimation;
  Blit.FreePic(GDVars.portraitSlots[1].pic);
  Blit.FreePic(GDVars.portraitSlots[2].pic);
  Blit.FreePic(GDVars.bigPicture);
  OrbitMap.FreeOrbitPictures;
  OrbitMap.FreeShipPictures;
  Blit.AllocPic(24, 3, 59, 0, GDVars.arenaTiles);
  GDVars.portraitSlots[1].pictureId := C_Pic.EMPTY_PORTRAIT_SLOT;
  GDVars.portraitSlots[2].pictureId := C_Pic.EMPTY_PORTRAIT_SLOT;
  GDVars.viewPicture^.height := 168;
  GDVars.viewPicture^.width := 21;
  TextRend.ClearStatusLine;
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, 'A battle begins...');
  GDVars.combatRound := 0;
  GDVars.combatEndRound := C_Combat.IDLE_ROUNDS;
  GDVars.currentAttackRoll := 0;
  GDVars.downedCount := 0;
  GDVars.lastMissileItem := nil;
  FillChar(GDVars.downedCreatures, SizeOf(GDVars.downedCreatures), 0);
  GDVars.zone1^.hasAttackedAlly := 0;
  CombatSt.LoadCombatTileSet;
  GameIo.DiscardPendingKeys;
  CombatSt.InitCreatureCombatData;
  GameIo.DiscardPendingKeys;
  CombatSt.PlaceAllCreatures;
  GameIo.DiscardPendingKeys;
  Blit.AllocPic(24, 3, 4, 1, GDVars.movingIcon);
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.enabled <> 0) and (p^.side = C_Side.TEAM) then begin
      GDVars.combatArena^.viewOriginX := CbtMap.CombatCellX(p) - 7 div 2;
      GDVars.combatArena^.viewOriginY := CbtMap.CombatCellY(p) - 7 div 2;
      Blit.SetDacPalette(C_Pic.PICTURE_DAC_FIRST, C_Pic.PICTURE_DAC_COUNT, GDVars.combatPalette);
      CharHlp.DisplayCombatInterface;
      p := nil;
    end else
      p := p^.nextCharAddr;
  end;
  CbtActs.UpdateHostileHpPercent;
  GDVars.inMoveMenu := 0;
  GDVars.cursorActive := 0;
  GDVars.moveMode := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    Debug.PrintDebug(p^.name, p^.status, p^.enabled, 0);
    p := p^.nextCharAddr;
  end;
end;

begin
end.
