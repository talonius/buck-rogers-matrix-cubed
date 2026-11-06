{ Combat lines of movement and fire. WalkLine walks a line across the combat arena and reports the chaff and aerosol
  mist clouds and the blocking terrain it crosses. BuildTargetList collects the combatants a line reaches from a
  position, and SortTargets puts them nearest first. }
{$O+,F+}
unit Pathing;

interface

uses CbtMap, Types, C_Terr, GDConsts, GDVars, C_Dir;

{ Gives the sign of a number.
  @param(v The number.)
  @returns(-1, 0 or 1.) }
function SignOf(v: Integer): Integer;

{ Starts a line walk from (sx, sy) to (ex, ey): sets the current point, the deltas, the step signs, and zero error and
  distance.
  @param(req The walk, with its start and end points set.) }
procedure PathFind(var req: Types.TPathReq);

{ Takes one Bresenham step along a line walk, adding 2 to the doubled distance for a straight step and 3 for a diagonal,
  and records the step's direction.
  @param(req The walk, started by PathFind.)
  @returns(False, without moving, once the end point is reached.) }
function NextPathStep(var req: Types.TPathReq): Boolean;

{ Walks the line from (x, y) toward (tx, ty), setting the saw flags. The walk stops early on a lineClass 1 cell while
  the arena's distMode is 0 (unless the two points are one), on a chaff cell while stopsAtChaff is set, or once it has
  walked past twice dist plus one.
  @param(x The start column.)
  @param(y The start row.)
  @param(tx The end column; on an early stop, set to the column the walk stopped on.)
  @param(ty The end row; on an early stop, set to the row the walk stopped on.)
  @param(dist In, the range in straight steps; out, the distance walked, 2 per straight step and 3 per diagonal.)
  @returns(True when the walk reached (tx, ty).) }
function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word): Boolean;

