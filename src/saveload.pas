{ Saving and loading. Characters are saved as <name>.who with their item lists (.stf, and .hid for the second list) and
  effects (.sfx); a saved game is savgam<slot>.dat, slots A..J, with its characters in CHRDAT<slot><n>.sav files. A .dat
  holds, in order: dataSet, zones 0 to 2, GDVars' partyPosition, the previous and current interfaceState, wall set 0's
  fileId and slot, the character count and eight character file names. Characters and saved games can also be read from
  the Doomsday save path (importFormat 0), whose .dat is read only from its character count on. Creatures load from
  MON0CHA.DAX, MON0SPC.DAX and MON0ITM.DAX, and ships from SHIPS. CharGen's character menus call most of it; EclVm and
  EclMenu add and load creatures, GameInit and ShipCbt load ships, and HeapErr and Explore also call SaveGame. Note:
  with I/O checking off ($I-) the file routines report to IOResult, which goes unchecked. The error tests read
  Dos.DosError, which only the Dos unit's own routines set (here FindFirst and FindNext, also through
  DaxIo.GetVolumeLabel), so after Reset, Rewrite or MkDir they see the last lookup's result. }
{$O+,F+,I-}
unit SaveLoad;

interface

uses Types, C_Menu, C_Npc, C_Pic, GDConsts, GDVars, MenuCore, Dos, DaxIo, Blit,
  TextRend, MapTiles, GameIo, CharHlp, View3D, Portrait, C_Ifc, C_Area, C_Keys, C_Combat, C_Map;

type
  { a file name without its extension, as SanitizeFileName cuts one to eight characters }
  TFileStem = String[8];

{ Lists the saved characters (.who files) in the save path importFormat selects that are not in the party and whose
  weaponSpecializations[9] byte is below 128.
  @param(list The names, padded to 15 characters, as menu lines.)
  @param(files The matching file names, in the same order.) }
procedure LoadCharlist(var list, files: Types.PMenuNode);

{ Loads the current character's icon from CHARS as icon animation orderNumber.
  @param(isLoading Unused.) }
procedure LoadCharIconAnim(isLoading: Boolean);

{ Deletes a character's .who, .stf, .hid and .sfx files from the save path.
  @param(character The character whose files go.) }
procedure DeleteCharacterFiles(character: Types.PCharRecord);

{ Writes a character and its item and effect lists to the save path. Rename at the overwrite prompt also renames the
  character. Note: when the disk lacks room it says so and shows a Lose character? menu, but saves anyway, since the
  answer is not read; and the room check counts one item list (itemsAddr, else alternateItemsAddr) though both are
  written.
  @param(character The character saved.)
  @param(fileStem Empty to save as <name>.who, asking before an overwrite; otherwise the stem of a saved game's .sav
    file.)
  @returns(False when the save was abandoned.) }
function SaveChar(character: Types.PCharRecord; fileStem: TFileStem): Boolean;

