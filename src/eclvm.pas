{ The ECL script interpreter and the map-mode main loop. DispatchEclCommand runs one script opcode,
  GDVars.currentOpcode, through its handler: Op and the opcode's ECL name where it has one, a name for its role
  otherwise. CallEclScript runs the loaded script from an address until a handler stops the run; GameLoop, which FixMain
  calls, is the map loop that runs the script's entry points around each menu choice and move. Only GameLoop is called
  from outside the unit. A handler that takes operands loads them at the ECL IP; the others step IP past their opcode.
  Note: EclNoop and the empty $3B arm leave IP where it is, so a script that reaches either never gets past it. Its
  tables, the ECL sound commands and the shop item lists, are GDConsts', and its run state is GDVars'. }
{$F+,O+,S-,R-,V-,B-,I-}
unit EclVm;

interface

{ Runs the map loop: loads the area's script (the saved one, or the start or demo script), then runs the map menu and
  the script's entry points around each choice and move until the party is defeated; the party is freed on the way out.
  In the demo it runs entry point 5 only. }
procedure GameLoop;

implementation

uses TextRend, Border, Music, Crt, EclMenu, MenuCore, CharHlp, View3D, ViewChar, FxEngine, MapView, Explore, CharGen,
  Portrait, MapCurs, GameTime, SaveLoad, Shop, OrbitMap, MapTiles, Mouse, GameIo, PostCbt, Combat, ShipCbt, Types,
  C_Combat, C_Ecl, C_Gbvm, C_Map, C_Npc, C_Pic, C_Screen, C_Search, C_Status, GDConsts, GDVars, C_Ifc, C_Diff, C_Area,
  C_Item, C_Side, C_Msg, C_Menu;

const
  { the opcodes a handler that serves several tells apart by GDVars.currentOpcode }
  OPCODE_ADD = $04;
  OPCODE_SUBTRACT = $05;
  OPCODE_DIVIDE = $06;
  OPCODE_MULTIPLY = $07;
  OPCODE_PRINT = $11;
  OPCODE_IF_EQUAL = $16;
  OPCODE_IF_NOT_EQUAL = $17;
  OPCODE_IF_LESS = $18;
  OPCODE_IF_GREATER = $19;
  OPCODE_IF_LESS_OR_EQUAL = $1A;
  OPCODE_IF_GREATER_OR_EQUAL = $1B;
  OPCODE_LOAD_FILES = $21;
  OPCODE_ON_GOTO = $25;
  OPCODE_AND = $2F;
  { the script GameLoop starts a new game's map loop with }
  START_ECL_SCRIPT = 16;
  { the script it starts the demo with }
  DEMO_ECL_SCRIPT = 24;
  { the most creatures EclLoadMonster adds between two EclClearMonsters }
  MAX_LOADED_CREATURES = 63;
  { a picture number from here on is a BIGPIC, below it a PIC close-up }
  FIRST_BIG_PICTURE = 112;
  { the two zone 0 cells EclSetSpeaker clears, by GBVM address }
  GBVM_SPEAKER_A = $4BB4;
  GBVM_SPEAKER_B = $4BB5;
  { TCharRecord.abilities' index for charisma }
  ABIL_CHA = 5;

{ EXIT, opcode $00: ends the script. Restores the character a LOAD CHARACTER replaced, clears the monster flags and the
  picture flag, stops the interpreter, empties the gosub stack and puts the text cursor back at the top of the message
  box. }
procedure EclExit;
begin
  if GDVars.restoresCharacter then begin
    GDVars.currentCharacter := GDVars.eclSavedCharacter;
    GDVars.restoresCharacter := False
  end;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.picturePending := False;
  GDVars.isEclStopped := True;
  Inc(GDVars.eclIp);
  while GDVars.eclStack <> nil do begin
    GDVars.eclStackPrevious := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack := GDVars.eclStackPrevious
  end;
  GDVars.cursorRow := C_Msg.MESSAGE_TOP;
  GDVars.cursorColumn := C_Msg.MESSAGE_LEFT;
  GDVars.eclDisplaying := 0
end;

{ GOTO, opcode $01: jumps to the address in its argument. }
procedure EclGoto;
begin
  EclMenu.LoadEclVars(1);
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1])
end;

{ GOSUB, opcode $02: pushes the return address and jumps to the address in its argument. }
procedure EclGosubCmd;
begin
  EclMenu.LoadEclVars(1);
  EclMenu.EclGosub(1)
end;

{ COMPARE, opcode $03: compares its two arguments, as strings when either is a string type ($80 and up), else as
  integers, and sets the comparison flags. }
procedure EclCompare;
var
  valueA: LongInt;
  valueB: LongInt;
    textA: String;
    textB: String;
begin
  EclMenu.LoadEclVars(2);
  if (GDVars.eclVarTypes[1] >= $80) or (GDVars.eclVarTypes[2] >= $80) then begin
    textA := GDVars.eclStrings[1];
    textB := GDVars.eclStrings[2];
    EclMenu.EclCompareStr(textA, textB)
  end else begin
    valueA := EclMenu.GetEclVar(1);
    valueB := EclMenu.GetEclVar(2);
    EclMenu.EclCompareInt(valueA, valueB)
  end
end;

{ ADD, SUBTRACT, DIVIDE, MULTIPLY: stores v1 + v2, v2 - v1, v1 div v2 (the remainder going to zone 1) or v1 * v2 at the
  third argument's address. }
procedure EclArithmetic;
var address: LongInt;
    values: array[1..2] of LongInt;
    remainder: LongInt;
    index: ShortInt;
    answer: LongInt;
begin
  EclMenu.LoadEclVars(3);
  for index := 1 to SizeOf(values) div SizeOf(LongInt) do
    values[index] := EclMenu.GetEclVar(index);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[3], GDVars.eclVarHigh[3]);
  case GDVars.currentOpcode of
    EclVm.OPCODE_ADD: answer := values[1] + values[2];
    EclVm.OPCODE_SUBTRACT: answer := values[2] - values[1];
    EclVm.OPCODE_DIVIDE: begin
        answer := values[1] div values[2];
        remainder := values[1] mod values[2];
        Move(remainder, GDVars.zone1^.divisionRemainder, SizeOf(remainder))
      end;
    EclVm.OPCODE_MULTIPLY: answer := values[1] * values[2]
  end;
  EclMenu.WriteGbvm(address, answer, GDVars.eclVarTypes[3])
end;

{ RANDOM, opcode $08: stores a random number from 0 to its first argument (0 to 254 when that is 255) at the address in
  its second. }
procedure EclRandom;
var choice: Byte;
    roll: Byte;
    address: Word;
begin
  EclMenu.LoadEclVars(2);
  choice := EclMenu.GetEclVar(1);
  if choice < 255 then Inc(choice);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[2], GDVars.eclVarHigh[2]);
  roll := Trunc(Random(choice));
  EclMenu.WriteGbvm(address, roll, GDVars.eclVarTypes[2])
end;

{ SAVE, opcode $09: stores its first argument, a number or a string (type bit 7 set), at the address in its second. }
procedure EclSave;
var value: LongInt;
    address: Word;
begin
  EclMenu.LoadEclVars(2);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[2], GDVars.eclVarHigh[2]);
  if GDVars.eclVarTypes[1] < $80 then begin
    value := EclMenu.GetEclVar(1);
    EclMenu.WriteGbvm(address, value, GDVars.eclVarTypes[2])
  end else
    EclMenu.WriteGbvmString(address, GDVars.eclStrings[1])
end;

{ LOAD CHARACTER: makes the party member its argument names (low 7 bits, counting from 0) the current character, or sets
  the character-not-found flag when there is none; EXIT restores the previous one. With bit 7 set and both removal flags
  raised, it removes that character from the party and redraws the party. }
procedure EclLoadCharacter;
var cursor: Types.PCharRecord;
    { Unused in this version; see the other implementations of this routine. }
    savedIndex: Byte;
    index: Byte;
    steps: Byte;
    refresh: Byte;
begin
  GDVars.restoresCharacter := True;
  EclMenu.LoadEclVars(1);
  steps := 0;
  index := EclMenu.GetEclVar(1);
  cursor := GDVars.partyHead;
  refresh := index and $80;
  index := index and $7F;
  if index > 0 then
    while (steps < index) and (cursor <> nil) do begin
      cursor := cursor^.nextCharAddr;
      Inc(steps)
    end;
  if cursor <> nil then begin
    GDVars.currentCharacter := cursor;
    GDVars.selectFailed := 0
  end else
    GDVars.selectFailed := 1;
  if (refresh <> 0) and (GDVars.refreshCharacterA <> 0) and (GDVars.refreshCharacterB <> 0) then begin
    if GDVars.eclSavedCharacter = GDVars.currentCharacter then GDVars.restoresCharacter := False;
    CharGen.RemoveCreature(False, True);
    MenuCore.DisplayParty(GDVars.currentCharacter);
    GDVars.refreshCharacterA := 0;
    GDVars.refreshCharacterB := 0
  end
end;

{ Takes the monster's sprite, maximum distance, close-up picture and approach directions from four operands, caps its
  distance by the walls ahead and shows it. }
procedure EclSetupMonster;
{ Unused in this version; see the other implementations of this routine. }
var distance: Word;
begin
  EclMenu.LoadEclVars(4);
  GDVars.monsterSpriteId := EclMenu.GetEclVar(1);
  GDVars.zone1^.monsterMaxDistance := EclMenu.GetEclVar(2);
  GDVars.monsterPictureId := EclMenu.GetEclVar(3);
  GDVars.monsterApproach := EclMenu.GetEclVar(4);
  GDVars.zone1^.monsterDistance := EclMenu.MaxMonsterDist(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                                            GDVars.partyPosition.facing);
  if GDVars.zone1^.monsterMaxDistance < GDVars.zone1^.monsterDistance then
    GDVars.zone1^.monsterDistance := GDVars.zone1^.monsterMaxDistance;
  EclMenu.DisplayMonster(GDVars.monsterSpriteId, GDVars.monsterPictureId, GDVars.zone1^.monsterDistance,
                         GDVars.monsterFlags)
