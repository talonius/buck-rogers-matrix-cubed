{ Moving the party: steps in the 3-D view and the wilderness and the rocket on the orbit map; the map main menu, with
  its change, party-order, level and message-speed menus; and the rest menu. Its menu lines, message-speed words and
  orbit-map steps are GDConsts', and the state it moves is GDVars' and zones 0 and 1. }
{$O+,F+,V-}
unit Explore;

interface

{ Makes the move the map menu chose, by interfaceState: a step ahead in C_Ifc.VIEW_3D, a wilderness step in
  C_Ifc.WILDERNESS or a rocket move in C_Ifc.ORBIT_MAP. A moveBlocked of 255 cancels it once instead. }
procedure ResolveMovement;

{ Runs the main menu of the 3-D view (C_Ifc.VIEW_3D), the orbit map (C_Ifc.ORBIT_MAP) or the wilderness
  (C_Ifc.WILDERNESS), with each one's move mode; on the way out it clears the text window while the bottom line is not
  marked clear.
  @returns(In the 3-D view the menu's last key, or #0 after a step or turn; on the orbit map 'M', the only key that ends
    its menu, but in move mode no key is read and the result is left unset; in the wilderness the last key, or a keypad
    key after a click.) }
function MapMainMenu: Char;

{ The rest menu: each Rest is GameTime's RestAndHeal(1), a day on the clock and a hit point for each okay or unconscious
  member, until Exit. }
procedure RestMenu;

implementation

uses View3D, Music, Crt, GameTime, Mouse, MapCurs, GameIo, Blit, MenuCore, CharHlp, TextRend, CbtMap, Portrait,
  OrbitMap, ViewChar, CharGen, SaveLoad, Types, C_Menu, C_Orbit, C_Pic, C_Search, GDConsts, GDVars, C_Dir, C_Sys, C_Ifc,
  C_Diff, C_Keys, C_Msg, C_Time;

