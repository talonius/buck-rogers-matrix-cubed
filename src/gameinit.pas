{ Start-up and restart, for FixMain: InitializeGame once at start-up and ResetGameState after each game; both end in
  InitShipAndOrbit, which loads the party's ship and puts its rocket at its starting orbit position. InitializeGame
  starts the 16 colors from defaultPalette. The state they set up lives in GDVars, zone 1, Crt's LastMode and the BIOS
  keyboard flags; its loop counters, the ITEMS file and the mouse read-back are GDVars' too. }
{$O+,F+,I-}
unit GameInit;

interface

{ Start-up: allocates and clears the game's buffers and zones, sets the palettes, the mouse and the default game state,
  and loads the font, tiles, icons, items and item templates. }
procedure InitializeGame;

{ Resets the game state for a restart after a game, keeping the buffers and what is loaded. The party starts facing
  east, and wall set slot 1 is reset to file 0. }
procedure ResetGameState;

implementation

uses Crt, Types, C_Map, C_Orbit, C_Pic, GDConsts, GDVars, Mouse, Blit, TextRend, Sym8x8,
  MapTiles, DaxIo, EffHndlr, EclMenu, SaveLoad, C_Dir, C_Ifc, C_Sound, C_Diff, C_Vm, C_Side, C_Ecl;

const
  { the ship SaveLoad.LoadShipData loads as the party's ship }
  PARTY_SHIP_ID = 10;
  { the orbit at whose starting position the party's rocket begins }
  START_ORBIT = 2;
  { zone 0's messageSpeed at start-up and on ResetGameState }
  START_MESSAGE_SPEED = 4;
  { the party's square on the 3-D map at start-up and on ResetGameState }
  START_MAP_X = 7;
  START_MAP_Y = 13;
  { the glyphs gameFont's allocation holds }
  FONT_GLYPHS = 177;
  { the WALLDEF banks wallDefs's allocation holds }
  WALL_BANKS = 3;
  { the iconFrames row of the first of the 25 COMSPR icons }
  FIRST_COMSPR_ICON_ROW = 13;
  { the BIOS keyboard flags' Num Lock bit }
  NUM_LOCK = $20;

var

  { The BIOS keyboard shift-state byte. }
  biosKbdFlags: Byte absolute $0000: $0417;

{ Resets the menu colors and the combat and orbit state, loads the party's ship and places its rocket at the starting
  orbit position. }
procedure InitShipAndOrbit;
var
  oldDataSet: Byte;
begin
  GDVars.promptColor := LightMagenta;
  GDVars.menuColor := LightGreen;
  GDVars.highlightColor := White;
  GDVars.treatmentPending := 0;
  GDVars.shipRepairPending := 0;
  GDVars.areaEffects := nil;
  GDVars.tacticsSides[C_Side.TEAM] := 0;
  GDVars.tacticsSides[C_Side.HOSTILE] := 0;
  GDVars.iconEditorActive := 0;
  GDVars.verticalMenuActive := False;
  GDVars.windowColor := 0;
  oldDataSet := GDVars.dataSet;
  GDVars.dataSet := 1;
  GDVars.zone1^.savedDataSet := GDVars.dataSet;
  GDVars.partyShip := @GDVars.zone0^.ship;
  SaveLoad.LoadShipData(GDVars.partyShip, GameInit.PARTY_SHIP_ID);
  GDVars.dataSet := oldDataSet;
  GDVars.orbitView := nil;
  GDVars.orbitView := @GDVars.zone0^.orbitBodies;
  with GDVars.orbitView^ do begin
    phase := 0;
    tick := 0;
    with GDConsts.orbitPositions[GDConsts.orbitStartPhases[GameInit.START_ORBIT] +
      GDConsts.orbitFirstPositions[GameInit.START_ORBIT]] do begin
      rocketX := x;
      rocketY := y;
      rocketIcon := C_Orbit.FIRST_ROCKET_ICON
    end
  end
end;

procedure InitializeGame;
var
  { Unused in this version; see the other implementations of this routine. }
  messageText: string;
begin
  for GDVars.index := 0 to SizeOf(GDConsts.defaultPalette) div SizeOf(Types.TRgb) - 1 do begin
    for GDVars.component := 0 to SizeOf(Types.TRgb) - 1 do
      GDVars.picturePalette[GDVars.index, GDVars.component] := GDConsts.defaultPalette[GDVars.index, GDVars.component];
    GDVars.paletteNibbles[GDVars.index] := GDVars.index
  end;
  for GDVars.index := 0 to 3 do
    GDVars.nibbleCgaColors[GDVars.index] := GDVars.index;
  Blit.ShadowPaletteEntries(0, 15, GDVars.combatPalette);
  Blit.ShadowPaletteEntries(0, 15, GDVars.viewPalette);
  Blit.SetDacPalette(0, 15, GDVars.picturePalette);
  biosKbdFlags := biosKbdFlags or GameInit.NUM_LOCK;
  Randomize;
  if GDVars.isMouseOn then begin
    GDVars.canClickParty := True;
    GDVars.mouseButtons := 0;
    GDVars.clearedBeforeMouseReset := 0;
    Mouse.InitMouse;
    if GDVars.isMouseOn then begin
      GDVars.isMouseScaled := True;
      if GDVars.displayMode = C_Vm.CGA then
        GDVars.mouseCursorMask := @GDConsts.cgaArrowCursor
      else
        GDVars.mouseCursorMask := @GDConsts.arrowCursor;
      Mouse.SetMouseCursor(0, 0, GDVars.mouseCursorMask);
      Mouse.SetMouse(639, 100);
      Mouse.GetMouse(GDVars.mBtn, GDVars.mX, GDVars.mY);
      { a driver that reports x 321 or more after SetMouse(639, ..) counts in 640-wide units, which Mouse halves }
      GDVars.isMouseScaled := (GDVars.mX >= 321) = False;
      Mouse.ShowMouse;
    end;
    GDVars.mouseX := 160;
    GDVars.mouseY := 100;
    Mouse.SetMouse(GDVars.mouseX, GDVars.mouseY);
    GDVars.mouseOldX := 0;
    GDVars.mouseOldY := 0;
  end;
  if GDVars.isJoystickOn then begin
    GDVars.joystickCenterX := 160;
    GDVars.joystickCenterY := 100;
  end;
  GetMem(GDVars.zone0, SizeOf(Types.TZone0));
  GetMem(GDVars.zone1, SizeOf(Types.TZone1));
  GetMem(GDVars.zone2, SizeOf(Types.TZone2));
  GetMem(GDVars.zone3, SizeOf(Types.TZone3));
  { Note: TextRend.LoadGameFont moves the whole 2048-byte font record into this 1416-byte block and overruns it; readers
    use only glyphs 0..63. }
  GetMem(GDVars.gameFont, GameInit.FONT_GLYPHS * SizeOf(Types.TGlyph));
  GetMem(GDVars.wallDefs, GameInit.WALL_BANKS * SizeOf(Types.TWallDef));
  GetMem(GDVars.geoMap, SizeOf(Types.TGeoMap));
  Blit.AllocPic(8, 1, 1, 0, GDVars.tileScratch);
  Blit.AllocPic(8, 1, 1, 0, GDVars.savedWildernessCell);
  Blit.AllocPic(8, 1, 1, 0, GDVars.wildernessCursorCell);
  GDVars.cursorPicture := nil;
  Blit.AllocPic(200, 40, 1, 0, GDVars.viewPicture);
  Blit.AllocPic(24, 3, 1, 0, GDVars.saveUnder);
  FillChar(GDVars.dirtyRows, SizeOf(GDVars.dirtyRows), 0);
  FillChar(GDVars.dirtyRowLeft, SizeOf(GDVars.dirtyRowLeft), 0);
  FillChar(GDVars.dirtyRowFirst, SizeOf(GDVars.dirtyRowFirst), $FF);
  FillChar(GDVars.dirtyRowLast, SizeOf(GDVars.dirtyRowLast), 0);
  for GDVars.index := 0 to SizeOf(GDVars.cgaRowSegments) div SizeOf(Word) - 1 do begin
    if Odd(GDVars.index) then
      GDVars.cgaRowSegments[GDVars.index] := (GDVars.index div 2) * 5 + $BA00
    else
      GDVars.cgaRowSegments[GDVars.index] := (GDVars.index div 2) * 5 + $B800;
    GDVars.egaRowOffsets[GDVars.index] := GDVars.index * SizeOf(Types.TEgaRow);
    case GDVars.index mod 4 of
      0: GDVars.tandyRowSegments[GDVars.index] := (GDVars.index div 4) * 10 + $B800;
      1: GDVars.tandyRowSegments[GDVars.index] := (GDVars.index div 4) * 10 + $BA00;
      2: GDVars.tandyRowSegments[GDVars.index] := (GDVars.index div 4) * 10 + $BC00;
      3: GDVars.tandyRowSegments[GDVars.index] := (GDVars.index div 4) * 10 + $BE00;
    end;
  end;
  FillChar(GDVars.backdropPictures, SizeOf(GDVars.backdropPictures), 0);
  FillChar(GDVars.tileSets, SizeOf(GDVars.tileSets), 0);
  FillChar(GDVars.arenaTiles, SizeOf(GDVars.arenaTiles), 0);
  FillChar(GDVars.shipPictureBuffers, SizeOf(GDVars.shipPictureBuffers), 0);
  FillChar(GDVars.zone0^, SizeOf(Types.TZone0), 0);
  GDVars.zone0^.difficulty := C_Diff.DIFFICULTY_TROOPER;
  GDVars.zone0^.areaType := 1;
  GDVars.zone0^.stateValue := C_Ecl.NO_ECL_SCRIPT;
  FillChar(GDVars.zone1^, SizeOf(Types.TZone1), 0);
  FillChar(GDVars.zone2^, SizeOf(Types.TZone2), 0);
  FillChar(GDVars.zone3^, SizeOf(Types.TZone3), 0);
  FillChar(GDVars.iconFrames, SizeOf(GDVars.iconFrames), 0);
  for GDVars.index := 1 to SizeOf(GDVars.portraitSlots) div SizeOf(Types.TPortraitCacheSlot) do begin
    GDVars.portraitSlots[GDVars.index].pictureId := C_Pic.EMPTY_PORTRAIT_SLOT;
    GDVars.portraitSlots[GDVars.index].pic := nil
  end;
  FillChar(GDVars.displayCounter, SizeOf(GDVars.displayCounter), 0);
  FillChar(GDVars.vgaAnimation, SizeOf(GDVars.vgaAnimation), 0);
  FillChar(GDVars.imageFrames, SizeOf(GDVars.imageFrames), 0);
  FillChar(GDVars.portraitAnimation, SizeOf(GDVars.portraitAnimation), 0);
  GDVars.bigPicture := nil;
  GDVars.availableItems := nil;
  FillChar(GDVars.partyPosition, SizeOf(GDVars.partyPosition), 0);
  GDVars.partyPosition.mapX := GameInit.START_MAP_X;
  GDVars.partyPosition.mapY := GameInit.START_MAP_Y;
  GDVars.partyPosition.facing := C_Dir.NORTH;
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  FillChar(GDVars.wallSets, SizeOf(GDVars.wallSets), 0);
  GDVars.isGameUp := False;
  GDVars.combatDebugPassword := GDConsts.shipNames[2, 1];
  GDVars.animationsEnabled := 1;
  GDVars.picturesEnabled := 1;
  GDVars.isDebugMode := False;
  GDVars.messageDelay := 1;
  GDVars.hasLoadedSave := 0;
  GDVars.restTicks := 0;
  GDVars.partyHead := nil;
  GDVars.currentCharacter := nil;
  GDVars.partyRowCharacter := nil;
  GDVars.eclIp := $8000;
  GDVars.zone0^.messageSpeed := GameInit.START_MESSAGE_SPEED;
  GDVars.demoMode := False;
  GDVars.dataSet := 1;
  GDVars.savedDataSet := 1;
  GDVars.automapOn := 0;
  LastMode := CO40;
  GDVars.zone1^.partyCount := 0;
  GDVars.vertTop := 1;
  GDVars.soloCombat := 0;
  GDVars.combatLineLowered := 0;
  GDVars.savedSearchFlag := 0;
  GDVars.eclDisplaying := 0;
  GDVars.picturePending := False;
  GDVars.partyDefeated := 0;
  GDVars.clipFlag := 1;
  GDVars.monsterSpriteShown := 0;
  GDVars.suppressDiskPrompt := 0;
  GDVars.picArcName[0] := #0;
  GDVars.savedPicArcName[0] := #0;
  GDVars.picArcId := C_Pic.NO_ANIMATION;
  GDVars.savedPicArcId := C_Pic.NO_ANIMATION;
  GDVars.gameSaved := 0;
  GDVars.horizonColorCode := $E8;
  GDVars.floorColorCode := $DB;
  GDVars.inEncounterMenu := 0;
  GDVars.selectorMode := False;
  GDVars.mapVisible := 1;
  GDVars.bigPictureId := C_Pic.NO_BIG_PICTURE;
  GDVars.freeTraining := 0;
  GDVars.horizChoice := 1;
  GDVars.interfaceState := C_Ifc.VIEW_3D;
  GDVars.previousInterfaceState := 0;
  GDVars.overrideFlag := 0;
  GDVars.bigPictureShown := 0;
  GDVars.victoryStart := 0;
  GDVars.inMoveMenu := 0;
  GDVars.cursorActive := 0;
  GDVars.moveMode := 0;
  GDVars.isMouseClick := False;
  GDVars.modifyActive := 0;
  GDVars.hasCenturyPassed := False;
  GDVars.musicEnabled := True;
  GDVars.savedSoundState := C_Sound.DRIVER_NONE;
  GDVars.soundState := C_Sound.DRIVER_NONE;
  GDVars.driverReady := 0;
  TextRend.LoadGameFont;
  TextRend.DisplayLoading;
  Sym8x8.Load8x8Set(0, 6);
  Sym8x8.Load8x8Set(202, 4);
  Blit.ShadowPaletteEntries(C_Pic.VIEW_DAC_FIRST, C_Pic.VIEW_DAC_COUNT, GDVars.viewPalette);
  Blit.SetDacPalette(C_Pic.VIEW_DAC_FIRST, C_Pic.VIEW_DAC_COUNT, GDVars.picturePalette);
  for GDVars.index := 1 to 25 do
    MapTiles.LoadIconAnim('COMSPR', GDVars.index, GDVars.index + GameInit.FIRST_COMSPR_ICON_ROW - 1);
  Blit.ShadowPaletteEntries($40, 32, GDVars.combatPalette);
  Blit.LoadPic('cursor', 1, True, C_Pic.KEY_COLOR, GDVars.cursorPicture);
  GDVars.hasOpenedItems := DaxIo.OpenWithRetry('ITEMS', GDConsts.diskPrompts[GDVars.dataSet], 0, GDVars.itemsFile);
  Reset(GDVars.itemsFile, 1);
  BlockRead(GDVars.itemsFile, GDVars.itemTypes, SizeOf(GDVars.itemTypes), GDVars.itemsRead);
  Close(GDVars.itemsFile);
  EffHndlr.InitEffectHandlers;
  EclMenu.LoadItemTemplates;
  GDVars.enemyShip := nil;
  GDVars.orbitPicturesLoaded := 0;
  GDVars.shipPictureBuffersLoaded := 0;
  GameInit.InitShipAndOrbit;
  GDVars.driverAllocSize := 0;
  GDVars.driverAlloc := nil;
  GDVars.driverImage := nil;
  GDVars.xmiData := nil;
  GDVars.xmiSize := 0;
  GDVars.activeSequence := 0;
  GDVars.driverHandle := 0;
  FillChar(GDVars.driverDesc, SizeOf(GDVars.driverDesc), 0);
  GDVars.timbreCacheSize := 0;
  GDVars.timbreCache := nil;
  for GDVars.index := 0 to SizeOf(GDVars.stateTables) div SizeOf(Pointer) - 1 do begin
    GDVars.sequenceHandles[GDVars.index] := 0;
    GDVars.stateTables[GDVars.index] := nil
  end;
  GDVars.stateAllocSize := 0;
end;

procedure ResetGameState;
begin
  GDVars.isGameUp := True;
  FillChar(GDVars.dirtyRows, SizeOf(GDVars.dirtyRows), 0);
  FillChar(GDVars.dirtyRowLeft, SizeOf(GDVars.dirtyRowLeft), 0);
  FillChar(GDVars.dirtyRowFirst, SizeOf(GDVars.dirtyRowFirst), $FF);
  FillChar(GDVars.dirtyRowLast, SizeOf(GDVars.dirtyRowLast), 0);
  FillChar(GDVars.zone0^, SizeOf(Types.TZone0), 0);
  GDVars.zone0^.difficulty := C_Diff.DIFFICULTY_TROOPER;
  GDVars.zone0^.areaType := 1;
  GDVars.zone0^.stateValue := C_Ecl.NO_ECL_SCRIPT;
  FillChar(GDVars.zone1^, SizeOf(Types.TZone1), 0);
  FillChar(GDVars.zone2^, SizeOf(Types.TZone2), 0);
  FillChar(GDVars.zone3^, SizeOf(Types.TZone3), 0);
  FillChar(GDVars.partyPosition, SizeOf(GDVars.partyPosition), 0);
  GDVars.partyPosition.mapX := GameInit.START_MAP_X;
  GDVars.partyPosition.mapY := GameInit.START_MAP_Y;
  GDVars.partyPosition.facing := C_Dir.EAST;
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  GDVars.canClickParty := True;
  GDVars.wallSets[1].fileId := 0;
  GDVars.wallSets[1].slot := 1;
  for GDVars.index := 2 to 3 do begin
    GDVars.wallSets[GDVars.index].fileId := C_Map.NO_WALL_SET_FILE;
    GDVars.wallSets[GDVars.index].slot := C_Map.NO_WALL_SET_SLOT;
  end;
  GDVars.isDebugMode := False;
  GDVars.messageDelay := 1;
  GDVars.hasLoadedSave := 0;
  GDVars.restTicks := 0;
  GDVars.partyHead := nil;
  GDVars.currentCharacter := nil;
  GDVars.partyRowCharacter := nil;
  GDVars.eclIp := $8000;
  GDVars.zone0^.messageSpeed := GameInit.START_MESSAGE_SPEED;
  GDVars.dataSet := 1;
  GDVars.zone1^.savedDataSet := GDVars.dataSet;
  GDVars.savedDataSet := 1;
  GDVars.automapOn := 0;
  LastMode := CO40;
  GDVars.zone1^.partyCount := 0;
  GDVars.vertTop := 1;
  GDVars.soloCombat := 0;
  GDVars.combatLineLowered := 0;
  GDVars.savedSearchFlag := 0;
  GDVars.eclDisplaying := 0;
  GDVars.picturePending := False;
  GDVars.partyDefeated := 0;
  GDVars.clipFlag := 1;
  GDVars.monsterSpriteShown := 0;
  GDVars.suppressDiskPrompt := 0;
  GDVars.picArcName[0] := #0;
  GDVars.savedPicArcName[0] := #0;
  GDVars.picArcId := C_Pic.NO_ANIMATION;
  GDVars.savedPicArcId := C_Pic.NO_ANIMATION;
  GDVars.gameSaved := 0;
  GDVars.horizonColorCode := $E8;
  GDVars.floorColorCode := $DB;
  GDVars.inEncounterMenu := 0;
  GDVars.mapVisible := 1;
  GDVars.bigPictureId := C_Pic.NO_BIG_PICTURE;
  GDVars.freeTraining := 0;
  TextRend.ClearStatusLine;
  GDVars.horizChoice := 1;
  GDVars.interfaceState := C_Ifc.VIEW_3D;
  GDVars.previousInterfaceState := 0;
  GDVars.overrideFlag := 0;
  GDVars.victoryStart := 0;
  GDVars.inMoveMenu := 0;
  GDVars.cursorActive := 0;
  GDVars.moveMode := 0;
  GDVars.isMouseClick := False;
  GDVars.selectorMode := False;
  GDVars.modifyActive := 0;
  GDVars.bigPictureShown := 0;
  GDVars.hasCenturyPassed := False;
  GameInit.InitShipAndOrbit;
end;

begin
end.