end;

{ Appends as many copies as its second operand says of the MON creature its first operand names, each with its own
  copies of the record's items and effects, to the party list, up to 63 creatures, and loads their combat icon from the
  CPIC picture its third operand names; a hostile's hit points scale by (difficulty + 2) / 4, at least 1. }
procedure EclLoadMonster;
var monsterId: Byte;
    count: Byte;
    pictureId: Byte;
    index: Byte;
    cursor: Types.PCharRecord;
    newNode: Types.PCharRecord;
    creature: Types.PCharRecord;
    saved: Types.PCharRecord;
    template: Types.TCharRecord;
    animName: String[12];
    itemList: Types.PItemRec;
    itemPrev: Types.PItemRec;
    itemHead: Types.PItemRec;
    effList: Types.PEffectRec;
    effPrev: Types.PEffectRec;
    effHead: Types.PEffectRec;
begin
  saved := GDVars.currentCharacter;
  index := 1;
  EclMenu.LoadEclVars(3);
  count := EclMenu.GetEclVar(2);
  if (GDVars.creatureCount < EclVm.MAX_LOADED_CREATURES) and (count > 0) then begin
    cursor := nil;
    newNode := nil;
    monsterId := EclMenu.GetEclVar(1);
    EclMenu.InitCreature(monsterId, creature, itemList, effList);
    if (creature^.hostile = C_Side.HOSTILE) and (GDVars.zone0^.difficulty >= C_Diff.DIFFICULTY_NOVICE) and
        (GDVars.zone0^.difficulty < C_Diff.DIFFICULTY_ACE + 1) then begin
      creature^.hitPoints := creature^.hitPoints * (GDVars.zone0^.difficulty + 2) div 4;
      if creature^.hitPoints = 0 then
        creature^.hitPoints := 1;
      creature^.hpMax := creature^.hitPoints
    end;
    template := creature^;
    itemHead := itemList;
    effHead := effList;
    pictureId := EclMenu.GetEclVar(3);
    cursor := GDVars.partyHead;
    animName := 'CPIC';
    MapTiles.LoadIconAnim(animName, pictureId, GDVars.nextCreatureIconSlot);
    while cursor^.nextCharAddr <> nil do
      cursor := cursor^.nextCharAddr;
    cursor^.nextCharAddr := creature;
    cursor := cursor^.nextCharAddr;
    cursor^.orderNumber := GDVars.nextCreatureIconSlot;
    cursor^.nextCharAddr := nil;
    Inc(GDVars.creatureCount);
    Inc(index);
    while (index <= count) and (GDVars.creatureCount < EclVm.MAX_LOADED_CREATURES) do begin
      GetMem(newNode, SizeOf(Types.TCharRecord));
      cursor^.nextCharAddr := newNode;
      cursor := cursor^.nextCharAddr;
      cursor^ := template;
      cursor^.orderNumber := GDVars.nextCreatureIconSlot;
      cursor^.nextCharAddr := nil;
      cursor^.effectsAddr := nil;
      cursor^.itemsAddr := nil;
      Inc(index);
      Inc(GDVars.creatureCount);
      while itemList <> nil do begin
        if cursor^.itemsAddr = nil then begin
          GetMem(cursor^.itemsAddr, SizeOf(Types.TItemRec));
          cursor^.itemsAddr^ := itemList^;
          cursor^.itemsAddr^.next := nil
        end else begin
          itemPrev := cursor^.itemsAddr;
          GetMem(cursor^.itemsAddr, SizeOf(Types.TItemRec));
          cursor^.itemsAddr^ := itemList^;
          cursor^.itemsAddr^.next := itemPrev
        end;
        itemList := itemList^.next
      end;
      itemList := itemHead;
      while effList <> nil do begin
        if cursor^.effectsAddr = nil then begin
          GetMem(cursor^.effectsAddr, SizeOf(Types.TEffectRec));
          cursor^.effectsAddr^ := effList^;
          cursor^.effectsAddr^.next := nil
        end else begin
          effPrev := cursor^.effectsAddr;
          GetMem(cursor^.effectsAddr, SizeOf(Types.TEffectRec));
          cursor^.effectsAddr^ := effList^;
          cursor^.effectsAddr^.next := effPrev
        end;
        effList := effList^.next
      end;
      effList := effHead
    end;
    Inc(GDVars.nextCreatureIconSlot);
    GDVars.partyChanged := 1;
    GDVars.currentCharacter := saved
  end
end;

{ APPROACH, opcode $0D: brings the monster one step nearer and redraws it, unless it is already adjacent. }
procedure EclApproach;
begin
  if GDVars.zone1^.monsterDistance > 0 then begin
    Dec(GDVars.zone1^.monsterDistance);
    EclMenu.DisplayMonster(GDVars.monsterSpriteId, GDVars.monsterPictureId, GDVars.zone1^.monsterDistance,
                           GDVars.monsterFlags)
  end;
  Inc(GDVars.eclIp)
end;

{ Shows a picture, or clears a shown picture or sprite from the view.
  @param(picId From the first big-picture number up a big picture, below it a PIC close-up; the no-animation value
    clears instead.) }
procedure ShowPicture(picId: Byte);
{ Unused in this version; see the other implementations of this routine. }
var picture: LongInt;
begin
  if picId <> C_Pic.NO_ANIMATION then begin
    GDVars.viewPaletteStale := 1;
    GDVars.monsterFlags[1] := True;
    GDVars.picturePending := True;
    if picId >= EclVm.FIRST_BIG_PICTURE then begin
      Portrait.LoadBigPic(picId);
      Portrait.DisplayBigPic;
      GDVars.viewPaletteStale := 1;
      if GDVars.interfaceState = C_Ifc.WILDERNESS then
        MapCurs.DrawCursor
      else
        GDVars.bigPictureShown := 1;
      GDVars.portraitPending := 0
    end else begin
      Portrait.LoadAnimation('PIC', picId, 0);
      Portrait.DisplayImageBuf(3, 3, True, 0);
      GDVars.viewPaletteStale := 1
    end
  end else begin
    if (GDVars.previousInterfaceState <> C_Ifc.VIEW_3D) or
        (GDVars.interfaceState = C_Ifc.VIEW_3D) then begin
      if GDVars.picturePending or (GDVars.monsterSpriteShown <> 0) then begin
        GDVars.viewPaletteStale := 1;
        GDVars.portraitPending := 1;
        MapView.DisplayMapView;
        GDVars.picturePending := False;
        GDVars.monsterSpriteShown := 0
      end
    end;
    GDVars.monsterFlags[0] := False;
    GDVars.monsterFlags[1] := False
  end
end;

{ PICTURE, opcode $0E: shows the picture its argument names. }
procedure EclPicture;
begin
  EclMenu.LoadEclVars(1);
  EclVm.ShowPicture(EclMenu.GetEclVar(1))
end;

{ INPUT NUMBER: reads a number from the player into the second argument's address. }
procedure EclInputNumber;
var emptyQuery: String[1];
    value: LongInt;
    address: Word;
begin
  EclMenu.LoadEclVars(2);
  emptyQuery := '';
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[2], GDVars.eclVarHigh[2]);
  value := TextRend.ReadNumber(emptyQuery, LightGreen, Black);
  EclMenu.WriteGbvm(address, value, GDVars.eclVarTypes[2])
end;

{ INPUT STRING: reads up to 40 characters into the second argument's address; an empty answer is stored as one space. }
procedure EclInputString;
var emptyQuery: String[1];
    address: Word;
    typed: String;
begin
  EclMenu.LoadEclVars(2);
  emptyQuery := '';
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[2], GDVars.eclVarHigh[2]);
  typed := TextRend.ReadString(emptyQuery, LightGreen, Black, 40);
  if typed = '' then typed := ' ';
  EclMenu.WriteGbvmString(address, typed)
end;

{ Shows its operand in the text window: a number formatted by its width, or a string; opcode $12 starts the window
  afresh, $11 carries on. }
procedure EclPrint;
begin
  EclMenu.LoadEclVars(1);
  GDVars.bottomClear := 0;
  GDVars.messageDelay := 1;
  case GDVars.eclVarTypes[1] of
    0, 1: GDVars.eclStrings[1] := TextRend.ByteToString(EclMenu.GetEclVar(1));
    2, 3: GDVars.eclStrings[1] := TextRend.WordToString(EclMenu.GetEclVar(1));
    4, 5: GDVars.eclStrings[1] := TextRend.CommaLongToString(EclMenu.GetEclVar(1))
  end;
  if GDVars.currentOpcode = EclVm.OPCODE_PRINT then
    TextRend.DisplayMessageWindow(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                                  LightGreen, Black, False, GDVars.eclStrings[1])
  else begin
    GDVars.cursorColumn := C_Msg.MESSAGE_LEFT;
    GDVars.cursorRow := C_Msg.MESSAGE_TOP;
    TextRend.DisplayMessageWindow(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                                  LightGreen, Black, True, GDVars.eclStrings[1])
  end;
  GDVars.messageDelay := 0
end;

{ RETURN, opcode $13: pops the gosub stack and returns to its address, or ends the script like EXIT when the stack is
  empty. }
procedure EclReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.eclStack <> nil then begin
    GDVars.eclIp := GDVars.eclStack^.addr;
    GDVars.eclStackPrevious := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack := GDVars.eclStackPrevious
  end else
    EclVm.EclExit
end;

{ COMPARE AND: sets the equal flag when v1 = v2 and v3 = v4, else the not-equal flag. }
procedure EclCompareAnd;
var values: array[1..4] of LongInt;
    index: Byte;
begin
  FillChar(GDVars.compareFlags, SizeOf(GDVars.compareFlags), 0);
  EclMenu.LoadEclVars(4);
  for index := 1 to SizeOf(values) div SizeOf(LongInt) do
    values[index] := EclMenu.GetEclVar(index);
  if (values[1] = values[2]) and (values[3] = values[4]) then
    GDVars.compareFlags[0] := True
  else
    GDVars.compareFlags[1] := True
end;

{ IF, opcodes $16..$1B (=, <>, <, >, <=, >=): skips the next command unless its comparison flag is set. }
procedure EclIf;
begin
  Inc(GDVars.eclIp);
  case GDVars.currentOpcode of
    EclVm.OPCODE_IF_EQUAL: if not GDVars.compareFlags[0] then EclMenu.SkipEclCmd;
    EclVm.OPCODE_IF_NOT_EQUAL: if not GDVars.compareFlags[1] then EclMenu.SkipEclCmd;
    EclVm.OPCODE_IF_LESS: if not GDVars.compareFlags[2] then EclMenu.SkipEclCmd;
    EclVm.OPCODE_IF_GREATER: if not GDVars.compareFlags[3] then EclMenu.SkipEclCmd;
    EclVm.OPCODE_IF_LESS_OR_EQUAL: if not GDVars.compareFlags[4] then EclMenu.SkipEclCmd;
    EclVm.OPCODE_IF_GREATER_OR_EQUAL: if not GDVars.compareFlags[5] then EclMenu.SkipEclCmd
  end
end;

{ NEWECL, opcode $20: saves the current script id in zone 0 and loads the script its operand names. When the load
  succeeds it starts the new script from the beginning, stops the run with the new-script flag set and clears the
  monster flags; when it fails it stops the run with the flag clear and restores the saved script id. }
procedure EclNewEcl;
var scriptId: Byte;
begin
  EclMenu.LoadEclVars(1);
  GDVars.zone0^.stateValue := GDVars.eclId;
  scriptId := EclMenu.GetEclVar(1);
  GDVars.eclId := scriptId;
  if EclMenu.LoadEclScript(scriptId) then begin
    EclMenu.EclInit;
    GDVars.isEclStopped := True;
    GDVars.isNewEclLoaded := True;
    FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0)
  end else begin
    GDVars.isEclStopped := True;
    GDVars.isNewEclLoaded := False;
    GDVars.eclId := GDVars.zone0^.stateValue
  end