const
  { GameTime's clock unit of ten minutes, which a step while searching and Look advance the clock by }
  TIME_TURN = 2;
  { GameTime's clock unit of an hour; a wilderness step advances the clock twelve of them }
  TIME_HOUR = 3;
  { TOrbitView.rocketIcon at the seventh heading after C_Orbit.FIRST_ROCKET_ICON, the rocket's last tile }
  LAST_ROCKET_ICON = 94;
  { zone1^.searchFlags: Look asks for one run of ECL entry point 2 }
  LOOK_PENDING = 2;
  { phase counts down through 0..PHASE_CYCLE - 1 and wraps }
  PHASE_CYCLE = 224;

{ Checks the step ahead: when the facing side has a barrier and the step would leave the 16 by 16 map, pins the party to
  that edge and sets zone 1's hasLeftMap. It does not move the party; ResolveMovement's MovePartyForward3D does. }
procedure MoveForward;
var
  nx: Integer;
  ny: Integer; face: Word;
begin
  nx := GDVars.partyPosition.mapX;
  ny := GDVars.partyPosition.mapY;
  face := GDVars.partyPosition.facing;
  GDVars.zone1^.hasLeftMap := 0;
  if View3D.GetBarrierType(nx, ny, face) <> 0 then begin
    Inc(nx, GDConsts.dirStepX[face]);
    Inc(ny, GDConsts.dirStepY[face]);
    if nx > SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then begin
      GDVars.partyPosition.mapX := SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
      GDVars.zone1^.hasLeftMap := 1
    end;
    if nx < 0 then begin GDVars.partyPosition.mapX := 0; GDVars.zone1^.hasLeftMap := 1 end;
    if ny > SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then begin
      GDVars.partyPosition.mapY := SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
      GDVars.zone1^.hasLeftMap := 1
    end;
    if ny < 0 then begin GDVars.partyPosition.mapY := 0; GDVars.zone1^.hasLeftMap := 1 end
  end
end;

{ Steps the party ahead with the step sound, wrapping at the map's edges, refreshes the wall-ahead and event bytes,
  resets doorOpen, and advances the clock a turn while searching, else a minute. }
procedure MovePartyForward3D;
begin
  Music.SendSoundCommand(GDConsts.stepSound);
  Delay(50);
  Inc(GDVars.partyPosition.mapX, GDConsts.dirStepX[GDVars.partyPosition.facing]);
  Inc(GDVars.partyPosition.mapY, GDConsts.dirStepY[GDVars.partyPosition.facing]);
  if GDVars.partyPosition.mapX < 0 then GDVars.partyPosition.mapX := SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
  if GDVars.partyPosition.mapX > SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then GDVars.partyPosition.mapX := 0;
  if GDVars.partyPosition.mapY < 0 then
    GDVars.partyPosition.mapY := SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
  if GDVars.partyPosition.mapY > SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then
    GDVars.partyPosition.mapY := 0;
  GDVars.partyPosition.wallAhead := View3D.GetWallType(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                                         GDVars.partyPosition.facing);
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  GDVars.partyPosition.mapEvent := View3D.GetMapEvent(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY);
  if GDVars.zone1^.searchFlags and C_Search.SEARCHING > 0 then
    GameTime.AdvanceTime(1, Explore.TIME_TURN)
  else GameTime.AdvanceTime(1, C_Time.MINUTES)
end;

{ Moves the wilderness cursor one step along the facing, held to columns 0..37 and rows 0..14, and advances the clock 12
  hours. }
procedure MovePartyWilderness;
{ Unused in this version; see the other implementations of this routine. }
var col: Byte;
    nx: ShortInt;
    ny: ShortInt;
begin
  Mouse.HideMouse;
  MapCurs.RestoreCursorBackground;
  GDVars.zone0^.prevX := GDVars.zone0^.partyX;
  GDVars.zone0^.prevY := GDVars.zone0^.partyY;
  nx := GDVars.zone0^.partyX + GDConsts.dirStepX[GDVars.partyPosition.facing];
  ny := GDVars.zone0^.partyY + GDConsts.dirStepY[GDVars.partyPosition.facing];
  if nx < 0 then nx := 0;
  if nx > 37 then nx := 37;
  if ny < 0 then ny := 0;
  if ny > 14 then ny := 14;
  GDVars.zone0^.partyX := nx;
  GDVars.zone0^.partyY := ny;
  MapCurs.DrawCursor;
  Mouse.ShowMouse;
  GameTime.AdvanceTime(12, Explore.TIME_HOUR)
end;

{ Sets zone 0's difficulty from the level menu; a cursor key steps the current character instead. }
procedure CampDifficultyMenu;
var difficulty: Byte;
begin
  difficulty := GDVars.zone0^.difficulty;
  GDVars.horizChoice := difficulty + 1;
  GDVars.menuChecksum := C_Menu.KEEP_MENU_CHOICE;
  MenuCore.MenuHorizontal('', GDConsts.difficultyMenu, False, True);
  if GDVars.extFlag then begin
    CharHlp.DisplayRoster(GDVars.currentCharacter, False);
    ViewChar.SelectPrevNextChar(GDVars.menuKey);
    CharHlp.DisplayRoster(GDVars.currentCharacter, True)
  end else
    case GDVars.menuKey of
      'N': difficulty := C_Diff.DIFFICULTY_NOVICE;
      'C': difficulty := C_Diff.DIFFICULTY_CADET;
      'T': difficulty := C_Diff.DIFFICULTY_TROOPER;
      'V': difficulty := C_Diff.DIFFICULTY_VETERAN;
      'A': difficulty := C_Diff.DIFFICULTY_ACE
    end;
  GDVars.zone0^.difficulty := difficulty
end;

{ Shows the message speed with its word, and makes it faster or slower (also by the down and up keys) until Exit. }
procedure CampSpeedMenu;
var menuText: Types.TString40;
begin
  TextRend.ClearTextWindow;
  repeat
    GDVars.textLeft := GDVars.windowLeft;
    GDVars.windowTextRow := GDVars.windowTop;
    TextRend.DisplayWindowText(Black, '');
    TextRend.DisplayWindowText(LightGreen,
                               'Message Speed = ' + TextRend.ByteToString(GDVars.zone0^.messageSpeed) + ' (' +
                               GDConsts.speedWords[GDConsts.speedWordCodes[GDVars.zone0^.messageSpeed] shr 4] +
                               GDConsts.speedSuffixes[GDConsts.speedWordCodes[GDVars.zone0^.messageSpeed] and 3] +
                               ')   ');
    menuText := '';
    if GDVars.zone0^.messageSpeed > 0 then menuText := menuText + ' Faster';
    if GDVars.zone0^.messageSpeed < C_Msg.SLOWEST_MESSAGE_SPEED then menuText := menuText + ' Slower';
    menuText := menuText + ' Exit';
    MenuCore.MenuHorizontal('Message Speed:', menuText, False, True);
    if GDVars.extFlag then
      case GDVars.menuKey of
        C_Keys.DOWN: if GDVars.zone0^.messageSpeed > 0 then Dec(GDVars.zone0^.messageSpeed);
        C_Keys.UP: if GDVars.zone0^.messageSpeed <
          C_Msg.SLOWEST_MESSAGE_SPEED then Inc(GDVars.zone0^.messageSpeed)
      end else
      case GDVars.menuKey of
        'F': Dec(GDVars.zone0^.messageSpeed);
        'S': Inc(GDVars.zone0^.messageSpeed)
      end
  until GDVars.menuKey in [C_Keys.NONE, 'E'];
  TextRend.ClearTextWindow
end;

{ Moves currentCharacter one place up the party list; from the top it goes to the bottom. }
procedure OrderMoveUp;
var
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  nxt: Types.PCharRecord;
begin
  p := GDVars.partyHead;
  prev := nil;
  if p = GDVars.currentCharacter then
    while p^.nextCharAddr <> nil do p := p^.nextCharAddr
  else
    while p^.nextCharAddr <> GDVars.currentCharacter do begin prev := p; p := p^.nextCharAddr end;
  nxt := GDVars.currentCharacter^.nextCharAddr;
  if GDVars.partyHead = GDVars.currentCharacter then begin
    if nxt <> nil then GDVars.partyHead := nxt;
    p^.nextCharAddr := GDVars.currentCharacter;
    GDVars.currentCharacter^.nextCharAddr := nil
  end else begin
    p^.nextCharAddr := nxt;
    GDVars.currentCharacter^.nextCharAddr := p;
    if (p = GDVars.partyHead) or (prev = nil) then GDVars.partyHead := GDVars.currentCharacter
    else prev^.nextCharAddr := GDVars.currentCharacter
  end
end;

{ Moves currentCharacter one place down the party list; from the bottom it goes to the top. }
procedure OrderMoveDown;
var
  p: Types.PCharRecord;
  nxt: Types.PCharRecord;
begin
  p := GDVars.partyHead;
  if p <> GDVars.currentCharacter then
    while p^.nextCharAddr <> GDVars.currentCharacter do p := p^.nextCharAddr;
  nxt := GDVars.currentCharacter^.nextCharAddr;
  if nxt = nil then begin
    GDVars.currentCharacter^.nextCharAddr := GDVars.partyHead;
    GDVars.partyHead := GDVars.currentCharacter;
    p^.nextCharAddr := nxt
  end else begin
    GDVars.currentCharacter^.nextCharAddr := nxt^.nextCharAddr;
    if GDVars.partyHead = GDVars.currentCharacter then GDVars.partyHead := nxt;
    if p <> GDVars.currentCharacter then p^.nextCharAddr := nxt;
    nxt^.nextCharAddr := GDVars.currentCharacter
  end
end;

{ Runs the party-order menu: a member is picked with Select or a click, then moved with the up and down keys, or put
  ahead of another member by clicking that one. Ends on Exit. }
procedure PartyOrderMenu;
var selected: ShortInt; savedCurChar: Types.PCharRecord; p: Types.PCharRecord;
begin
  selected := 0;
  GDVars.menuKey := ' ';
  GDVars.inPartyOrderMenu := 1;
  while not (GDVars.menuKey in [C_Keys.NONE, 'E']) do begin
    savedCurChar := GDVars.currentCharacter;
    MenuCore.MenuHorizontal('Party Order: ', GDConsts.partyOrderMenus[selected], True, True);
    if savedCurChar <> GDVars.currentCharacter then begin
      selected := Ord(selected = 0);
      if selected <> 0 then
        CharHlp.PrintCreatureMessage(GDVars.currentCharacter, 'has been selected', 10, False)
      else begin
        if (savedCurChar <> nil) and (GDVars.currentCharacter <> nil) then begin
          if savedCurChar = GDVars.partyHead then GDVars.partyHead := savedCurChar^.nextCharAddr
          else begin
            p := GDVars.partyHead;
            while (p^.nextCharAddr <> savedCurChar) and (p <> nil) do p := p^.nextCharAddr;
            if p^.nextCharAddr = savedCurChar then p^.nextCharAddr := savedCurChar^.nextCharAddr
            else TextRend.DisplayValue('lost pc in alterpartyorder', 0)
          end;
          savedCurChar^.nextCharAddr := GDVars.currentCharacter;
          if GDVars.currentCharacter = GDVars.partyHead then GDVars.partyHead := savedCurChar
          else begin
            p := GDVars.partyHead;
            while (p^.nextCharAddr <> GDVars.currentCharacter) and (p <> nil) do p := p^.nextCharAddr;
            if p^.nextCharAddr = GDVars.currentCharacter then p^.nextCharAddr := savedCurChar
            else TextRend.DisplayValue('lost olddude in alterpartyorder', 0)
          end
        end;
        MenuCore.DisplayParty(GDVars.currentCharacter)
      end
    end else if GDVars.extFlag then begin
      if selected = 0 then begin
        CharHlp.DisplayRoster(GDVars.currentCharacter, False);
        ViewChar.SelectPrevNextChar(GDVars.menuKey);
        CharHlp.DisplayRoster(GDVars.currentCharacter, True)
      end else begin
        case GDVars.menuKey of C_Keys.UP: Explore.OrderMoveUp; C_Keys.DOWN: Explore.OrderMoveDown end;
        MenuCore.DisplayParty(GDVars.currentCharacter)
      end
    end else if GDVars.menuKey in [C_Keys.ENTER, 'P', 'S'] then begin
      selected := Ord(selected = 0);
      if selected <> 0 then
        CharHlp.PrintCreatureMessage(GDVars.currentCharacter, 'has been selected', 10, False)
      else CharHlp.ClearMessageWindow
    end
  end;
  GDVars.inPartyOrderMenu := 0;
  CharHlp.ClearMessageWindow
end;

{ The Change menu: party order and purge (not on the orbit map), message speed, the animation switch and the difficulty
  level, until Exit; a cursor key steps the current character. }
procedure CampAlterMenu;
var choice: Char;
    { Unused in this version; see the other implementations of this routine. }
    toggleChoice: Byte;
    menuText: Types.TString40;
begin
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do begin
    if GDVars.interfaceState = C_Ifc.ORBIT_MAP then menuText := '' else menuText := GDConsts.changeMenuHead;
    MenuCore.MenuHorizontal('', menuText + GDConsts.changeMenuTail, False, True);
    choice := GDVars.menuKey;
    if GDVars.extFlag then begin
      CharHlp.DisplayRoster(GDVars.currentCharacter, False);
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.DisplayRoster(GDVars.currentCharacter, True)
    end else
      case choice of
        'O': Explore.PartyOrderMenu;
        'P': CharGen.DropCharacterMenu;
        'M': Explore.CampSpeedMenu;
        'A': begin
          GDVars.animationsEnabled := Ord(GDVars.animationsEnabled = 0);
          if GDVars.animationsEnabled <> 0 then
            CharHlp.PrintBottomLine('Animation on')
          else CharHlp.PrintBottomLine('Animation off')
        end;
        'L': Explore.CampDifficultyMenu
      end
  end
end;

{ Reads one rocket move on the orbit map, by key or click, and makes it: turns the rocket to the heading, steps it
  (never onto the center body), rests the team three days and, each time the tick reaches 32, moves the bodies on a
  phase.
  @param(isFromMenu True, the map menu's call in move mode, returns at once.) }
procedure MoveRocket(isFromMenu: Boolean);
var
  target: Byte;
  dir: Byte;
  ticks: Byte; step: ShortInt;
    { Unused in this version; see the other implementations of this routine. }
    distanceText: array[0..3] of Byte;
    fuelText: String[4];
    { Unused in this version; see the other implementations of this routine. }
    heading: Byte;
begin
  if isFromMenu then Exit;
  with GDVars.orbitView^ do begin
  GDVars.savedCursorX := rocketX;
  GDVars.savedCursorY := rocketY;
  Str(GDVars.partyShip^.systemNow[C_Sys.FUEL]:0, fuelText);
  MenuCore.MenuHorizontal('En route. Fuel = ' + fuelText + ' ', 'Done', True, False);
  target := C_Dir.CENTER;
  case GDVars.menuKey of
    C_Keys.PAGE_UP: target := 7; C_Keys.UP: target := 0;
    C_Keys.PAGE_DOWN: target := 5; C_Keys.RIGHT: target := 6;
    C_Keys.END_KEY: target := 3; C_Keys.DOWN: target := 4;
    C_Keys.HOME: target := 1; C_Keys.LEFT: target := 2;
    { Note: meant as Escape, which MenuHorizontal answers as NONE }
    'D', C_Keys.NONE, C_Keys.ENTER, C_Keys.RIGHT_BRACKET:
      if GDVars.isMouseClick and (GDVars.mouseY <= 176) and
          (GDVars.mouseX >= C_Orbit.MAP_LEFT * 8) then begin
        target := CbtMap.DirectionBetween(rocketX, rocketY, GDVars.mouseX div 8 - C_Orbit.MAP_LEFT,
                                          GDVars.mouseY div 8 - C_Orbit.MAP_TOP);
        { DirectionBetween counts clockwise, mapStepX counterclockwise }
        target := (-target) and 7
      end else GDVars.moveMode := 0
  end;
  if target < C_Dir.CENTER then begin
    Mouse.HideMouse;
    dir := target + C_Orbit.FIRST_ROCKET_ICON;
    if ((dir < rocketIcon) and (dir >= rocketIcon - 4)) or (dir >= rocketIcon + 4) then step := -1 else step := 1;
    while rocketIcon <> dir do begin
      Inc(rocketIcon, step);
      if rocketIcon < C_Orbit.FIRST_ROCKET_ICON then rocketIcon := Explore.LAST_ROCKET_ICON
      else if rocketIcon > Explore.LAST_ROCKET_ICON then rocketIcon := C_Orbit.FIRST_ROCKET_ICON;
      OrbitMap.RedrawOrbitCursor;
      Delay(100)
    end;
    Inc(rocketX, GDConsts.mapStepX[target]);
    if rocketX = 255 then rocketX := 0
    else if rocketX > 21 then rocketX := 21;
    Inc(rocketY, GDConsts.mapStepY[target]);
    if rocketY = 255 then rocketY := 0
    else if rocketY > 21 then rocketY := 21;
    if (rocketX = C_Orbit.CENTER_X) and (rocketY = C_Orbit.CENTER_Y) then begin
      Dec(rocketX, GDConsts.mapStepX[target]);
      Dec(rocketY, GDConsts.mapStepY[target])
    end;
    OrbitMap.RedrawOrbitCursor;
    ticks := 3;
    Inc(tick, ticks);
    GameTime.RestAndHeal(3);
    if tick > 32 - 1 then begin
      Dec(tick, 32);
      if phase = 0 then phase := Explore.PHASE_CYCLE;
      Dec(phase);
      OrbitMap.PaintOrbitMap
    end;
    Mouse.ShowMouse
  end
  end
end;

{ Saves the game, then offers to quit to DOS. }
procedure SaveQuit;
begin
  SaveLoad.SaveGame;
  GDVars.promptColor := Yellow;
  if MenuCore.YesNoMenu('Quit TO DOS ', C_Menu.DEFAULT_NO) = 'Y' then
    GameIo.ExitGame
end;

function MapMainMenu: Char;
var done: Boolean; c: Char;
    { Unused in this version; see the other implementations of this routine. }
    ext: Byte;
    { Unused in this version; see the other implementations of this routine. }
    menuText: array[0..39] of Byte;
    { ViewChar's ViewCharMenu's done flag, not read here }
    isSheetDone: Boolean;
    { Unused in this version; see the other implementations of this routine. }
    oldZone: Pointer;
    { Unused in this version; see the other implementations of this routine. }
    savedZone: Pointer;
    { Unused in this version; see the other implementations of this routine. }
    savedOrbit: Pointer;
    picture: ShortInt;
begin
  GDVars.zone1^.moveBlocked := 0;
  case GDVars.interfaceState of
    C_Ifc.VIEW_3D: begin
      done := False;
      c := C_Keys.NONE;
      repeat
        if GDVars.moveMode = 0 then begin
          GDVars.canClickParty := True;
          MenuCore.MenuHorizontal('', GDConsts.dungeonMenu, True, True);
          GDVars.canClickParty := False;
          c := GDVars.menuKey;
          if not GDVars.extFlag then
            case c of
              'M': begin
                TextRend.ClearStatusLine;
                GDVars.moveMode := 1
              end;
              'A': if GDVars.zone0^.areaLock = 0 then begin
                     GDVars.automapOn := Ord(GDVars.automapOn = 0);
                     View3D.Display3DMapView(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                             GDVars.partyPosition.facing)
                   end else begin
                     TextRend.PrintAndPause('Not Here', Yellow, Black);
                     CharHlp.PrintMiscInfo
                   end;
              'V': begin
                ViewChar.ViewCharMenu(isSheetDone);
                CharHlp.DisplayNoncombatInterface
              end;
              'S': Explore.SaveQuit;
              'C': Explore.CampAlterMenu;
              'L': begin
                GDVars.zone1^.searchFlags := GDVars.zone1^.searchFlags or Explore.LOOK_PENDING;
                CharHlp.PrintMiscInfo;
                GameTime.AdvanceTime(1, Explore.TIME_TURN);
                GDVars.eclIp := GDVars.eclEntryPoints[2];
                done := True
              end
            end else begin
            CharHlp.DisplayRoster(GDVars.currentCharacter, False);
            ViewChar.SelectPrevNextChar(c);
            CharHlp.DisplayRoster(GDVars.currentCharacter, True);
            CharHlp.PrintMiscInfo
          end
        end else begin
          MenuCore.MenuHorizontal('', 'Exit', True, False);
          c := GDVars.menuKey;
          if not GDVars.extFlag then begin
            case c of 'E': GDVars.moveMode := 0 end
          end else begin
            case c of
              C_Keys.UP: begin
                Explore.MoveForward;
                done := True;
                CharHlp.PrintMiscInfo;
                c := C_Keys.NONE
              end;
              C_Keys.DOWN: begin
                GDVars.partyPosition.facing := (GDVars.partyPosition.facing + 4) mod 8;
                GDVars.partyPosition.wallAhead := View3D.GetWallType(GDVars.partyPosition.mapX,
                                                                       GDVars.partyPosition.mapY,
                                                                       GDVars.partyPosition.facing);
                View3D.Display3DMapView(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                        GDVars.partyPosition.facing);
                CharHlp.PrintMiscInfo;
                c := C_Keys.NONE
              end;
              C_Keys.LEFT: begin
                GDVars.partyPosition.facing := (GDVars.partyPosition.facing + 6) mod 8;
                Music.SendSoundCommand(GDConsts.stepSound);
                GDVars.partyPosition.wallAhead := View3D.GetWallType(GDVars.partyPosition.mapX,
                                                                       GDVars.partyPosition.mapY,
                                                                       GDVars.partyPosition.facing);
                View3D.Display3DMapView(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                        GDVars.partyPosition.facing);
                CharHlp.PrintMiscInfo;
                c := C_Keys.NONE
              end;
              C_Keys.RIGHT: begin
                GDVars.partyPosition.facing := (GDVars.partyPosition.facing + 2) mod 8;
                Music.SendSoundCommand(GDConsts.stepSound);
                GDVars.partyPosition.wallAhead := View3D.GetWallType(GDVars.partyPosition.mapX,
                                                                       GDVars.partyPosition.mapY,
                                                                       GDVars.partyPosition.facing);
                View3D.Display3DMapView(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                        GDVars.partyPosition.facing);
                CharHlp.PrintMiscInfo;
                c := C_Keys.NONE
              end
            end;
          end
        end
      until done or (GDVars.partyDefeated <> 0)
    end;
    C_Ifc.ORBIT_MAP: if GDVars.moveMode <> 0 then Explore.MoveRocket(True) else begin
      repeat
        MenuCore.MenuHorizontal('', 'Move Rocket Change Save', False, True);
        c := GDVars.menuKey;
        if GDVars.extFlag then c := C_Keys.NONE
        else
          case c of
            'M': GDVars.moveMode := 1;
            'R': begin
              picture := GDVars.picArcId;
              GDVars.interfaceState := C_Ifc.SHIP;
              OrbitMap.LoadShipPictures;
              CharHlp.DisplayNoncombatInterface;
              TextRend.PauseContinue;
              GDVars.interfaceState := C_Ifc.ORBIT_MAP;
              OrbitMap.LoadOrbitPictures;
              if picture <> -1 then
                Portrait.LoadAnimation('PIC', picture, 0);
              CharHlp.DisplayNoncombatInterface
            end;
            'C': Explore.CampAlterMenu;
            'S': Explore.SaveQuit
          end
      until c = 'M'
    end;
    C_Ifc.WILDERNESS: begin
      done := False;
      repeat
        if GDVars.moveMode = 0 then begin
          MenuCore.MenuHorizontal('', 'Move Save', False, True);
          c := GDVars.menuKey;
          if not GDVars.extFlag then
            case c of
              'M': begin
                TextRend.ClearStatusLine;
                GDVars.moveMode := 1
              end;
              'S': Explore.SaveQuit
            end
        end else begin
          c := C_Keys.NONE;
          if c = C_Keys.NONE then begin
            MenuCore.MenuHorizontal('', 'Exit', True, False);
            c := GDVars.menuKey
          end;
          if not GDVars.extFlag then
            case c of
              'E': if GDVars.isMouseClick and (GDVars.mouseY <= 128) then begin
                     GDVars.partyPosition.facing := CbtMap.DirectionBetween(GDVars.zone0^.partyX,
                                                                              GDVars.zone0^.partyY,
                                                                              GDVars.mouseX div 8 - 1,
                                                                              GDVars.mouseY div 8 - 1);
                     { the key of keypad digit facing + 1 }
                     c := GDConsts.keypadScan[GDVars.partyPosition.facing];
                     done := True
                   end else GDVars.moveMode := 0
            end else begin
            done := True;
            case c of
              C_Keys.UP: GDVars.partyPosition.facing := C_Dir.NORTH;
              C_Keys.PAGE_UP: GDVars.partyPosition.facing := C_Dir.NORTHEAST;
              C_Keys.RIGHT: GDVars.partyPosition.facing := C_Dir.EAST;
              C_Keys.PAGE_DOWN: GDVars.partyPosition.facing := C_Dir.SOUTHEAST;
              C_Keys.DOWN: GDVars.partyPosition.facing := C_Dir.SOUTH;
              C_Keys.END_KEY: GDVars.partyPosition.facing := C_Dir.SOUTHWEST;
              C_Keys.LEFT: GDVars.partyPosition.facing := C_Dir.WEST;
              C_Keys.HOME: GDVars.partyPosition.facing := C_Dir.NORTHWEST
            end;
            CharHlp.PrintMiscInfo
          end
        end
      until done
    end
  end;
  if GDVars.bottomClear = 0 then begin
    TextRend.FillRect(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                      GDVars.windowColor);
    GDVars.bottomClear := 1
  end;
  MapMainMenu := c
end;

procedure ResolveMovement;
var canStep: Boolean;
    { Unused in this version; see the other implementations of this routine. }
    menuStr: array[0..40] of Byte;
begin
  canStep := False;
  case GDVars.interfaceState of
    C_Ifc.VIEW_3D: begin
      if GDVars.zone1^.moveBlocked < 255 then begin
        GDVars.portraitPending := 1;
        if View3D.GetBarrierType(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                 GDVars.partyPosition.facing)
            = 1 then canStep := True;
        if canStep then Explore.MovePartyForward3D;
        CharHlp.PrintMiscInfo
      end else GDVars.zone1^.moveBlocked := 0;
      Portrait.FreeAnimation;
      Blit.FreePic(GDVars.portraitSlots[1].pic);
      Blit.FreePic(GDVars.portraitSlots[2].pic);
      GDVars.portraitSlots[1].pictureId := C_Pic.EMPTY_PORTRAIT_SLOT;
      GDVars.portraitSlots[2].pictureId := C_Pic.EMPTY_PORTRAIT_SLOT
    end;
    C_Ifc.WILDERNESS: if GDVars.zone1^.moveBlocked < 255 then begin
      Explore.MovePartyWilderness;
      CharHlp.PrintMiscInfo
    end else GDVars.zone1^.moveBlocked := 0;
    C_Ifc.ORBIT_MAP: if GDVars.zone1^.moveBlocked < 255 then Explore.MoveRocket(False)
       else GDVars.zone1^.moveBlocked := 0
  end
end;

procedure RestMenu;
var c: Char;
begin
  repeat
    MenuCore.MenuHorizontal('', 'Rest Save Change Exit', False, True);
    c := GDVars.menuKey;
    if not GDVars.extFlag then
      case c of
        'R': begin
          CharHlp.PrintBottomLine('The team rests.');
          GameTime.RestAndHeal(1);
          MenuCore.DisplayParty(GDVars.currentCharacter)
        end;
        'S': Explore.SaveQuit;
        'C': Explore.CampAlterMenu
      end else begin
      CharHlp.DisplayRoster(GDVars.currentCharacter, False);
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayRoster(GDVars.currentCharacter, True);
      CharHlp.PrintMiscInfo
    end
  until (c = 'E') and not GDVars.extFlag
end;

begin
end.