{ Reads a character from the save path importFormat selects, with its effects (.sfx) and items: .stf into itemsAddr, or,
  only when there is no .stf, .hid into alternateItemsAddr.
  @param(name The character's file name, extension included.)
  @param(character Receives the character.)
  @param(isFromSavedGame Unused; True from LoadGame, False from CharGen's AddCharacterMenu.)
  @param(usesSaveDiskPrompt True to ask for the save disk when a file is missing, False to ask for the data set's disk;
    both callers pass True.) }
procedure LoadChar(name: String; character: Types.PCharRecord; isFromSavedGame, usesSaveDiskPrompt: Boolean);

{ Loads a creature from <prefix>0CHA.DAX, with its effects from <prefix>0SPC and its items from <prefix>0ITM; a missing
  CHA record ends the game.
  @param(prefix The archives' name prefix.)
  @param(id The creature's record.)
  @param(character Receives the creature.) }
procedure LoadCreatureData(prefix: String; id: Byte; character: Types.PCharRecord);

{ Adds a MON creature to the party, unless it already holds eight, and loads its icon: the CPIC record of the same id,
  or in the demo its CHARS icon, which it sets for ids 106..108.
  @param(id The creature's record.) }
procedure AddCreatureToParty(id: Byte);

{ Asks whether to load from this game's saves or Doomsday's, then loads the saved game in a slot the player picks,
  deletes each member's single-character files (DeleteCharacterFiles) and, for one of this game's saves, leaves the game
  in the main menu. }
procedure LoadGame;

{ Saves the game to a slot the player picks, unless the disk lacks room, deletes each member's single-character files
  (DeleteCharacterFiles) and sets GDVars' gameSaved. }
procedure SaveGame;

{ Appends a character to the party, makes it current, gives it the lowest free order number, and counts it into zone 1's
  party count.
  @param(character The character added.) }
procedure AddCharToParty(character: Types.PCharRecord);

{ Loads a ship's record from SHIPS and names it; for the enemy ship it also loads the 'ships' picture numbered by the
  type mod 5 as the big picture and sets DAC $40..$FF from it.
  @param(ship Receives the ship.)
  @param(id The ship type: 0 to 4 take a numbered name from the ship-name table, above 4 is the Maelstrom Rider.) }
procedure LoadShipData(ship: Types.PShipRec; id: ShortInt);

implementation

type
  { a character's file name with or without its extension, and the character file-name field of a saved game's .dat }
  TFileName40 = String[40];
  { A saved game's .dat up to its wall set, as SaveGame writes it and LoadGame reads it. }
  TDatHeader = record
    dataSet: Byte;
    zone0: Types.TZone0;
    zone1: Types.TZone1;
    zone2: Types.TZone2;
    partyPosition: Types.TPartyPosition;
    previousInterfaceState: Byte;
    interfaceState: Byte
  end;

const
  { zone 0's cells counting the ships named so far, by ship type }
  GBVM_SHIP_NAME_COUNTS = $4D91;
  { the SHIPS record of ship type 0; type n is record 40 + n }
  FIRST_SHIP_RECORD = 40;
  { the big picture LoadGame asks for in VENUS_WILDERNESS }
  VENUS_WILDERNESS_PIC = 72;
  { and in MARS_WILDERNESS }
  MARS_WILDERNESS_PIC = 71;

function CheckSaveDir: Boolean; forward;

procedure LoadCharlist(var list, files: Types.PMenuNode);

  { Lists the names and file names of the saved characters pattern matches that are not already in the party. }
  procedure ScanSaveFiles(pattern: Types.TString80; nameOffset, exclusionOffset, recordSize: Word; var nameList,
                          fileList: Types.PMenuNode);
  var
    nameNode: Types.PMenuNode;
    nameTail: Types.PMenuNode;
    fileNode: Types.PMenuNode;
    fileTail: Types.PMenuNode;
    characterCursor: Types.PCharRecord;
    searchResult: SearchRec;
    bytesRead: Word;
    f: file;
    sourceSuffix: String[80];
    { a value above 127 leaves the file out }
    exclusionByte: Byte;
    { Unused in this version; see the other implementations of this routine. }
    matchCount: array[1..17] of Byte;
  begin
    nameNode := nil;
    fileNode := nil;
    FindFirst(pattern, 0, searchResult);
    while DosError = 0 do begin
      if GDVars.importFormat = 1 then
        Assign(f, GDVars.savePath + searchResult.Name)
      else
        Assign(f, GDVars.doomsdaySavePath + searchResult.Name);
      Reset(f, 1);
      if FileSize(f) = recordSize then begin
        GetMem(nameNode, SizeOf(Types.TMenuNode));
        GetMem(fileNode, SizeOf(Types.TMenuNode));
        FillChar(nameNode^, SizeOf(Types.TMenuNode), 0);
        FillChar(fileNode^, SizeOf(Types.TMenuNode), 0);
        Seek(f, nameOffset);
        BlockRead(f, nameNode^, SizeOf(characterCursor^.name), bytesRead);
        Seek(f, exclusionOffset);
        BlockRead(f, exclusionByte, SizeOf(exclusionByte));
        fileNode^.name := searchResult.Name;
        { never true: the pattern matches only .who files }
        if Copy(searchResult.Name, 9, 4) = '.SAV' then
          sourceSuffix := 'from saved game ' + searchResult.Name[7]
        else
          sourceSuffix := '';
        nameNode^.name := nameNode^.name + Copy(GDConsts.nameBlanks, 1, 15 - Length(nameNode^.name)) + sourceSuffix;
        characterCursor := GDVars.partyHead;
        while (characterCursor <> nil) and
            (Copy(nameNode^.name, 1, 15) <> characterCursor^.name + Copy(GDConsts.nameBlanks, 1,
                                                                         15 - Length(characterCursor^.name))) do
          characterCursor := characterCursor^.nextCharAddr;
        if (exclusionByte > 127) or (characterCursor <> nil) then begin
          FreeMem(nameNode, SizeOf(Types.TMenuNode));
          FreeMem(fileNode, SizeOf(Types.TMenuNode));
          nameNode := nil;
          fileNode := nil;
        end;
        if nameNode <> nil then
          if nameList = nil then begin
            nameList := nameNode;
            nameTail := nameList;
            fileList := fileNode;
            fileTail := fileList;
          end else begin
            nameTail^.next := nameNode;
            nameTail := nameTail^.next;
            fileTail^.next := fileNode;
            fileTail := fileTail^.next;
          end;
      end;
      Close(f);
      FindNext(searchResult);
    end;
  end;

begin
  list := nil;
  files := nil;
  if not SaveLoad.CheckSaveDir then Exit;
  { byte $C2 of a character is weaponSpecializations[9] }
  case GDVars.importFormat of
    1: ScanSaveFiles(GDVars.savePath + '*.who', 0, $C2, SizeOf(Types.TCharRecord), list, files);
    0: ScanSaveFiles(GDVars.doomsdaySavePath + '*.who', 0, $C2, SizeOf(Types.TCharRecord), list, files);
  end;
end;

{ Checks the save path importFormat selects. While its drive is A or B and holds the volume labeled BUCK, asks for the
  save disk. Then looks up the directory with FindFirst, repeating the lookup until it can decide. After a lookup error
  of 2 or 18 it calls MkDir (on drive A or B after asking whether the save disk is in) and looks up again. After any
  other lookup error on drive A or B it shows the save-disk prompt. Note: the DosError tested after MkDir is still the
  lookup's, so MkDir's outcome never decides the result.
  @returns(True when a lookup ends with DOS error 0 or 5; False when one on drive C or later ends with an error other
    than 0, 2, 5 and 18.) }
function CheckSaveDir: Boolean;
var
  lastDosError: Integer;
  searchResult: SearchRec;
  choice: Char;
  path: String;
begin
  CheckSaveDir := False;
  if GDVars.importFormat = 0 then
    path := GDVars.doomsdaySavePath
  else
    path := GDVars.savePath;
  repeat
      while (DaxIo.GetVolumeLabel(path[1]) = 'BUCK') and (path[1] < 'C') do
        TextRend.DisplayAndPause(14, 0, GDConsts.saveDiskPrompt + path[1] + ':');
      repeat
        FindFirst(Copy(path, 1, Length(path) - 1), Directory, searchResult);
        lastDosError := DosError;
        case lastDosError of
          0: ;
          2, 18:
            begin
              if UpCase(path[1]) < 'C' then begin
                choice := MenuCore.YesNoMenu('Is your save disk in drive ' + path[1] + ':? ', C_Menu.DEFAULT_NO);
                if choice <> 'Y' then
                  TextRend.DisplayAndPause(14, 0, GDConsts.saveDiskPrompt + path[1] + ':');
              end;
              MkDir(Copy(path, 1, Length(path) - 1));
              lastDosError := DosError;
            end;
        else
          if UpCase(path[1]) < 'C' then
            TextRend.DisplayAndPause(14, 0, GDConsts.saveDiskPrompt + path[1] + ':')
          else begin
            TextRend.DisplayAndPause(14, 0, 'Unexpected error during save: ' + TextRend.ByteToString(lastDosError));
            Exit;
          end;
        end;
      until lastDosError in [0, 5];
  until lastDosError in [0, 5];
  CheckSaveDir := True;
end;

procedure LoadCharIconAnim(isLoading: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  fileName: array[1..37] of Byte;
begin
  DaxIo.PushState(1);
  with GDVars.currentCharacter^ do begin
    MapTiles.LoadIconAnim('CHARS', icon, orderNumber);
  end;
  DaxIo.PopState;
  GameIo.FlushKeys;
end;

procedure DeleteCharacterFiles(character: Types.PCharRecord);
var
  fileName: String[80];
  { Unused in this version; see the other implementations of this routine. }
  targetFile: file;
begin
  fileName := GDVars.savePath + DaxIo.SanitizeFileName(character^.name);
  DaxIo.DeleteIfPresent(fileName + GDConsts.alternateItemFileExt);
  DaxIo.DeleteIfPresent(fileName + '.who');
  DaxIo.DeleteIfPresent(fileName + GDConsts.itemFileExt);
  DaxIo.DeleteIfPresent(fileName + GDConsts.effectFileExt);
end;

function SaveChar(character: Types.PCharRecord; fileStem: TFileStem): Boolean;
var
  f: file;
  fileName: TFileName40;
  ext: String[4];
  choice: Char;
  { Unused in this version; see the other implementations of this routine. }
  extIndex: Byte;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  pathText: array[1..24] of Byte;
  { Reset reports to IOResult, not DosError, so this holds the last Dos lookup's error }
  lastDosError: Integer;
  requiredBytes: Word;
begin
  GDVars.importFormat := 1;
  repeat
    if not SaveLoad.CheckSaveDir then begin
      SaveChar := False;
      Exit;
    end;
    requiredBytes := 0;
    Inc(requiredBytes, SizeOf(Types.TCharRecord));
    if character^.itemsAddr <> nil then begin
      item := character^.itemsAddr;
      while item <> nil do begin
        Inc(requiredBytes, SizeOf(Types.TItemRec));
        item := item^.next;
      end;
    end else if character^.alternateItemsAddr <> nil then begin
      item := character^.alternateItemsAddr;
      while item <> nil do begin
        Inc(requiredBytes, SizeOf(Types.TItemRec));
        item := item^.next;
      end;
    end;
    if character^.effectsAddr <> nil then begin
      effect := character^.effectsAddr;
      while effect <> nil do begin
        Inc(requiredBytes, SizeOf(Types.TEffectRec));
        effect := effect^.next;
      end;
    end;
    choice := 'O';
    if requiredBytes > DiskFree(Ord(UpCase(GDVars.savePath[1])) - (Ord('A') - 1)) then begin
      TextRend.DisplayAndPause(14, 0, 'Can''t save.  No room on this disk.');
      MenuCore.MenuHorizontal
        ('Lose character? ', 'Ok  Try another disk', False, False);
    end;
  until choice = 'O';
  if Length(fileStem) = 0 then begin
    ext := '.who';
    fileName := DaxIo.SanitizeFileName(DaxIo.SanitizeString(character^.name, '.'));
  end else begin
    ext := '.sav';
    fileName := fileStem;
  end;
  repeat
    Assign(f, GDVars.savePath + fileName + ext);
    Reset(f, 1);
    lastDosError := DosError;
    if not (lastDosError in [0, 2]) then begin
      if UpCase(GDVars.savePath[1]) < 'C' then
        TextRend.DisplayAndPause(14, 0, GDConsts.saveDiskPrompt + GDVars.savePath[1] + ':')
      else begin
        TextRend.DisplayAndPause(14, 0, 'Unexpected error during save: ' + TextRend.ByteToString(lastDosError));
        Close(f);
        SaveChar := False;
        Exit;
      end;
    end;
  until (lastDosError = 0) or (lastDosError = 2);
  Close(f);
  choice := 'A';
  while (Length(fileStem) = 0) and DaxIo.FileExists(GDVars.savePath + fileName + ext) and (choice <> 'O') and
      (choice <> 'R') do begin
    CharHlp.PrintBottomLine
      (fileName + ' already exists');
    MenuCore.MenuHorizontal
      ('', 'Overwrite Rename Abort save', False, False);
    choice := GDVars.menuKey;
    case choice of
      'R': begin
             fileName := '';
             while Length(fileName) = 0 do
               fileName := TextRend.ReadString('New file name: ', 10, 0, 8);
             character^.name := fileName;
           end;
      'A': begin
             SaveChar := False;
             Exit
           end;
    end;
  end;
  Assign(f, GDVars.savePath + fileName + ext);
  Rewrite(f, 1);
  BlockWrite(f, character^, SizeOf(Types.TCharRecord));
  Close(f);
  DaxIo.DeleteIfPresent(GDVars.savePath + fileName + GDConsts.itemFileExt);
  if character^.itemsAddr <> nil then begin
    if DaxIo.FileExists(GDVars.savePath + fileName + GDConsts.alternateItemFileExt) then
      DaxIo.DeleteIfPresent(GDVars.savePath + fileName + GDConsts.alternateItemFileExt);
    Assign(f, GDVars.savePath + fileName + GDConsts.itemFileExt);
    Rewrite(f, 1);
    item := character^.itemsAddr;
    while item <> nil do begin
      BlockWrite(f, item^, SizeOf(Types.TItemRec));
      item := item^.next;
    end;
    Close(f);
  end else if DaxIo.FileExists(GDVars.savePath + fileName + GDConsts.itemFileExt) then
    DaxIo.DeleteIfPresent(GDVars.savePath + fileName + GDConsts.itemFileExt);
  if character^.alternateItemsAddr <> nil then begin
    Assign(f, GDVars.savePath + fileName + GDConsts.alternateItemFileExt);
    Rewrite(f, 1);
    item := character^.alternateItemsAddr;
    while item <> nil do begin
      BlockWrite(f, item^, SizeOf(Types.TItemRec));
      item := item^.next;
    end;
    Close(f);
  end;
  DaxIo.DeleteIfPresent(GDVars.savePath + fileName + GDConsts.effectFileExt);
  if character^.effectsAddr <> nil then begin
    Assign(f, GDVars.savePath + fileName + GDConsts.effectFileExt);
    Rewrite(f, 1);
    effect := character^.effectsAddr;
    while effect <> nil do begin
      BlockWrite(f, effect^, SizeOf(Types.TEffectRec));
      effect := effect^.next;
    end;
    Close(f);
  end;
  SaveChar := True;
end;

procedure LoadChar(name: String; character: Types.PCharRecord; isFromSavedGame, usesSaveDiskPrompt: Boolean);
var
  f: file;
  bytesRead: Word;
  item: Types.PItemRec;
  itemBuffer: Types.PItemRec;
  effect: Types.PEffectRec;
  effectBuffer: Types.PEffectRec;
  diskPrompt: Types.TString40;
  { Unused in this version; see the other implementations of this routine. }
  hasOpened: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  dataBuffer: array[1..283] of Byte;
  path: String;
begin
  if GDVars.importFormat = 1 then
    path := GDVars.savePath
  else
    path := GDVars.doomsdaySavePath;
  if usesSaveDiskPrompt then
    diskPrompt := GDConsts.saveDiskPrompt
  else
    diskPrompt := GDConsts.diskPrompts[GDVars.dataSet];
  hasOpened := DaxIo.OpenWithRetry(path + name, diskPrompt, 0, f);
  TextRend.DisplayLoading;
  FillChar(character^, SizeOf(Types.TCharRecord), 0);
  BlockRead(f, character^, SizeOf(Types.TCharRecord), bytesRead);
  Close(f);
  character^.itemsAddr := nil;
  character^.alternateItemsAddr := nil;
  character^.effectsAddr := nil;
  character^.combatAddr := nil;
  character^.nextCharAddr := nil;
  Delete(name, Pos('.', name), 4);
  if DaxIo.FileExists(path + name + GDConsts.itemFileExt) then begin
    GetMem(itemBuffer, SizeOf(Types.TItemRec));
    hasOpened := DaxIo.OpenWithRetry(path + name + GDConsts.itemFileExt, diskPrompt, 0, f);
    repeat
      BlockRead(f, itemBuffer^, SizeOf(Types.TItemRec), bytesRead);
      if bytesRead = SizeOf(Types.TItemRec) then begin
        if character^.itemsAddr = nil then begin
          GetMem(character^.itemsAddr, SizeOf(Types.TItemRec));
          item := character^.itemsAddr;
        end else begin
          GetMem(item^.next, SizeOf(Types.TItemRec));
          item := item^.next;
        end;
        item^ := itemBuffer^;
        item^.next := nil;
      end;
    until bytesRead <> SizeOf(Types.TItemRec);
    Close(f);
    FreeMem(itemBuffer, SizeOf(Types.TItemRec));
  end else if DaxIo.FileExists(path + name + GDConsts.alternateItemFileExt) then begin
    GetMem(itemBuffer, SizeOf(Types.TItemRec));
    hasOpened := DaxIo.OpenWithRetry(path + name + GDConsts.alternateItemFileExt, diskPrompt, 0, f);
    repeat
      BlockRead(f, itemBuffer^, SizeOf(Types.TItemRec), bytesRead);
      if bytesRead = SizeOf(Types.TItemRec) then begin
        if character^.alternateItemsAddr = nil then begin
          GetMem(character^.alternateItemsAddr, SizeOf(Types.TItemRec));
          item := character^.alternateItemsAddr;
        end else begin
          GetMem(item^.next, SizeOf(Types.TItemRec));
          item := item^.next;
        end;
        item^ := itemBuffer^;
        item^.next := nil;
      end;
    until bytesRead <> SizeOf(Types.TItemRec);
    Close(f);
    FreeMem(itemBuffer, SizeOf(Types.TItemRec));
  end;
  if DaxIo.FileExists(path + name + GDConsts.effectFileExt) then begin
    GetMem(effectBuffer, SizeOf(Types.TEffectRec));
    hasOpened := DaxIo.OpenWithRetry(path + name + GDConsts.effectFileExt, diskPrompt, 0, f);
    repeat
      BlockRead(f, effectBuffer^, SizeOf(Types.TEffectRec), bytesRead);
      if bytesRead = SizeOf(Types.TEffectRec) then begin
        if character^.effectsAddr = nil then begin
          GetMem(character^.effectsAddr, SizeOf(Types.TEffectRec));
          effect := character^.effectsAddr;
        end else begin
          GetMem(effect^.next, SizeOf(Types.TEffectRec));
          effect := effect^.next;
        end;
        effect^ := effectBuffer^;
        effect^.next := nil;
      end;
    until bytesRead <> SizeOf(Types.TEffectRec);
    Close(f);
    FreeMem(effectBuffer, SizeOf(Types.TEffectRec));
  end;
  GameIo.FlushKeys;
  CharHlp.RecalcStats(character);
end;

procedure AddCreatureToParty(id: Byte);
var
  character: Types.PCharRecord;
begin
  if GDVars.zone1^.partyCount > C_Combat.MAX_PARTY_SIZE - 1 then Exit;
  GetMem(character, SizeOf(Types.TCharRecord));
  SaveLoad.LoadCreatureData('MON', id, character);
  SaveLoad.AddCharToParty(character);
  if GDVars.demoMode then begin
    case id of
      106: character^.icon := 12;
      107: character^.icon := 0;
      108: character^.icon := 31;
    end;
    MapTiles.LoadIconAnim('CHARS', character^.icon, character^.orderNumber)
  end else begin
    character^.icon := id;
    MapTiles.LoadIconAnim('CPIC', id, character^.orderNumber)
  end;
end;

procedure LoadCreatureData(prefix: String; id: Byte; character: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  idText: array[1..5] of Byte;
  dataSize: Word;
  dataBuffer: Types.PByteArr;
  dataOffset: Word;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  numStr: String[1];
begin
  numStr := '0';
  DaxIo.LoadDax(prefix + numStr + 'CHA', '.dax', id, dataSize, dataBuffer);
  if dataSize = 0 then begin
    TextRend.DisplayAndPause(15, 0, 'Unable to load Monster');
    GameIo.ExitGame;
  end;
  Move(dataBuffer^, character^, SizeOf(Types.TCharRecord));
  with character^ do begin
    itemsAddr := nil;
    alternateItemsAddr := nil;
    effectsAddr := nil;
    nextCharAddr := nil;
    combatAddr := nil;
  end;
  FreeMem(dataBuffer, dataSize);
  GDVars.suppressDiskPrompt := 1;
  DaxIo.LoadDax(prefix + numStr + 'SPC', '.dax', id, dataSize, dataBuffer);
  if dataSize <> 0 then begin
    dataOffset := 0;
    GetMem(character^.effectsAddr, SizeOf(Types.TEffectRec));
    effect := character^.effectsAddr;
    repeat
      Move(dataBuffer^[dataOffset], effect^, SizeOf(Types.TEffectRec));
      effect^.next := nil;
      Inc(dataOffset, SizeOf(Types.TEffectRec));
      if dataOffset < dataSize then begin
        GetMem(effect^.next, SizeOf(Types.TEffectRec));
        effect := effect^.next;
      end;
    until dataOffset >= dataSize;
    FreeMem(dataBuffer, dataSize);
  end;
  DaxIo.LoadDax(prefix + numStr + 'ITM', '.dax', id, dataSize, dataBuffer);
  if dataSize <> 0 then begin
    dataOffset := 0;
    GetMem(character^.itemsAddr, SizeOf(Types.TItemRec));
    item := character^.itemsAddr;
    repeat
      Move(dataBuffer^[dataOffset], item^, SizeOf(Types.TItemRec));
      item^.next := nil;
      Inc(dataOffset, SizeOf(Types.TItemRec));
      if dataOffset < dataSize then begin
        GetMem(item^.next, SizeOf(Types.TItemRec));
        item := item^.next;
      end;
    until dataOffset >= dataSize;
    FreeMem(dataBuffer, dataSize);
  end;
  GDVars.suppressDiskPrompt := 0;
  GameIo.FlushKeys;
end;

procedure AddCharToParty(character: Types.PCharRecord);
var
  characterCursor: Types.PCharRecord;
  usedOrderNumbers: array[0..C_Combat.FIRST_CREATURE_ICON_SLOT - 1] of Byte;
begin
  character^.orderNumber := 255;
  if GDVars.partyHead = nil then
    GDVars.partyHead := character
  else begin
    characterCursor := GDVars.partyHead;
    while characterCursor^.nextCharAddr <> nil do
      characterCursor := characterCursor^.nextCharAddr;
    characterCursor^.nextCharAddr := character;
  end;
  GDVars.currentCharacter := character;
  FillChar(usedOrderNumbers, SizeOf(usedOrderNumbers), 0);
  characterCursor := GDVars.partyHead;
  while characterCursor <> nil do begin
    if characterCursor^.orderNumber in [0..C_Combat.FIRST_CREATURE_ICON_SLOT - 1] then
      usedOrderNumbers[characterCursor^.orderNumber] := 1;
    characterCursor := characterCursor^.nextCharAddr;
  end;
  with GDVars.currentCharacter^ do begin
    orderNumber := 0;
    while (orderNumber < C_Combat.FIRST_CREATURE_ICON_SLOT) and (usedOrderNumbers[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GDVars.zone1^.partyCount);
end;

procedure LoadGame;
var
  characterNames: array[1..8] of TFileName40;
  f: file;
  i: Byte;
  character: Types.PCharRecord;
  fileName: TFileName40;
  bytesRead: Word;
  characterCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hasOpened: Boolean;
  saveSlot: Char;
  availableSlots: String[20];
  picId: Byte;
  path: String;
begin
  TextRend.ClearRect(1, 1, 38, 22);
  MenuCore.MenuHorizontal
    ('load from:', 'Matrix Countdown', False, False);
  case GDVars.menuKey of
    'C': begin
           GDVars.importFormat := 0;
           path := GDVars.doomsdaySavePath
         end;
    'M': begin
           GDVars.importFormat := 1;
           path := GDVars.savePath
         end;
  else
    { Note: meant as Escape, which MenuHorizontal answers as NONE }
    if GDVars.extFlag and (GDVars.menuKey = C_Keys.RIGHT_BRACKET) then Exit
  end;
  if not SaveLoad.CheckSaveDir then Exit;
  availableSlots := '';
  for saveSlot := 'A' to 'J' do
    if DaxIo.FileExists(path + GDConsts.saveGameStem + saveSlot + '.dat') then
      availableSlots := availableSlots + saveSlot + ' ';
  if Length(availableSlots) = 0 then Exit;
  Delete(availableSlots, Length(availableSlots), 1);
  GDVars.horizChoice := 1;
  GDVars.menuChecksum := C_Menu.KEEP_MENU_CHOICE;
  repeat
    MenuCore.MenuHorizontal
      ('Load Which Game: ', availableSlots, False, False);
    saveSlot := GDVars.menuKey;
  until ((saveSlot in ['A'..'J']) and DaxIo.FileExists(path + GDConsts.saveGameStem + saveSlot + '.dat')) or
      (saveSlot = C_Keys.NONE);
  if saveSlot = C_Keys.NONE then Exit;
  hasOpened := DaxIo.OpenWithRetry(path + GDConsts.saveGameStem + saveSlot + '.dat', GDConsts.saveDiskPrompt + path, 1,
                                   f);
  TextRend.DisplayLoading;
  GDVars.hasLoadedSave := 1;
  if GDVars.importFormat = 1 then begin
    BlockRead(f, GDVars.dataSet, SizeOf(GDVars.dataSet), bytesRead);
    BlockRead(f, GDVars.zone0^, SizeOf(Types.TZone0), bytesRead);
    BlockRead(f, GDVars.zone1^, SizeOf(Types.TZone1), bytesRead);
    BlockRead(f, GDVars.zone2^, SizeOf(Types.TZone2), bytesRead);
    BlockRead(f, GDVars.partyPosition, SizeOf(GDVars.partyPosition), bytesRead);
    BlockRead(f, GDVars.previousInterfaceState, SizeOf(GDVars.previousInterfaceState), bytesRead);
    BlockRead(f, GDVars.interfaceState, SizeOf(GDVars.interfaceState), bytesRead);
    BlockRead(f, GDVars.wallSets[0].fileId, SizeOf(GDVars.wallSets[0].fileId), bytesRead);
    BlockRead(f, GDVars.wallSets[0].slot, SizeOf(GDVars.wallSets[0].slot), bytesRead)
  end else
    { the character count, after wall set 0 }
    Seek(f, SizeOf(TDatHeader) + SizeOf(Types.TWallSet));
  BlockRead(f, characterCount, SizeOf(characterCount), bytesRead);
  BlockRead(f, characterNames, SizeOf(characterNames), bytesRead);
  Close(f);
  GDVars.picturesEnabled := GDVars.zone0^.displayOptions shr 1;
  GDVars.animationsEnabled := GDVars.zone0^.displayOptions and 1;
  GDVars.zone1^.partyCount := 0;
  for i := 1 to characterCount do begin
    fileName := DaxIo.SanitizeFileName(DaxIo.SanitizeString(characterNames[i], '.'));
    if DaxIo.FileExists(path + fileName + '.sav') then begin
      GetMem(character, SizeOf(Types.TCharRecord));
      SaveLoad.LoadChar(fileName + '.sav', character, True, True);
      SaveLoad.AddCharToParty(character);
      if not SaveLoad.CheckSaveDir then Exit;
    end;
  end;
  character := GDVars.partyHead;
  while character <> nil do begin
    SaveLoad.DeleteCharacterFiles(character);
    character := character^.nextCharAddr;
  end;
  GDVars.currentCharacter := GDVars.partyHead;
  while GDVars.currentCharacter <> nil do begin
    if GDVars.currentCharacter^.npc < C_Npc.NON_PLAYER_FLAG then
      SaveLoad.LoadCharIconAnim(True)
    else
      MapTiles.LoadIconAnim('CPIC', GDVars.currentCharacter^.icon, GDVars.currentCharacter^.orderNumber);
    GDVars.currentCharacter := GDVars.currentCharacter^.nextCharAddr;
  end;
  GDVars.currentCharacter := GDVars.partyHead;
  GDVars.dataSet := GDVars.zone1^.savedDataSet;
  { a wilderness asks for a big picture, not a 3-D map }
  if GDVars.zone0^.areaType in [C_Area.VENUS_WILDERNESS, C_Area.MARS_WILDERNESS] then begin
    if GDVars.zone0^.areaType = C_Area.VENUS_WILDERNESS then
      picId := SaveLoad.VENUS_WILDERNESS_PIC
    else
      picId := SaveLoad.MARS_WILDERNESS_PIC;
    GDVars.bigPictureId := C_Pic.NO_BIG_PICTURE;
    Portrait.LoadBigPic(picId)
  end else if (GDVars.wallSets[0].fileId > 0) and (GDVars.zone0^.mapId <> C_Map.NO_GEO_MAP) and
    (GDVars.interfaceState <> C_Ifc.PICTURE_VIEW) then begin
    View3D.Load3DMap(GDVars.zone0^.mapId);
    View3D.LoadWallSet(GDVars.wallSets[0].fileId, GDVars.wallSets[0].slot)
  end;
  GameIo.FlushKeys;
  TextRend.ClearStatusLine;
  if GDVars.importFormat = 1 then begin
    GDVars.previousInterfaceState := GDVars.interfaceState;
    GDVars.interfaceState := C_Ifc.MAIN_MENU
  end;
end;

procedure SaveGame;
var
  characterNames: array[1..8] of TFileName40;
  f: file;
  characterCount: Byte;
  characterCursor: Types.PCharRecord;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  fileName: String[40];
  { Unused in this version; see the other implementations of this routine. }
  wasExtendedKey: Boolean;
  saveSlot: Char;
  { Rewrite reports to IOResult, not DosError, so this holds the last Dos lookup's error }
  lastDosError: Integer;
  requiredBytes: Word;

  { Returns the bytes the party's characters, items and effects take on disk. }
  function CalculateSaveSize: Word;
  var
    partyCharacter: Types.PCharRecord;
    item: Types.PItemRec;
    effect: Types.PEffectRec;
    totalBytes: Word;
  begin
    totalBytes := 0;
    partyCharacter := GDVars.partyHead;
    while partyCharacter <> nil do begin
      Inc(totalBytes, SizeOf(Types.TCharRecord));
      if partyCharacter^.itemsAddr <> nil then begin
        item := partyCharacter^.itemsAddr;
        while item <> nil do begin
          Inc(totalBytes, SizeOf(Types.TItemRec));
          item := item^.next;
        end;
      end else if partyCharacter^.alternateItemsAddr <> nil then begin
        item := partyCharacter^.alternateItemsAddr;
        while item <> nil do begin
          Inc(totalBytes, SizeOf(Types.TItemRec));
          item := item^.next;
        end;
      end;
      if partyCharacter^.effectsAddr <> nil then begin
        effect := partyCharacter^.effectsAddr;
        while effect <> nil do begin
          Inc(totalBytes, SizeOf(Types.TEffectRec));
          effect := effect^.next;
        end;
      end;
      partyCharacter := partyCharacter^.nextCharAddr;
    end;
    CalculateSaveSize := totalBytes;
  end;

begin
  GDVars.importFormat := 1;
  repeat
    MenuCore.MenuHorizontal
      ('Save Which Game: ', 'A B C D E F G H I J', False, GDVars.interfaceState = C_Ifc.CAMPING);
    saveSlot := GDVars.menuKey;
  until saveSlot in [C_Keys.NONE, 'A'..'J'];
  if saveSlot = C_Keys.NONE then Exit;
  if not SaveLoad.CheckSaveDir then Exit;
  if DaxIo.FileExists(GDVars.savePath + GDConsts.saveGameStem + saveSlot + '.dat') then
    requiredBytes := 0
  else
    { Note: leaves out the wall set, count and names, 333 more bytes }
    requiredBytes := SizeOf(TDatHeader);
  Inc(requiredBytes, CalculateSaveSize);
  if requiredBytes > DiskFree(Ord(UpCase(GDVars.savePath[1])) - (Ord('A') - 1)) then begin
    TextRend.DisplayAndPause(14, 0, 'Can''t save.  No room on this disk.');
    Exit;
  end;
  repeat
    Assign(f, GDVars.savePath + GDConsts.saveGameStem + saveSlot + '.dat');
    Rewrite(f, 1);
    lastDosError := DosError;
    if not (lastDosError in [0, 2, 18]) then begin
      if UpCase(GDVars.savePath[1]) < 'C' then
        TextRend.DisplayAndPause(14, 0, GDConsts.saveDiskPrompt + GDVars.savePath[1] + ':')
      else begin
        TextRend.DisplayAndPause(14, 0, 'Unexpected error during save: ' + TextRend.ByteToString(lastDosError));
        Close(f);
        Exit;
      end;
    end;
  until lastDosError in [0, 2, 18];
  TextRend.DisplaySaving;
  GDVars.zone0^.displayOptions := GDVars.picturesEnabled * 2 + GDVars.animationsEnabled;
  GDVars.zone1^.savedDataSet := GDVars.dataSet;
  BlockWrite(f, GDVars.dataSet, SizeOf(GDVars.dataSet));
  BlockWrite(f, GDVars.zone0^, SizeOf(Types.TZone0));
  BlockWrite(f, GDVars.zone1^, SizeOf(Types.TZone1));
  BlockWrite(f, GDVars.zone2^, SizeOf(Types.TZone2));
  BlockWrite(f, GDVars.partyPosition, SizeOf(GDVars.partyPosition));
  BlockWrite(f, GDVars.previousInterfaceState, SizeOf(GDVars.previousInterfaceState));
  BlockWrite(f, GDVars.interfaceState, SizeOf(GDVars.interfaceState));
  BlockWrite(f, GDVars.wallSets[0].fileId, SizeOf(GDVars.wallSets[0].fileId));
  BlockWrite(f, GDVars.wallSets[0].slot, SizeOf(GDVars.wallSets[0].slot));
  characterCount := 0;
  characterCursor := GDVars.partyHead;
  if characterCursor = nil then
    TextRend.DisplayAndPause(14, 0, 'WARNING: Problem Saving Characters');
  while characterCursor <> nil do begin
    Inc(characterCount);
    Str(characterCount, numStr);
    characterNames[characterCount] := 'CHRDAT' + saveSlot + numStr;
    characterCursor := characterCursor^.nextCharAddr;
  end;
  BlockWrite(f, characterCount, SizeOf(characterCount));
  BlockWrite(f, characterNames, SizeOf(characterNames));
  Close(f);
  characterCursor := GDVars.partyHead;
  characterCount := 0;
  while characterCursor <> nil do begin
    Inc(characterCount);
    Str(characterCount, numStr);
    if SaveLoad.SaveChar(characterCursor, 'CHRDAT' + saveSlot + numStr) then;
    SaveLoad.DeleteCharacterFiles(characterCursor);
    characterCursor := characterCursor^.nextCharAddr;
  end;
  GDVars.gameSaved := 1;
  TextRend.ClearStatusLine;
end;

procedure LoadShipData(ship: Types.PShipRec; id: ShortInt);
var
  dataSize: Word;
  dataBuffer: Types.PByteArr;
  count: Byte;
begin
  TextRend.DisplayLoading;
  DaxIo.LoadDax('ships', '.dax', id + SaveLoad.FIRST_SHIP_RECORD, dataSize, dataBuffer);
  Move(dataBuffer^, ship^, SizeOf(Types.TShipRec));
  FreeMem(dataBuffer, dataSize);
  if ship = GDVars.enemyShip then begin
    Portrait.FreeAnimation;
    Blit.LoadPic
      ('ships', id mod 5, False, 0, GDVars.bigPicture);
    Blit.SetDacPalette(C_Pic.ORBIT_DAC_FIRST, C_Pic.ORBIT_DAC_COUNT, GDVars.picturePalette);
    GDVars.bigPictureId := C_Pic.NO_BIG_PICTURE
  end;
  if id > 4 then
    ship^.name := 'Maelstrom Rider'
  else begin
    count := GDVars.zone0^.shipNameCounts[SaveLoad.GBVM_SHIP_NAME_COUNTS + id];
    ship^.name := GDConsts.shipNames[id, count mod 5];
    if count > 1 then
      ship^.name := ship^.name + ' ' + TextRend.ByteToString(count);
    Inc(GDVars.zone0^.shipNameCounts[SaveLoad.GBVM_SHIP_NAME_COUNTS + id])
  end;
end;

begin
end.
