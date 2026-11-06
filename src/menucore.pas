{ The menu core: the party roster with armor class and hit points, the horizontal menu on the bottom lines, the vertical
  list menu in a window, the yes/no prompt, and the TMenuNode list helpers. The current horizontal option and the
  selected list line are drawn black on highlightColor. The menu state is GDVars': the choice, the answered key, the
  colors, the timeout, and the vertical menu's page, hot rows and click columns. The direction keys an arena click
  answers with are GDConsts'. }
{$O+,F+,S-}
{$A-}
unit MenuCore;

interface

uses Types, C_Menu, C_Screen, GDConsts, GDVars, Mouse, Border, CbtMap, Portrait, GameIo,
  Joystick, Crt, TextRend, C_Ifc, C_Keys, C_Side;

{ Writes character's name in its state's color: light red disabled, yellow on C_Side.HOSTILE in ground combat, light
  magenta with the experience for its next level (below level 21), else light cyan.
  @param(character The character named.)
  @param(column The text column.)
  @param(row The text row.)
  @param(isPossessive Adds 's.) }
procedure DisplayCreatureName(character: Types.PCharRecord; column, row: Byte; isPossessive: Boolean);

{ Draws the party roster with armor class and hit points, and sets the panel bounds a party click tests; not on the
  wilderness or orbit map or over a big picture.
  @param(highlight The character whose name is drawn in white.) }
procedure DisplayParty(highlight: Types.PCharRecord);

{ Writes character's armor class: 60 minus the stored value, negative above 60.
  @param(character The character.)
  @param(column The text column.)
  @param(row The text row.) }
procedure PrintArmorClass(character: Types.PCharRecord; column, row: Byte);

{ Writes character's hit points, in yellow while below the maximum, else white.
  @param(character The character.)
  @param(column The text column.)
  @param(row The text row.)
  @param(isHotPink Writes them in light magenta instead.)
  @param(showsMax Adds '/' and the maximum, padded on the left to 7 characters.) }
procedure PrintHitPoints(character: Types.PCharRecord; column, row: Byte; isHotPink, showsMax: Boolean);

{ Finds a list member by position.
  @param(n The 0-based position.)
  @param(list The list.)
  @returns(The member, nil past the end.) }
function FindListMember(n: Integer; list: Types.PMenuNode): Types.PMenuNode;

{ Shows query and menu on the bottom lines and waits for a choice; the choice is left in menuKey, an extended scan code
  when the extended-key flag is set. A menu's options start at its digits and capitals. With GDVars.menuTimeout
  non-zero, it answers GDVars.menuTimeoutKey once that many hundredths of a second pass from the call or the last
  portrait frame (input does not restart the count). Resets the three menu colors to their defaults.
  @param(query The text shown before the options.)
  @param(menu The options; '@' starts the second line.)
  @param(mapsDigitsToKeypad Returns '1'..'9' and '\' as extended keys: the keypad cursor keys' scan codes, a space for
    '5', scan code 55 for '\'.)
  @param(isAnimated Steps the portrait animation while it waits.) }
procedure MenuHorizontal(query, menu: String; mapsDigitsToKeypad, isAnimated: Boolean);

{ Shows a list in a window with MenuHorizontal's options below (menu, then Next and Prev as they apply, and Exit when
  offersExit), and lets the player move through it and choose.
  @param(query The text shown before the options.)
  @param(menu The options.)
  @param(ulCol The window's left column.)
  @param(ulRow The window's top row.)
  @param(lrCol The window's right column.)
  @param(lrRow The window's bottom row.)
  @param(list The members listed.)
  @param(offersExit Adds an Exit option.)
  @param(needsRedraw Draws the page first; cleared on return, except when list is nil.)
  @param(idx The selected member, 0-based, in and out.)
  @param(sel The chosen member, nil when none.)
  @returns(The key that chose, #0 for Escape or Exit.) }
function MenuVertical(query, menu: Types.TString40; ulCol, ulRow, lrCol, lrRow: ShortInt; list: Types.PMenuNode;
                      offersExit: Boolean; var needsRedraw: Boolean; var idx: Integer; var sel: Types.PMenuNode): Char;

{ Asks a question with Yes and No until one is chosen.
  @param(query The question.)
  @param(defaultChoice The option selected first, DEFAULT_YES or DEFAULT_NO.)
  @returns('Y' or 'N'.) }
function YesNoMenu(query: Types.TString40; defaultChoice: Byte): Char;

{ Allocates a list of empty members; the first is allocated before n is read, so an n below 1 gives one member.
  @param(n The number of members.)
  @param(list Receives the list.) }
procedure AllocStringList(n: Integer; var list: Types.PMenuNode);

{ Frees every member; list itself is left pointing at the freed first one.
  @param(list The list freed.) }
procedure FreeStringList(var list: Types.PMenuNode);

implementation

const
  { the text column and row the combat map view starts at: Blit's FlushView copies viewPicture one 8-pixel column in and
    eight scanlines down }
  VIEW_SCREEN_OFFSET = 1;
  { a menuHotRows entry with no selectable line }
  NO_HOT_ROW = 255;
  { menuClickLeft and menuClickRight with no vertical menu: no column selects }
  CLOSED_CLICK_LEFT = 127;
  CLOSED_CLICK_RIGHT = -128;

type
  { one horizontal-menu option: the indices of its first and last characters in the menu }
  TOptRange = record
    first: Byte;
    last: Byte;
  end;

function FindListMember(n: Integer; list: Types.PMenuNode): Types.PMenuNode;
var
  p: Types.PMenuNode;
  i: Integer;
begin
  i := 0;
  p := list;
  while (p <> nil) and (i <> n) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = n then
    FindListMember := p
  else
    FindListMember := nil;
end;

{ Counts a list's members.
  @param(list The list.)
  @returns(The number of members.) }
function ListCount(list: Types.PMenuNode): Integer;
var
  p: Types.PMenuNode;
  n: Integer;
begin
  n := 0;
  p := list;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

procedure MenuHorizontal(query, menu: String; mapsDigitsToKeypad, isAnimated: Boolean);
var
  frameTick: LongInt;
  { the deadlines are set but unused }
  deadline30: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  deadline80: LongInt;
  { the click's text column and row; a letter key reuses mouseCol as an option index }
  mouseCol: Integer;
  mouseRow: Integer;
  { a party row, a combat slot, a menuHotRows index, a menu character index, the joystick's zone }
  scratch: Byte;
  isDone: Boolean;
  mLen: Byte;
  qLen: Byte;
  opt: array[0..20] of TOptRange;
  walk: Types.PCharRecord;
  { WaitMouseRelease's GetMouse leaves the release position here, and HandleArenaClick puts the current cell in view in
    them }
  buttons: Integer;
  releaseX: Integer;
  releaseY: Integer;
  hasAt: Boolean;
  displayRow: Byte;
  spanCount: Byte;

  { Sums menu's characters; a new menu resets horizChoice to 1 unless menuChecksum is KEEP_MENU_CHOICE. }
  procedure TrackMenu;
  var
    sum: Byte;
    i: Byte;
  begin
    sum := 0;
    for i := Length(menu) downto 1 do
      Inc(sum, Ord(menu[i]));
    if (sum <> GDVars.menuChecksum) and (GDVars.menuChecksum <> C_Menu.KEEP_MENU_CHOICE) then
      GDVars.horizChoice := 1;
    GDVars.menuChecksum := sum;
  end;

  { Splits the menu into options, each opening at a digit or capital, counted in opt[0].last; an @ ends line one. }
  procedure ParseMenu;
  var
    wordIdx: Byte;
    i: Byte;
    len: Byte;
  begin
    FillChar(opt[1], SizeOf(opt) - SizeOf(TOptRange), 0);
    wordIdx := 1;
    len := Length(menu);
    for i := 1 to len do
      if menu[i] in ['0'..'9', 'A'..'Z'] then
        if opt[wordIdx].first = 0 then
          opt[wordIdx].first := i
        else begin
          opt[wordIdx].last := i - 2;
          Inc(wordIdx);
          opt[wordIdx].first := i;
        end else if menu[i] = '@' then
        spanCount := wordIdx;
    opt[wordIdx].last := len;
    opt[0].last := wordIdx;
  end;

  { Draws the menu line, the current option black on highlightColor, then pads it with color 0. }
  procedure DisplayOption(cur: Byte);
  var
    i: Byte;
    col: Byte;
    row: Byte;
  begin
    Mouse.HideMouse;
    col := 1;
    row := displayRow;
    if mLen > 0 then
      for i := 1 to mLen do
        if menu[i] = '@' then
        begin
          Border.ClearBox(qLen + col - 1, row, 39, row);
          Inc(row);
          col := 1;
        end else begin
          if (opt[cur].first <= i) and (opt[cur].last >= i)
             and (GDVars.highlightColor <> 0) then
            TextRend.RenderChar(qLen + col - 1, row, 0, GDVars.highlightColor, 1, Ord(menu[i]), 1)
          else if menu[i] in ['0'..'9', 'A'..'Z'] then
            TextRend.RenderChar(qLen + col - 1, row, GDVars.highlightColor, 0, 1, Ord(menu[i]), 1)
          else
            TextRend.RenderChar(qLen + col - 1, row, GDVars.menuColor, 0, 1, Ord(menu[i]), 1);
          Inc(col);
        end;
    if qLen + col - 1 <= 39 then
      Border.ClearBox(qLen + col - 1, row, 39, row);
    Mouse.ShowMouse;
  end;

  { Answers with the current option's key (Enter for an empty one) and finishes. }
  procedure AcceptCurrent;
  begin
    GDVars.extFlag := False;
    GDVars.menuKey := menu[opt[GDVars.horizChoice].first];
    if GDVars.menuKey = #0 then
      GDVars.menuKey := C_Keys.ENTER;
    isDone := True;
  end;

  { After a click, waits until the mouse buttons are up. }
  procedure WaitMouseRelease;
  begin
    if GDVars.isMouseClick then
      repeat
        Mouse.GetMouse(buttons, releaseX, releaseY)
      until buttons = 0
  end;

  { Tells whether a click is on the party roster, on a screen that shows it and not in the 3-D view's move mode. }
  function PartyClick: Boolean;
  begin
    PartyClick := GDVars.canClickParty
      and
        (GDVars.interfaceState in [C_Ifc.MAIN_MENU, C_Ifc.IN_SHOP, C_Ifc.VIEW_3D, C_Ifc.POST_COMBAT,
                                     C_Ifc.PICTURE_VIEW])
      and ((GDVars.interfaceState <> C_Ifc.VIEW_3D) or (GDVars.moveMode = 0))
      and (GDVars.panelLeft <= mouseCol) and (GDVars.panelRight >= mouseCol)
      and (GDVars.panelTop <= mouseRow) and (GDVars.panelBottom >= mouseRow);
  end;

  { Makes the clicked member current, or the anchor in selector mode; a click on the current one accepts. }
  procedure HandlePartyClick;
  var
    i: Byte;
    old: Types.PCharRecord;
  begin
    old := GDVars.currentCharacter;
    scratch := mouseRow - GDVars.panelTop;
    walk := GDVars.partyHead;
    for i := 1 to scratch do
      if walk <> nil then
        walk := walk^.nextCharAddr;
    if walk = nil then Exit;
    GDVars.menuKey := C_Keys.UP;
    GDVars.extFlag := True;
    isDone := True;
    if GDVars.selectorMode then
      GDVars.selectorAnchor := walk
    else begin
      if GDVars.currentCharacter = walk then begin
        GDVars.extFlag := False;
        GDVars.menuKey := menu[opt[GDVars.horizChoice].first];
        if GDVars.menuKey = #0 then
          GDVars.menuKey := C_Keys.ENTER
      end else begin
        GDVars.partyRowCharacter := GDVars.currentCharacter;
        GDVars.currentCharacter := walk;
      end;
    end;
    MenuCore.DisplayParty(GDVars.currentCharacter);
    if (GDVars.interfaceState = C_Ifc.MAIN_MENU) and GDVars.verticalMenuActive then begin
      GDVars.menuKey := C_Keys.ENTER;
      GDVars.extFlag := False;
      isDone := False;
      WaitMouseRelease;
      if walk = old then begin
        GDVars.partyClicked := 1;
        AcceptCurrent;
        GDVars.isMouseClick := False;
      end;
    end;
  end;

  { Tells whether a click is on the combat map view while moving or aiming. }
  function ArenaClick: Boolean;
  begin
    ArenaClick := ((GDVars.inMoveMenu <> 0) or (GDVars.cursorActive <> 0))
      and (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (mouseRow <= 21);
  end;

  { Answers a click in the arena: accepts on the mover's cell, moves the aim cursor, or steps toward the cell. }
  procedure HandleArenaClick;
  var
    x: ShortInt;
    y: ShortInt;
  begin
    isDone := True;
    GDVars.extFlag := True;
    if GDVars.cursorActive <> 0 then begin
      releaseX := GDVars.combatCursorX - GDVars.combatArena^.viewOriginX;
      releaseY := GDVars.combatCursorY - GDVars.combatArena^.viewOriginY;
    end else begin
      scratch := CbtMap.CombatSlot(GDVars.currentCharacter);
      releaseX := GDVars.combatantCells[scratch].x - GDVars.combatArena^.viewOriginX;
      releaseY := GDVars.combatantCells[scratch].y - GDVars.combatArena^.viewOriginY;
    end;
    x := (mouseCol - MenuCore.VIEW_SCREEN_OFFSET) div 3;
    y := (mouseRow - MenuCore.VIEW_SCREEN_OFFSET) div 3;
    if (x = releaseX) and (y = releaseY) then begin
      AcceptCurrent;
      if not (GDVars.menuKey in ['A', 'L']) then
      begin
        GDVars.menuKey := C_Keys.NONE;
        isDone := False;
      end;
    end else if (GDVars.cursorActive <> 0) and (x >= 0) and (x <= 6) and (y >= 0) and (y <= 6) then begin
      CbtMap.RedrawArenaCell(GDVars.combatCursorX, GDVars.combatCursorY);
      GDVars.combatCursorX := x + GDVars.combatArena^.viewOriginX;
      GDVars.combatCursorY := y + GDVars.combatArena^.viewOriginY;
      if (x >= 1) and (x <= 5) and (y >= 1) and (y <= 5) then
        GDVars.menuKey := '!'
      else
        GDVars.menuKey := '5';
    end else
      GDVars.menuKey := GDConsts.directionKeys[CbtMap.DirectionBetween(releaseX, releaseY, x, y)];
  end;

  { Tells whether a click is on the 3-D view while the map menu's Move is on. }
  function ViewAreaClick: Boolean;
  begin
    ViewAreaClick := (GDVars.moveMode <> 0) and (GDVars.interfaceState = C_Ifc.VIEW_3D)
      and (mouseCol >= 3) and (mouseCol <= 13)
      and (mouseRow >= 3) and (mouseRow <= 13);
  end;

  { Answers the arrow key for the clicked cell. }
  procedure HandleViewAreaClick;
  begin
    GDVars.extFlag := True;
    GDVars.menuKey := GDConsts.vectorScan[mouseRow, mouseCol];
    isDone := True;
  end;

  { Tells whether the click is on the menu's rows or below them. }
  function MenuRowClick: Boolean;
  begin
    MenuRowClick := displayRow <= mouseRow;
  end;

  { Chooses the option under the click, on either line of a two-line menu. }
  procedure HandleMenuRowClick;
  var i: Byte;
  begin
    Inc(mouseCol);
    if qLen < mouseCol then begin
      mouseCol := mouseCol - qLen;
      if hasAt then
        if displayRow < mouseRow then
          Inc(mouseCol, Pos('@', menu))
        else if Pos('@', menu) <= mouseCol then
          Exit;
      for i := 1 to opt[0].last do
        if (opt[i].first <= mouseCol) and (opt[i].last >= mouseCol) then begin
          GDVars.menuKey := menu[opt[i].first];
          GDVars.horizChoice := i;
          DisplayOption(GDVars.horizChoice);
          isDone := True;
        end;
    end;
    if GDVars.interfaceState = C_Ifc.SHIP then
      WaitMouseRelease;
  end;

  { In the icon editor, answers '!' for a click on the icon grid; any other click is waited out and ignored. }
  procedure SpecialClick;
  begin
    if (mouseRow >= 4) and (mouseRow < 22) and (mouseCol >= 19) and (mouseCol < 37) then begin
      GDVars.menuKey := '!';
      isDone := True;
    end else begin
      WaitMouseRelease;
      GDVars.isMouseClick := False;
      GDVars.menuKey := C_Keys.NONE;
      isDone := False;
    end;
    GDVars.extFlag := False;
  end;

  { On the modify screen, selects the field clicked: the name or the hit points on row 1, an ability below. }
  procedure HandleModifyClick;
  begin
    isDone := True;
    case mouseRow of
      1: begin
           if (mouseCol >= 8) and (mouseCol <= 24) then
             GDVars.modifyFieldSelection := C_Menu.MODIFY_NAME_FIELD
           else if (mouseCol >= 31) and (mouseCol <= 38) then
             GDVars.modifyFieldSelection := C_Menu.MODIFY_HIT_POINTS_FIELD;
         end;
      15..21: if (mouseCol >= 5) and (mouseCol <= 10) then
                   GDVars.modifyFieldSelection := mouseRow - 15;
    else
      isDone := False;
    end;
    GDVars.isMouseClick := False;
    GDVars.extFlag := True;
  end;

  { Accepts the current option for a click in a vertical menu's columns at or below a selectable line. }
  procedure HandleHotspotClick;
  begin
    if isDone then Exit;
    if (GDVars.menuClickLeft <= mouseCol) and (GDVars.menuClickRight >= mouseCol) then begin
      scratch := 1;
      while (scratch <= 25) and not isDone do begin
        if (GDVars.menuHotRows[scratch] <= mouseRow) and
            (GDVars.menuHotRows[scratch] <> MenuCore.NO_HOT_ROW) then begin
          isDone := True;
          GDVars.menuKey := menu[opt[GDVars.horizChoice].first];
        end;
        Inc(scratch);
      end;
    end;
  end;

  { Highlights the previous option, wrapping to the last. }
  procedure MoveLeft;
  begin
    if GDVars.horizChoice = 1 then GDVars.horizChoice := opt[0].last
    else Dec(GDVars.horizChoice);
    DisplayOption(GDVars.horizChoice);
    isDone := False;
  end;

  { Highlights the next option, wrapping to the first. }
  procedure MoveRight;
  begin
    if GDVars.horizChoice = opt[0].last then GDVars.horizChoice := 1
    else Inc(GDVars.horizChoice);
    DisplayOption(GDVars.horizChoice);
    isDone := False;
  end;

  { Moves to the other line of a two-line menu, clamped to its options. }
  procedure MoveVertical;
  begin
    if GDVars.horizChoice <= spanCount then begin
      Inc(GDVars.horizChoice, spanCount);
      if GDVars.horizChoice > opt[0].last then
        GDVars.horizChoice := opt[0].last;
    end else begin
      Dec(GDVars.horizChoice, spanCount);
      if GDVars.horizChoice > spanCount then
        GDVars.horizChoice := spanCount;
    end;
    DisplayOption(GDVars.horizChoice);
    isDone := False;
  end;

  { Clears clickedSkillLine and tells whether a click on the skill screen is above the status line. }
  function SkillListClick: Boolean;
  begin
    GDVars.clickedSkillLine := C_Menu.NO_SKILL_LINE;
    SkillListClick := (GDVars.interfaceState = C_Ifc.EDITING_SKILLS) and (mouseRow <= 22);
  end;

  { Sets clickedSkillLine for a click on a skill line (row 6 on); either way the menu finishes. }
  procedure HandleSkillListClick;
  begin
    if (mouseCol >= 1) and (mouseCol <= 38) and (mouseRow >= 6) then begin
      GDVars.clickedSkillLine := mouseRow - 5;
      GDVars.isMouseClick := False;
      Delay(65);
    end;
    isDone := True;
  end;

  { Tells whether a click is on the wilderness map while Move is on. }
  function WildernessClick: Boolean;
  begin
    WildernessClick := (GDVars.interfaceState = C_Ifc.WILDERNESS) and (GDVars.moveMode <> 0)
      and (mouseCol >= 1) and (mouseCol <= 38)
      and (mouseRow >= 1) and (mouseRow <= 15);
  end;

  { Tells whether a click is on the orbit map while Move is on. }
  function OrbitMapClick: Boolean;
  begin
    OrbitMapClick := (GDVars.interfaceState = C_Ifc.ORBIT_MAP) and (GDVars.moveMode <> 0)
      and (mouseCol >= 17) and (mouseCol <= 38)
      and (mouseRow >= 1) and (mouseRow <= 22);
  end;

begin
  if Pos('@', menu) > 0 then begin hasAt := True; displayRow := C_Screen.STATUS_ROW - 1 end
  else begin hasAt := False; displayRow := C_Screen.STATUS_ROW end;
  GDVars.extFlag := False;
  { set but unused }
  opt[0].first := Ord((GDVars.menuColor <> 0) or (GDVars.highlightColor <> 0));
  qLen := Length(query) + 0;
  ParseMenu;
  TrackMenu;
  if (GDVars.horizChoice > opt[0].last) or (GDVars.horizChoice = 0) then
    GDVars.horizChoice := 1;
  mLen := Length(menu);
  GDVars.menuKey := C_Keys.NONE;
  isDone := False;
  frameTick := TextRend.GetTicks;
  deadline30 := TextRend.GetTicks + 30;
  deadline80 := deadline30 + 50;
  if Length(query) <> 0 then
    TextRend.DisplayString(0, displayRow, GDVars.promptColor, 0, query);
  DisplayOption(GDVars.horizChoice);
  if GDVars.spriteArchive then
    isAnimated := False;
  if isAnimated and (GDVars.portraitAnimation.currentFrame > 0) then begin
    Portrait.DisplayImageBuf(3, 3, isAnimated, GDVars.portraitAnimation.currentFrame);
    if GDVars.portraitAnimation.lastFrameIndex < 2 then
      isAnimated := False;
  end;
  repeat
    if isAnimated and (GDVars.portraitAnimation.lastFrameIndex > 0) and
       (GDVars.portraitAnimation.frameDelays[GDVars.portraitAnimation.currentFrame] * 10 <=
        TextRend.GetTicks - frameTick) then begin
      Inc(GDVars.portraitAnimation.currentFrame);
      if GDVars.portraitAnimation.currentFrame > GDVars.portraitAnimation.lastFrameIndex then
        GDVars.portraitAnimation.currentFrame := GDVars.portraitAnimation.loopStartFrame;
      Portrait.DisplayImageBuf(3, 3, isAnimated, GDVars.portraitAnimation.currentFrame);
      frameTick := TextRend.GetTicks;
    end;
    if (GDVars.menuTimeout > 0) and (TextRend.GetTicks - frameTick >= GDVars.menuTimeout) then begin
      GDVars.menuKey := GDVars.menuTimeoutKey;
      isDone := True;
    end;
    if GameIo.InputPending then begin
      GDVars.menuKey := GameIo.ReadGameKey;
      if GDVars.isMouseClick then begin
        mouseRow := GDVars.mouseY div 8;
        mouseCol := GDVars.mouseX div 8;
      end;
      if GDVars.menuKey = #0 then begin
        GDVars.menuKey := GameIo.ReadGameKey;
        GDVars.extFlag := True;
        isDone := True;
        if opt[0].last > 1 then
          case GDVars.menuKey of
            C_Keys.LEFT: MoveLeft;
            C_Keys.RIGHT: MoveRight;
            C_Keys.UP, C_Keys.DOWN: if hasAt then MoveVertical;
          end;
      end else begin
        GDVars.extFlag := False;
        case GDVars.menuKey of
          C_Keys.ESCAPE:
            if GDVars.isMouseClick and SkillListClick then
              HandleSkillListClick
            else if GDVars.isMouseClick and (GDVars.modifyActive <> 0) then
              HandleModifyClick
            else begin isDone := True; GDVars.menuKey := C_Keys.NONE end;
          C_Keys.ENTER: if GDVars.isMouseClick then begin
                 if SkillListClick then
                   HandleSkillListClick
                 else if (GDVars.iconEditorActive <> 0) and (mouseRow <= 22) then
                   SpecialClick
                 else if PartyClick then HandlePartyClick
                 else if WildernessClick or OrbitMapClick then AcceptCurrent
                 else if ArenaClick then HandleArenaClick
                 else if ViewAreaClick then HandleViewAreaClick
                 else if MenuRowClick then HandleMenuRowClick
                 else if GDVars.modifyActive <> 0 then HandleModifyClick
                 else if GDVars.verticalMenuActive then HandleHotspotClick
                 else if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (mouseRow <= 22) then begin
                   if hasAt then begin
                     GDVars.menuKey := 'T';
                     isDone := True;
                   end else if query = 'Aim:' then
                   begin
                     GDVars.menuKey := C_Keys.RIGHT;
                     isDone := True;
                   end;
                 end else if opt[0].last > 1 then GDVars.menuKey := C_Keys.NONE
                 else isDone := True;
               end else AcceptCurrent;
        else begin
          GDVars.menuKey := UpCase(GDVars.menuKey);
          if GDVars.menuKey in [' ', '0'..'9', 'A'..'Z'] then
            if GDVars.menuKey = ' ' then
              isDone := True
            else
              for scratch := 1 to mLen do
                if menu[scratch] = GDVars.menuKey then begin
                  isDone := True;
                  mouseCol := 1;
                  while scratch <> opt[mouseCol].first do Inc(mouseCol);
                  GDVars.horizChoice := mouseCol;
                  DisplayOption(GDVars.horizChoice);
                end;
        end;
        if not isDone and (opt[0].last > 1) then
          if GDVars.menuKey = '4' then MoveLeft
          else if GDVars.menuKey = '6' then MoveRight
          else if (GDVars.menuKey in ['2', '8', C_Keys.UP, C_Keys.DOWN]) and hasAt then MoveVertical;
        if mapsDigitsToKeypad then
          if GDVars.menuKey in ['1'..'9', '\'] then
          begin
            if GDVars.menuKey = '\' then
              GDVars.menuKey := #55
            else
              GDVars.menuKey := GDConsts.keypadScan[Ord(GDVars.menuKey) - Ord('1')];
            GDVars.extFlag := True;
            isDone := True;
          end;
        end;
      end;
    end;
  until isDone;
  GDVars.promptColor := LightMagenta;
  GDVars.highlightColor := White;
  GDVars.menuColor := LightGreen;
  GameIo.FlushKeys;
  WaitMouseRelease;
  if GDVars.isJoystickOn then
    repeat Joystick.GetJoystick(buttons, scratch) until buttons = 0;
end;

function MenuVertical(query, menu: Types.TString40; ulCol, ulRow, lrCol, lrRow: ShortInt; list: Types.PMenuNode;
                      offersExit: Boolean; var needsRedraw: Boolean; var idx: Integer; var sel: Types.PMenuNode): Char;
var
  width: Byte;
  line: Byte;
  count: Integer;
  rows: Integer;
  prevCh: Char;
  hMenu: Types.TString40;
  hasNext: Boolean;
  hasPrev: Boolean;
  p: Types.PMenuNode;
  headerCnt: Integer;
  total: Integer;
  mouseCellCol: Byte;
  mouseCellRow: Byte;

  { The last label line among the first n members, nil when none; for n below 1, the first member if a label. }
  function LastLabelBefore(n: Integer; l: Types.PMenuNode): Types.PMenuNode;
  var
    pp: Types.PMenuNode;
    found: Types.PMenuNode;
    i: Integer;
  begin
    i := 0;
    pp := l;
    found := nil;
    while (pp <> nil) and (i < n) do begin
      if pp^.menuLabel <> 0 then
        found := pp;
      pp := pp^.next;
      Inc(i);
    end;
    if (found = nil) and (l^.menuLabel <> 0) then
      LastLabelBefore := l
    else
      LastLabelBefore := found;
  end;

  { Clears the window and draws one member per line from top; label lines are not hot rows. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PMenuNode;
    { Unused in this version; see the other implementations of this routine. }
    lastLabel: Types.PMenuNode;
    row: ShortInt;
  begin
    FillChar(GDVars.menuHotRows, SizeOf(GDVars.menuHotRows), MenuCore.NO_HOT_ROW);
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    Mouse.HideMouse;
    pp := MenuCore.FindListMember(top, list);
    lastLabel := LastLabelBefore(top, list);
    row := ulRow;
    line := 1;
    while (pp <> nil) and (row <= lrRow) do begin
      if pp^.menuLabel <> 0 then
        TextRend.DisplayString(ulCol, row, GDVars.promptColor, 0, pp^.name)
      else begin
        GDVars.menuHotRows[line] := row;
        TextRend.DisplayString(ulCol, row, GDVars.menuColor, 0, pp^.name);
      end;
      if Length(pp^.name) < width then
        TextRend.RenderChar(ulCol + Length(pp^.name), row, Black, 0, width - Length(pp^.name), Ord(' '), 1);
      pp := pp^.next;
      Inc(row);
      Inc(line);
    end;
    Mouse.ShowMouse;
  end;

  { Finds the first non-space character. }
  function FirstNonBlank(s: Types.TString40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(s);
    while (i < len) and (s[i] = ' ') do
      Inc(i);
    FirstNonBlank := i;
  end;

  { Finds the last non-space character. }
  function LastNonBlank(s: Types.TString40): Byte;
  var
    n: Byte;
  begin
    n := Length(s);
    while (n > 1) and (s[n] = ' ') do
      Dec(n);
    LastNonBlank := n;
  end;

  { Redraws list line n, trimmed, in the highlight color. }
  procedure HighlightLine(n: Integer);
  var
    pp: Types.PMenuNode;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), 0, GDVars.highlightColor,
                           Copy(pp^.name, a, b));
  end;

  { Redraws list line n, trimmed, in its resting color. }
  procedure UnhighlightLine(n: Integer);
  var
    pp: Types.PMenuNode;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    if pp^.menuLabel <> 0 then
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), GDVars.promptColor, 0,
                             Copy(pp^.name, a, b))
    else
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), GDVars.menuColor, 0,
                             Copy(pp^.name, a, b));
  end;

  { Steps the selection off label lines, wrapping inside the page. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then begin
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.menuLabel <> 0) do begin
        Inc(k);
        Inc(idx);
        if GDVars.vertTop + rows - 1 < idx then
          idx := GDVars.vertTop;
        if count - 1 < idx then
          idx := GDVars.vertTop;
      end;
    end else
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.menuLabel <> 0) do begin
        Inc(k);
        Dec(idx);
        if idx < GDVars.vertTop then
          idx := GDVars.vertTop + rows - 1;
        if count - 1 < idx then
          idx := count - 1;
      end;
  end;

  { Moves a page down or up, clamped to the list, keeping the selection's offset on the page. }
  procedure MovePage(down: Boolean);
  var
    rel: Integer;
  begin
    rel := idx - GDVars.vertTop;
    if down then begin
      Inc(GDVars.vertTop, rows);
      if count - rows < GDVars.vertTop then
        GDVars.vertTop := count - rows;
    end else begin
      Dec(GDVars.vertTop, rows);
      if GDVars.vertTop < 0 then
        GDVars.vertTop := 0;
    end;
    idx := GDVars.vertTop + rel;
    SkipLabels(down);
    DrawPage(GDVars.vertTop);
  end;

  { Moves the selection a line, wrapping inside the page and clamped to the list's end. }
  procedure MoveLine(down: Boolean);
  var
    { Unused in this version; see the other implementations of this routine. }
    node: Types.PMenuNode;
    { Unused in this version; see the other implementations of this routine. }
    skipped: Integer;
    { Unused in this version; see the other implementations of this routine. }
    index: Integer;
  begin
    if down then begin
      Inc(idx);
      if GDVars.vertTop + rows - 1 < idx then
        idx := GDVars.vertTop;
      if count - 1 < idx then
        idx := GDVars.vertTop;
    end else begin
      Dec(idx);
      if idx < GDVars.vertTop then
        idx := GDVars.vertTop + rows - 1;
      if count - 1 < idx then
        idx := count - 1;
    end;
    SkipLabels(down);
  end;

begin
  if list = nil then begin
    idx := 0;
    sel := nil;
    GDVars.menuClickLeft := MenuCore.CLOSED_CLICK_LEFT;
    GDVars.menuClickRight := MenuCore.CLOSED_CLICK_RIGHT;
    MenuVertical := C_Keys.NONE;
    Exit;
  end;
  prevCh := 'N';
  GDVars.menuClickLeft := ulCol;
  GDVars.menuClickRight := lrCol;
  width := lrCol - ulCol + 1;
  count := MenuCore.ListCount(list);
  rows := lrRow - ulRow + 1;
  p := list;
  headerCnt := 0;
  while (p <> nil) and (p^.menuLabel <> 0) do begin
    p := p^.next;
    Inc(headerCnt);
  end;
  p := list;
  total := 0;
  while p <> nil do begin
    p := p^.next;
    Inc(total);
  end;
  if total <= rows then GDVars.vertTop := 0;
  if GDVars.vertTop > idx then begin
    GDVars.vertTop := idx;
    needsRedraw := True;
  end;
  if GDVars.vertTop > total then begin
    GDVars.vertTop := 0;
    needsRedraw := True;
  end;
  Inc(idx);
  MoveLine(False);
  if needsRedraw then DrawPage(GDVars.vertTop);
  needsRedraw := False;
  repeat
    HighlightLine(idx);
    hMenu := menu;
    hasNext := False;
    hasPrev := False;
    if count - rows > GDVars.vertTop then begin
      hMenu := hMenu + ' Next';
      hasNext := True;
    end;
    if GDVars.vertTop > headerCnt then begin
      hMenu := hMenu + ' Prev';
      hasPrev := True;
    end;
    if offersExit then hMenu := hMenu + ' Exit';
    GDVars.verticalMenuActive := True;
    MenuCore.MenuHorizontal(query, hMenu, True, False);
    GDVars.verticalMenuActive := False;
    UnhighlightLine(idx);
    mouseCellRow := GDVars.mouseY div 8;
    mouseCellCol := GDVars.mouseX div 8;
    if GDVars.extFlag then
      case GDVars.menuKey of
        C_Keys.UP: MoveLine(False);
        C_Keys.DOWN: MoveLine(True);
        C_Keys.PAGE_UP: if hasPrev then MovePage(False);
        C_Keys.PAGE_DOWN: if hasNext then MovePage(True);
      end else
      case GDVars.menuKey of
        'P': if not GDVars.isMouseClick or
          (GDVars.isMouseClick and (mouseCellRow = C_Screen.STATUS_ROW)) then MovePage(False);
        'N': if not GDVars.isMouseClick or
          (GDVars.isMouseClick and (mouseCellRow = C_Screen.STATUS_ROW)) then MovePage(True);
        C_Keys.ESCAPE, 'E', C_Keys.NONE:
          begin
            sel := nil;
            MenuVertical := C_Keys.NONE;
            GDVars.menuClickLeft := MenuCore.CLOSED_CLICK_LEFT;
            GDVars.menuClickRight := MenuCore.CLOSED_CLICK_RIGHT;
            Exit;
          end;
      else
        if GDVars.isMouseClick and (mouseCellRow <> C_Screen.STATUS_ROW) then begin
          if (mouseCellCol >= GDVars.menuClickLeft) and (mouseCellCol <= GDVars.menuClickRight) then begin
            line := 1;
            while line <= 25 do begin
              if GDVars.menuHotRows[line] = mouseCellRow then
                if line - 1 + GDVars.vertTop = idx then begin
                  sel := MenuCore.FindListMember(idx, list);
                  MenuVertical := GDVars.menuKey;
                  Exit;
                end else begin
                  UnhighlightLine(idx);
                  idx := line - 1 + GDVars.vertTop;
                  HighlightLine(idx);
                end;
              Inc(line);
            end;
          end;
        end else if not GDVars.isMouseClick or (GDVars.isMouseClick and (prevCh = GDVars.menuKey)) then begin
          sel := MenuCore.FindListMember(idx, list);
          MenuVertical := GDVars.menuKey;
          GDVars.menuClickLeft := MenuCore.CLOSED_CLICK_LEFT;
          GDVars.menuClickRight := MenuCore.CLOSED_CLICK_RIGHT;
          Exit;
        end;
      end;
    prevCh := GDVars.menuKey;
  until False;
end;

function YesNoMenu(query: Types.TString40; defaultChoice: Byte): Char;
var
  savedHighlight: Byte;
  savedMenu: Byte;
  savedQuery: Byte;
begin
  GDVars.horizChoice := defaultChoice;
  savedHighlight := GDVars.highlightColor;
  savedMenu := GDVars.menuColor;
  savedQuery := GDVars.promptColor;
  repeat
    GDVars.highlightColor := savedHighlight;
    GDVars.menuColor := savedMenu;
    GDVars.promptColor := savedQuery;
    GDVars.menuChecksum := C_Menu.KEEP_MENU_CHOICE;
    MenuCore.MenuHorizontal(query, 'Yes No', False, False);
  until GDVars.menuKey in ['Y', 'N'];
  YesNoMenu := GDVars.menuKey;
end;

procedure AllocStringList(n: Integer; var list: Types.PMenuNode);
var
  p: Types.PMenuNode;
  i: Integer;
begin
  GetMem(list, SizeOf(Types.TMenuNode));
  list^.next := nil;
  list^.menuLabel := 0;
  list^.name := '';
  p := list;
  for i := 2 to n do begin
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
    p^.next := nil;
    p^.menuLabel := 0;
    p^.name := '';
  end;
end;

procedure FreeStringList(var list: Types.PMenuNode);
var
  p: Types.PMenuNode;
  q: Types.PMenuNode;
begin
  p := list;
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TMenuNode));
  end;
end;

procedure DisplayParty(highlight: Types.PCharRecord);
var
  character: Types.PCharRecord;
  column: Byte;
  row: Byte;
  band: Byte;
begin
  if (GDVars.interfaceState = C_Ifc.ORBIT_MAP) or (GDVars.interfaceState = C_Ifc.WILDERNESS) or
      (GDVars.bigPictureShown <> 0) then
    Exit;
  if GDVars.interfaceState = C_Ifc.MAIN_MENU then
    column := 1
  else
    column := 17;
  GDVars.panelLeft := column;
  GDVars.panelTop := 4;
  GDVars.panelRight := 38;
  GDVars.panelBottom := 3;
  row := 2;
  TextRend.DisplayString(column, row, White, 0, 'Name');
  TextRend.DisplayString(33, row, White, 0, 'AC HP');
  Inc(row, 2);
  character := GDVars.partyHead;
  while character <> nil do begin
    Inc(GDVars.panelBottom);
    Border.ClearBox(column, row, 38, row);
    if character = highlight then
      TextRend.DisplayString(column, row, White, 0, character^.name)
    else
      MenuCore.DisplayCreatureName(character, column, row, False);
    case character^.armorClass[0] of
      0..50: band := 1;
      51..60: band := 2;
      61..69: band := 1
    else
      band := 0
    end;
    MenuCore.PrintArmorClass(character, band + 32, row);
    case character^.hitPoints of
      0..9: band := 2;
      10..99: band := 1
    else
      band := 0
    end;
    MenuCore.PrintHitPoints(character, band + 36, row, False, False);
    Inc(row);
    character := character^.nextCharAddr
  end;
  Border.ClearBox(column, row, 38, row)
end;

procedure DisplayCreatureName(character: Types.PCharRecord; column, row: Byte; isPossessive: Boolean);
var color: Byte;
begin
  with character^ do begin
    if enabled = 0 then
      color := LightRed
    else if (side = C_Side.HOSTILE) and (GDVars.interfaceState = C_Ifc.IN_COMBAT) then
      color := Yellow
    else if (level < 21) and (GDConsts.experienceNeeded[career, Succ(level)] < experience) then
      color := LightMagenta
    else
      color := LightCyan;
    TextRend.DisplayString(column, row, color, 0, name);
    if isPossessive then
      TextRend.DisplayString(column + Length(name), row, color, 0, '''s')
  end
end;

procedure PrintArmorClass(character: Types.PCharRecord; column, row: Byte);
var value: String;
    { Unused in this version; see the other implementations of this routine. }
    width: Byte;
begin
  value := TextRend.ByteToString(Abs(character^.armorClass[0] - 60));
  if character^.armorClass[0] > 60 then
    value := '-' + value;
  TextRend.DisplayString(column, row, White, 0, value)
end;

procedure PrintHitPoints(character: Types.PCharRecord; column, row: Byte; isHotPink, showsMax: Boolean);
var value: String; color: Byte;
begin
  if isHotPink then
    color := LightMagenta
  else if character^.hitPoints < character^.hpMax then
    color := Yellow
  else
    color := White;
  Str(character^.hitPoints:0, value);
  if showsMax then begin
    value := value + '/' + TextRend.ByteToString(character^.hpMax);
    TextRend.RightAlignString(value, 7)
  end;
  TextRend.DisplayString(column, row, color, 0, value)
end;

begin
end.