end;

const
  { an operand naming no file: LOAD FILES keeps the map, LOAD PIECES empties that slot }
  NO_FILE_OPERAND = 255;
  { as LOAD PIECES' first operand, reloads WALLDEF record 0 into slot 1 and nothing else; as its third, where slots 0
    and 3 are loaded, it names no file }
  START_WALL_SET_OPERAND = 127;

{ LOAD FILES and LOAD PIECES, opcodes $21 and $37. LOAD FILES loads the 3-D map its first operand names (not 127 or 255,
  and not in a Venus or Mars wilderness area), and records 127 as the map id when the operand is 127. LOAD PIECES loads
  the wall sets its three operands name into slots 1..3 (127 as the first loads set 0 into slot 1; 255 empties a slot),
  or, when both of zone 0's gate values are set, only the first into slot 0 and the third into slot 3 (127 there also
  empties it). Once both have run after the wilderness view and the interface has left it, the explore frame, the party
  and the status line are redrawn. }
procedure EclLoadFiles;
var setIds: array[1..3] of Byte;
    index: Byte;
begin
  EclMenu.LoadEclVars(3);
  GDVars.hasLoadedFiles := True;
  for index := 1 to SizeOf(setIds) do
    setIds[index] := EclMenu.GetEclVar(index);
  if GDVars.currentOpcode = EclVm.OPCODE_LOAD_FILES then begin
    GDVars.hasLoadedMap := True;
    if (setIds[1] <> EclVm.NO_FILE_OPERAND) and (setIds[1] <> C_Map.NO_GEO_MAP) and
        (not (GDVars.zone0^.areaType in [C_Area.VENUS_WILDERNESS, C_Area.MARS_WILDERNESS])) then begin
      GDVars.zone0^.mapId := setIds[1];
      View3D.Load3DMap(setIds[1]);
      GDVars.zone1^.moveBlocked := 0
    end else if setIds[1] = C_Map.NO_GEO_MAP then
      GDVars.zone0^.mapId := C_Map.NO_GEO_MAP
  end else begin
    GDVars.hasLoadedPieces := True;
    if setIds[1] = EclVm.START_WALL_SET_OPERAND then
      View3D.LoadWallSet(0, 1)
    else if (GDVars.zone0^.targetGateA <> 0) and (GDVars.zone0^.targetGateB <> 0) then begin
      if setIds[1] <> EclVm.NO_FILE_OPERAND then
        View3D.LoadWallSet(setIds[1], 0)
      else begin
        GDVars.wallSets[0].fileId := C_Map.NO_WALL_SET_FILE;
        GDVars.wallSets[0].slot := C_Map.NO_WALL_SET_SLOT
      end;
      if (setIds[3] <> EclVm.NO_FILE_OPERAND) and (setIds[3] <> EclVm.START_WALL_SET_OPERAND) then
        View3D.LoadWallSet(setIds[3], 3)
      else begin
        GDVars.wallSets[3].fileId := C_Map.NO_WALL_SET_FILE;
        GDVars.wallSets[3].slot := C_Map.NO_WALL_SET_SLOT
      end
    end else begin
      for index := 1 to SizeOf(setIds) do
        if setIds[index] <> EclVm.NO_FILE_OPERAND then
          View3D.LoadWallSet(setIds[index], index)
        else begin
          GDVars.wallSets[index].fileId := C_Map.NO_WALL_SET_FILE;
          GDVars.wallSets[index].slot := C_Map.NO_WALL_SET_SLOT
        end
    end
  end;
  if GDVars.hasLoadedPieces and GDVars.hasLoadedMap and (GDVars.previousInterfaceState = C_Ifc.WILDERNESS) then begin
    if (GDVars.interfaceState <> C_Ifc.WILDERNESS) and (GDVars.refreshState <> 0) then begin
      Border.DrawExploreFrame;
      MenuCore.DisplayParty(GDVars.currentCharacter);
      CharHlp.PrintMiscInfo
    end;
    GDVars.refreshState := 0
  end
end;

{ AND and OR, opcodes $2F and $30: combines its first two arguments bitwise, truncates the result to a byte, sets the
  comparison flags as for COMPARE of 0 with the result, and stores it at the address in its third. }
procedure EclAndOr;
var address: Word;
    valueB: Word;
    valueA: Word;
    merged: Byte;
begin
  EclMenu.LoadEclVars(3);
  valueA := EclMenu.GetEclVar(1);
  valueB := EclMenu.GetEclVar(2);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[3], GDVars.eclVarHigh[3]);
  if GDVars.currentOpcode = EclVm.OPCODE_AND then
    merged := valueA and valueB
  else
    merged := valueA or valueB;
  EclMenu.EclCompareInt(0, merged);
  EclMenu.WriteGbvm(address, merged, GDVars.eclVarTypes[3])
end;

{ GETTABLE, opcode $2A: reads the GBVM entry at its first argument's address plus its second and stores it at the
  address in its third. }
procedure EclGetTable;
var base: Word;
    target: Word;
    slot: Word;
    value: Word;
    offset: Byte;
begin
  EclMenu.LoadEclVars(3);
  base := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  offset := EclMenu.GetEclVar(2);
  target := EclMenu.CombineBytesToWord(GDVars.eclVarLow[3], GDVars.eclVarHigh[3]);
  slot := offset + base;
  value := EclMenu.ReadGbvm(slot, GDVars.eclVarTypes[3]);
  EclMenu.WriteGbvm(target, value, GDVars.eclVarTypes[3])
end;

