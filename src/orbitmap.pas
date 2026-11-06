{ The orbit map: its backdrop, the bodies on their five orbits, the rocket cursor, and the two picture sets that take
  turns in memory -- the orbit-map tiles in tile-set slot 5 and the 29 'ships' pictures. The orbit state lives in zone
  0, reached through GDVars.orbitView; the load flags and buffers are GDVars'. }
{$O+,F+,A-}
unit OrbitMap;

interface

{ Opens the orbit map: loads its pictures, sets the palette, draws the screen frame, the view area and the map, and sets
  the text window. }
procedure EnterOrbitMap;

{ Draws the backdrop, the center body, each body where the current phase puts it (recording its cell in the orbit state)
  and the rocket. }
procedure PaintOrbitMap;

{ Loads the orbit-map tiles from data set 0 and allocates the cell saved under the rocket, freeing the ship pictures
  first; nothing when already loaded. }
procedure LoadOrbitPictures;

{ Loads the 'ships' pictures, freeing the orbit-map pictures, the animation and the big picture first; nothing when
  already loaded. }
procedure LoadShipPictures;

{ Frees the orbit-map tiles, the rocket's saved cell and the big picture; nothing when not loaded. }
procedure FreeOrbitPictures;

{ Frees the 'ships' pictures; nothing when not loaded. }
procedure FreeShipPictures;

{ Puts back the cell saved under the rocket's last position, saves the cell under its current one and draws the rocket
  there. }
procedure RedrawOrbitCursor;

implementation

uses Blit, Border, Mouse, TextRend, Sym8x8, Portrait, MapView, Types, C_Pic, GDConsts, GDVars,
  C_Orbit;

const
  { the tile-set slot the orbit-map tiles load into }
  ORBIT_TILE_SLOT = 5;
  { their record in 8x8d0 }
  ORBIT_TILE_SET = 1;
  ORBIT_DATA_SET = 0;
  { GDConsts.symSetFirst[ORBIT_TILE_SLOT]: a body's sprite or the rocket's icon plus this is its tile; the center body
    is the slot's first }
  ORBIT_TILES = 296;
  { orbit 4's sprites plus this are the eight outer bodies' tiles }
  OUTER_BODY_TILES = 268;
  { the orbit map's picture in 'ships' }
  ORBIT_BACKDROP = 128;
  { GDConsts.shipPictures[i] is picture FIRST_SHIP_PICTURE + i in 'ships' }
  FIRST_SHIP_PICTURE = 10;

procedure RedrawOrbitCursor;
begin
  if GDVars.savedCursorX >= 0 then
    Blit.ShowPic(GDVars.savedCursorX + C_Orbit.MAP_LEFT, GDVars.savedCursorY + C_Orbit.MAP_TOP,
                 GDVars.savedOrbitCell);
  GDVars.savedCursorX := GDVars.orbitView^.rocketX;
  GDVars.savedCursorY := GDVars.orbitView^.rocketY;
  Blit.GrabPic(GDVars.orbitView^.rocketX + C_Orbit.MAP_LEFT,
               GDVars.orbitView^.rocketY + C_Orbit.MAP_TOP, GDVars.savedOrbitCell);
  Sym8x8.Put8x8Sym(GDVars.orbitView^.rocketX + C_Orbit.MAP_LEFT,
                   GDVars.orbitView^.rocketY + C_Orbit.MAP_TOP,
                   GDVars.orbitView^.rocketIcon + OrbitMap.ORBIT_TILES, 0, 1)
end;

procedure FreeOrbitPictures;
begin
  if GDVars.orbitPicturesLoaded = 0 then Exit;
  GDVars.orbitPicturesLoaded := 0;
  Blit.FreePic(GDVars.tileSets[OrbitMap.ORBIT_TILE_SLOT]);
  Blit.FreePic(GDVars.savedOrbitCell);
  Blit.FreePic(GDVars.bigPicture)
end;

procedure FreeShipPictures;
var i: Byte;
begin
  if GDVars.shipPictureBuffersLoaded = 0 then Exit;
  GDVars.shipPictureBuffersLoaded := 0;
  for i := 0 to SizeOf(GDVars.shipPictureBuffers) div SizeOf(Types.PImgBuf) - 1 do
    Blit.FreePic(GDVars.shipPictureBuffers[i])
end;

procedure LoadOrbitPictures;
var oldDataSet: Byte;
begin
  if GDVars.orbitPicturesLoaded <> 0 then Exit;
  OrbitMap.FreeShipPictures;
  TextRend.DisplayLoading;
  GDVars.orbitPicturesLoaded := 1;
  oldDataSet := GDVars.dataSet;
  GDVars.dataSet := OrbitMap.ORBIT_DATA_SET;
  Sym8x8.Load8x8Set(OrbitMap.ORBIT_TILE_SET, OrbitMap.ORBIT_TILE_SLOT);
  GDVars.dataSet := oldDataSet;
  Blit.AllocPic(8, 1, 1, 0, GDVars.savedOrbitCell);
  TextRend.ClearStatusLine
end;

procedure LoadShipPictures;
var
  keyColor: Byte;
  i: Byte;
begin
  if GDVars.shipPictureBuffersLoaded <> 0 then Exit;
  OrbitMap.FreeOrbitPictures;
  Portrait.FreeAnimation;
  Blit.FreePic(GDVars.bigPicture);
  TextRend.DisplayLoading;
  GDVars.shipPictureBuffersLoaded := 1;
  keyColor := 0;
  for i := 0 to SizeOf(GDVars.shipPictureBuffers) div SizeOf(Types.PImgBuf) - 1 do begin
    Blit.LoadPic('ships', i + OrbitMap.FIRST_SHIP_PICTURE, GDConsts.shipPictures[i].isTransparent, keyColor,
                 GDVars.shipPictureBuffers[i])
  end;
  TextRend.ClearStatusLine
end;

procedure EnterOrbitMap;
begin
  OrbitMap.LoadOrbitPictures;
  Blit.LoadPic('ships', OrbitMap.ORBIT_BACKDROP, False, 0, GDVars.bigPicture);
  Blit.SetDacPalette(C_Pic.PICTURE_DAC_FIRST, C_Pic.PICTURE_DAC_COUNT, GDVars.picturePalette);
  Mouse.HideMouse;
  Border.DrawWindowFrame(0);
  Border.DrawFrameSegments(GDConsts.orbitMapFrame);
  MapView.DisplayMapView;
  GDVars.windowLeft := 1;
  GDVars.windowTop := 17;
  GDVars.windowRight := 15;
  GDVars.windowBottom := 22;
  GDVars.bigPictureId := C_Pic.NO_BIG_PICTURE;
  Mouse.ShowMouse;
  OrbitMap.PaintOrbitMap;
  TextRend.SetTextWindow(1, 17, 15, 22, 0)
end;

procedure PaintOrbitMap;
var
  { Unused in this version; see the other implementations of this routine. }
  position: array[0..2] of Byte;
  i: Byte;
begin
  Mouse.HideMouse;
  Blit.ShowPic(C_Orbit.MAP_LEFT, C_Orbit.MAP_TOP, GDVars.bigPicture);
  Sym8x8.Put8x8Sym(C_Orbit.MAP_LEFT + C_Orbit.CENTER_X, C_Orbit.MAP_TOP + C_Orbit.CENTER_Y,
                   OrbitMap.ORBIT_TILES, 0, 1);
  for i := 0 to SizeOf(GDConsts.orbitStartPhases) - 1 do
    with GDConsts.orbitPositions[Word(GDConsts.orbitStartPhases[i] +
      GDVars.orbitView^.phase) mod GDConsts.orbitLengths[i] + GDConsts.orbitFirstPositions[i]] do begin
      GDVars.orbitView^.positions[i].x := x;
      GDVars.orbitView^.positions[i].y := y;
      Sym8x8.Put8x8Sym(x + C_Orbit.MAP_LEFT, y + C_Orbit.MAP_TOP, sprite + OrbitMap.ORBIT_TILES, 0, 1)
    end;
  for i := 0 to SizeOf(GDConsts.outerBodyPhases) - 1 do
    with GDConsts.orbitPositions[GDConsts.orbitFirstPositions[4] +
      Word(GDConsts.orbitStartPhases[4] + GDConsts.outerBodyPhases[i] +
      GDVars.orbitView^.phase) mod GDConsts.orbitLengths[4]] do begin
      GDVars.orbitView^.positions[i + 5].x := x;
      GDVars.orbitView^.positions[i + 5].y := y;
      Sym8x8.Put8x8Sym(x + C_Orbit.MAP_LEFT, y + C_Orbit.MAP_TOP, sprite + OrbitMap.OUTER_BODY_TILES, 0, 1)
    end;
  GDVars.savedCursorX := -1;
  OrbitMap.RedrawOrbitCursor;
  Mouse.ShowMouse
end;

end.