{ Fills pathTargets with every combatant a line from (x, y) reaches within range, trying each of the mover's icon cells
  against each of the target's and keeping the shortest line, then sorts them.
  @param(x The mover's column.)
  @param(y The mover's row.)
  @param(range The reach, in straight steps.)
  @param(filter A direction 0..7 that targets must lie toward, and that each is recorded under; 8 or 255 for any, each
    target then recorded under the first direction it lies toward.)
  @param(size The icon size of the combatant at (x, y).) }
procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte);

implementation

const
  { lineClass: the terrain stops a line while the arena's distMode is 0 }
  LINE_STOPS = 1;
  { lineClass: the terrain marks the line blocked past its grace cells }
  LINE_BLOCKED = 2;
  { cells at a line's start where LINE_BLOCKED terrain is not counted }
  GRACE_CELLS = 2;
  { IsDirToward's direction for any cone; 255 is taken as it too }
  ANY_DIRECTION = 8;

function SignOf(v: Integer): Integer;
begin
  if v < 0 then
    SignOf := -1
  else if v > 0 then
    SignOf := 1
  else
    SignOf := 0;
end;

{ Sorts pathTargets nearest first; at equal distances a target moves ahead of one with a higher direction unless its
  direction is odd and the other's even. }
procedure SortTargets;
var
  i: Byte;
  j: Byte;
  dirJ: Byte;
  dirI: Byte;
  tmp: Types.TTarget;
begin
  if GDVars.pathTargetCount <= 1 then Exit;
  for i := 1 to GDVars.pathTargetCount - 1 do
    for j := i + 1 to GDVars.pathTargetCount do begin
      dirI := GDVars.pathTargets[i].direction;
      dirJ := GDVars.pathTargets[j].direction;
      if (GDVars.pathTargets[j].distance < GDVars.pathTargets[i].distance) or
          ((GDVars.pathTargets[j].distance = GDVars.pathTargets[i].distance) and (dirJ < dirI) and
           (dirJ mod 2 <= dirI mod 2)) then begin
        tmp := GDVars.pathTargets[i];
        GDVars.pathTargets[i] := GDVars.pathTargets[j];
        GDVars.pathTargets[j] := tmp;
      end;
    end;
end;

procedure PathFind(var req: Types.TPathReq);
begin
  with req do begin
    cx := sx;
    cy := sy;
    adx := Abs(ex - sx);
    ady := Abs(ey - sy);
    stepX := Pathing.SignOf(ex - sx);
    stepY := Pathing.SignOf(ey - sy);
    err := 0;
    dist := 0;
  end;
end;

function NextPathStep(var req: Types.TPathReq): Boolean;
var
  xIdx: ShortInt;
  yIdx: ShortInt;
begin
  NextPathStep := False;
  xIdx := 1;
  yIdx := 1;
  with req do begin
    if adx >= ady then begin
      if cx <> ex then begin
        Inc(cx, stepX);
        xIdx := stepX + 1;
        Inc(err, ady);
        Inc(err, ady);
        Inc(dist);
        Inc(dist);
        if err >= adx then begin
          Dec(err, adx);
          Dec(err, adx);
          Inc(cy, stepY);
          yIdx := stepY + 1;
          Inc(dist);
        end;
        NextPathStep := True;
      end;
    end else begin
      if cy <> ey then begin
        Inc(cy, stepY);
        yIdx := stepY + 1;
        Inc(err, adx);
        Inc(err, adx);
        Inc(dist);
        Inc(dist);
        if err >= ady then begin
          Dec(err, ady);
          Dec(err, ady);
          Inc(cx, stepX);
          xIdx := stepX + 1;
          Inc(dist);
        end;
        NextPathStep := True;
      end;
    end;
    step := GDConsts.directionByDelta[yIdx, xIdx];
  end;
end;

function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word): Boolean;
var
  walk: Types.TPathReq;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  step: Byte;
  maxDist: Word;
  cell: Byte;
  grace: Byte;
begin
  GDVars.sawChaff := False;
  GDVars.sawAerosolMist := False;
  GDVars.sawBlockedTerrain := False;
  grace := Pathing.GRACE_CELLS;
  maxDist := dist * 2 + 1;
  walk.sx := x;
  walk.sy := y;
  walk.ex := tx;
  walk.ey := ty;
  Pathing.PathFind(walk);
  done := False;
  repeat
    cell := GDVars.combatArena^.cells[walk.cy, walk.cx];
    if cell = C_Terr.CHAFF_TERRAIN then begin
      GDVars.sawChaff := True;
      if GDVars.stopsAtChaff then
        done := True
    end else if cell = C_Terr.AEROSOL_MIST_TERRAIN then
      GDVars.sawAerosolMist := True
    else if grace > 0 then
      Dec(grace)
    else if GDConsts.terrainInfo[cell].lineClass = Pathing.LINE_BLOCKED then
      GDVars.sawBlockedTerrain := True;
    if ((GDVars.combatArena^.distMode = 0) and (GDConsts.terrainInfo[cell].lineClass = Pathing.LINE_STOPS) and
        ((x <> tx) or (y <> ty))) or done or (walk.dist > maxDist) then begin
      tx := walk.cx;
      ty := walk.cy;
      dist := walk.dist;
      WalkLine := False;
      GDVars.stopsAtChaff := False;
      Exit;
    end;
    done := not Pathing.NextPathStep(walk);
  until done;
  dist := walk.dist;
  WalkLine := True;
  GDVars.stopsAtChaff := False;
end;

{ Tests whether a point lies toward a direction from another.
  @param(x The column looked from.)
  @param(y The row looked from.)
  @param(tx The column of the point tested.)
  @param(ty The row of the point tested.)
  @param(dir A direction 0..7 clockwise from north; 8 or 255 for any.)
  @returns(True when (tx, ty) lies in the 90-degree cone that opens in direction dir from the cell one step that way
    from (x, y), or is (x, y) or that cell; False when either point is off the 50 x 25 arena.) }
function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;
var
  nx: ShortInt;
  ny: ShortInt;
begin
  if (x < 0) or (x > SizeOf(GDVars.combatArena^.cells[0]) - 1) or (y < 0) or
      (y > SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) or (tx < 0) or
      (tx > SizeOf(GDVars.combatArena^.cells[0]) - 1) or (ty < 0) or
      (ty > SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) then begin
    IsDirToward := False;
    Exit;
  end;
  if dir = 255 then
    dir := Pathing.ANY_DIRECTION;
  nx := x + GDConsts.dirStepX[dir];
  ny := y + GDConsts.dirStepY[dir];
  if ((x = tx) and (y = ty)) or ((nx = tx) and (ny = ty)) then begin
    IsDirToward := True;
    Exit;
  end;
  case dir of
    C_Dir.NORTH: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or ((tx <= nx) and (ty <= (tx - nx) + ny));
    C_Dir.NORTHEAST: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or
      ((tx >= (nx + ny) - ty) and (ty <= ny));
    C_Dir.EAST: IsDirToward := ((tx >= (nx + ny) - ty) and (ty <= ny)) or ((tx >= (nx + ty) - ny) and (ty >= ny));
    C_Dir.SOUTHEAST: IsDirToward := ((tx >= (nx + ty) - ny) and (ty >= ny)) or
      ((tx >= nx) and (ty >= (tx - nx) + ny));
    C_Dir.SOUTH: IsDirToward := ((tx >= nx) and (ty >= (tx - nx) + ny)) or ((tx <= nx) and (ty >= (nx - tx) + ny));
    C_Dir.SOUTHWEST: IsDirToward := ((tx <= nx) and (ty >= (nx - tx) + ny)) or
      ((tx <= (nx + ny) - ty) and (ty >= ny));
    C_Dir.WEST: IsDirToward := ((tx <= (nx + ny) - ty) and (ty >= ny)) or ((tx <= (nx + ty) - ny) and (ty <= ny));
    C_Dir.NORTHWEST: IsDirToward := ((tx <= (nx + ty) - ny) and (ty <= ny)) or
      ((tx <= nx) and (ty <= (tx - nx) + ny));
    Pathing.ANY_DIRECTION: IsDirToward := True;
  end;
end;

procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte);
var
  i: Byte;
  bestDir: Byte;
  k: Byte;
  j: Byte;
  bestK: Byte;
  bestJ: Byte;
  found: Boolean;
  tx: ShortInt;
  ty: ShortInt;
  dx8: ShortInt;
  dy8: ShortInt;
  myX: array[0..3] of ShortInt;
  myY: array[0..3] of ShortInt;
  tgX: array[0..3] of ShortInt;
  tgY: array[0..3] of ShortInt;
  dist: Word;
  bestDist: Word;
begin
  for k := 0 to SizeOf(myX) - 1 do
    if CbtMap.GetIconTileDelta(size, k, dx8, dy8) then begin
      myX[k] := x + dx8;
      myY[k] := y + dy8;
    end else
      myX[k] := -1;
  GDVars.pathTargetCount := 0;
  for i := 1 to GDVars.combatantCount do
    if GDVars.combatantCells[i].size > 0 then begin
      found := False;
      bestDist := 255;
      for j := 0 to SizeOf(tgX) - 1 do
        if CbtMap.GetIconTileDelta(GDVars.combatantCells[i].size, j, dx8, dy8) then begin
          tgX[j] := GDVars.combatantCells[i].x + dx8;
          tgY[j] := GDVars.combatantCells[i].y + dy8;
        end else
          tgX[j] := -1;
      for j := 0 to SizeOf(tgX) - 1 do
        if tgX[j] >= 0 then
          for k := 0 to SizeOf(myX) - 1 do
            if myX[k] >= 0 then
              if Pathing.IsDirToward(myX[k], myY[k], tgX[j], tgY[j], filter) then begin
                tx := tgX[j];
                ty := tgY[j];
                dist := range;
                if Pathing.WalkLine(myX[k], myY[k], tx, ty, dist) then begin
                  found := True;
                  if dist < bestDist then begin
                    bestDist := dist;
                    bestK := k;
                    bestJ := j;
                  end;
                end;
              end;
      if found then begin
        Inc(GDVars.pathTargetCount);
        GDVars.pathTargets[GDVars.pathTargetCount].slot := i;
        GDVars.pathTargets[GDVars.pathTargetCount].distance := bestDist;
        bestDir := 0;
        if filter < Pathing.ANY_DIRECTION then
          bestDir := filter
        else
          while not Pathing.IsDirToward(myX[bestK], myY[bestK], tgX[bestJ], tgY[bestJ], bestDir) do
            Inc(bestDir);
        GDVars.pathTargets[GDVars.pathTargetCount].direction := bestDir;
      end;
    end;
  Pathing.SortTargets;
end;

begin
end.
