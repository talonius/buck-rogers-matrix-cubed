{ The character menus: the main menu between adventures, character creation and modification, adding, removing and
  dropping party members, training, the body icon editor, and the mouse and joystick set-up, which rewrites the config
  file and calibrates the joystick with its own copy of Joystick's calibration. The main menu's table and a new
  character's icon by gender and career are GDConsts'. }
{$F+,O+,S-,R-,V-,B-,I-}
unit CharGen;

interface

{ The main menu between adventures: create, modify, drop, add or remove a character, change its icon, train or view it,
  load or save the game, set up the mouse or joystick, exit to DOS, or begin, which returns once there is a party (or in
  the demo). }
procedure MainMenu;

{ Takes the current character out of the party and frees it; the member before it, or after it when it led the party,
  becomes current.
  @param(keepsPartyCount True leaves zone 1's partyCount as it is.)
  @param(freesIcon True also frees its icon animation.) }
procedure RemoveCreature(keepsPartyCount, freesIcon: Boolean);

{ After two confirmations deletes the current character's files, removes it from the party and returns. When a
  confirmation is refused, or there is no current character, it instead marks the party defeated unless an enabled,
  non-companion party-side member is left. It returns at once when no character is picked. }
procedure DropCharacterMenu;

implementation

uses Types, C_Npc, C_Status, GDConsts, GDVars, Mouse, Joystick, Crt, Border, TextRend,
  GameIo, DaxIo, Music, Blit, MapTiles, CbtMap, CharHlp, ViewChar, SaveLoad, MenuCore, Skills, Shop, C_Ifc,
  C_Vm, C_Career, C_Side, C_Joy, C_Keys, C_Menu, C_Pic, C_Combat;

const
  { TCharRecord.career of an engineer, as careerNames names it }
  CAREER_ENGINEER = 4;
  { TCharRecord.abilities' index for constitution }
  ABIL_CON = 2;
  { the Delete key's scan code, read with extFlag set: the name entry deletes a character }
  KEY_DELETE = #83;
  { modifyFieldSelection before a click picks a field }
  NO_MODIFY_FIELD = 255;
  { the highest level training reaches: TrainingMenu refuses a character at it ('maximum level in game has been
    reached') }
  MAX_LEVEL = 20;

type
  { a character level, as TrainingMenu's every-third-level test takes it }
  TLevelValue = 0..127;
  { CHARS.DAX's 36 body icons, two frames each }
  TImageGrid = array[0..35, 0..1] of Types.PImgBuf;
  PImageGrid = ^TImageGrid;
  TImageEntry = record
    id: Byte;
    offset: LongInt;
    size: Word;
    packedSize: Word
  end;
  PImageEntries = ^TImageEntries;
  TImageEntries = array[0..72] of TImageEntry;
  { The buffer each CHARS.DAX body icon is unpacked into for PreparePic. }
  TIconRecord = array[0..1023] of Byte;

procedure AddCharacterMenu; forward;

procedure CustomizeIcon; forward;

procedure TrainingMenu; forward;

procedure SetDefaultIcon; forward;

procedure CreateCharacterMenu; forward;

procedure ModifyCharacterMenu; forward;

function HpMaximum(character: Pointer): Byte; forward;

function HpMinimum(character: Pointer): Byte; forward;

procedure AddLevelHitPoints(character: Pointer); forward;

procedure InitMouseJoystick; forward;

procedure CalibrateJoystickInWindow; forward;

{ Frees character with its combat state, items and effects, and sets it to nil. Note: a nil character is reported on the
  bottom line but then dereferenced anyway.
  @param(character The creature freed, nil afterward.) }
procedure FreeCreature(var character: Types.PCharRecord);
var
  hold: Types.PItemRec;
  item: Types.PItemRec;
  holdEffect: Types.PEffectRec;
  effect: Types.PEffectRec;
begin
  if character = nil then
    CharHlp.PrintBottomLine('disposing a nil char');
  with character^ do begin
    if combatAddr <> nil then
      FreeMem(combatAddr, SizeOf(Types.TCombatRec));
    item := Types.PItemRec(itemsAddr);
    while item <> nil do begin
      hold := item;
      item := item^.next;
      FreeMem(hold, SizeOf(Types.TItemRec))
    end;
    effect := Types.PEffectRec(effectsAddr);
    while effect <> nil do begin
      holdEffect := effect;
      effect := effect^.next;
      FreeMem(holdEffect, SizeOf(Types.TEffectRec))
    end
  end;
  FreeMem(character, SizeOf(Types.TCharRecord));
  character := nil
end;

procedure MainMenu;
var
  i: Byte;
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  ext: Byte;
  needsRedraw: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  promptText: array[1..9] of Byte;
  enabledCount: ShortInt;
  { never cleared: the list is rebuilt on every pass }
  needsRebuild: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  previousInterface: Byte;
  head: Types.PMenuNode;
  selected: Types.PMenuNode;
  node: Types.PMenuNode;
  count: Integer;
begin
  GDVars.previousInterfaceState := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.MAIN_MENU;
  needsRebuild := True;
  GDVars.trainingMode := 0;
  count := 0;
  while True do begin
    if needsRebuild then begin
      Border.DrawWindowFrame(1);
      if GDVars.currentCharacter <> nil then begin
        MenuCore.DisplayParty(GDVars.currentCharacter);
        GDConsts.menuTable[1].isEnabled := True;
        GDConsts.menuTable[2].isEnabled := True;
        GDConsts.menuTable[3].isEnabled := True;
        GDConsts.menuTable[4].isEnabled := GDVars.zone1^.trainingMask > 0;
        GDConsts.menuTable[5].isEnabled := True;
        GDConsts.menuTable[7].isEnabled := True;
        GDConsts.menuTable[8].isEnabled := False;
        GDConsts.menuTable[9].isEnabled := True;
        GDConsts.menuTable[10].isEnabled := True;
        GDConsts.menuTable[11].isEnabled := False;
        GDConsts.menuTable[12].isEnabled := True
      end else begin
        GDConsts.menuTable[1].isEnabled := False;
        GDConsts.menuTable[2].isEnabled := False;
        GDConsts.menuTable[3].isEnabled := False;
        GDConsts.menuTable[4].isEnabled := False;
        GDConsts.menuTable[5].isEnabled := False;
        GDConsts.menuTable[7].isEnabled := False;
        GDConsts.menuTable[8].isEnabled := True;
        GDConsts.menuTable[9].isEnabled := False;
        GDConsts.menuTable[10].isEnabled := False;
        GDConsts.menuTable[11].isEnabled := True;
        GDConsts.menuTable[12].isEnabled := True
      end;
      enabledCount := 0;
      for i := 0 to SizeOf(GDConsts.menuTable) div SizeOf(Types.TMenuRow) - 1 do
        if GDConsts.menuTable[i].isEnabled then Inc(enabledCount);
      MenuCore.AllocStringList(enabledCount, head);
      node := head;
      for i := 0 to SizeOf(GDConsts.menuTable) div SizeOf(Types.TMenuRow) - 1 do
        if GDConsts.menuTable[i].isEnabled then begin
          node^.name := GDConsts.menuTable[i].name;
          node := node^.next
        end
    end;
    needsRedraw := True;
    GDVars.partyClicked := 0;
    GDVars.canClickParty := True;
    ch := MenuCore.MenuVertical('Choose a FUNCTION ', 'Select ', 9, 12, 38, 22, head, False, needsRedraw, count,
                                selected);
    GDVars.canClickParty := False;
    ch := selected^.name[1];
    if (GDVars.partyClicked <> 0) and (ch in ['A', 'B', 'C', 'E', 'L', 'S']) then
      ch := 'V';
    if needsRebuild then
      MenuCore.FreeStringList(head);
    if not (ch in ['E', 'S']) then GDVars.gameSaved := 0;
    case ch of
      'C': if GDConsts.menuTable[0].isEnabled then CharGen.CreateCharacterMenu;
      { Note: 'M' tests Purge's row and 'P' Modify's; harmless, since the two rows are always enabled together }
      'M': if GDConsts.menuTable[1].isEnabled then CharGen.ModifyCharacterMenu;
      'P': if GDConsts.menuTable[2].isEnabled then CharGen.DropCharacterMenu;
      'I': if GDConsts.menuTable[3].isEnabled then
            if (GDVars.partyClicked <> 0) or ViewChar.PickCharacter then
              CharGen.CustomizeIcon;
      'T': if GDConsts.menuTable[4].isEnabled then CharGen.TrainingMenu;
      'V': if GDConsts.menuTable[5].isEnabled then
            if (GDVars.partyClicked <> 0) or ViewChar.PickCharacter then
              ViewChar.ViewCharMenu(needsRedraw);
      'A': if GDConsts.menuTable[6].isEnabled then CharGen.AddCharacterMenu;
      'R': if GDConsts.menuTable[7].isEnabled then
            if (GDVars.partyClicked <> 0) or ViewChar.PickCharacter then
              if GDVars.currentCharacter^.npc < C_Npc.NON_PLAYER_FLAG then begin
                if SaveLoad.SaveChar(GDVars.currentCharacter, '') then
                  CharGen.RemoveCreature(False, True)
              end else
                CharGen.DropCharacterMenu;
      'L': if GDConsts.menuTable[8].isEnabled then
            SaveLoad.LoadGame;
      'S': if GDConsts.menuTable[9].isEnabled then
            if GDVars.partyHead <> nil then begin
              GDVars.interfaceState := GDVars.previousInterfaceState;
              SaveLoad.SaveGame;
              GDVars.interfaceState := C_Ifc.MAIN_MENU
            end;
      'B': if GDConsts.menuTable[10].isEnabled then begin
            GDVars.canClickParty := True;
            if (GDVars.partyHead <> nil) or GDVars.demoMode then begin
              GDVars.interfaceState := GDVars.previousInterfaceState;
              CharHlp.DisplayNoncombatInterface;
              GDVars.zone1^.trainingMask := 0;
              Exit
            end
          end;
      'J': if GDConsts.menuTable[11].isEnabled then CharGen.InitMouseJoystick;
      'E': if GDConsts.menuTable[12].isEnabled then begin
            GDVars.promptColor := Yellow;
            ch := MenuCore.YesNoMenu('Quit to DOS ', C_Menu.DEFAULT_NO);
            if ch = 'Y' then begin
              if GDVars.partyHead <> nil then
                if GDVars.gameSaved = 0 then begin
                  GDVars.promptColor := Yellow;
                  ch := MenuCore.YesNoMenu('Game NOT saved.  Quit anyway? ', C_Menu.DEFAULT_NO);
                  if ch = 'N' then SaveLoad.SaveGame
                end;
              if ch = 'Y' then GameIo.ExitGame
            end
          end
    end
  end
end;

{ Creates a character: race, gender and career; abilities rolled and free training to its starting experience (level
  7's), rerolled on request; name, specialization, skills and icon; saved if the player agrees. }
procedure CreateCharacterMenu;
var
  character: Types.PCharRecord;
  previous: Types.PCharRecord;
  head: Types.PMenuNode;
  node: Types.PMenuNode;
  count: Integer;
  i: Byte;
  attempt: Byte;
  rolled: Byte;
  ch: Char;
  raceIndex: ShortInt;
  genderIndex: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  classIndex: ShortInt;
  statIndex: ShortInt;
  choiceCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  conBonus: array[1..3] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  classCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hpTotal: Byte;
  offersExit: Boolean;
  needsRedraw: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  redrawByte: Byte;
  { Unused in this version; see the other implementations of this routine. }
  haveLevelText: Byte;
  { Unused in this version; see the other implementations of this routine. }
  levelText: array[1..39] of Byte;
  savedTrainingMask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tailFlag: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedPanel: Byte;

  { Sets each saving throw to its base less the race's adjustment. }
  procedure InitializeSaves;
  var i: ShortInt;
  begin
    for i := 0 to SizeOf(character^.saves) - 1 do
      character^.saves[i] := GDConsts.baseSavingThrows[i] - GDConsts.raceSaveAdjust[character^.race, i]
  end;

  { sets the career's eight skills to their starting levels }
  procedure InitializeCareerSkills;
  var
    i: Byte;
    skill: Byte;
  begin
    with GDVars.currentCharacter^ do
      for i := 1 to SizeOf(GDConsts.careerSkills[career]) do begin
        skill := GDConsts.careerSkills[career, i];
        skillLevels[skill] := Skills.StartingSkillLevel(GDVars.currentCharacter, skill)
      end
  end;

  { Sets each skill to its starting level. Note: the loop also writes one entry past the last skill. }
  procedure InitializeAllSkills;
  var i: Byte;
  begin
    with GDVars.currentCharacter^ do
      { Note: runs one past the last skill }
      for i := 1 to SizeOf(skillLevels) do
        skillLevels[i] := Skills.StartingSkillLevel(GDVars.currentCharacter, i)
  end;

begin
  GDVars.trainingMode := 0;
  GetMem(character, SizeOf(Types.TCharRecord));
  FillChar(character^, SizeOf(Types.TCharRecord), 0);
  with character^ do begin
    for i := 0 to SizeOf(iconSequence) - 1 do iconSequence[i] := i;
    baseArmorClass := 50;
    baseCombat := 40;
    status := C_Status.OKAY;
    enabled := 1;
    iconDimensions := 1;
    orderNumber := 10;
    credits := 1000;

  MenuCore.AllocStringList(7, head);
  head^.menuLabel := 1;
  head^.name := 'Pick Race';
  for raceIndex := 1 to 6 do begin
    node := MenuCore.FindListMember(raceIndex, head);
    node^.name := '  ' + GDConsts.raceNames[raceIndex]
  end;
  node := head;
  count := 1;
  needsRedraw := True;
  offersExit := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', 1, 2, 38, 22, head, offersExit, needsRedraw, count, node);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(head);
      FreeMem(character, SizeOf(Types.TCharRecord));
      Exit
    end
  until ch = 'S';
  race := count;

  MenuCore.AllocStringList(3, head);
  head^.menuLabel := 1;
  head^.name := 'Pick Gender';
  for genderIndex := 0 to SizeOf(GDConsts.genderNames) div SizeOf(GDConsts.genderNames[0]) - 1 do begin
    node := MenuCore.FindListMember(genderIndex + 1, head);
    node^.name := '  ' + GDConsts.genderNames[genderIndex]
  end;
  node := head;
  count := 1;
  offersExit := True;
  needsRedraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', 1, 2, 38, 22, head, offersExit, needsRedraw, count, node);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(head);
      FreeMem(character, SizeOf(Types.TCharRecord));
      Exit
    end
  until ch = 'S';
  gender := count - 1;
  MenuCore.FreeStringList(head);

  choiceCount := GDConsts.raceCareers[race].count;
  MenuCore.AllocStringList(choiceCount + 1, head);
  head^.menuLabel := 1;
  head^.name := 'Pick Class';
  for i := 1 to GDConsts.raceCareers[race].count do begin
    node := MenuCore.FindListMember(i, head);
    node^.name := '  ' + GDConsts.careerNames[GDConsts.raceCareers[race].careers[i]]
  end;
  node := head;
  count := 1;
  offersExit := True;
  needsRedraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', 1, 2, 38, 22, head, offersExit, needsRedraw, count, node);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(head);
      FreeMem(character, SizeOf(Types.TCharRecord));
      Exit
    end
  until ch = 'S';
  career := GDConsts.raceCareers[race].careers[count];
  experience := GDConsts.experienceNeeded[career, 7];
  baseCombat := GDConsts.careerBaseCombat[career, 7];
  InitializeSaves;
  age := CharHlp.RollDice(1, 6) + 18;
  previous := GDVars.currentCharacter;
  GDVars.currentCharacter := character;
  level := 7;
  armorClass[0] := 50;
  hitPoints := 0;
  hpMax := 0;
  ViewChar.DisplayChar;
  repeat
  for statIndex := 0 to SizeOf(abilities) - 1 do begin
    abilities[statIndex] := 0;
    for attempt := 1 to 6 do begin
      rolled := CharHlp.RollDice(3, 6);
      if abilities[statIndex] < rolled then abilities[statIndex] := rolled
    end;
    Inc(abilities[statIndex], GDConsts.raceStatAdjust[race, statIndex]);
    if abilities[statIndex] < 1 then abilities[statIndex] := 1;
    if abilities[statIndex] < GDConsts.careerStatMinimum[career, statIndex] then
      abilities[statIndex] := GDConsts.careerStatMinimum[career, statIndex];
    currentAbilities[statIndex] := abilities[statIndex];
    ViewChar.PrintStat(statIndex, False)
  end;
  unarmedRolls[1] := 1;
  if (race = 6) or (career = C_Career.WARRIOR) then unarmedDice[1] := 3 else unarmedDice[1] := 2;
  if race = 6 then unarmedModifiers[1] := 1 else unarmedModifiers[1] := 0;
  if career = C_Career.WARRIOR then baseScale := 4 else baseScale := 2;
  case race of
    1, 2, 3, 4: baseMovement := 12;
    5: baseMovement := 9;
    6: baseMovement := 15
  end;
  tailFlag := 0;
  level := 0;
  hpMax := 0;
  hitPoints := 0;
  GDVars.freeTraining := 1;
  savedTrainingMask := GDVars.zone1^.trainingMask;
  GDVars.zone1^.trainingMask := $FF;
  GDVars.trainingComplete := 0;
  repeat
    CharGen.TrainingMenu
  until GDVars.trainingComplete <> 0;
  GDVars.zone1^.trainingMask := savedTrainingMask;
  GDVars.freeTraining := 0;
  ViewChar.PrintCombatStats;
  InitializeCareerSkills;
  ViewChar.DisplayCareerSkills;
  ViewChar.PrintMoney;
  ch := MenuCore.YesNoMenu('Reroll stats? ', C_Menu.DEFAULT_NO);
  until ch = 'N';
  ViewChar.DisplayChar;
  repeat
    name := TextRend.ReadString('Character name: ', LightMagenta, Black, 15)
  until Length(name) <> 0;
  if career = C_Career.WARRIOR then
    ViewChar.SpecializationMenu(True, 3);
  InitializeAllSkills;
  Skills.ApplyInitialSkills(character);
  Skills.EditSkills(0, 0, 105, 1);
  CharGen.SetDefaultIcon;
  CharGen.CustomizeIcon;
  ch := MenuCore.YesNoMenu('Save ' + name + '? ', C_Menu.DEFAULT_YES);
  if ch = 'N' then begin
    FreeMem(character, SizeOf(Types.TCharRecord));
    GDVars.currentCharacter := previous;
    Exit
  end;
  Shop.BuildAmmoItems;
  if SaveLoad.SaveChar(character, '') then;
  FreeMem(character, SizeOf(Types.TCharRecord));
  GDVars.currentCharacter := previous
  end
end;

const
  MODIFY_KEYS = ['1'..'9', '\'];

{ Edits a character that has only its starting experience: its abilities, name and hit-point maximum, within HpMinimum
  and HpMaximum. Keep keeps the changes; Exit and Escape restore them. }
procedure ModifyCharacterMenu;
var
  savedStats: array[0..6] of Byte;
  { hpMax is a Word: this keeps its low byte, which Exit and Escape put back zero-extended }
  savedHpMax: Byte;
  savedName: String[40];
  i: ShortInt;
  inputChar: Char;
  field: Byte;
  { Unused in this version; see the other implementations of this routine. }
  numberText: array[1..8] of Byte;
  nameIndex: Byte;
  shiftIndex: Byte;

  { Redraws field; a highlighted name shows its character at nameIndex in white, '%' for a space. }
  procedure DisplayModifyField(isHighlighted: Boolean);
  begin
    case field of
      0..6: ViewChar.PrintStat(field, isHighlighted);
      C_Menu.MODIFY_HIT_POINTS_FIELD: MenuCore.PrintHitPoints(GDVars.currentCharacter, 31, 1, isHighlighted, True);
      C_Menu.MODIFY_NAME_FIELD: if isHighlighted then begin
          TextRend.PrintSpaces(Length(GDVars.currentCharacter^.name) + 8, 1, Black, 1);
          TextRend.DisplayString(8, 1, LightMagenta, Black, GDVars.currentCharacter^.name);
          if GDVars.currentCharacter^.name[nameIndex] = ' ' then
            TextRend.DisplayString(nameIndex + 7, 1, White, Black, '%')
          else
            TextRend.DisplayString(nameIndex + 7, 1, White, Black, GDVars.currentCharacter^.name[nameIndex])
        end else
          TextRend.DisplayString(8, 1, LightGreen, Black, GDVars.currentCharacter^.name)
    end
  end;

  { In the name field, deletes the character at nameIndex, leaving at least one. }
  procedure DeleteNameCharacter;
  var
    i: Byte;
  begin
    if field = C_Menu.MODIFY_NAME_FIELD then
      if Length(GDVars.currentCharacter^.name) > 1 then
        if nameIndex = Length(GDVars.currentCharacter^.name) then begin
          Dec(GDVars.currentCharacter^.name[0]);
          nameIndex := Length(GDVars.currentCharacter^.name)
        end else begin
          for i := nameIndex to
                Length(GDVars.currentCharacter^.name) - 1 do
            GDVars.currentCharacter^.name[i] := GDVars.currentCharacter^.name[i + 1];
          Dec(GDVars.currentCharacter^.name[0])
        end
  end;

begin
  if (GDVars.partyClicked = 0) and not ViewChar.PickCharacter then Exit;
  if GDConsts.experienceNeeded[GDVars.currentCharacter^.career, 7] <> GDVars.currentCharacter^.experience then begin
      TextRend.PrintAndPause(GDVars.currentCharacter^.name + ' can''t be modified.', Yellow, Black);
      Exit
    end;
  GDVars.modifyFieldSelection := CharGen.NO_MODIFY_FIELD;
  GDVars.modifyActive := 1;
  ViewChar.DisplayChar;
  for i := 0 to SizeOf(savedStats) - 1 do
    savedStats[i] := GDVars.currentCharacter^.abilities[i];
  savedHpMax := GDVars.currentCharacter^.hpMax;
  savedName := GDVars.currentCharacter^.name;
  nameIndex := 1;
  field := C_Menu.MODIFY_HIT_POINTS_FIELD;
  DisplayModifyField(False);
  field := 0;
  DisplayModifyField(True);
  with GDVars.currentCharacter^ do begin
  repeat
    GDVars.modifyFieldSelection := CharGen.NO_MODIFY_FIELD;
    if field = C_Menu.MODIFY_NAME_FIELD then begin
      GDVars.extFlag := False;
      repeat until GameIo.InputPending;
      inputChar := GameIo.ReadGameKey;
      if inputChar in CharGen.MODIFY_KEYS then begin
        if inputChar = '\' then inputChar := '7'
        else inputChar := GDConsts.keypadScan[Ord(inputChar) - Ord('1')];
        GDVars.extFlag := True
      end;
      if inputChar = #0 then begin
        inputChar := GameIo.ReadGameKey;
        GDVars.extFlag := True
      end;
      if inputChar = C_Keys.ESCAPE then inputChar := C_Keys.NONE
    end else begin
      MenuCore.MenuHorizontal('Modify: ', 'Add Subtract Keep Exit', True, False);
      inputChar := GDVars.menuKey
    end;
    DisplayModifyField(False);
    if GDVars.modifyFieldSelection <> CharGen.NO_MODIFY_FIELD then begin
      field := GDVars.modifyFieldSelection;
      if inputChar = C_Keys.ENTER then inputChar := 'A'
      else if inputChar = C_Keys.ESCAPE then inputChar := 'S'
      else inputChar := C_Keys.NONE;
      GDVars.extFlag := False
    end;
    if GDVars.extFlag then begin
      case inputChar of
        C_Keys.LEFT, CharGen.KEY_DELETE: DeleteNameCharacter;
        C_Keys.DOWN: begin
          Inc(field);
          if field > C_Menu.MODIFY_HIT_POINTS_FIELD then field := 0
        end;
        C_Keys.UP: begin
          Dec(field);
          if field = 255 then field := C_Menu.MODIFY_HIT_POINTS_FIELD
        end
      end
    end else case inputChar of
    C_Keys.BACKSPACE: DeleteNameCharacter;
    'A', 'S': begin
      if field < C_Menu.MODIFY_NAME_FIELD then begin
        i := field;
        if inputChar = 'A' then Inc(abilities[i])
        else Dec(abilities[i]);
        if abilities[i] > GDConsts.raceStatAdjust[race, i] + 18 then
          abilities[i] := GDConsts.raceStatAdjust[race, i] + 18;
        if abilities[i] < GDConsts.raceStatAdjust[race, i] + 3 then
          abilities[i] := GDConsts.raceStatAdjust[race, i] + 3;
        if abilities[i] < GDConsts.careerStatMinimum[career, i] then
          abilities[i] := GDConsts.careerStatMinimum[career, i];
        if i = 2 then begin
          if CharGen.HpMinimum(GDVars.currentCharacter) > hpMax then
            hpMax := CharGen.HpMinimum(GDVars.currentCharacter)
          else if CharGen.HpMaximum(GDVars.currentCharacter) < hpMax then
            hpMax := CharGen.HpMaximum(GDVars.currentCharacter);
          hitPoints := hpMax;
          field := C_Menu.MODIFY_NAME_FIELD;
          DisplayModifyField(False);
          field := 2
        end;
        ViewChar.DisplayCareerSkills
      end else if field = C_Menu.MODIFY_HIT_POINTS_FIELD then begin
        if inputChar = 'A' then Inc(hpMax) else Dec(hpMax);
        if CharGen.HpMaximum(GDVars.currentCharacter) < hpMax then
          hpMax := CharGen.HpMaximum(GDVars.currentCharacter);
        if CharGen.HpMinimum(GDVars.currentCharacter) > hpMax then
          hpMax := CharGen.HpMinimum(GDVars.currentCharacter);
        hitPoints := hpMax
      end else begin
        if nameIndex = Length(GDVars.currentCharacter^.name) then
          nameIndex := 1
        else Inc(nameIndex)
      end
      end;
    C_Keys.ENTER: begin
      Inc(field);
      if field > C_Menu.MODIFY_HIT_POINTS_FIELD then field := 0
    end;
    { Note: never reached; the arm above takes Backspace }
    C_Keys.BACKSPACE: if (nameIndex > 1) and
      (field = 6) then begin
      for shiftIndex := nameIndex to
          Length(GDVars.currentCharacter^.name) do
        GDVars.currentCharacter^.name[shiftIndex - 1] := GDVars.currentCharacter^.name[shiftIndex];
      Dec(GDVars.currentCharacter^.name[0]);
      if nameIndex > Length(GDVars.currentCharacter^.name) then
        nameIndex := Length(GDVars.currentCharacter^.name)
    end;
    '0', '1'..'9', ' '..'z': begin
        if field = C_Menu.MODIFY_NAME_FIELD then begin
          if nameIndex <= 15 then begin
            GDVars.currentCharacter^.name[nameIndex] := inputChar;
            Inc(nameIndex);
            if nameIndex > 15 then nameIndex := 15;
            if nameIndex > Length(GDVars.currentCharacter^.name) then begin
              Inc(GDVars.currentCharacter^.name[0]);
              GDVars.currentCharacter^.name[nameIndex] := ' '
            end
          end
        end else if inputChar = 'E' then begin
          for i := 0 to SizeOf(savedStats) - 1 do
            GDVars.currentCharacter^.abilities[i] := savedStats[i];
          GDVars.currentCharacter^.hpMax := savedHpMax;
          GDVars.currentCharacter^.hitPoints := hpMax;
          GDVars.currentCharacter^.name := savedName;
          CharHlp.RecalcStats(GDVars.currentCharacter);
          GDVars.modifyActive := 0;
          Exit
        end
      end;
    C_Keys.NONE: begin
        for i := 0 to SizeOf(savedStats) - 1 do
          GDVars.currentCharacter^.abilities[i] := savedStats[i];
        GDVars.currentCharacter^.hpMax := savedHpMax;
        GDVars.currentCharacter^.name := savedName;
        GDVars.currentCharacter^.hitPoints := hpMax;
        CharHlp.RecalcStats(GDVars.currentCharacter);
        GDVars.modifyActive := 0;
        Exit
      end
    end;
    CharHlp.RecalcStats(GDVars.currentCharacter);
    ViewChar.PrintCombatStats;
    DisplayModifyField(True)
  until not GDVars.extFlag and (inputChar = 'K');
  for i := 0 to SizeOf(GDVars.currentCharacter^.currentAbilities) - 1 do
    GDVars.currentCharacter^.currentAbilities[i] := GDVars.currentCharacter^.abilities[i];
  GDVars.modifyActive := 0
  end
end;

procedure DropCharacterMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  answer: Byte;
  scan: Types.PCharRecord;
begin
  if (GDVars.partyClicked = 0) and not ViewChar.PickCharacter then Exit;
  if GDVars.currentCharacter <> nil then begin
    GDVars.promptColor := Yellow;
    with GDVars.currentCharacter^ do begin
      if MenuCore.YesNoMenu('Drop ' + name + ' forever? ', C_Menu.DEFAULT_NO) = 'Y' then begin
        GDVars.promptColor := Yellow;
        if MenuCore.YesNoMenu('Are you sure? ', C_Menu.DEFAULT_NO) = 'Y' then begin
          if enabled = 0 then
            CharHlp.PrintBottomLine('You incinerate ' + name + '.')
          else
            CharHlp.PrintBottomLine(name + ' hitches the next rocket.');
          TextRend.PauseOnly;
          TextRend.PauseOnly;
          SaveLoad.DeleteCharacterFiles(GDVars.currentCharacter);
          CharGen.RemoveCreature(False, True);
          MenuCore.DisplayParty(GDVars.currentCharacter);
          Exit
        end
      end;
      CharHlp.PrintBottomLine(name + ' gives a sigh of relief.')
    end
  end;
  GDVars.partyDefeated := 1;
  scan := GDVars.partyHead;
  while scan <> nil do
    if (scan^.side = C_Side.TEAM) and (scan^.enabled <> 0) and (scan^.skillLevels[0] = 0) then begin
      GDVars.partyDefeated := 0;
      scan := nil
    end else
      scan := scan^.nextCharAddr
end;

const
  { the most player characters (npc below NON_PLAYER_FLAG) the party takes }
  MAX_PLAYER_CHARACTERS = 6;

{ Asks whether to load from Doomsday's saves or this game's own, lists the saved characters not in the party and adds
  the ones picked, up to six player characters and eight members in all. }
procedure AddCharacterMenu;
var
  displayList: Types.PMenuNode;
  recordList: Types.PMenuNode;
  selected: Types.PMenuNode;
  source: Types.PMenuNode;
  candidate: Types.PCharRecord;
  scan: Types.PCharRecord;
  index: Integer;
  ch: Char;
  { Note: never set, so MenuVertical gets whatever the stack holds }
  offersExit: Boolean;
  needsRedraw: Boolean;
  realCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rangerCount: Byte;
begin
  Border.ClearBox(1, 1, 38, 22);
  MenuCore.MenuHorizontal('load from:', 'Matrix Countdown', False, False);
  case GDVars.menuKey of
    'C': GDVars.importFormat := 0;
    'M': GDVars.importFormat := 1
  else
    { Note: meant as Escape, which MenuHorizontal answers as NONE }
    if GDVars.extFlag and (GDVars.menuKey = C_Keys.RIGHT_BRACKET) then Exit
  end;
  SaveLoad.LoadCharlist(displayList, recordList);
  if displayList <> nil then begin
    index := 0;
    selected := displayList;
    needsRedraw := True;
    repeat
      ch := MenuCore.MenuVertical('Add a character: ', 'Add ', 1, 2, 38, 22, displayList, offersExit, needsRedraw,
                                  index, selected);
      if (ch = C_Keys.ENTER) or (ch = 'A') then
        if selected^.name[1] <> '*' then begin
          TextRend.ClearStatusLine;
          GetMem(candidate, SizeOf(Types.TCharRecord));
          source := MenuCore.FindListMember(index, recordList);
          SaveLoad.LoadChar(source^.name, candidate, False, True);
          selected^.name := '* ' + selected^.name;
          realCount := 0;
          if GDVars.partyHead = nil then begin
            GDVars.zone1^.partyCount := 0;
            SaveLoad.AddCharToParty(candidate);
            SaveLoad.LoadCharIconAnim(True)
          end else begin
            scan := GDVars.partyHead;
            while (scan <> nil) and (scan^.name <> candidate^.name) do begin
              if scan^.npc < C_Npc.NON_PLAYER_FLAG then Inc(realCount);
              scan := scan^.nextCharAddr
            end;
            if (scan = nil) and
                (((candidate^.npc < C_Npc.NON_PLAYER_FLAG) and (realCount < CharGen.MAX_PLAYER_CHARACTERS)) or
                 ((candidate^.npc > C_Npc.NON_PLAYER_FLAG - 1) and
                  (GDVars.zone1^.partyCount < C_Combat.MAX_PARTY_SIZE))) then begin
              SaveLoad.AddCharToParty(candidate);
              SaveLoad.LoadCharIconAnim(True);
              if candidate^.npc < C_Npc.NON_PLAYER_FLAG then Inc(realCount)
            end else begin
              Delete(selected^.name, 1, 2);
              FreeMem(candidate, SizeOf(Types.TCharRecord))
            end
          end
        end
    until (ch = 'E') or (ch = C_Keys.NONE) or (realCount > CharGen.MAX_PLAYER_CHARACTERS - 1) or
        (GDVars.zone1^.partyCount > C_Combat.MAX_PARTY_SIZE - 1);
    MenuCore.FreeStringList(displayList)
  end;
  GDVars.canClickParty := True
end;

procedure RemoveCreature(keepsPartyCount, freesIcon: Boolean);
var node: Types.PCharRecord;
begin
  if GDVars.partyHead = nil then Exit;
  node := GDVars.partyHead;
  if node <> GDVars.currentCharacter then begin
    while (node^.nextCharAddr <> GDVars.currentCharacter) and (node^.nextCharAddr <> nil) do
      node := node^.nextCharAddr;
    if node^.nextCharAddr <> nil then begin
      if freesIcon then
        MapTiles.FreeIconAnim(GDVars.currentCharacter^.orderNumber);
      node^.nextCharAddr := GDVars.currentCharacter^.nextCharAddr;
      CharGen.FreeCreature(GDVars.currentCharacter);
      GDVars.currentCharacter := node;
      if not keepsPartyCount then Dec(GDVars.zone1^.partyCount)
    end
  end else begin
    if freesIcon then MapTiles.FreeIconAnim(GDVars.currentCharacter^.orderNumber);
    GDVars.partyHead := GDVars.currentCharacter^.nextCharAddr;
    node := GDVars.currentCharacter^.nextCharAddr;
    CharGen.FreeCreature(GDVars.currentCharacter);
    GDVars.currentCharacter := node;
    if not keepsPartyCount then Dec(GDVars.zone1^.partyCount)
  end;
  if GDVars.currentCharacter = nil then GDVars.currentCharacter := GDVars.partyHead
end;

{ Gives the current character its starting icon: 17 for a tinker, one of four at random for a desert runner, else
  characterIcons' by gender and career. }
procedure SetDefaultIcon;
begin
  with GDVars.currentCharacter^ do
    if race = 5 then icon := 17
    else if race = 6 then
      case CharHlp.RollDice(1, 4) of
        1: icon := 16;
        2: icon := 23;
        3: icon := 24;
        4: icon := 31
      end else
      icon := GDConsts.characterIcons[gender, career]
end;

{ Frees every picture of an image grid.
  @param(images The grid freed.) }
procedure ClearImageGrid(var images: TImageGrid);
var
  i: Byte;
  j: Byte;
begin
  for i := 0 to SizeOf(images) div SizeOf(images[0]) - 1 do
    for j := 0 to SizeOf(images[0]) div SizeOf(Types.PImgBuf) - 1 do
      Blit.FreePic(images[i, j])
end;

{ Loads CHARS.DAX's 72 records, two frames for each of the 36 body icons, into images (masked on color 8) from data set
  1 with the sound silenced, then loads their DAC range. A missing CHARS.DAX ends the game.
  @param(images Receives the icons.) }
procedure LoadCharacterImages(var images: TImageGrid);
var
  dataFile: file;
  indexFile: file;
  headerSize: Word;
  entries: PImageEntries;
  data: Types.PByteArr;
  i: Byte;
  j: Byte;
  bytesRead: Word;
  loadedSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  largestFreeBlock: LongInt;
begin
  DaxIo.PushState(1);
  Music.SendSoundCommand(GDConsts.silenceSounds);
  if not DaxIo.OpenDax('CHARS', '.DAX', headerSize, dataFile, indexFile) then begin
    TextRend.DisplayValue('Can''t open CHARS.DAX! ', 0);
    GameIo.ExitGame
  end;
  TextRend.DisplayLoading;
  GetMem(entries, SizeOf(TImageEntries));
  BlockRead(indexFile, entries^, headerSize, bytesRead);
  largestFreeBlock := MaxAvail;
  GetMem(data, SizeOf(TIconRecord));
  for i := 0 to SizeOf(images) div SizeOf(images[0]) - 1 do
    for j := 0 to SizeOf(images[0]) div SizeOf(Types.PImgBuf) - 1 do begin
      with entries^[i * (SizeOf(images[0]) div SizeOf(Types.PImgBuf)) + j] do begin
        Seek(dataFile, headerSize + offset);
        DaxIo.DecompressDax(data, size, dataFile);
        Blit.PreparePic(data, 1, 8, True, loadedSize, images[i, j])
      end
    end;
  Close(indexFile);
  Close(dataFile);
  Music.SendSoundCommand(GDConsts.soundOutputOn);
  DaxIo.PopState;
  GameIo.FlushKeys;
  FreeMem(data, SizeOf(TIconRecord));
  FreeMem(entries, SizeOf(TImageEntries));
  TextRend.ClearStatusLine;
  Blit.SetDacPalette(C_Pic.CHARS_ICON_DAC_FIRST, C_Pic.CHARS_ICON_DAC_COUNT, GDVars.picturePalette)
end;

const
  { the icon slot the editor draws its candidates in }
  PREVIEW_SLOT = 11;
  { DrawCandidate's iconChoice: the icon the character has now }
  CURRENT_ICON_CHOICE = 254;
  { DrawCandidate's iconChoice: the icon it had on entry }
  DEFAULT_ICON_CHOICE = 255;

{ Lets the player pick the current character's body icon from CHARS.DAX's 6 by 6 grid, the old icon shown above the new,
  each in its ready and action frames; does nothing for a companion. }
procedure CustomizeIcon;
var
  { Unused in this version; see the other implementations of this routine. }
  state: Byte;
  savedSequence: Types.TIconSequence;
  defaultIcon: Byte;
  isDone: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuExt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedOrder: Byte;
  { Unused in this version; see the other implementations of this routine. }
  imageBuffer: array[$16..$116] of Byte;
  images: PImageGrid;
  imageSize: Word;
  selected: Byte;
  deltaColumn: ShortInt;
  deltaRow: ShortInt;

  { Copies body icon source's two frames, with their masks or else their transparent colors, into icon slot selected. }
  procedure CopyIconImages(source: Byte);
  begin
    Move(images^[source, 0]^.data, GDVars.iconFrames[selected, 0]^.data, GDVars.iconFrames[selected, 0]^.frameSize);
    Move(images^[source, 1]^.data, GDVars.iconFrames[selected, 1]^.data, GDVars.iconFrames[selected, 1]^.frameSize);
    if images^[source, 0]^.transp <> nil then
      Move(images^[source, 0]^.transp^, GDVars.iconFrames[selected, 0]^.transp^, imageSize)
    else
      GDVars.iconFrames[selected, 0]^.transparentColor := images^[source, 0]^.transparentColor;
    if images^[source, 1]^.transp <> nil then
      Move(images^[source, 1]^.transp^, GDVars.iconFrames[selected, 1]^.transp^, imageSize)
    else
      GDVars.iconFrames[selected, 1]^.transparentColor := images^[source, 1]^.transparentColor
  end;

  { Draws the current character with icon iconChoice through slot selected; sequenceChoice is never read. }
  procedure DrawCandidate(column, row: ShortInt; iconChoice, sequenceChoice, frame: Byte; isHighlighted: Boolean);
  var
    savedIcon: Byte;
    savedOrder: Byte;
    savedSequence: Types.TIconSequence;
    background: ShortInt;
  begin
    if isHighlighted then begin
      if GDVars.displayMode = C_Vm.CGA then background := 15
      else if GDVars.displayMode = C_Vm.TANDY then background := 7
      else background := -1
    end else begin
      if GDVars.displayMode = C_Vm.CGA then background := 8
      { 8 either way }
      else background := 8
    end;
    if background < 0 then
      MapTiles.DrawIconAnimSprite(column, row, 0, 0, 32)
    else
      Blit.FillPicRect(column * 3, row * 24, 3, 24, background, GDConsts.packedColorMap, GDVars.viewPicture);
    with GDVars.currentCharacter^ do begin
      savedIcon := icon;
      savedSequence := iconSequence;
      savedOrder := orderNumber;
      orderNumber := selected;
      if iconChoice = CharGen.DEFAULT_ICON_CHOICE then icon := defaultIcon
      else if iconChoice <> CharGen.CURRENT_ICON_CHOICE then icon := iconChoice;
      CopyIconImages(icon);
      MapTiles.DrawIconAnimSprite(column, row, 0, frame, selected);
      icon := savedIcon;
      iconSequence := savedSequence;
      orderNumber := savedOrder
    end
  end;

  { Draws the current character's ready and action frames at (column, row) and (column + 3, row). }
  procedure ShowIconFrames(column, row: Byte);
  begin
    DrawCandidate(column, row, CharGen.CURRENT_ICON_CHOICE, 254, 0, GDVars.displayMode <> C_Vm.CGA);
    Blit.FlushView;
    DrawCandidate(column + 3, row, CharGen.CURRENT_ICON_CHOICE, 254, 1, GDVars.displayMode <> C_Vm.CGA);
    Blit.FlushView
  end;

  { Draws the whole icon grid, or moves its highlight by (column, row) and makes that icon the character's. }
  procedure DrawIconGrid(column, row: ShortInt; isWholeGrid: Boolean);
  var
    index: ShortInt;
    currentColumn: ShortInt;
    currentRow: ShortInt;
  begin
    if isWholeGrid then begin
      index := 0;
      for row := 0 to 5 do
        for column := 0 to 5 do begin
          if index = GDVars.currentCharacter^.icon then
            DrawCandidate(column + 6, row + 1, index, 254, 0, True)
          else
            DrawCandidate(column + 6, row + 1, index, 254, 0, False);
          Inc(index)
        end
    end else begin
      currentColumn := GDVars.currentCharacter^.icon mod 6;
      currentRow := GDVars.currentCharacter^.icon div 6;
      DrawCandidate(currentColumn + 6, currentRow + 1, GDVars.currentCharacter^.icon, 254, 0, False);
      Inc(column, currentColumn);
      if column < 0 then column := 5
      else if column > 5 then column := 0;
      Inc(row, currentRow);
      if row < 0 then row := 5
      else if row > 5 then row := 0;
      GDVars.currentCharacter^.icon := row * 6 + column;
      DrawCandidate(column + 6, row + 1, GDVars.currentCharacter^.icon, 254, 0, True)
    end;
    Blit.FlushView
  end;
begin
  if GDVars.currentCharacter^.skillLevels[0] <> 0 then Exit;
  GDVars.iconEditorActive := 1;
  selected := CharGen.PREVIEW_SLOT;
  Border.DrawWindowFrame(1);
  CbtMap.SetCombatPalette;
  defaultIcon := GDVars.currentCharacter^.icon;
  savedSequence := GDVars.currentCharacter^.iconSequence;
  isDone := False;
  savedOrder := GDVars.currentCharacter^.orderNumber;
  menuExt := 255;
  GetMem(images, SizeOf(TImageGrid));
  CharGen.LoadCharacterImages(images^);
  MapTiles.FreeIconAnim(selected);
  Blit.AllocPic(24, 3, 1, 1, GDVars.iconFrames[selected, 0]);
  Blit.AllocPic(24, 3, 1, 1, GDVars.iconFrames[selected, 1]);
  imageSize := GDVars.iconFrames[selected, 0]^.frameSize;
  repeat
    with GDVars.currentCharacter^ do begin
      icon := defaultIcon;
      iconSequence := savedSequence;
      state := 1;
      ShowIconFrames(1, 2);
      TextRend.DisplayString(8, 6, White, Black, 'old');
      TextRend.DisplayString(3, 10, White, Black, 'ready   action');
      TextRend.DisplayString(8, 12, White, Black, 'new');
      TextRend.DisplayString(3, 16, White, Black, 'ready   action');
      DrawIconGrid(0, 0, True);
      isDone := False;
      repeat
        ShowIconFrames(1, 4);
        MenuCore.MenuHorizontal('Select a body icon. ', 'Done', True, False);
        case GDVars.menuKey of
          C_Keys.HOME: DrawIconGrid(-1, -1, False);
          C_Keys.UP: DrawIconGrid(0, -1, False);
          C_Keys.PAGE_UP: DrawIconGrid(1, -1, False);
          C_Keys.LEFT: DrawIconGrid(-1, 0, False);
          C_Keys.RIGHT: DrawIconGrid(1, 0, False);
          C_Keys.END_KEY: DrawIconGrid(-1, 1, False);
          C_Keys.DOWN: DrawIconGrid(0, 1, False);
          C_Keys.PAGE_DOWN: DrawIconGrid(1, 1, False);
          { a mouse click, which on the current icon ends the choice }
          '!': begin
                deltaColumn := (GDVars.mouseX - 152) div 24 - (icon mod 6);
                deltaRow := (GDVars.mouseY - 32) div 24 - (icon div 6);
                if (deltaColumn = 0) and (deltaRow = 0) then isDone := True
                else DrawIconGrid(deltaColumn, deltaRow, False)
              end;
          'D': isDone := True;
          { Note: meant as Escape, which MenuHorizontal answers as NONE }
          C_Keys.RIGHT_BRACKET, C_Keys.NONE: begin
                    icon := defaultIcon;
                    isDone := True
                  end
        end
      until isDone;
    end;
    TextRend.ClearStatusLine;
    GDVars.menuKey := MenuCore.YesNoMenu('Is this icon ok? ', C_Menu.DEFAULT_YES)
  until GDVars.menuKey = 'Y';
  MapTiles.FreeIconAnim(selected);
  selected := GDVars.currentCharacter^.orderNumber;
  if GDVars.iconFrames[selected, 0] <> nil then
    CopyIconImages(GDVars.currentCharacter^.icon);
  CharGen.ClearImageGrid(images^);
  FreeMem(images, SizeOf(TImageGrid));
  CbtMap.SetNoncombatPalette;
  GDVars.iconEditorActive := 0
end;

{ Gives the least maximum hit points Modify allows.
  @param(character The character modified.)
  @returns((constitution bonus + 1, at least 1 and for non-warriors at most 3) times the level.) }
function HpMinimum(character: Pointer): Byte;
var value: ShortInt;
begin
  with Types.PCharRecord(character)^ do begin
    value := GDConsts.constitutionLevelBonus[abilities[CharGen.ABIL_CON]] + 1;
    if value < 1 then value := 1;
    if (value > 3) and (career <> C_Career.WARRIOR) then value := 3;
    HpMinimum := value * level
  end
end;

{ Gives the most maximum hit points Modify allows.
  @param(character The character modified.)
  @returns((constitution bonus, for non-warriors at most 2, plus 10 for a warrior, 8 for a scout or engineer, 6 for a
    rocket jock, rogue or medic) times the level.) }
function HpMaximum(character: Pointer): Byte;
var value: ShortInt;
begin
  with Types.PCharRecord(character)^ do begin
    value := GDConsts.constitutionLevelBonus[abilities[CharGen.ABIL_CON]];
    if (career <> C_Career.WARRIOR) and (value > 2) then value := 2;
    case career of
      C_Career.WARRIOR: Inc(value, 10);
      C_Career.SCOUT, CharGen.CAREER_ENGINEER: Inc(value, 8);
      C_Career.ROCKET_JOCK, C_Career.ROGUE, C_Career.MEDIC: Inc(value, 6)
    end;
    value := value * level;
    HpMaximum := value
  end
end;

{ Adds a level's hit points: below level 10 the better of two career dice (d10 warrior, d8 engineer, else d6) plus the
  constitution bonus, at most 2 for a non-warrior (at least 1 in all); from level 10 a fixed 2, or 3 for a warrior.
  @param(character The character.) }
procedure AddLevelHitPoints(character: Pointer);
var
  first: ShortInt;
  second: ShortInt;
    sides: Byte;
    modifier: ShortInt;
begin
  with Types.PCharRecord(character)^ do begin
    if level < 10 then begin
      sides := 6;
      if career = C_Career.WARRIOR then sides := 10
      else if career = CharGen.CAREER_ENGINEER then sides := 8;
      first := CharHlp.RollDice(1, sides);
      second := CharHlp.RollDice(1, sides);
      if first < second then first := second;
      modifier := GDConsts.constitutionLevelBonus[abilities[CharGen.ABIL_CON]];
      if (career <> C_Career.WARRIOR) and (modifier > 2) then modifier := 2;
      Inc(first, modifier);
      if first < 1 then first := 1
    end else
      case career of
        C_Career.ROCKET_JOCK, CharGen.CAREER_ENGINEER, C_Career.ROGUE, C_Career.MEDIC,
        C_Career.SCOUT: first := 2;
        C_Career.WARRIOR: first := 3
      end;
    Inc(hpMax, first);
    Inc(hitPoints, first)
  end
end;

{ Trains the current character one level, when it is conscious, below level 20 and has the experience for it: hit
  points, a specialization for a warrior at an even level, and skill points, with experience cut back below the next
  level's; every third level lowers each saving throw by 1. With freeTraining set, during creation, it asks nothing and
  sets trainingComplete once the experience runs out. }
procedure TrainingMenu;
var isAtMaxLevel: Boolean;
    { Unused in this version; see the other implementations of this routine. }
    message: String[80];
    i: ShortInt;
begin
  if (GDVars.freeTraining <> 0) or (GDVars.partyClicked <> 0) or ViewChar.PickCharacter then begin
    if GDVars.currentCharacter^.status <> C_Status.OKAY then begin
      TextRend.PrintAndPause('we only train conscious people', Yellow, Black);
      Exit
    end;
    with GDVars.currentCharacter^ do begin
      GDVars.trainingMode := 0;
      isAtMaxLevel := level >= CharGen.MAX_LEVEL;
      { always taken: trainingMode was just cleared }
      if GDVars.trainingMode = 0 then begin
        if GDVars.freeTraining = 0 then begin
          if isAtMaxLevel then begin
            TextRend.PrintAndPause('maximum level in game has been reached', Yellow, Black);
            Exit
          end;
          if GDConsts.experienceNeeded[career, Succ(level)] > experience then begin
            TextRend.PrintAndPause('Not enough experience', Yellow, Black);
            Exit
          end;
          Border.ClearBox(1, 1, 38, 22);
          MenuCore.DisplayCreatureName(GDVars.currentCharacter, 4, 4, False);
          TextRend.DisplayString(Length(name) + 4, 4, LightGreen, Black, ' will become:');
          TextRend.DisplayString(6, 5, LightGreen, Black,
                                 '    a level ' + TextRend.ByteToString(level + 1) + ' ' +
                                   GDConsts.careerNames[career]);
          if MenuCore.YesNoMenu('Do you wish to train? ', C_Menu.DEFAULT_YES) <> 'Y' then Exit;
          CharHlp.PrintBottomLine('Congratulations...')
        end else begin
          if level >= 1 then
            if GDConsts.experienceNeeded[career, Succ(level)] > experience then begin
              GDVars.trainingComplete := 1;
              Exit
            end
        end
      end;
      level := Succ(level);
      baseCombat := GDConsts.careerBaseCombat[career, level];
      CharGen.AddLevelHitPoints(GDVars.currentCharacter);
      if GDVars.freeTraining = 0 then begin
        if (career = C_Career.WARRIOR) and not Odd(level) then
          ViewChar.SpecializationMenu(True, 1);
        if GDConsts.experienceNeeded[career, Succ(level)] <= experience then
          experience := GDConsts.experienceNeeded[career, Succ(level)] - 1;
        Skills.EditSkills(40, 20, 15, 0)
      end;
      if TLevelValue(level) mod 3 = 0 then
        for i := 0 to SizeOf(saves) - 1 do Dec(saves[i])
    end
  end
end;

{ Lets the player turn the mouse or joystick on or off, or disable both, calibrating the joystick when it is turned on.
  Each change rewrites the configuration file: line 3 holds the input mode (M, J, or N) and the joystick calibration, or
  zeros, follow the five header lines. }
procedure InitMouseJoystick;
var
  head: Types.PMenuNode;
  node: Types.PMenuNode;
  isDone: Boolean;
  ch: Char;
  needsRedraw: Boolean;
  count: Integer;
  buttons: Integer;
  readX: Integer;
  readY: Integer;
  selected: Types.PMenuNode;
  configIn: Text;
  configOut: Text;
  i: Byte;
  lines: array[1..5] of String;
  items: array[1..3] of Types.TString40;
begin
  MenuCore.AllocStringList(SizeOf(items) div SizeOf(items[1]), head);
  needsRedraw := True;
  isDone := False;
  selected := head;
  count := 0;
  repeat
    Assign(configIn, GDConsts.configFileName);
    Reset(configIn);
    for i := 1 to SizeOf(lines) div SizeOf(lines[1]) do ReadLn(configIn, lines[i]);
    Close(configIn);
    if GDVars.isMouseOn then items[1] := 'mouse ON' else items[1] := 'mouse OFF';
    if GDVars.isJoystickOn then items[2] := 'joystick ON'
    else items[2] := 'joystick OFF';
    items[3] := 'disable both';
    node := head;
    for i := 1 to SizeOf(items) div SizeOf(items[1]) do begin
      node^.name := items[i];
      node^.menuLabel := 0;
      node := node^.next
    end;
    needsRedraw := True;
    ch := MenuCore.MenuVertical('Init Mouse/Joystick: ', 'Select', 9, 12, 38, 22, head, True, needsRedraw, count,
                                selected);
    if ch = 'S' then case count of
      0: begin
          GDVars.isMouseOn := GDVars.isMouseOn = False;
          Assign(configOut, GDConsts.configFileName);
          Rewrite(configOut);
          if GDVars.isMouseOn then begin
            GDVars.canClickParty := True;
            GDVars.mouseButtons := 0;
            Mouse.InitMouse;
            if GDVars.isMouseOn then begin
              if GDVars.displayMode = C_Vm.CGA then GDVars.mouseCursorMask := @GDConsts.cgaArrowCursor
              else GDVars.mouseCursorMask := @GDConsts.arrowCursor;
              Mouse.SetMouseCursor(0, 0, GDVars.mouseCursorMask);
              GDVars.isMouseScaled := True;
              Mouse.SetMouse(639, 100);
              Mouse.GetMouse(buttons, readX, readY);
              GDVars.isMouseScaled := (readX >= 321) = False;
              GDVars.isJoystickOn := False;
              Mouse.ShowMouse;
              lines[3] := 'M';
              for i := 1 to SizeOf(lines) div SizeOf(lines[1]) do WriteLn(configOut, lines[i]);
              for i := 0 to SizeOf(Types.TJoyCal) div SizeOf(Word) - 1 do WriteLn(configOut, '0');
              Close(configOut);
              GDVars.mouseX := 160;
              GDVars.mouseY := 100;
              GDVars.mouseOldX := 0;
              GDVars.mouseOldY := 0
            end
          end;
          if not GDVars.isMouseOn then begin
            lines[3] := 'N';
            for i := 1 to SizeOf(lines) div SizeOf(lines[1]) do WriteLn(configOut, lines[i]);
            for i := 0 to SizeOf(Types.TJoyCal) div SizeOf(Word) - 1 do WriteLn(configOut, '0');
            Close(configOut);
            GDVars.isMouseOn := True;
            Mouse.HideMouse;
            GDVars.isMouseOn := False
          end
        end;
      1: begin
          GDVars.isJoystickOn := GDVars.isJoystickOn = False;
          Assign(configOut, GDConsts.configFileName);
          Rewrite(configOut);
          if GDVars.isJoystickOn then begin
            CharGen.CalibrateJoystickInWindow;
            if GDVars.isJoystickOn then begin
              lines[3] := 'J';
              for i := 1 to SizeOf(lines) div SizeOf(lines[1]) do WriteLn(configOut, lines[i]);
              for i := 0 to SizeOf(Types.TJoyAxis) div SizeOf(Word) - 1 do begin
                WriteLn(configOut, GDVars.joystickCalibration[1].x[i]);
                WriteLn(configOut, GDVars.joystickCalibration[1].y[i])
              end;
              Close(configOut);
              if GDVars.isJoystickOn then begin
                Mouse.HideMouse;
                GDVars.isMouseOn := False
              end
            end
          end;
          if not GDVars.isJoystickOn then begin
            lines[3] := 'N';
            for i := 1 to SizeOf(lines) div SizeOf(lines[1]) do WriteLn(configOut, lines[i]);
            for i := 0 to SizeOf(Types.TJoyCal) div SizeOf(Word) - 1 do WriteLn(configOut, '0');
            Close(configOut)
          end
        end;
      2: begin
          GDVars.isJoystickOn := False;
          Mouse.HideMouse;
          GDVars.isMouseOn := False;
          Assign(configOut, GDConsts.configFileName);
          Rewrite(configOut);
          lines[3] := 'N';
          for i := 1 to SizeOf(lines) div SizeOf(lines[1]) do WriteLn(configOut, lines[i]);
          for i := 0 to SizeOf(Types.TJoyCal) div SizeOf(Word) - 1 do WriteLn(configOut, '0');
          Close(configOut)
        end
    end else isDone := True
  until isDone;
  MenuCore.FreeStringList(head)
end;

{ Calibrates joystick 1 in the text window, like Joystick.CalibrateJoystick: exits at once when Joystick.ProbeJoystick
  finds no stick; otherwise the center from 20 readings, then the upper-left and lower-right extremes with button 1
  down, and boundaries a third and two thirds of the way to the center. 20000 polls without a press, or a failed read,
  abort with "Unable to read joystick"; success enables the joystick. }
procedure CalibrateJoystickInWindow;
var
  sumX: Word;
  sumY: Word;
  hasReading: Boolean;
  x: Word;
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  reading: Byte;
  j: Word;
  buttons: Byte;
begin
  Joystick.ProbeJoystick;
  if not GDVars.isJoystickOn then Exit;
  sumX := 0;
  sumY := 0;
  for j := 1 to C_Joy.CALIBRATION_SAMPLES do begin
    hasReading := Joystick.ReadJoystick(1, x, y, buttons);
    Inc(sumX, x);
    Inc(sumY, y)
  end;
  GDVars.joystickCalibration[1].x[3] := sumX div C_Joy.CALIBRATION_SAMPLES;
  GDVars.joystickCalibration[1].y[3] := sumY div C_Joy.CALIBRATION_SAMPLES;
  repeat
    Border.ClearBox(1, 1, 38, 22);
    TextRend.DisplayString(1, 3, LightMagenta, Black, 'Push JOYSTICK #1 to the extreme upper');
    TextRend.DisplayString(1, 5, LightMagenta, Black, 'left position and press button #1.');
    j := 0;
    repeat
      hasReading := Joystick.ReadJoystick(1, x, y, buttons);
      Inc(j)
    until (j > 20000) or (hasReading and ((buttons and 1) <> 0));
    if j > 20000 then begin
      Border.ClearBox(1, 1, 38, 22);
      TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
      Delay(2000);
      Exit
    end;
    sumX := 65535;
    sumY := 65535;
    for GDVars.loopIndex := 1 to C_Joy.CALIBRATION_SAMPLES do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x < sumX then sumX := x;
          if y < sumY then sumY := y
        end
      end else begin
        Border.ClearBox(1, 1, 38, 22);
        TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
        Delay(2000);
        Exit
      end
  until hasReading;
  GDVars.joystickCalibration[1].x[0] := sumX;
  GDVars.joystickCalibration[1].x[1] :=
    GDVars.joystickCalibration[1].x[0] +
    (GDVars.joystickCalibration[1].x[3] - GDVars.joystickCalibration[1].x[0]) div 3;
  GDVars.joystickCalibration[1].x[2] :=
    GDVars.joystickCalibration[1].x[0] +
    (GDVars.joystickCalibration[1].x[3] - GDVars.joystickCalibration[1].x[0]) * 2 div 3;
  GDVars.joystickCalibration[1].y[0] := sumY;
  GDVars.joystickCalibration[1].y[1] :=
    GDVars.joystickCalibration[1].y[0] +
    (GDVars.joystickCalibration[1].y[3] - GDVars.joystickCalibration[1].y[0]) div 3;
  GDVars.joystickCalibration[1].y[2] :=
    GDVars.joystickCalibration[1].y[0] +
    (GDVars.joystickCalibration[1].y[3] - GDVars.joystickCalibration[1].y[0]) * 2 div 3;
  repeat until not Joystick.JoyButton(1, 1);
  repeat
    Border.ClearBox(1, 1, 38, 22);
    TextRend.DisplayString(1, 3, LightMagenta, Black, 'Push JOYSTICK #1 to the extreme lower');
    TextRend.DisplayString(1, 5, LightMagenta, Black, 'right position and press button #1.');
    j := 0;
    repeat
      hasReading := Joystick.ReadJoystick(1, x, y, buttons);
      Inc(j)
    until (j > 20000) or (hasReading and ((buttons and 1) <> 0));
    if j > 20000 then begin
      Border.ClearBox(1, 1, 38, 22);
      TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
      Delay(2000);
      Exit
    end;
    sumX := 0;
    sumY := 0;
    for GDVars.loopIndex := 1 to C_Joy.CALIBRATION_SAMPLES do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x > sumX then sumX := x;
          if y > sumY then sumY := y
        end
      end else begin
        Border.ClearBox(1, 1, 38, 22);
        TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
        Delay(2000);
        Exit
      end
  until hasReading;
  GDVars.joystickCalibration[1].x[6] := sumX;
  GDVars.joystickCalibration[1].x[4] :=
    GDVars.joystickCalibration[1].x[3] +
    (GDVars.joystickCalibration[1].x[6] - GDVars.joystickCalibration[1].x[3]) div 3;
  GDVars.joystickCalibration[1].x[5] :=
    GDVars.joystickCalibration[1].x[3] +
    (GDVars.joystickCalibration[1].x[6] - GDVars.joystickCalibration[1].x[3]) * 2 div 3;
  GDVars.joystickCalibration[1].y[6] := sumY;
  GDVars.joystickCalibration[1].y[4] :=
    GDVars.joystickCalibration[1].y[3] +
    (GDVars.joystickCalibration[1].y[6] - GDVars.joystickCalibration[1].y[3]) div 3;
  GDVars.joystickCalibration[1].y[5] :=
    GDVars.joystickCalibration[1].y[3] +
    (GDVars.joystickCalibration[1].y[6] - GDVars.joystickCalibration[1].y[3]) * 2 div 3;
  GDVars.isJoystickOn := True
end;

begin
end.
