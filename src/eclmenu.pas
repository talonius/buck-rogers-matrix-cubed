{ The ECL virtual machine's support routines: loading and decoding ECL variables, reading and writing GBVM addresses,
  the ECL menus, COMPARE and GOSUB, creatures and monster pictures, robbery and damage, and the item templates. The VM's
  state is GDVars'. }
{$O+,F+,V-}
unit EclMenu;

interface

uses Types, C_Combat, C_Gbvm, C_Pic, C_Status, GDConsts, GDVars, SaveLoad, Portrait,
  TextRend, DaxIo, View3D, ViewChar, MapView, CharHlp, MenuCore, GameIo, Crt, C_Dir, C_Ifc, C_Area, C_Item, C_Side,
  C_Keys;

{ Gives the value of a loaded ECL variable: a literal (types 0, 2, 4 and $81) or a 1-, 2- or 4-byte GBVM read (types 1,
  3 and $80, and 5).
  @param(idx The variable's index.)
  @returns(Its value.) }
function GetEclVar(idx: ShortInt): LongInt;

{ Reads ECL variables at the ECL IP into eclVarTypes, eclVarLow and eclVarHigh (eclVarByte2 and eclVarByte3 for type 4),
  decoding string values and string references into eclStrings. A variable has its type at +1 and its low byte at +2;
  types 1, 2, 3 and 5 add a high byte, type 4 three more bytes. Type $80 is a packed string whose low byte is its length
  in bytes; $81 is a string reference whose extra byte is the address's high byte.
  @param(count The number of variables.) }
procedure LoadEclVars(count: Byte);

{ ECL initialization: sets the instruction pointer to $8000, reads the five entry points, and without a loaded save
  zeroes GBVM $4C00..$4C1F and $7F79..$7F82. }
procedure EclInit;

{ Loads a block of ECL<data set>.dax into zone 3, less its first 2 bytes, retrying until the block yields at least 2
  bytes. Note: nothing ends the retry, so a missing block hangs the game.
  @param(scriptId The block.)
  @returns(True.) }
function LoadEclScript(scriptId: Byte): Boolean;

{ Allocates and loads a MON creature.
  @param(id The creature's record.)
  @param(character Set to the creature.)
  @param(items Set to its item list.)
  @param(effects Set to its effect list.) }
procedure InitCreature(id: Byte; var character: Types.PCharRecord; var items: Types.PItemRec;
                       var effects: Types.PEffectRec);

{ Gives how far ahead monsters may appear, walls permitting; 2, also stored in zone 1's monsterDistance, when zone 0's
  area kind is 0. The walk steps its own copies of x and y.
  @param(x The party's column.)
  @param(y The party's row.)
  @param(facing The direction looked.)
  @returns(The distance, 0..5 cells.) }
function MaxMonsterDist(x, y, facing: Byte): Byte;

{ Loads the monster's SPRIT sprite (not when zone 0's area kind is 0) and draws it in the 3-D view when interfaceState
  is C_Ifc.VIEW_3D; there, at distance 0, it also shows the PIC close-up, during an encounter menu only while monster
  pictures are on.
  @param(sprId The sprite.)
  @param(picId The close-up, C_Pic.NO_ANIMATION for none.)
  @param(dist The monster's distance; the sprite is drawn at dist + 1.)
  @param(flags The monster flags EclVm passes: [0] sprite loaded, [1] close-up loaded.) }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);

{ Joins two bytes into a word.
  @param(lowByte The low byte.)
  @param(highByte The high byte.)
  @returns(The word.) }
function CombineBytesToWord(lowByte, highByte: Byte): Word;

{ Turns a packed script character into ASCII: codes below 32 become 64..95.
  @param(c The packed character.)
  @returns(The ASCII character.) }
function DecodeGameCharacter(c: Byte): Char;

{ Gives the GBVM zone an address falls in.
  @param(address The GBVM address.)
  @returns(The zone: zone 0 to 3, or zone 4 when zones 0 to 3 do not hold the address.) }
function GbvmZone(address: Word): Byte;

{ Reads the zone 1 addresses that stand for the current character's fields (offsets from the current-character address),
  its place in the party (+$2B1) and the data set (+$312).
  @param(address The GBVM address.)
  @param(width The bytes read, 1, 2 or 4.)
  @param(isHandled False when `address` is none of them, and the caller reads the zone.)
  @returns(The value read, 0 when unhandled.) }
function SpecialReadZ1(address: Word; width: Byte; var isHandled: Boolean): LongInt;

{ Applies a zone 1 write to what it stands for: the current character's fields, and at +$312 a pushed data set; a zero
  written to the name's first byte sets the name-cleared flag. WriteGbvm calls it after writing the zone.
  @param(address The GBVM address.)
  @param(value The value written.)
  @param(width The bytes written: 1, 2 or 4.) }
procedure SpecialWriteZ1(address: Word; value: LongInt; width: Byte);

{ Writes a value to a GBVM address. A zone 1 write also goes through SpecialWriteZ1; a zone 4 write above $BF68 sets the
  party's position, facing or view colors, and any other zone 4 write is ignored. A new area kind in zone 0 sets
  interfaceState, and a sky index write marks the sky for redrawing.
  @param(address The GBVM address.)
  @param(value The value written.)
  @param(gbType The variable type, which sets the width: 0 and 1 one byte, 2 and 3 two, 4 and 5 four.) }
procedure WriteGbvm(address: Word; value: LongInt; gbType: Byte);

{ Reads a GBVM address. A zone 1 read goes through SpecialReadZ1 first; zone 4 from GBVM_PARTY_X reads the party's
  position, facing (halved unless zone 0's areaType has bit $20), wall-ahead and event bytes (the write side splits at
  GBVM_ZONE_4_WRITE_BASE instead). Zone 0's GBVM_ZONE_0_FACING and zone 4's GBVM_STORED_FACING read the party's facing
  as stored.
  @param(address The GBVM address.)
  @param(gbType The variable type, which sets the width as WriteGbvm's does.)
  @returns(The value read.) }
function ReadGbvm(address: Word; gbType: Byte): LongInt;

{ Writes a string to the GBVM, zero-terminated, except at the current-character address, where it sets the current
  character's name (a String[15], so longer text is cut).
  @param(address The GBVM address.)
  @param(s The string.) }
procedure WriteGbvmString(address: Word; s: String);

{ Decodes packed bytes at the ECL IP into eclStrings: three bytes hold four 6-bit characters, the fourth from the low
  bits of the byte already read, and a character code of 0 is left out.
  @param(len The packed bytes.)
  @param(strIdx The eclStrings entry.) }
procedure ConvGbString(len, strIdx: Byte);

{ Copies the zero-terminated string at a GBVM address into eclStrings, or at the current-character address the current
  character's name.
  @param(strIdx The eclStrings entry.)
  @param(address The GBVM address.) }
procedure DerefGbString(strIdx: Byte; address: Word);

{ Shows a menu, whose letters marked with '~' are its options, until a letter or digit (or, when Enter is accepted,
  Enter or Escape) is pressed.
  @param(query The prompt.)
  @param(menu The menu text.)
  @param(acceptsEnter True also takes Enter and Escape.)
  @param(isAnimated Steps the portrait animation while it waits.)
  @returns(The option's index from 0, 0 also for Enter, or 255 for Escape or a key that is no option.) }
function MenuHorizontalCharacterSelect(query: Types.TString40; menu: String; acceptsEnter, isAnimated: Boolean): Byte;

{ Shows a list in a MenuCore.MenuVertical window under query, with 'Select' as its menu line. Note: menu goes through
  MenuToOptions but is never shown, and the key MenuVertical returns is dropped.
  @param(query The prompt.)
  @param(menu Unshown options.)
  @param(ulCol The window's left column.)
  @param(ulRow The window's top row.)
  @param(lrCol The window's right column.)
  @param(lrRow The window's bottom row.)
  @param(list The members listed.)
  @param(offersExit True offers Exit.)
  @param(needsRedraw True draws the page first.)
  @param(idx The selected member, 0-based, in and out.)
  @param(sel Receives the member chosen, nil when none.) }
procedure EclVerticalMenu(query: Types.TString40; menu: String; ulCol, ulRow, lrCol, lrRow: ShortInt;
                          list: Types.PItemRec; offersExit: Boolean; var needsRedraw: Boolean; var idx: Integer;
                          var sel: Types.PItemRec);

{ Sets the six comparison flags from two strings: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareStr(leftOperand, rightOperand: String);

{ Sets the six comparison flags from two numbers: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareInt(leftOperand, rightOperand: LongInt);

{ Pushes the ECL IP on eclStack and jumps to an address; the node below the new top is held in eclStackPrevious.
  @param(varIdx The ECL variable holding the address.) }
procedure EclGosub(varIdx: Byte);

{ Steps the party forward, wrapping at the map's edges (0..15), then refreshes the event and wall-ahead bytes. }
procedure EclMoveForward;

{ Multiplies a character's credits by a fraction.
  @param(fraction The share kept.)
  @param(character The character robbed.) }
procedure RobMoney(fraction: Real; character: Types.PCharRecord);

{ Steals each of a character's items, in list order, when a d100 roll is at most chance; a readied item is unreadied
  first. An item heavier than 255 lowers chance by 90 before its roll, one heavier than 24 by 50 (not below 0). Note:
  the lowered chance carries on to the items after it.
  @param(chance The percent chance for each item.)
  @param(character The character robbed.) }
procedure RobItems(chance: Byte; character: Types.PCharRecord);

{ Skips the ECL command at IP by loading its operands, their count keyed on the opcode; for an opcode not listed, IP
  moves one byte. }
procedure SkipEclCmd;

{ Deals damage to a character, if its status is okay, with a message in the text window, and redraws the party panel
  outside C_Ifc.WILDERNESS and C_Ifc.ORBIT_MAP. The message reports the character dying when dmg exceeds its hit points
  by more than 10.
  @param(dmg The damage.)
  @param(character The character hurt.) }
procedure EclInflictDamage(dmg: Word; character: Types.PCharRecord);

{ Refreshes the event byte and, when a picture, sprite, color, move or sky change is pending, redraws the view and the
  status line and refreshes the wall-ahead byte. }
procedure UpdateEclDisplay;

{ Loads itemTemplates from ITEM0.DAX block 1, up to 127 of them; the rest stay C_Item.EMPTY_TEMPLATE. Without the file
  the game aborts. }
procedure LoadItemTemplates;

implementation

const
  { the zones' bounds, by which GbvmZone classifies an address }
  { the first address of zone 0 }
  GBVM_ZONE_0_FIRST = $4B00;
  { the last address of zone 0 }
  GBVM_ZONE_0_LAST = $4EFF;
  { the first address of zone 1 }
  GBVM_ZONE_1_FIRST = $7C00;
  { the last address of zone 1 }
  GBVM_ZONE_1_LAST = $7FFF;
  { the first address of zone 2 }
  GBVM_ZONE_2_FIRST = $7A00;
  { the last address of zone 2 }
  GBVM_ZONE_2_LAST = $7BFF;
  { the first address of zone 3 }
  GBVM_ZONE_3_FIRST = $8000;
  { the last address of zone 3 }
  GBVM_ZONE_3_LAST = $A400;
  { TZone0.areaType }
  GBVM_AREA_TYPE = $4BE6;
  { ReadGbvm answers it with partyPosition.facing as stored, not the zone's byte }
  GBVM_ZONE_0_FACING = $4BEA;
  { TZone0.skyIndexLo and skyIndexHi }
  GBVM_SKY_INDEX_LO = $4BFD;
  GBVM_SKY_INDEX_HI = $4BFE;
  { GBVM addresses ReadGbvm and WriteGbvm answer from GDVars' party and view state, not a zone }
  { reads partyPosition.facing as stored }
  GBVM_STORED_FACING = $33D;
  GBVM_PARTY_X = $C04B;
  GBVM_PARTY_Y = $C04C;
  { the facing as 0..3, north first }
  GBVM_FACING = $C04D;
  GBVM_WALL_AHEAD = $C04E;
  GBVM_MAP_EVENT = $C04F;
  GBVM_FLOOR_COLOR = $C059;
  GBVM_HORIZON_COLOR = $C05F;
  { WriteGbvm handles a zone 4 address only above it, dispatching on the offset from it }
  GBVM_ZONE_4_WRITE_BASE = $BF68;
  { the GBVM address of zone1^.savedDataSet, which SpecialReadZ1 and SpecialWriteZ1 answer with dataSet itself }
  GBVM_DATA_SET = $7F12;

type
  { An ECL<n>.DAX block as loaded. }
  TEclRecord = record
    { Never read. }
    header: Word;
    { What LoadEclScript copies into zone 3; a block may end short of it. }
    script: Types.TZone3
  end;

procedure LoadEclVars(count: Byte);
var
  i: Byte;
  strIdx: Byte;
  { the reference's GBVM address }
  address: Word;
  { the packed string's length in bytes }
  len: Word;
begin
  strIdx := 0;
  for i := 1 to count do begin
    GDVars.eclVarTypes[i] := GDVars.zone3^[GDVars.eclIp + 1];
    GDVars.eclVarLow[i] := GDVars.zone3^[GDVars.eclIp + 2];
    GDVars.eclIp := GDVars.eclIp + 2;
    case GDVars.eclVarTypes[i] of
      1, 2, 3, 5: begin
        Inc(GDVars.eclIp);
        GDVars.eclVarHigh[i] := GDVars.zone3^[GDVars.eclIp];
      end;
      4: begin
        GDVars.eclVarHigh[i] := GDVars.zone3^[GDVars.eclIp + 1];
        GDVars.eclVarByte2[i] := GDVars.zone3^[GDVars.eclIp + 2];
        GDVars.eclVarByte3[i] := GDVars.zone3^[GDVars.eclIp + 3];
        Inc(GDVars.eclIp, 3);
      end;
      $80: begin
        Inc(strIdx);
        len := GDVars.eclVarLow[i];
        if len > 0 then
          EclMenu.ConvGbString(len, strIdx)
        else
          GDVars.eclStrings[strIdx] := '';
      end;
      $81: begin
        Inc(strIdx);
        Inc(GDVars.eclIp);
        GDVars.eclVarHigh[i] := GDVars.zone3^[GDVars.eclIp];
        address := EclMenu.CombineBytesToWord(GDVars.eclVarLow[i], GDVars.eclVarHigh[i]);
        EclMenu.DerefGbString(strIdx, address);
      end;
    end;
  end;
  Inc(GDVars.eclIp);
end;

function GetEclVar(idx: ShortInt): LongInt;
var
  vLo: Byte;
  vHi: Byte;
begin
  vLo := GDVars.eclVarLow[idx];
  vHi := GDVars.eclVarHigh[idx];
  case GDVars.eclVarTypes[idx] of
    0: GetEclVar := LongInt(vLo);
    1: GetEclVar := EclMenu.ReadGbvm(vHi * 256 + vLo, 1);
    2, $81: GetEclVar := LongInt(EclMenu.CombineBytesToWord(vLo, vHi));
    3, $80: GetEclVar := EclMenu.ReadGbvm(vHi * 256 + vLo, 2);
    4: GetEclVar := LongInt(vLo + vHi * 256)
                           + LongInt(GDVars.eclVarByte2[idx]) * $10000
                           + LongInt(GDVars.eclVarByte3[idx]) * $1000000;
    5: GetEclVar := EclMenu.ReadGbvm(vHi * 256 + vLo, 4);
  end;
end;

procedure EclInit;
var
  { Unused in this version; see the other implementations of this routine. }
  scriptId: Byte;
  i: Word;
begin
  GDVars.picturePending := False;
  GDVars.protectionTextShown := 0;
  GDVars.refreshCharacterA := 0;
  GDVars.refreshCharacterB := 0;
  GDVars.floorColorCode := 65;
  GDVars.horizonColorCode := 9;
  GDVars.viewColorsChanged := 1;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.nextCreatureIconSlot := C_Combat.FIRST_CREATURE_ICON_SLOT;
  GDVars.eclIp := $8000;
  GDVars.frameScriptDone := False;
  GDVars.eclStack := nil;
  GDVars.eclStackPrevious := nil;
  FillChar(GDVars.compareFlags, SizeOf(GDVars.compareFlags), 0);
  GDVars.zone1^.restSafeTime := 0;
  GDVars.zone1^.restInterruptChance := 0;
  GDVars.zone0^.antimagic := 0;
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints[1] := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints[2] := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints[3] := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints[4] := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints[5] := EclMenu.CombineBytesToWord(GDVars.eclVarLow[1], GDVars.eclVarHigh[1]);
  if GDVars.hasLoadedSave = 0 then begin
    for i := 1 to SizeOf(GDVars.zone0^.entryBytes) do
      GDVars.zone0^.entryBytes[i + $4BFF] := 0;
    for i := 0 to SizeOf(GDVars.zone1^.newGameBytes) - 1 do
      GDVars.zone1^.newGameBytes[i + $7F79] := 0;
  end;
end;

function LoadEclScript(scriptId: Byte): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  headerSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  recordCount: Word;
  dataSetDigit: String[1];
  sizeRead: Word;
  data: Types.PByteArr;
  { never set True, so the loop ends only on a big enough block }
  isStopped: Boolean;
begin
  isStopped := False;
  repeat
    TextRend.DisplayLoading;
    Str(GDVars.dataSet, dataSetDigit);
    DaxIo.LoadDax('ECL' + dataSetDigit, '.dax', scriptId, sizeRead, data);
  until (sizeRead >= SizeOf(TEclRecord) - SizeOf(Types.TZone3)) or isStopped;
  FillChar(GDVars.zone3^, SizeOf(Types.TZone3), 0);
  Move(data^[SizeOf(TEclRecord) - SizeOf(Types.TZone3)], GDVars.zone3^,
       sizeRead - (SizeOf(TEclRecord) - SizeOf(Types.TZone3)));
  FreeMem(data, sizeRead);
  TextRend.ClearStatusLine;
  LoadEclScript := True;
end;

procedure InitCreature(id: Byte; var character: Types.PCharRecord; var items: Types.PItemRec;
                       var effects: Types.PEffectRec);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
begin
  character := nil;
  GetMem(character, SizeOf(Types.TCharRecord));
  FillChar(character^, SizeOf(Types.TCharRecord), 0);
  SaveLoad.LoadCreatureData('MON', id, character);
  items := character^.itemsAddr;
  effects := character^.effectsAddr;
end;

function MaxMonsterDist(x, y, facing: Byte): Byte;
var
  isBlocked: Boolean;
  dist: Byte;
begin
  dist := 0;
  isBlocked := False;
  if GDVars.zone0^.areaType = 0 then begin
    dist := 2;
    GDVars.zone1^.monsterDistance := 2;
  end else
    while (dist < 5) and (not isBlocked) do begin
      if View3D.GetWallType(x, y, facing) = 0 then begin
        Inc(dist);
        case facing of
          C_Dir.NORTH: Dec(y);
          C_Dir.EAST: Inc(x);
          C_Dir.SOUTH: Inc(y);
          C_Dir.WEST: Dec(x);
        end;
      end else
        isBlocked := True;
    end;
  MaxMonsterDist := dist;
end;

procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);
var
  { Unused in this version; see the other implementations of this routine. }
  headPic: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  bodyPic: Pointer;
  spriteDistance: Byte;
begin
  spriteDistance := dist + 1;
  if picId = C_Pic.NO_ANIMATION then
    flags[1] := False;
  if not flags[1] then begin
    if not flags[0] then begin
      if GDVars.automapOn <> 0 then begin
        GDVars.automapOn := 0;
        GDVars.portraitPending := 1;
        MapView.DisplayMapView;
      end;
      if GDVars.zone0^.areaType <> 0 then begin
        Portrait.LoadAnimation('SPRIT', sprId, 1);
        flags[0] := True;
        GDVars.monsterSpriteShown := 1;
      end;
    end else begin
      GDVars.portraitPending := 1;
      MapView.DisplayMapView;
    end;
    if GDVars.interfaceState = C_Ifc.VIEW_3D then
      Portrait.Show3DSprite(spriteDistance);
  end;
  if (not flags[1]) and (dist = 0) and (GDVars.interfaceState = C_Ifc.VIEW_3D) and
      (picId <> C_Pic.NO_ANIMATION) and ((GDVars.inEncounterMenu = 0) or (GDVars.monsterPictures <> 0)) then begin
    GDVars.picturePending := True;
    Portrait.LoadAnimation('PIC', picId, 0);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, 0);
    GDVars.viewPaletteStale := 1;
  end;
end;

function CombineBytesToWord(lowByte, highByte: Byte): Word;
begin
  CombineBytesToWord := highByte * 256 + lowByte;
end;

function DecodeGameCharacter(c: Byte): Char;
begin
  if c > 31 then
    DecodeGameCharacter := Chr(c)
  else
    DecodeGameCharacter := Chr(c + 64);
end;

function GbvmZone(address: Word): Byte;
begin
  GbvmZone := 4;
  if (address >= EclMenu.GBVM_ZONE_0_FIRST) and (address <= EclMenu.GBVM_ZONE_0_LAST) then GbvmZone := 0;
  if (address >= EclMenu.GBVM_ZONE_1_FIRST) and (address <= EclMenu.GBVM_ZONE_1_LAST) then GbvmZone := 1;
  if (address >= EclMenu.GBVM_ZONE_2_FIRST) and (address <= EclMenu.GBVM_ZONE_2_LAST) then GbvmZone := 2;
  if (address >= EclMenu.GBVM_ZONE_3_FIRST) and (address <= EclMenu.GBVM_ZONE_3_LAST) then GbvmZone := 3;
end;

function SpecialReadZ1(address: Word; width: Byte; var isHandled: Boolean): LongInt;
var
  buf: array[0..$B9] of Byte;
  p: Types.PCharRecord;
  value: LongInt;
begin
  isHandled := True;
  address := address - C_Gbvm.CURRENT_CHARACTER;
  value := 0;
  case address of
    $000..$00F:
      Move(GDVars.currentCharacter^.raw[address + 1], value, width);
    $010..$0B9: begin
      Move(GDVars.currentCharacter^.raw[0], buf, SizeOf(buf));
      Move(buf[address], value, width);
      if (address = $4C) and (value > 0) then
        value := $80;
    end;
    $0C4..$0CD:
      Move(GDVars.currentCharacter^.weaponSpecializations[address - $C3], value, width);
    $100:
      if GDVars.selectFailed <> 0 then
        value := 0
      else
        value := GDVars.currentCharacter^.status;
    $10C: begin
      value := 0;
      Inc(value, GDVars.currentCharacter^.hostile);
      if GDVars.currentCharacter^.skillLevels[0] <> 0 then
        Inc(value, $40);
      if GDVars.currentCharacter^.quickfight <> 0 then
        Inc(value, $80);
    end;
    $10E: value := GDVars.currentCharacter^.attackBonus;
    $10F..$110: value := GDVars.currentCharacter^.armorClass[ShortInt(address - $10F)];
    $119: value := GDVars.currentCharacter^.hpCur;
    $11B: value := GDVars.currentCharacter^.currentMovement;
    $2B1: begin
      value := 0;
      p := GDVars.partyHead;
      while (p <> nil) and (p <> GDVars.currentCharacter) do begin
        p := p^.nextCharAddr;
        Inc(value);
      end;
    end;
    EclMenu.GBVM_DATA_SET - C_Gbvm.CURRENT_CHARACTER: value := GDVars.dataSet;
  else
    isHandled := False;
  end;
  SpecialReadZ1 := value;
end;

procedure SpecialWriteZ1(address: Word; value: LongInt; width: Byte);
var
  statusByte: Byte;
  field: Pointer;
  fieldAddress: Pointer;
begin
  address := address - C_Gbvm.CURRENT_CHARACTER;
  case address of
    0:
      if value = 0 then GDVars.refreshCharacterB := 1;
    $10..$B9: begin
      fieldAddress := Pointer(LongInt(GDVars.currentCharacter) + address);
      field := fieldAddress;
      Move(value, field^, width);
    end;
    $100: begin
      statusByte := Byte(value) and $7F;
      GDVars.currentCharacter^.status := statusByte;
      if GDVars.currentCharacter^.status = C_Status.OKAY then
        GDVars.currentCharacter^.enabled := 1
      else
        GDVars.currentCharacter^.enabled := 0;
      CharHlp.DisplayRoster(GDVars.currentCharacter, False);
    end;
    $10C: begin
      GDVars.currentCharacter^.hostile := value and $01;
      GDVars.currentCharacter^.skillLevels[0] := value and $40;
      GDVars.currentCharacter^.quickfight := value and $80;
      if GDVars.currentCharacter^.hostile = C_Side.HOSTILE then GDVars.partyChanged := 1;
    end;
    $10E: GDVars.currentCharacter^.attackBonus := value;
    $119: GDVars.currentCharacter^.hitPoints := value;
    $11B: GDVars.currentCharacter^.currentMovement := value;
    EclMenu.GBVM_DATA_SET - C_Gbvm.CURRENT_CHARACTER: DaxIo.PushState(value);
  end;
end;

procedure WriteGbvm(address: Word; value: LongInt; gbType: Byte);
var
  zone: Byte;
  isInRange: Boolean;
  width: Byte;
begin
  case gbType of
    0, 1: width := 1;
    2, 3: width := 2;
    4, 5: width := 4;
  end;
  zone := EclMenu.GbvmZone(address);
  case zone of
    0: begin
      case address - EclMenu.GBVM_ZONE_0_FIRST of
        EclMenu.GBVM_SKY_INDEX_LO - EclMenu.GBVM_ZONE_0_FIRST,
            EclMenu.GBVM_SKY_INDEX_HI - EclMenu.GBVM_ZONE_0_FIRST: GDVars.redrawSky := True;
        EclMenu.GBVM_AREA_TYPE - EclMenu.GBVM_ZONE_0_FIRST:
          if GDVars.zone0^.areaType <> value then begin
            GDVars.previousInterfaceState := GDVars.interfaceState;
            if Byte(value) in [C_Area.VENUS_WILDERNESS, C_Area.MARS_WILDERNESS] then
              GDVars.interfaceState := C_Ifc.WILDERNESS
            else if value = C_Area.ORBIT then
              GDVars.interfaceState := C_Ifc.ORBIT_MAP
            else
              GDVars.interfaceState := C_Ifc.VIEW_3D;
          end;
      end;
      Move(value, GDVars.zone0^.cells[address], width);
    end;
    1: begin
      Move(value, GDVars.zone1^.cells[address], width);
      EclMenu.SpecialWriteZ1(address, value, width);
    end;
    2:
      Move(value, GDVars.zone2^[address], width);
    3:
      Move(value, GDVars.zone3^[address], width);
    4:
      if address > EclMenu.GBVM_ZONE_4_WRITE_BASE then begin
        address := address - EclMenu.GBVM_ZONE_4_WRITE_BASE;
        case address of
          EclMenu.GBVM_PARTY_X - EclMenu.GBVM_ZONE_4_WRITE_BASE: begin
            GDVars.partyMoved := True;
            GDVars.partyPosition.mapX := value;
          end;
          EclMenu.GBVM_PARTY_Y - EclMenu.GBVM_ZONE_4_WRITE_BASE: begin
            GDVars.partyPosition.mapY := value;
            GDVars.partyMoved := True;
          end;
          { taken mod 4 }
          EclMenu.GBVM_FACING - EclMenu.GBVM_ZONE_4_WRITE_BASE: begin
            repeat
              isInRange := True;
              case value of
                0: GDVars.partyPosition.facing := C_Dir.NORTH;
                1: GDVars.partyPosition.facing := C_Dir.EAST;
                2: GDVars.partyPosition.facing := C_Dir.SOUTH;
                3: GDVars.partyPosition.facing := C_Dir.WEST;
              else begin
                isInRange := False;
                Dec(value, 4);
              end;
              end;
            until isInRange = True;
            GDVars.partyMoved := True;
          end;
          EclMenu.GBVM_FLOOR_COLOR - EclMenu.GBVM_ZONE_4_WRITE_BASE: begin
            GDVars.floorColorCode := value;
            GDVars.viewColorsChanged := 1;
          end;
          EclMenu.GBVM_HORIZON_COLOR - EclMenu.GBVM_ZONE_4_WRITE_BASE: begin
            GDVars.horizonColorCode := value;
            GDVars.viewColorsChanged := 1;
          end;
        end;
      end;
  end;
end;

function ReadGbvm(address: Word; gbType: Byte): LongInt;
var
  zone: Byte;
  isHandled: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  byteValue: Byte;
  value: LongInt;
  width: Byte;
begin
  case gbType of
    0, 1: width := 1;
    2, 3: width := 2;
    4, 5: width := 4;
  end;
  value := 0;
  zone := EclMenu.GbvmZone(address);
  isHandled := False;
  case zone of
    0: begin
      if address = EclMenu.GBVM_ZONE_0_FACING then
        value := GDVars.partyPosition.facing
      else
        Move(GDVars.zone0^.cells[address], value, width);
    end;
    1: begin
      value := EclMenu.SpecialReadZ1(address, width, isHandled);
      if not isHandled then begin
        value := 0;
        Move(GDVars.zone1^.cells[address], value, width);
      end;
    end;
    2: Move(GDVars.zone2^[address], value, width);
    3: Move(GDVars.zone3^[address], value, width);
    4:
      if address < EclMenu.GBVM_PARTY_X then begin
        if address = EclMenu.GBVM_STORED_FACING then value := GDVars.partyPosition.facing
      end else begin
        address := address - EclMenu.GBVM_PARTY_X;
        case address of
          0: value := GDVars.partyPosition.mapX;
          EclMenu.GBVM_PARTY_Y - EclMenu.GBVM_PARTY_X: value := GDVars.partyPosition.mapY;
          EclMenu.GBVM_FACING - EclMenu.GBVM_PARTY_X:
            if GDVars.zone0^.areaType and $20 <> 0 then
              value := GDVars.partyPosition.facing
            else
              value := Integer(GDVars.partyPosition.facing) shr 1;
          EclMenu.GBVM_WALL_AHEAD - EclMenu.GBVM_PARTY_X: value := GDVars.partyPosition.wallAhead;
          EclMenu.GBVM_MAP_EVENT - EclMenu.GBVM_PARTY_X: value := GDVars.partyPosition.mapEvent;
        end;
      end;
  end;
  ReadGbvm := value;
end;

procedure WriteGbvmString(address: Word; s: String);
var
  zone: ShortInt;
  len: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(address);
  len := Length(s);
  case zone of
    0: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.zone0^.cells[address + i] := Ord(s[i + 1]);
      GDVars.zone0^.cells[address + len] := 0;
    end;
    1:
      if address = C_Gbvm.CURRENT_CHARACTER then
        GDVars.currentCharacter^.name := s
      else begin
        if len > 0 then
          for i := 0 to len - 1 do
            GDVars.zone1^.cells[address + i] := Ord(s[i + 1]);
        GDVars.zone1^.cells[address + len] := 0;
      end;
    2: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.zone2^[address + i] := Ord(s[i + 1]);
      GDVars.zone2^[address + len] := 0;
    end;
    3: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.zone3^[address + i] := Ord(s[i + 1]);
      GDVars.zone3^[address + len] := 0;
    end;
  end;
end;

procedure ConvGbString(len, strIdx: Byte);
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outPos: Byte;
  cur: Byte;
  prev: Byte;
  { the 6-bit character code }
  code: Byte;
  phase: Byte;
  ch: Char;
begin
  GDVars.eclStrings[strIdx] := '';
  i := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GDVars.eclIp);
      prev := cur;
      cur := GDVars.zone3^[GDVars.eclIp];
      Inc(i);
    end;
    case phase of
      1:
        code := cur shr 2;
      2: begin
        code := prev shl 6 + cur shr 2;
        code := code shr 2;
      end;
      3: begin
        code := prev shl 4 + cur shr 4;
        code := code shr 2;
      end;
      4:
        code := cur and $3F;
    end;
    if phase < 4 then Inc(phase) else phase := 1;
    if code <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(code);
      GDVars.eclStrings[strIdx] := Concat(GDVars.eclStrings[strIdx], ch);
    end;
  end;
  if phase = 4 then begin
    code := cur and $3F;
    if code <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(code);
      GDVars.eclStrings[strIdx] := Concat(GDVars.eclStrings[strIdx], ch);
    end;
  end;
end;

procedure DerefGbString(strIdx: Byte; address: Word);
var
  zone: ShortInt;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(address);
  GDVars.eclStrings[strIdx] := '';
  i := 0;
  case zone of
    0:
      while GDVars.zone0^.cells[address + i] <> 0 do begin
        GDVars.eclStrings[strIdx] := Concat(GDVars.eclStrings[strIdx], Char(GDVars.zone0^.cells[address + i]));
        Inc(i);
      end;
    1:
      if address = C_Gbvm.CURRENT_CHARACTER then
        GDVars.eclStrings[strIdx] := GDVars.currentCharacter^.name
      else
        while GDVars.zone1^.cells[address + i] <> 0 do begin
          GDVars.eclStrings[strIdx] := Concat(GDVars.eclStrings[strIdx], Char(GDVars.zone1^.cells[address + i]));
          Inc(i);
        end;
    2:
      while GDVars.zone2^[address + i] <> 0 do begin
        GDVars.eclStrings[strIdx] := Concat(GDVars.eclStrings[strIdx], Char(GDVars.zone2^[address + i]));
        Inc(i);
      end;
    3:
      while GDVars.zone3^[address + i] <> 0 do begin
        GDVars.eclStrings[strIdx] := Concat(GDVars.eclStrings[strIdx], Char(GDVars.zone3^[address + i]));
        Inc(i);
      end;
  end;
end;

{ Lowercases menu, strips the '~'s and collects the letters they marked, uppercased, into opts. Note: digits are shifted
  by 32 too, so an unmarked '0'..'9' in the menu text becomes 'P'..'Y'.
  @param(menu The menu text, rewritten in place.)
  @param(opts Receives the option letters.) }
procedure MenuToOptions(var menu: String; var opts: Types.TString40);
var
  i: Byte;
begin
  opts := '';
  for i := 1 to Length(menu) do begin
    if menu[i] in ['0'..'9', 'A'..'Z'] then
      menu[i] := Chr(Ord(menu[i]) + 32);
    if menu[i] = '~' then begin
      Delete(menu, i, 1);
      menu[i] := UpCase(menu[i]);
      opts := opts + menu[i];
    end;
  end;
end;

function MenuHorizontalCharacterSelect(query: Types.TString40; menu: String; acceptsEnter, isAnimated: Boolean): Byte;
var
  opts: Types.TString40;
  idx: Byte;
  ch: Char;
begin
  EclMenu.MenuToOptions(menu, opts);
  repeat
    MenuCore.MenuHorizontal(query, menu, True, isAnimated);
    ch := GDVars.menuKey;
    if GDVars.extFlag then ch := C_Keys.NONE;
  until (ch in ['0'..'9', 'A'..'Z']) or
      (acceptsEnter and (ch in [C_Keys.NONE, C_Keys.ENTER]) and not GDVars.extFlag);
  case ch of
    C_Keys.ENTER: MenuHorizontalCharacterSelect := 0;
  else begin
    idx := 1;
    while (idx <= Length(opts)) and (opts[idx] <> ch) do
      Inc(idx);
    if idx <= Length(opts) then
      MenuHorizontalCharacterSelect := idx - 1
    else
      MenuHorizontalCharacterSelect := 255;
  end;
  end;
end;

procedure EclVerticalMenu(query: Types.TString40; menu: String; ulCol, ulRow, lrCol, lrRow: ShortInt;
                          list: Types.PItemRec; offersExit: Boolean; var needsRedraw: Boolean; var idx: Integer;
                          var sel: Types.PItemRec);
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  opts: Types.TString40;
begin
  EclMenu.MenuToOptions(menu, opts);
  ch := MenuCore.MenuVertical(query, 'Select', ulCol, ulRow, lrCol, lrRow, Types.PMenuNode(list), offersExit,
                              needsRedraw, idx, Types.PMenuNode(sel));
end;

procedure EclCompareStr(leftOperand, rightOperand: String);
begin
  FillChar(GDVars.compareFlags, SizeOf(GDVars.compareFlags), 0);
  if leftOperand = rightOperand then GDVars.compareFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.compareFlags[1] := True;
  if leftOperand < rightOperand then GDVars.compareFlags[2] := True;
  if leftOperand > rightOperand then GDVars.compareFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.compareFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.compareFlags[5] := True;
end;

procedure EclCompareInt(leftOperand, rightOperand: LongInt);
begin
  FillChar(GDVars.compareFlags, SizeOf(GDVars.compareFlags), 0);
  if leftOperand = rightOperand then GDVars.compareFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.compareFlags[1] := True;
  if leftOperand < rightOperand then GDVars.compareFlags[2] := True;
  if leftOperand > rightOperand then GDVars.compareFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.compareFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.compareFlags[5] := True;
end;

procedure EclGosub(varIdx: Byte);
begin
  if GDVars.eclStack = nil then begin
    GetMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack^.next := nil;
  end else begin
    GDVars.eclStackPrevious := GDVars.eclStack;
    GetMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack^.next := GDVars.eclStackPrevious;
  end;
  GDVars.eclStack^.addr := GDVars.eclIp;
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.eclVarLow[varIdx], GDVars.eclVarHigh[varIdx]);
end;

procedure EclMoveForward;
begin
  case GDVars.partyPosition.facing of
    C_Dir.NORTH:
      if GDVars.partyPosition.mapY > 0 then Dec(GDVars.partyPosition.mapY)
      else GDVars.partyPosition.mapY := SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
    C_Dir.EAST:
      if GDVars.partyPosition.mapX < SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then Inc(GDVars.partyPosition.mapX)
      else GDVars.partyPosition.mapX := 0;
    C_Dir.SOUTH:
      if GDVars.partyPosition.mapY <
          SizeOf(GDVars.geoMap^.wallsNE) div SizeOf(GDVars.geoMap^.wallsNE[0]) - 1 then
        Inc(GDVars.partyPosition.mapY)
      else GDVars.partyPosition.mapY := 0;
    C_Dir.WEST:
      if GDVars.partyPosition.mapX > 0 then Dec(GDVars.partyPosition.mapX)
      else GDVars.partyPosition.mapX := SizeOf(GDVars.geoMap^.wallsNE[0]) - 1;
  end;
  GDVars.partyPosition.mapEvent := View3D.GetMapEvent(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY);
  GDVars.partyPosition.wallAhead := View3D.GetWallType(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                                         GDVars.partyPosition.facing);
  GDVars.partyMoved := True;
end;

procedure RobMoney(fraction: Real; character: Types.PCharRecord);
begin
  character^.credits := Trunc(character^.credits * fraction);
end;

procedure RobItems(chance: Byte; character: Types.PCharRecord);
var
  roll: Byte;
  item: Types.PItemRec;
  nextItem: Types.PItemRec;
  { ToggleReadyItem's answer; unused }
  hasEndedTurn: Boolean;
begin
  item := character^.itemsAddr;
  while item <> nil do begin
    if item^.template.weight > 255 then begin
      if chance > 90 then
        chance := chance - 90
      else
        chance := 0;
    end else if item^.template.weight > 24 then begin
      if chance > 50 then
        chance := chance - 50
      else
        chance := 0;
    end;
    roll := CharHlp.RollDice(1, 100);
    nextItem := item^.next;
    if roll <= chance then begin
      if item^.template.flags and C_Item.READIED <> 0 then
        ViewChar.ToggleReadyItem(item, hasEndedTurn);
      CharHlp.RemoveItem(character, item);
    end;
    item := nextItem;
  end;
end;

procedure SkipEclCmd;
begin
  GDVars.currentOpcode := GDVars.zone3^[GDVars.eclIp];
  case GDVars.currentOpcode of
    1, 2, $A, $E, $11, $12, $20, $2D, $32, $34, $36, $38, $39,
    $3C, $43, $48, $4B:
      EclMenu.LoadEclVars(1);
    3, 8, 9, $F, $10, $1F, $41, $40, $1D, $3F, $45, $46, $4C:
      EclMenu.LoadEclVars(2);
    4..7, $B, $C, $21, $28, $2A, $2F, $30, $35, $37, $3B, $22, $23:
      EclMenu.LoadEclVars(3);
    $14:
      EclMenu.LoadEclVars(4);
    $2E:
      EclMenu.LoadEclVars(5);
    $1E, $49:
      EclMenu.LoadEclVars(6);
  else
    Inc(GDVars.eclIp);
  end;
end;

procedure EclInflictDamage(dmg: Word; character: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  msg: String;
  dmgStr: String[3];
  clearsFirst: Boolean;
begin
  if character^.status <> C_Status.OKAY then Exit;
  clearsFirst := False;
  Str(LongInt(dmg), dmgStr);
  if character^.hitPoints + 10 < dmg then
    msg := '  ' + character^.name + ' dies. '
  else
    msg := '  ' + character^.name + ' is hit FOR ' + dmgStr + ' points of Damage.';
  if GDVars.cursorRow > GDVars.windowBottom then begin
    GDVars.cursorRow := GDVars.windowTop;
    clearsFirst := True;
    TextRend.DisplayAndPause(White, Black, GDConsts.continuePrompt);
  end else
    clearsFirst := False;
  GDVars.cursorColumn := 38;
  TextRend.DisplayMessageWindow(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                                White, Black, clearsFirst, msg);
  CharHlp.InflictDamage(character, dmg);
  if (GDVars.interfaceState <> C_Ifc.WILDERNESS) and (GDVars.interfaceState <> C_Ifc.ORBIT_MAP) then begin
    TextRend.ClearRect(17, 1, 38, 15);
    MenuCore.DisplayParty(GDVars.currentCharacter);
  end;
end;

procedure LoadItemTemplates;
var
  sizeRead: Word;
  offset: Word;
  idx: Byte;
  data: Types.PByteArr;
  template: Types.TItemTemplate;
begin
  FillChar(GDVars.itemTemplates, SizeOf(GDVars.itemTemplates), C_Item.EMPTY_TEMPLATE);
  DaxIo.LoadDax('ITEM0', '.dax', 1, sizeRead, data);
  if sizeRead = 0 then begin
    TextRend.DisplayAndPause(White, Black, 'Unable to find item file');
    GameIo.ExitGame;
  end;
  offset := 0;
  idx := 1;
  repeat
    Move(data^[offset], template, SizeOf(template));
    GDVars.itemTemplates[idx] := template;
    Inc(idx);
    Inc(offset, SizeOf(template));
  until (offset >= sizeRead) or (idx > 127);
  FreeMem(data, sizeRead);
end;

procedure UpdateEclDisplay;
begin
  GDVars.partyPosition.mapEvent := View3D.GetMapEvent(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY);
  if GDVars.picturePending or (GDVars.monsterSpriteShown <> 0) or (GDVars.viewColorsChanged <> 0) or
      GDVars.partyMoved or GDVars.redrawSky then begin
    FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
    GDVars.portraitPending := 1;
    MapView.DisplayMapView;
    CharHlp.PrintMiscInfo;
    GDVars.redrawSky := False;
    GDVars.viewColorsChanged := 0;
    GDVars.partyMoved := False;
    GDVars.picturePending := False;
    GDVars.monsterSpriteShown := 0;
    GDVars.partyPosition.wallAhead := View3D.GetWallType(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY,
                                                           GDVars.partyPosition.facing);
  end;
end;

begin
end.