{ SAVETABLE, opcode $35: stores its first argument at the GBVM entry at its second argument's address plus its third. }
procedure EclSaveTable;
var offset: Word;
    base: Word;
    value: Word;
    target: Word;
begin
  EclMenu.LoadEclVars(3);
  value := EclMenu.GetEclVar(1);
  base := EclMenu.CombineBytesToWord(GDVars.eclVarLow[2], GDVars.eclVarHigh[2]);
  offset := EclMenu.GetEclVar(3);
  target := base + offset;
  EclMenu.WriteGbvm(target, value, GDVars.eclVarTypes[1])
end;

{ VERTICAL MENU, opcode $15: shows its message, then a vertical menu of as many strings as its third argument says, and
  stores the choice at the GBVM address in its first. }
procedure EclVMenu;
var
  count: Byte;
  index: Byte;
    prompt: String;
    list: Types.PMenuNode;
    listHead: Types.PMenuNode;
    emptyQuery: String[1];
    choice: Integer;
    needsRedraw: Boolean;
    address: Word;
    gbType: Byte;
begin
  GDVars.horizChoice := 1;
  GDVars.bottomClear := 0;
  needsRedraw := True;
  emptyQuery := '';
  index := 1;
  EclMenu.LoadEclVars(3);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  gbType := GDVars.eclVarTypes[1];
  prompt := GDVars.eclStrings[1];
  count := EclMenu.GetEclVar(3);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  MenuCore.AllocStringList(count, list);
  listHead := list;
  GDVars.cursorColumn := C_Msg.MESSAGE_LEFT;
  GDVars.cursorRow := C_Msg.MESSAGE_TOP;
  TextRend.DisplayMessageWindow(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                                LightGreen, Black, True, prompt);
  while list <> nil do begin
    list^.name := GDVars.eclStrings[index];
    list^.menuLabel := 0;
    list := list^.next;
    Inc(index)
  end;
  list := listHead;
  choice := 0;
  { EclVerticalMenu declares its menu list as a PItemRec; the list is MenuCore's }
  EclMenu.EclVerticalMenu(emptyQuery, emptyQuery, C_Msg.MESSAGE_LEFT, GDVars.cursorRow + 1, C_Msg.MESSAGE_RIGHT,
                          C_Msg.MESSAGE_BOTTOM,
                          Types.PItemRec(list), False, needsRedraw, choice, Types.PItemRec(list));
  EclMenu.WriteGbvm(address, choice, gbType);
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(C_Msg.MESSAGE_LEFT, C_Msg.MESSAGE_TOP, C_Msg.MESSAGE_RIGHT, C_Msg.MESSAGE_BOTTOM)
end;

{ Offers the string operands as a horizontal menu and stores the choice's index.
  @param(showsPrompt True first prints 'what do you do?'.) }
procedure EclHMenu(showsPrompt: Boolean);
var
  count: Byte;
  choice: Byte;
  index: Byte;
    query: String[1];
    menu: String[50];
    address: Word;
    acceptsEnter: Boolean;
    isAnimated: Boolean;
    gbType: Byte;
begin
  if showsPrompt then
    TextRend.DisplayMessageWindow(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                                  LightGreen, Black, False, 'what do you do?');
  GDVars.horizChoice := 1;
  query := '';
  menu := '';
  EclMenu.LoadEclVars(2);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  gbType := GDVars.eclVarTypes[1];
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  menu := '';
  acceptsEnter := count = 1;
  isAnimated := GDVars.picturePending;
  for index := 1 to count - 1 do
    menu := menu + '~' + GDVars.eclStrings[index] + ' ';
  { nothing bounds count at eclStrings' 20 entries }
  menu := menu + '~' + GDVars.eclStrings[count];
  choice := EclMenu.MenuHorizontalCharacterSelect(query, menu, acceptsEnter, isAnimated);
  EclMenu.WriteGbvm(address, choice, gbType);
  TextRend.ClearRect(0, C_Screen.STATUS_ROW, C_Screen.LAST_COLUMN, C_Screen.STATUS_ROW)
end;

{ CLEARMONSTERS: forgets the loaded monsters (the next icon slot is 8 again), clears the treasure money and frees the
  treasure items. }
procedure EclClearMonsters;
var nextItem: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    index: Word;
begin
  Inc(GDVars.eclIp);
  GDVars.creatureCount := 0;
  GDVars.partyChanged := 0;
  GDVars.nextCreatureIconSlot := C_Combat.FIRST_CREATURE_ICON_SLOT;
  FillChar(GDVars.poolCredits, SizeOf(GDVars.poolCredits), 0);
  while GDVars.availableItems <> nil do begin
    nextItem := GDVars.availableItems^.next;
    FreeMem(GDVars.availableItems, SizeOf(Types.TItemRec));
    GDVars.availableItems := nextItem
  end
end;

{ Clears the two speaker cells in zone 0 and keeps the two operands as the speaker arguments. }
procedure EclSetSpeaker;
begin
  EclMenu.LoadEclVars(2);
  GDVars.zone0^.cells[EclVm.GBVM_SPEAKER_A] := 0;
  GDVars.zone0^.cells[EclVm.GBVM_SPEAKER_B] := 0;
  GDVars.speakerArg2 := EclMenu.GetEclVar(2);
  GDVars.speakerArg1 := EclMenu.GetEclVar(1)
end;

const
  { the attribute operand's values, less C_Gbvm.CURRENT_CHARACTER }
  CHECKED_CHARISMA = $19;
  CHECKED_RACE = $72;
  CHECKED_MOVEMENT = $9F;

{ For the attribute operand 1 names (a selector below), writes the party's minimum, maximum and average, and whether a
  member of race operand 2 is in it, to operands 3..6's addresses. }
procedure EclCheckParty;
var attribute: Integer;
    sum: Integer;
    raceId: Byte;
    cursor: Types.PCharRecord;
    found: ShortInt;
    { Unused in this version; see the other implementations of this routine. }
    effect: LongInt;
    average: Byte;
    maxValue: Byte;
    minValue: Byte;
    addrMin: Word;
    addrMax: Word;
    addrAvg: Word;
    addrFound: Word;
    count: Byte;
    { Unused in this version; see the other implementations of this routine. }
    valueText: String;
    { Unused in this version; see the other implementations of this routine. }
    classIndex: Word;

  { Writes minValue, maxValue, average and found to operands 3..6's addresses. }
  procedure Write4Gbvm;
  begin
    EclMenu.WriteGbvm(addrMin, minValue, GDVars.eclVarTypes[3]);
    EclMenu.WriteGbvm(addrMax, maxValue, GDVars.eclVarTypes[4]);
    EclMenu.WriteGbvm(addrAvg, average, GDVars.eclVarTypes[5]);
    EclMenu.WriteGbvm(addrFound, found, GDVars.eclVarTypes[6])
  end;

begin
  EclMenu.LoadEclVars(6);
  cursor := GDVars.partyHead;
  found := 0;
  if GDVars.eclVarTypes[1] = 1 then
    attribute := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1])
  else
    attribute := EclMenu.GetEclVar(1);
  raceId := EclMenu.GetEclVar(2);
  addrMin := EclMenu.CombineBytesToWord(GDVars.eclVarLow[3], GDVars.eclVarHigh[3]);
  addrMax := EclMenu.CombineBytesToWord(GDVars.eclVarLow[4], GDVars.eclVarHigh[4]);
  addrAvg := EclMenu.CombineBytesToWord(GDVars.eclVarLow[5], GDVars.eclVarHigh[5]);
  addrFound := EclMenu.CombineBytesToWord(GDVars.eclVarLow[6], GDVars.eclVarHigh[6]);
  sum := 0;
  count := 0;
  minValue := 255;
  maxValue := 0;
  Dec(attribute, C_Gbvm.CURRENT_CHARACTER);
  case attribute of
    EclVm.CHECKED_CHARISMA: begin
      while cursor <> nil do begin
        Inc(count);
        if cursor^.abilities[EclVm.ABIL_CHA] > maxValue then maxValue := cursor^.abilities[EclVm.ABIL_CHA];
        if cursor^.abilities[EclVm.ABIL_CHA] < minValue then minValue := cursor^.abilities[EclVm.ABIL_CHA];
        Inc(sum, cursor^.abilities[EclVm.ABIL_CHA]);
        cursor := cursor^.nextCharAddr
      end;
      average := sum div count;
      Write4Gbvm
    end;
    EclVm.CHECKED_RACE: begin
      while (cursor <> nil) and (found = 0) do begin
        if Byte(cursor^.race) = raceId then found := 1;
        cursor := cursor^.nextCharAddr
      end;
      Write4Gbvm
    end;
    EclVm.CHECKED_MOVEMENT: begin
      while cursor <> nil do begin
        Inc(count);
        if cursor^.currentMovement < minValue then minValue := cursor^.currentMovement;
        if cursor^.currentMovement > maxValue then maxValue := cursor^.currentMovement;
        Inc(sum, cursor^.currentMovement);
        cursor := cursor^.nextCharAddr
      end;
      average := sum div count;
      Write4Gbvm
    end
  end
end;

{ Rolls the skill in operand 1 at the scale in operand 3 for the current character or, when operand 2 is nonzero, the
  party's best; writes that member's party index to operand 2's address and the outcome to operand 3's.
  @param(showsText True to show the roll's text.) }
procedure EclSkillCheck(showsText: Boolean);
var count: Byte;
    skillId: Byte;
    scale: Byte;
    outcome: Byte;
    wholeParty: Byte;
    message: String;
    character: Types.PCharRecord;
    cursor: Types.PCharRecord;
    memberAddr: Word;
    outcomeAddr: Word;
begin
  EclMenu.LoadEclVars(3);
  skillId := EclMenu.GetEclVar(1);
  wholeParty := EclMenu.GetEclVar(2);
  memberAddr := EclMenu.CombineBytesToWord(GDVars.eclVarLow[2], GDVars.eclVarHigh[2]);
  outcomeAddr := EclMenu.CombineBytesToWord(GDVars.eclVarLow[3], GDVars.eclVarHigh[3]);
  scale := EclMenu.GetEclVar(3);
  if wholeParty = 0 then character := GDVars.currentCharacter;
  outcome := CharHlp.SelectSkillCharacter(skillId, scale, Boolean(wholeParty), Pointer(character));
  GDVars.cursorRow := GDVars.windowTop;
  GDVars.cursorColumn := GDVars.windowLeft;
  if outcome > 1 then
    message := character^.name + ' ' + 'succeeds at ' + GDConsts.skillDefinitions[skillId].name
  else begin
    if wholeParty <> 0 then
      message := 'party'
    else
      message := character^.name;
    message := message + ' fails at ' + GDConsts.skillDefinitions[skillId].name
  end;
  if showsText then begin
    TextRend.DisplayMessageWindow(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                                  LightGreen, Black, True, message);
    TextRend.PauseOnly;
    TextRend.PauseOnly;
    TextRend.PauseOnly;
    TextRend.PauseOnly
  end;
  count := 0;
  cursor := GDVars.partyHead;
  while (cursor <> nil) and (cursor <> character) do begin
    cursor := cursor^.nextCharAddr;
    Inc(count)
  end;
  EclMenu.WriteGbvm(memberAddr, count, GDVars.eclVarTypes[2]);
  EclMenu.WriteGbvm(outcomeAddr, outcome, GDVars.eclVarTypes[3])
end;

{ Runs the ground combat against the loaded monsters, then redraws the view. When no monster is loaded or none is
  hostile and the combat is not a solo one, it skips the fight and runs the post-combat screen. In a solo combat the
  other team members sit it out. }
procedure EclCombat;
var maxDistance: Word;
    redrawsView: Boolean;
    savedMode: Byte;
    cursor: Types.PCharRecord;
    savedBigPictureId: Byte;

  { 1 when any creature on the party list is hostile, else 0. }
  function AnyHostile: Byte;
  var cursor: Types.PCharRecord;
      found: Byte;
  begin
    found := 0;
    cursor := GDVars.partyHead;
    while (found = 0) and (cursor <> nil) do begin
      found := Ord(cursor^.hostile = C_Side.HOSTILE);
      cursor := cursor^.nextCharAddr
    end;
    AnyHostile := found
  end;

  { Disables every other C_Side.TEAM member, or enables those whose status lets them act. }
  procedure UpdateCharacters(disablesOthers: Byte);
  begin
    cursor := GDVars.partyHead;
    while cursor <> nil do begin
      if cursor^.hostile = C_Side.TEAM then begin
        if cursor <> GDVars.currentCharacter then begin
          if disablesOthers <> 0 then
            cursor^.enabled := 0
          else
            cursor^.enabled := Ord(cursor^.status in [C_Status.OKAY,
                                                      C_Status.DODGING..C_Status.FAILED_ZERO_G])
        end
      end;
      cursor := cursor^.nextCharAddr
    end
  end;

begin
  if GDVars.partyChanged = 0 then GDVars.partyChanged := AnyHostile;
  GDVars.previousInterfaceState := GDVars.interfaceState;
  GDVars.bigPictureShown := 0;
  savedMode := GDVars.moveMode;
  GDVars.moveMode := 0;
  Inc(GDVars.eclIp);
  redrawsView := True;
  if (GDVars.partyChanged = 0) and (GDVars.soloCombat = 0) then begin
    GDVars.viewPaletteStale := 1;
    PostCbt.PostCombat
  end else begin
    maxDistance := EclMenu.MaxMonsterDist(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                          GDVars.partyPosition.facing);
    if GDVars.zone1^.monsterDistance > maxDistance then
      GDVars.zone1^.monsterDistance := maxDistance;
    if GDVars.soloCombat <> 0 then UpdateCharacters(1);
    Combat.CombatMain;
    GDVars.viewPaletteStale := 1;
    if GDVars.soloCombat <> 0 then UpdateCharacters(0);
    PostCbt.PostCombat;
    GDVars.soloCombat := 0
  end;
  GDVars.interfaceState := GDVars.previousInterfaceState;
  GDVars.zone1^.searchFlags := GDVars.zone1^.searchFlags and C_Search.SEARCHING;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.picturePending := False;
  if redrawsView then begin
    if GDVars.interfaceState = C_Ifc.WILDERNESS then begin
      savedBigPictureId := GDVars.bigPictureId;
      GDVars.bigPictureId := C_Pic.NO_BIG_PICTURE;
      Portrait.LoadBigPic(savedBigPictureId);
      Portrait.DisplayBigPic;
      MapCurs.DrawCursor
    end else begin
      GDVars.bigPictureId := C_Pic.NO_BIG_PICTURE;
      CharHlp.DisplayNoncombatInterface
    end
  end;
  GDVars.moveMode := savedMode
end;

{ ON GOTO and ON GOSUB, opcodes $25 and $26: jumps to, or calls, the address its first argument picks from the list
  whose length its second gives; an index past the list does nothing. }
procedure EclOnGoto;
var selected: Byte;
    count: Byte;
    { Unused in this version; see the other implementations of this routine. }
    target: Byte;
    index: Byte;
    isDone: Boolean;
begin
  isDone := False;
  EclMenu.LoadEclVars(2);
  selected := EclMenu.GetEclVar(1);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  index := 0;
  while (index < count) and (not isDone) do begin
    if selected = index then begin
      if GDVars.currentOpcode = EclVm.OPCODE_ON_GOTO then
        GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.eclVarLow[index + 1], GDVars.eclVarHigh[index + 1])
      else
        EclMenu.EclGosub(index + 1);
      isDone := True
    end else
      Inc(index)
  end
end;

{ Adds operand 1 credits to the pool and each listed item template to the available items. }
procedure EclTreasure;
var count: Byte;
    index: Byte;
    templateIndex: Byte;
    item: Types.TItemRec;
    previous: Types.PItemRec;
begin
  EclMenu.LoadEclVars(2);
  Inc(GDVars.poolCredits, EclMenu.GetEclVar(1));
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  for index := 1 to count do begin
    templateIndex := EclMenu.GetEclVar(index);
    if GDVars.itemTemplates[templateIndex].itemType <> C_Item.EMPTY_TEMPLATE then begin
      Move(GDVars.itemTemplates[templateIndex], item.template, SizeOf(Types.TItemTemplate));
      item.next := nil;
      item.menuLabel := 0;
      if GDVars.availableItems = nil then begin
        New(GDVars.availableItems);
        GDVars.availableItems^ := item
      end else begin
        previous := GDVars.availableItems;
        New(GDVars.availableItems);
        GDVars.availableItems^ := item;
        GDVars.availableItems^.next := previous
      end
    end
  end
end;

{ ROB, opcode $28: takes the percentage of money in its second argument and, with the chance in its third, items from
  the current character, or from every member when its first is non-zero. }
procedure EclRob;
var wholeParty: Byte;
    moneyPercent: Byte;
    itemChance: Byte;
    cursor: Types.PCharRecord;
    { Unused in this version; see the other implementations of this routine. }
    items: Types.PItemRec;
    fraction: Real;
begin
  EclMenu.LoadEclVars(3);
  wholeParty := EclMenu.GetEclVar(1);
  moneyPercent := EclMenu.GetEclVar(2);
  fraction := (100 - moneyPercent) / 100;
  itemChance := EclMenu.GetEclVar(3);
  if wholeParty = 0 then begin
    EclMenu.RobMoney(fraction, GDVars.currentCharacter);
    EclMenu.RobItems(itemChance, GDVars.currentCharacter)
  end else begin
    cursor := GDVars.partyHead;
    while cursor <> nil do begin
      items := cursor^.itemsAddr;
      EclMenu.RobMoney(fraction, cursor);
      EclMenu.RobItems(itemChance, cursor);
      cursor := cursor^.nextCharAddr
    end
  end
end;

{ Offers the continue menu and waits. }
procedure EclContinuePrompt;
{ Unused in this version; see the other implementations of this routine. }
var choice: Byte;
begin
  Inc(GDVars.eclIp);
  choice := EclMenu.MenuHorizontalCharacterSelect('', GDConsts.continueMenuPrompt, True, GDVars.picturePending);
  TextRend.ClearStatusLine
end;

{ Asks Yes or No; compareFlags equal for Yes, not equal for No. }
procedure EclYesNoCompare;
{ Unused in this version; see the other implementations of this routine. }
var answer: Byte;
begin
  Inc(GDVars.eclIp);
  FillChar(GDVars.compareFlags, SizeOf(GDVars.compareFlags), 0);
  if MenuCore.YesNoMenu('', C_Menu.DEFAULT_YES) = 'Y' then
    GDVars.compareFlags[0] := True
  else
    GDVars.compareFlags[1] := True
end;

{ FIND ITEM, opcode $32: sets the equal flag when a party member carries an item of the type in its argument, the
  not-equal flag otherwise. }
procedure EclFindItem;
var itemType: Byte;
    { Unused in this version; see the other implementations of this routine. }
    itemCount: Byte;
    cursor: Types.PCharRecord;
    item: Types.PItemRec;
    isFound: Boolean;
begin
  EclMenu.LoadEclVars(1);
  isFound := False;
  itemType := EclMenu.GetEclVar(1);
  FillChar(GDVars.compareFlags, SizeOf(GDVars.compareFlags), 0);
  GDVars.compareFlags[1] := True;
  cursor := GDVars.partyHead;
  while (cursor <> nil) and (not isFound) do begin
    item := cursor^.itemsAddr;
    while (item <> nil) and (not isFound) do begin
      if itemType = item^.template.itemType then begin
        GDVars.compareFlags[0] := True;
        GDVars.compareFlags[1] := False;
        isFound := True
      end;
      item := item^.next
    end;
    cursor := cursor^.nextCharAddr
  end
end;

{ DELAY, opcode $3A: waits the message delay; no key is read. }
procedure EclDelay;
begin
  Inc(GDVars.eclIp);
  TextRend.PauseOnly
end;

const
  PARTY_KILLED_TEXT = 'The entire party is killed!';

{ DAMAGE, opcode $2E: deals damage of its second operand's count of dice with its third's sides, plus its fourth. With
  bit 7 of its first operand set, the damage goes to the whole party (bit 6), the current character (bit 7 of the fifth
  operand) or a random member, and a saving throw of the type in the fifth operand's low three bits (one less for the
  current character, for whom 0 allows none), modified by the first operand's low five bits, avoids it unless bit 4 is
  set; bit 5 skips the whole party's saves. Otherwise the first operand is a number of attacks on random members, each
  rolled to hit against the fifth operand and each with fresh damage. When no member is left in play, it shows that the
  party is killed. }
procedure EclDamage;
var
  attack: Byte;
  diceCount: Byte;
  diceSides: Byte;
  index: Byte;
  saveModifier: Byte;
  value: Byte;
  damageBonus: Byte;
    memberIndex: Byte;
    saveType: Byte;
    inner: Byte;
    amount: Word;
    cursor: Types.PCharRecord;
    scanCursor: Types.PCharRecord;
    saved: Types.PCharRecord;
    { Unused in this version; see the other implementations of this routine. }
    clearedAtStart: Byte;
    isWholeParty: Boolean;
    { non-zero: a character that saves still takes the whole amount, else none }
    damageOnSave: Byte;
begin
  saved := GDVars.currentCharacter;
  clearedAtStart := 0;
  isWholeParty := False;
  cursor := GDVars.partyHead;
  EclMenu.LoadEclVars(5);
  attack := EclMenu.GetEclVar(1);
  diceCount := EclMenu.GetEclVar(2);
  diceSides := EclMenu.GetEclVar(3);
  damageBonus := EclMenu.GetEclVar(4);
  value := EclMenu.GetEclVar(5);
  amount := CharHlp.RollDice(diceCount, diceSides) + damageBonus;
  damageOnSave := attack and $10;
  if (attack and $40) <> 0 then
    isWholeParty := True
  else
    memberIndex := CharHlp.RollDice(1, GDVars.zone1^.partyCount);
  if (attack and $80) <> 0 then begin
    saveModifier := attack and $1F;
    saveType := value and 7;
    if isWholeParty then begin
      while cursor <> nil do begin
        if (attack and $20) <> 0 then
          EclMenu.EclInflictDamage(amount, cursor)
        else if Byte(FxEngine.RollSavingThrow(cursor, saveType, saveModifier)) = 0 then
          EclMenu.EclInflictDamage(amount, cursor)
        else if damageOnSave <> 0 then
          EclMenu.EclInflictDamage(amount, cursor);
        cursor := cursor^.nextCharAddr
      end
    end else if (value and $80) <> 0 then begin
      if (saveType = 0) or
          (Byte(FxEngine.RollSavingThrow(GDVars.currentCharacter, saveType - 1, saveModifier)) = 0) then
        EclMenu.EclInflictDamage(amount, GDVars.currentCharacter)
      else if damageOnSave <> 0 then
        EclMenu.EclInflictDamage(amount, GDVars.currentCharacter)
    end else begin
      for index := 2 to memberIndex do cursor := cursor^.nextCharAddr;
      if Byte(FxEngine.RollSavingThrow(cursor, saveType, saveModifier)) = 0 then
        EclMenu.EclInflictDamage(amount, cursor)
      else if damageOnSave <> 0 then
        EclMenu.EclInflictDamage(amount, cursor)
    end
  end else begin
    for index := 1 to attack do begin
      cursor := GDVars.partyHead;
      memberIndex := CharHlp.RollDice(1, GDVars.zone1^.partyCount);
      inner := 1;
      while inner < memberIndex do begin
        cursor := cursor^.nextCharAddr;
        Inc(inner)
      end;
      if Byte(FxEngine.AttackRollNoAttacker(cursor, value)) <> 0 then
        EclMenu.EclInflictDamage(amount, cursor);
      amount := CharHlp.RollDice(diceCount, diceSides) + damageBonus
    end
  end;
  scanCursor := GDVars.partyHead;
  GDVars.partyDefeated := 1;
  while scanCursor <> nil do begin
    if scanCursor^.enabled <> 0 then GDVars.partyDefeated := 0;
    scanCursor := scanCursor^.nextCharAddr
  end;
  if GDVars.partyDefeated <> 0 then begin
    Border.DrawWindowFrame(1);
    GDVars.cursorColumn := 2;
    GDVars.cursorRow := 2;
    TextRend.DisplayMessageWindow(1, 1, 38, 22, LightGreen, Black, True, EclVm.PARTY_KILLED_TEXT);
    Delay(3000)
  end;
  GDVars.currentCharacter := saved;
  TextRend.PauseContinue
end;

{ CLOCK, opcode $34: advances the clock by its first argument in the unit its second names. }
procedure EclClock;
var
  amount: Byte;
  timeUnit: Byte;
begin
  EclMenu.LoadEclVars(2);
  amount := EclMenu.GetEclVar(1);
  timeUnit := EclMenu.GetEclVar(2);
  GameTime.AdvanceTime(amount, timeUnit)
end;

{ Moves the text cursor to the start of the next line. }
procedure EclPrintReturn;
begin
  Inc(GDVars.eclIp);
  GDVars.cursorColumn := GDVars.windowLeft;
  Inc(GDVars.cursorRow)
end;

{ Redraws the party list and position line, over a big picture too. }
procedure EclClearBox;
begin
  Inc(GDVars.eclIp);
  GDVars.bigPictureShown := 0;
  MenuCore.DisplayParty(GDVars.currentCharacter);
  CharHlp.PrintMiscInfo;
  GDVars.refreshState := 0;
  GDVars.eclDisplaying := 1
end;

{ WHO, opcode $39: asks the player to pick a party member, with its argument as the prompt, and makes that member
  current. }
procedure EclWho;
var query: String;
    savedMode: Byte;
begin
  savedMode := GDVars.moveMode;
  GDVars.moveMode := 0;
  GDVars.selectFailed := 0;
  EclMenu.LoadEclVars(1);
  TextRend.FillRect(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                    GDVars.windowColor);
  query := GDVars.eclStrings[1];
  ViewChar.SelectChar(query, False, False, Pointer(GDVars.currentCharacter), 1);
  GDVars.moveMode := savedMode
end;

{ ADD NPC, opcode $36: adds the monster its first argument names to the party as a non-player character whose morale is
  half its second argument. }
procedure EclAddNpc;
{ Unused in this version; see the other implementations of this routine. }
var npc: Pointer;
    creatureId: Byte;
    morale: Byte;
begin
  EclMenu.LoadEclVars(2);
  creatureId := EclMenu.GetEclVar(1);
  SaveLoad.AddCreatureToParty(creatureId);
  morale := EclMenu.GetEclVar(2);
  morale := Word(morale) div 2;
  morale := morale or C_Npc.NON_PLAYER_FLAG;
  GDVars.currentCharacter^.npc := morale;
  CharHlp.RecalcStats(GDVars.currentCharacter);
  MenuCore.DisplayParty(GDVars.currentCharacter)
end;

{ CALL: runs the built-in routine its address operand names, less $7FFF: refreshes the display, plays the selector
  sound, moves forward, refreshes the wall ahead (when the area kind is 0) or steps the portrait animation; any other
  value does nothing. }
procedure EclCall;
var address: Word;
    selector: Word;
begin
  EclMenu.LoadEclVars(1);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  selector := address - $7FFF;
  case selector of
    $ADCC: EclMenu.UpdateEclDisplay;
    $3204: if GDVars.selectorSound > 127 then
      Music.StartMusic(GDVars.selectorSound and $7F)
    else
      Music.SendSoundCommand(GDVars.selectorSound);
    $401F: EclMenu.EclMoveForward;
    $4019: if GDVars.zone0^.areaType = 0 then
      GDVars.partyPosition.wallAhead := View3D.GetWallType(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                                             GDVars.partyPosition.facing);
    $E804: begin
      Mouse.HideMouse;
      Portrait.DisplayImageBuf(3, 3, True, GDVars.portraitAnimation.currentFrame);
      Mouse.ShowMouse;
      Inc(GDVars.displayCounter.position);
      if GDVars.displayCounter.position > GDVars.displayCounter.limit then GDVars.displayCounter.position := 1;
      TextRend.PauseOnly
    end
  end
end;

const
  { the program operands EclProgram runs; it ignores the others }
  PROGRAM_MAIN_MENU = 0;
  PROGRAM_QUIT = 2;
  PROGRAM_REST_MENU = 9;

{ Puts the saved current character back and runs the main menu, quits the game or runs the rest menu, as operand 1 says;
  other operands do nothing. }
procedure EclProgram;
var programId: Byte;
    { Unused in this version; see the other implementations of this routine. }
    key: array[0..6] of Byte;
    savedMode: Byte;
begin
  savedMode := GDVars.moveMode;
  GDVars.moveMode := 0;
  if GDVars.restoresCharacter then begin
    GDVars.currentCharacter := GDVars.eclSavedCharacter;
    GDVars.restoresCharacter := False
  end;
  EclMenu.LoadEclVars(1);
  programId := EclMenu.GetEclVar(1);
  case programId of
    EclVm.PROGRAM_MAIN_MENU: begin
      CharGen.MainMenu;
      CharHlp.DisplayNoncombatInterface
    end;
    EclVm.PROGRAM_QUIT: begin
      GameIo.ExitGame;
      Halt(0)
    end;
    EclVm.PROGRAM_REST_MENU: Explore.RestMenu
  end;
  GDVars.moveMode := savedMode
end;

{ opcode $3C; it leaves IP where it is }
procedure EclNoop;
begin
end;

{ DUMP, opcode $3E: removes the current character from the party, keeps the character that becomes current as the saved
  character to restore, and redraws the party. }
procedure EclDump;
{ Unused in this version; see the other implementations of this routine. }
var index: Word;
begin
  Inc(GDVars.eclIp);
  CharGen.RemoveCreature(False, True);
  GDVars.eclSavedCharacter := GDVars.currentCharacter;
  MenuCore.DisplayParty(GDVars.currentCharacter)
end;

{ Tells the player to record string operand 1 as logbook entry operand 2, and waits. }
procedure EclLogbookEntry;
var message: String;
    { Unused in this version; see the other implementations of this routine. }
    choice: Byte;
    value: Word;
begin
  EclMenu.LoadEclVars(2);
  value := EclMenu.GetEclVar(2);
  message := ' and you record ' + GDVars.eclStrings[1] + ' as logbook entry ' + TextRend.WordToString(value) + '.';
  TextRend.DisplayMessageWindow(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                                LightGreen, Black, False, message);
  choice := EclMenu.MenuHorizontalCharacterSelect('', GDConsts.continueMenuPrompt, True, GDVars.picturePending);
  TextRend.ClearStatusLine
end;

{ Destroys the current character's items of type itemType, or every member's with wholeParty set. With bit 7 of the type
  operand it stops at the first match, and takes one unit off a joinable stack instead of the whole item. }
procedure EclDestroyItems;
var itemType: Byte;
    savedCurrent: Types.PCharRecord;
    item: Types.PItemRec;
    nextItem: Types.PItemRec;
    highBit: Byte;
    wholeParty: Byte;
    found: Byte;
    { ToggleReadyItem's out flag; not needed here }
    hasEndedTurn: Boolean;
begin
  EclMenu.LoadEclVars(2);
  wholeParty := EclMenu.GetEclVar(1);
  itemType := EclMenu.GetEclVar(2);
  highBit := itemType and $80;
  itemType := itemType and $7F;
  savedCurrent := GDVars.currentCharacter;
  if wholeParty <> 0 then GDVars.currentCharacter := GDVars.partyHead;
  found := 0;
  while (GDVars.currentCharacter <> nil) and (found = 0) do begin
    item := GDVars.currentCharacter^.itemsAddr;
    while (item <> nil) and (found = 0) do begin
      nextItem := item^.next;
      if itemType = item^.template.itemType then begin
        if ((item^.template.flags and C_Item.NOT_JOINABLE) = 0) and ((item^.template.quantity > 1) <> False) and
            (highBit <> 0) then
          Dec(item^.template.quantity)
        else begin
          if (item^.template.flags and C_Item.READIED) <> 0 then
            ViewChar.ToggleReadyItem(item, hasEndedTurn);
          CharHlp.RemoveItem(GDVars.currentCharacter, item)
        end;
        found := highBit
      end;
      item := nextItem
    end;
    if found = 0 then found := Ord(wholeParty = 0);
    CharHlp.RecalcStats(GDVars.currentCharacter);
    GDVars.currentCharacter := GDVars.currentCharacter^.nextCharAddr
  end;
  GDVars.currentCharacter := savedCurrent
end;

const
  TEAM_AWARD_TEXT = 'Congrats. The team gains experience!';
  AWARD_PREFIX = 'Congrats. ';
  AWARD_SUFFIX = ' gains experience!';

{ Gives operand 2 experience to each enabled party member (operand 1 non-zero) or to the current character when enabled,
  with a message. }
procedure EclAwardExperience;
var amount: Word;
    wholeParty: Byte;
    cursor: Types.PCharRecord;
    { Unused in this version; see the other implementations of this routine. }
    share: Pointer;
begin
  EclMenu.LoadEclVars(2);
  amount := EclMenu.GetEclVar(2);
  wholeParty := EclMenu.GetEclVar(1);
  GDVars.cursorRow := GDVars.windowTop;
  GDVars.cursorColumn := GDVars.windowLeft;
  if wholeParty <> 0 then begin
    TextRend.DisplayMessageWindow(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                                  LightGreen, Black, True, EclVm.TEAM_AWARD_TEXT);
    TextRend.PauseOnly;
    cursor := GDVars.partyHead;
    while cursor <> nil do begin
      if cursor^.enabled <> 0 then Inc(cursor^.experience, amount);
      cursor := cursor^.nextCharAddr
    end
  end else begin
    cursor := GDVars.currentCharacter;
    TextRend.DisplayMessageWindow(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                                  LightGreen, Black, True, EclVm.AWARD_PREFIX + cursor^.name + EclVm.AWARD_SUFFIX);
    TextRend.PauseOnly;
    if cursor^.enabled <> 0 then Inc(cursor^.experience, amount)
  end
end;

{ Clears the text window, refreshes the view and exits the script. }
procedure EclClearAndStop;
begin
  TextRend.FillRect(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                    GDVars.windowColor);
  EclMenu.UpdateEclDisplay;
  EclVm.EclExit
end;

{ Sends the operand's eclSoundCommands entry; above 127, starts music sequence operand - 128 instead. }
procedure EclPlaySound;
var value: Byte;
begin
  EclMenu.LoadEclVars(1);
  value := EclMenu.GetEclVar(1);
  if value > 127 then
    Music.StartMusic(value and $7F)
  else
    Music.SendSoundCommand(GDConsts.eclSoundCommands[value])
end;

{ Steps past its own opcode. }
procedure EclSkipOpcode;
begin
  Inc(GDVars.eclIp)
end;

{ Writes MaxMonsterDist toward facing quarter operand 2 to operand 1's address. }
procedure EclDistanceAhead;
var facing: Byte;
    distance: Byte;
    address: Word;
begin
  EclMenu.LoadEclVars(2);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  facing := EclMenu.GetEclVar(2) * 2;
  distance := EclMenu.MaxMonsterDist(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY, facing);
  EclMenu.WriteGbvm(address, distance, GDVars.eclVarTypes[1])
end;

{ Opens a counted loop at the next command: counter operand 1, limit operand 2. }
procedure EclLoopInitialize;
begin
  EclMenu.LoadEclVars(2);
  GDVars.eclLoopStart := GDVars.eclIp;
  GDVars.zone0^.loopCurrent := EclMenu.GetEclVar(1);
  GDVars.zone0^.loopLimit := EclMenu.GetEclVar(2)
end;

{ Counts the loop on and jumps back to its start while the counter is within the limit. }
procedure EclLoopAdvance;
begin
  Inc(GDVars.eclIp);
  Inc(GDVars.zone0^.loopCurrent);
  if GDVars.zone0^.loopCurrent <= GDVars.zone0^.loopLimit then
    GDVars.eclIp := GDVars.eclLoopStart
end;

{ Moves each member's items to its alternate item list (when the operand is 0, also marking in zone 0 that the items are
  stashed) or back, ahead of any already there. }
procedure EclTransferCharacterLists;
{ a cell holding an item list's head; PItemRec is Types' }
type PItemHead = ^PItemRec;
var direction: Byte;
    cursor: Types.PCharRecord;
    tail: Types.PItemRec;
    sourceHead: PItemHead;
    destinationHead: PItemHead;
begin
  EclMenu.LoadEclVars(1);
  direction := EclMenu.GetEclVar(1);
  GDVars.zone0^.listTransferState := Ord(direction = 0);
  cursor := GDVars.partyHead;
  while cursor <> nil do begin
    if direction <> 0 then begin
      sourceHead := @cursor^.alternateItemsAddr;
      destinationHead := @cursor^.itemsAddr
    end else begin
      sourceHead := @cursor^.itemsAddr;
      destinationHead := @cursor^.alternateItemsAddr
    end;
    if destinationHead^ = nil then
      destinationHead^ := sourceHead^
    else if sourceHead^ <> nil then begin
      tail := sourceHead^;
      while tail^.next <> nil do tail := tail^.next;
      tail^.next := destinationHead^;
      destinationHead^ := sourceHead^
    end;
    sourceHead^ := nil;
    CharHlp.RecalcStats(cursor);
    cursor := cursor^.nextCharAddr
  end
end;

{ Rolls the skill in operand 1 at the scale in operand 3 for the current character or, with operand 2, each party
  member; each that fails takes operands 4 d 5 plus 6 damage. Note: the member loop runs until the script-stopped flag
  is set, and with operand 2 = 0 it sets that flag after the one character, which also ends the script run. }
procedure EclSkillDamage;
var skillId: Byte;
    scale: Byte;
    diceCount: Byte;
    diceSides: Byte;
    damageBonus: Byte;
    damage: Byte;
    wholeParty: Byte;
    isFirst: Boolean;
    cursor: Types.PCharRecord;
    { Unused in this version; see the other implementations of this routine. }
    message: String;
begin
  EclMenu.LoadEclVars(6);
  skillId := EclMenu.GetEclVar(1);
  wholeParty := EclMenu.GetEclVar(2);
  scale := EclMenu.GetEclVar(3);
  diceCount := EclMenu.GetEclVar(4);
  diceSides := EclMenu.GetEclVar(5);
  damageBonus := EclMenu.GetEclVar(6);
  GDVars.cursorColumn := GDVars.windowLeft;
  GDVars.cursorRow := GDVars.windowTop;
  isFirst := True;
  if wholeParty <> 0 then cursor := GDVars.partyHead
  else cursor := GDVars.currentCharacter;
  while (cursor <> nil) and (not GDVars.isEclStopped) do begin
    if CharHlp.SelectSkillCharacter(skillId, scale, False, Pointer(cursor)) < 2 then begin
      if isFirst then begin
        isFirst := False;
        TextRend.FillRect(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                          GDVars.windowColor)
      end;
      damage := CharHlp.RollDice(diceCount, diceSides) + damageBonus;
      EclMenu.EclInflictDamage(damage, cursor)
    end;
    cursor := cursor^.nextCharAddr;
    GDVars.isEclStopped := wholeParty = 0
  end
end;

{ EclCombat with only the current character fighting. }
procedure EclSoloCombat;
begin
  GDVars.soloCombat := 1;
  EclVm.EclCombat
end;

{ Stocks the available items from shop item list operand 1 and runs the shop. }
procedure EclShop;
var listNumber: Byte;
    templateIndex: Byte;
    item: Types.TItemRec;
    previous: Types.PItemRec;
    first: Byte;
    last: Byte;
    index: Byte;
begin
  EclMenu.LoadEclVars(1);
  while GDVars.availableItems <> nil do begin
    previous := GDVars.availableItems;
    GDVars.availableItems := GDVars.availableItems^.next;
    FreeMem(previous, SizeOf(Types.TItemRec))
  end;
  listNumber := EclMenu.GetEclVar(1);
  first := GDConsts.itemListStarts[listNumber];
  last := first + GDConsts.itemListCounts[listNumber] - 1;
  for index := first to last do begin
    templateIndex := GDConsts.itemListEntries[index];
    if GDVars.itemTemplates[templateIndex].itemType <> C_Item.EMPTY_TEMPLATE then begin
      Move(GDVars.itemTemplates[templateIndex], item.template, SizeOf(Types.TItemTemplate));
      item.next := nil;
      item.menuLabel := 0;
      if GDVars.availableItems = nil then begin
        New(GDVars.availableItems);
        GDVars.availableItems^ := item
      end else begin
        previous := GDVars.availableItems;
        New(GDVars.availableItems);
        GDVars.availableItems^ := item;
        GDVars.availableItems^.next := previous
      end
    end
  end;
  Shop.ShopMainMenu
end;

{ Sets zone 0's picture mode to operand 1 and the screen it names (0 3-D view, 2 orbit map, 3 picture view, 4
  wilderness; 1 keeps the screen) and shows the picture in operand 2. }
procedure EclSetPictureMode;
var picId: Byte;
    mode: Byte;
begin
  EclMenu.LoadEclVars(2);
  mode := EclMenu.GetEclVar(1);
  picId := EclMenu.GetEclVar(2);
  GDVars.zone0^.extendedPictureMode := mode;
  GDVars.bigPictureShown := 0;
  GDVars.viewActive := 0;
  case mode of
    0: begin
      if GDVars.interfaceState = C_Ifc.ORBIT_MAP then
        OrbitMap.FreeOrbitPictures;
      GDVars.interfaceState := C_Ifc.VIEW_3D
    end;
    2: GDVars.interfaceState := C_Ifc.ORBIT_MAP;
    3: GDVars.interfaceState := C_Ifc.PICTURE_VIEW;
    4: begin
      GDVars.interfaceState := C_Ifc.WILDERNESS;
      GDVars.viewActive := 1
    end
  end;
  if (mode <> 1) and (mode <> 4) then
    CharHlp.DisplayNoncombatInterface;
  EclVm.ShowPicture(picId)
end;

{ Runs currentOpcode's handler; an opcode with no arm does nothing and leaves IP. }
procedure DispatchEclCommand;
begin
  case GDVars.currentOpcode of
    $00: EclVm.EclExit;
    $01: EclVm.EclGoto;
    $02: EclVm.EclGosubCmd;
    $03: EclVm.EclCompare;
    $04, $05, $06, $07: EclVm.EclArithmetic;
    $08: EclVm.EclRandom;
    $09: EclVm.EclSave;
    $0A: EclVm.EclLoadCharacter;
    $0B: EclVm.EclLoadMonster;
    $0C: EclVm.EclSetupMonster;
    $0D: EclVm.EclApproach;
    $0E: EclVm.EclPicture;
    $0F: EclVm.EclInputNumber;
    $10: EclVm.EclInputString;
    $11, $12: EclVm.EclPrint;
    $13: EclVm.EclReturn;
    $14: EclVm.EclCompareAnd;
    $15: EclVm.EclVMenu;
    $16, $17, $18, $19, $1A, $1B: EclVm.EclIf;
    $1C: EclVm.EclClearMonsters;
    $1D: EclVm.EclSetSpeaker;
    $1E: EclVm.EclCheckParty;
    $1F: ShipCbt.ShipCombat;
    $20: EclVm.EclNewEcl;
    $21, $37: EclVm.EclLoadFiles;
    $22: EclVm.EclSkillCheck(False);
    $23: EclVm.EclSkillCheck(True);
    $24: EclVm.EclCombat;
    $25, $26: EclVm.EclOnGoto;
    $27: EclVm.EclTreasure;
    $28: EclVm.EclRob;
    $29: EclVm.EclContinuePrompt;
    $2A: EclVm.EclGetTable;
    $2B: EclVm.EclHMenu(False);
    $2C: EclVm.EclYesNoCompare;
    $2D: EclVm.EclCall;
    $2E: EclVm.EclDamage;
    $2F, $30: EclVm.EclAndOr;
    $31: EclVm.EclHMenu(True);
    $32: EclVm.EclFindItem;
    $33: EclVm.EclPrintReturn;
    $34: EclVm.EclClock;
    $35: EclVm.EclSaveTable;
    $36: EclVm.EclAddNpc;
    $38: EclVm.EclProgram;
    $39: EclVm.EclWho;
    $3A: EclVm.EclDelay;
    $3B: ;
    $3C: EclVm.EclNoop;
    $3D: EclVm.EclClearBox;
    $3E: EclVm.EclDump;
    $3F: EclVm.EclLogbookEntry;
    $40: EclVm.EclDestroyItems;
    $41: EclVm.EclAwardExperience;
    $42: EclVm.EclClearAndStop;
    $43: EclVm.EclPlaySound;
    $44: EclVm.EclSkipOpcode;
    $45: EclVm.EclDistanceAhead;
    $46: EclVm.EclLoopInitialize;
    $47: EclVm.EclLoopAdvance;
    $48: EclVm.EclTransferCharacterLists;
    $49: EclVm.EclSkillDamage;
    $4A: EclVm.EclSoloCombat;
    $4B: EclVm.EclShop;
    $4C: EclVm.EclSetPictureMode
  end
end;

{ Runs the loaded script until a handler stops it or the party is defeated.
  @param(address The script address to start at.) }
procedure CallEclScript(address: Word);
{ Unused in this version; see the other implementations of this routine. }
var savedIp: Word;
begin
  GDVars.loopIndex := 1;
  GDVars.eclIp := address;
  GDVars.isEclStopped := False;
  while (not GDVars.isEclStopped) and (GDVars.partyDefeated = 0) do begin
    GDVars.previousOpcode := GDVars.currentOpcode;
    GDVars.currentOpcode := GDVars.zone3^[GDVars.eclIp];
    EclVm.DispatchEclCommand
  end;
  GDVars.isEclStopped := False
end;

{ Starts each newly loaded script: entry point 5, then, unless that loads another, the view, entry points 1 and 2 and
  the party list; again while a script loads another. }
procedure NewEclDone;
begin
  repeat
    Portrait.FreeAnimation;
    GDVars.savedPicArcName[0] := #0;
    GDVars.savedPicArcId := C_Pic.NO_ANIMATION;
    GDVars.isNewEclLoaded := False;
    GDVars.partyPosition.mapEvent := View3D.GetMapEvent(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY);
    GDVars.partyPosition.wallAhead := View3D.GetWallType(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                                           GDVars.partyPosition.facing);
    GDVars.partyMoved := True;
    GDVars.zone1^.hasLeftMap := 0;
    GDVars.eclSavedCharacter := GDVars.currentCharacter;
    EclVm.CallEclScript(GDVars.eclEntryPoints[5]);
    if not GDVars.isNewEclLoaded then GDVars.zone0^.stateValue := GDVars.eclId;
    if not GDVars.isNewEclLoaded then begin
      if (((GDVars.previousInterfaceState <> C_Ifc.VIEW_3D) or (GDVars.interfaceState = C_Ifc.VIEW_3D)) and
          GDVars.hasLoadedFiles) or
          ((GDVars.previousInterfaceState = C_Ifc.VIEW_3D) and (GDVars.interfaceState = C_Ifc.VIEW_3D)) then
        MapView.DisplayMapView;
      GDVars.isNewEclLoaded := False;
      EclVm.CallEclScript(GDVars.eclEntryPoints[1]);
      if not GDVars.isNewEclLoaded then begin
        EclVm.CallEclScript(GDVars.eclEntryPoints[2]);
        if not GDVars.isNewEclLoaded then begin
          GDVars.currentCharacter := GDVars.eclSavedCharacter;
          MenuCore.DisplayParty(GDVars.currentCharacter)
        end
      end
    end
  until not GDVars.isNewEclLoaded;
  GDVars.previousInterfaceState := GDVars.interfaceState
end;

procedure GameLoop;
var selection: Byte;
    cursor: Types.PCharRecord;
begin
  GDVars.eclSavedCharacter := GDVars.currentCharacter;
  GDVars.portraitPending := 1;
  GDVars.protectionTextShown := 0;
  GDVars.hasLoadedPieces := False;
  GDVars.hasLoadedMap := False;
  GDVars.restoresCharacter := False;
  GDVars.hasLoadedFiles := False;
  GDVars.refreshState := 1;
  GDVars.isNewEclLoaded := False;
  if GDVars.zone0^.stateValue = C_Ecl.NO_ECL_SCRIPT then begin
    GDVars.refreshState := 0;
    if GDVars.demoMode then begin
      GDVars.eclId := EclVm.DEMO_ECL_SCRIPT;
      GDVars.interfaceState := C_Ifc.VIEW_3D
    end else begin
      GDVars.eclId := EclVm.START_ECL_SCRIPT;
      GDVars.interfaceState := C_Ifc.VIEW_3D;
      MenuCore.DisplayParty(GDVars.currentCharacter)
    end
  end else
    GDVars.eclId := GDVars.zone0^.stateValue;
  if EclMenu.LoadEclScript(GDVars.eclId) then
    EclMenu.EclInit;
  EclVm.CallEclScript(GDVars.eclEntryPoints[5]);
  if GDVars.demoMode then begin
    cursor := GDVars.partyHead;
    while cursor <> nil do begin
      GDVars.currentCharacter := cursor;
      cursor := cursor^.nextCharAddr;
      CharGen.RemoveCreature(True, True)
    end;
    Exit
  end;
  if not GDVars.isNewEclLoaded then
    GDVars.zone0^.stateValue := GDVars.eclId
  else
    EclVm.NewEclDone;
  if (GDVars.interfaceState <> C_Ifc.WILDERNESS) and (GDVars.hasLoadedSave <> 0) then begin
    if GDVars.refreshState = 1 then
      CharHlp.DisplayNoncombatInterface;
    GDVars.portraitPending := 1;
    MapView.DisplayMapView
  end;
  GDVars.hasLoadedSave := 0;
  GDVars.moveMode := 0;
  repeat
    selection := Byte(Explore.MapMainMenu);
    GDVars.eclSavedCharacter := GDVars.currentCharacter;
    if not GDVars.isNewEclLoaded then GDVars.zone0^.stateValue := GDVars.eclId;
    while ((GDVars.zone1^.searchFlags > C_Search.SEARCHING) or (UpCase(Char(selection)) = 'E')) and
        (GDVars.partyDefeated = 0) do begin
      GDVars.savedSearchFlag := GDVars.zone1^.searchFlags and C_Search.SEARCHING;
      GDVars.zone1^.searchFlags := C_Search.SEARCHING;
      GDVars.portraitPending := 1;
      MapView.DisplayMapView;
      EclVm.CallEclScript(GDVars.eclEntryPoints[2]);
      if GDVars.isNewEclLoaded then EclVm.NewEclDone;
      GDVars.zone1^.searchFlags := GDVars.savedSearchFlag;
      if GDVars.partyDefeated = 0 then begin
        selection := Byte(Explore.MapMainMenu);
        GDVars.eclSavedCharacter := GDVars.currentCharacter
      end
    end;
    if GDVars.partyDefeated = 0 then EclVm.CallEclScript(GDVars.eclEntryPoints[1]);
    if GDVars.isNewEclLoaded then
      EclVm.NewEclDone
    else if GDVars.partyDefeated = 0 then begin
      GDVars.zone0^.prevX := GDVars.partyPosition.mapX;
      GDVars.zone0^.prevY := GDVars.partyPosition.mapY;
      Explore.ResolveMovement;
      if (GDVars.zone0^.areaType <> C_Area.VENUS_WILDERNESS) and
          (GDVars.zone0^.areaType <> C_Area.MARS_WILDERNESS) then
        MapView.DisplayMapView;
      if GDVars.interfaceState = C_Ifc.VIEW_3D then
        if (GDVars.partyPosition.mapX <> GDVars.zone0^.prevX) or
            (GDVars.partyPosition.mapY <> GDVars.zone0^.prevY) then
          Music.SendSoundCommand(GDConsts.stepSound);
      GDVars.picturePending := False;
      EclVm.CallEclScript(GDVars.eclEntryPoints[2]);
      if GDVars.isNewEclLoaded then EclVm.NewEclDone
    end
  until GDVars.partyDefeated <> 0;
  GDVars.partyDefeated := 0;
  cursor := GDVars.partyHead;
  while cursor <> nil do begin
    GDVars.currentCharacter := cursor;
    cursor := cursor^.nextCharAddr;
    CharGen.RemoveCreature(False, True)
  end
end;

begin
end.
