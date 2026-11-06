{ Resident disk and archive access: DAX archive loading, the file helpers that find a game file on the data path or ask
  for its disk, the bottom-row prompt they ask with, the video-BIOS text writes that prompt uses, and the data-set
  switch. LoadDax loads a record with sound suspended (PushSoundState, PopSoundState). The two data paths and the drive
  letter the floppy prompt names are GDVars', the characters a file name is cleared of GDConsts'. }
{$O+,F+,I-,R-,S-}
unit DaxIo;

interface

uses Types, C_Screen, GDConsts, GDVars, Dos, GameIo, SoundDrv, Xmidi, C_Sound, C_Vm;

type
  TString20 = string[20];
  TString2 = string[2];

{ For a disk access: stops SoundDrv's own driver when soundState names it, then saves soundState for PopSoundState and
  sets it to 0 until then. }
procedure PushSoundState;

{ Restores the driver mode PushSoundState saved and, when it is the built-in driver, starts it again. }
procedure PopSoundState;

{ Writes a character repeatedly through the video BIOS.
  @param(col Text column of the first character.)
  @param(row Text row.)
  @param(attr Text attribute, which CGA mode maps through cgaTextColors.)
  @param(count How many times.)
  @param(ch The character.) }
procedure WriteChar(col, row, attr, count, ch: Byte);

{ Writes a string in text mode through the video BIOS, one character per column.
  @param(col Text column of the first character.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(source The text.) }
procedure WriteString(col, row, attr: Byte; source: string);

{ Writes a run of solid blocks, character 219, from a text cell.
  @param(col Text column of the first block.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(count How many blocks.) }
procedure WriteBlock(col, row, attr, count: Byte);

{ Shows a message on the status line, STATUS_ROW, waits for a key, and blanks the line again.
  @param(attr Text attribute.)
  @param(message The text.) }
procedure PromptBox(attr: Byte; message: Types.TString40);

{ Erases a file if it exists.
  @param(name The file's name.) }
procedure DeleteIfPresent(name: Types.TString80);

{ Asks for the overlay disk until game.ovr is found. }
procedure OverlayPrompt;

{ Reads a drive's volume label. The FindFirst status is not checked: the name buffer is cleared first, so a failed
  search leaves it empty.
  @param(drive The drive letter.)
  @returns(The label, or an empty string when it has none.) }
function GetVolumeLabel(drive: TString2): Types.TString40;

{ Opens a game file for reading in one-byte records. A name without a directory is looked for in the data path and then
  in the alternate path; the two paths trade places whenever the data path misses. A missing file whose directory starts
  below 'C', a floppy drive, is asked for with promptMsg and the prompt drive's letter; any other ends the game with
  'Check install'. A directory below 'C' also stops the loaded music driver first. Note: for a name without a directory
  that test reads the first character of an empty string, a stale byte.
  @param(fileName The file's name, with or without a directory.)
  @param(promptMsg The disk prompt.)
  @param(noPrompt Non-zero gives up on a missing file instead of asking.)
  @param(f Receives the open file.)
  @returns(True when the file is open.) }
function OpenWithRetry(fileName, promptMsg: Types.TString80; noPrompt: Byte; var f: file): Boolean;

{ Tests whether a file exists.
  @param(name The file's name.)
  @returns(True when name is not empty and FindFirst finds it.) }
function FileExists(name: Types.TString80): Boolean;

{ Deletes occurrences of del from src in one pass over positions fixed before it starts. Note: an occurrence that a
  deletion moves onto the position just tested stays, so 'A..B' less '.' is 'A.B'.
  @param(src The text.)
  @param(del The substring to remove.)
  @returns(src after the pass.) }
function SanitizeString(src, del: string): string;

{ Makes a name fit for a DOS file name.
  @param(name The name.)
  @returns(name after one SanitizeString pass for each character in invalidFileChars, which can leave some of them, cut
    to eight characters and upper-cased.) }
function SanitizeFileName(name: string): Types.TString80;

{ Decompresses a DAX record from a file into a buffer until the decompressed size is written: a count byte of 0..126
  copies that many bytes plus one, and -1..-127 repeats the next byte that many times.
  @param(dst The buffer the record expands into.)
  @param(lenDecompressed The record's decompressed size.)
  @param(f The archive, positioned at the record's data.) }
procedure DecompressDax(var dst: Types.PByteArr; var lenDecompressed: Word; var f: file);

{ Opens an archive twice through OpenWithRetry, once for the index and once for the data, with the data set's disk
  prompt, and reads the size of its index.
  @param(fileName The archive's name.)
  @param(ext The archive's extension.)
  @param(headerSize Set to where the record data starts, the index's size plus its size word; the data file is left
    there.)
  @param(dataFile Receives the archive opened for the data.)
  @param(indexFile Receives the archive opened for the index.)
  @returns(True when both files opened.) }
function OpenDax(fileName, ext: TString20; var headerSize: Word; var dataFile, indexFile: file): Boolean;

{ Closes both files of a DAX archive.
  @param(dataFile The archive opened for the data.)
  @param(indexFile The archive opened for the index.) }
procedure CloseDax(var dataFile, indexFile: file);

{ Loads a record of an archive into a new buffer, with sound suspended.
  @param(fileName The archive's name.)
  @param(ext The archive's extension.)
  @param(fileId The record.)
  @param(sizeRead Set to the record's decompressed size, 0 when it is missing.)
  @param(data Set to the buffer, `sizeRead` bytes, nil when the record is missing.) }
procedure LoadDax(fileName, ext: Types.TString80; fileId: Byte; var sizeRead: Word; var data: Types.PByteArr);

{ Switches the data set, keeping the one it replaces for PopState.
  @param(newDataSet The data set to use.) }
procedure PushState(newDataSet: Byte);

{ Restores the dataSet PushState replaced. }
procedure PopState;

implementation

const
  { INT 10h function: moves the page-BH cursor to row DH, column DL }
  BIOS_SET_CURSOR_POS = $02;
  { INT 10h function: writes AL CX times at the cursor in attribute BL }
  BIOS_WRITE_CHAR_ATTR = $09;

procedure PushSoundState;
begin
  case GDVars.soundState of
    C_Sound.DRIVER_OWN: SoundDrv.SoundCommand(GDConsts.soundDriverOff);
  end;
  GDVars.savedSoundState := GDVars.soundState;
  GDVars.soundState := C_Sound.DRIVER_NONE;
end;

procedure PopSoundState;
begin
  GDVars.soundState := GDVars.savedSoundState;
  if GDVars.soundState = C_Sound.DRIVER_OWN then
    SoundDrv.StartSound;
end;

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  GDVars.regs.ah := DaxIo.BIOS_SET_CURSOR_POS;
  GDVars.regs.bh := 0;
  GDVars.regs.dh := row;
  GDVars.regs.dl := col;
  Intr($10, Registers(GDVars.regs));
  GDVars.regs.ah := DaxIo.BIOS_WRITE_CHAR_ATTR;
  GDVars.regs.al := ch;
  GDVars.regs.bh := 0;
  if GDVars.displayMode = C_Vm.CGA then
    GDVars.regs.bl := GDConsts.cgaTextColors[attr]
  else
    GDVars.regs.bl := attr;
  GDVars.regs.cx := count;
  Intr($10, Registers(GDVars.regs));
end;

procedure WriteString(col, row, attr: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  n := Length(source);
  for i := 1 to n do begin
    DaxIo.WriteChar(col, row, attr, 1, Ord(source[i]));
    Inc(col);
  end;
end;

procedure WriteBlock(col, row, attr, count: Byte);
begin
  DaxIo.WriteChar(col, row, attr, count, 219);
end;

procedure PromptBox(attr: Byte; message: Types.TString40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  DaxIo.WriteBlock(0, C_Screen.STATUS_ROW, 0, C_Screen.TEXT_COLUMNS);
  DaxIo.WriteString(0, C_Screen.STATUS_ROW, attr, message);
  key := GameIo.ReadGameKey;
  DaxIo.WriteBlock(0, C_Screen.STATUS_ROW, 0, C_Screen.TEXT_COLUMNS);
end;

procedure DeleteIfPresent(name: Types.TString80);
begin
  if DaxIo.FileExists(name) then begin
    Assign(GDVars.deletionFile, name);
    Close(GDVars.deletionFile);
    Erase(GDVars.deletionFile);
  end;
end;

procedure OverlayPrompt;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  isFound: Boolean;
begin
  repeat
    isFound := DaxIo.FileExists('game.ovr');
    if not isFound then begin
      Writeln('Please insert overlay disk.');
      key := GameIo.ReadGameKey;
    end;
  until isFound;
end;

function GetVolumeLabel(drive: TString2): Types.TString40;
var
  sr: SearchRec;
begin
  FillChar(sr.Name, SizeOf(sr.Name), 0);
  FindFirst(drive + ':\*.*', VolumeID, sr);
  GetVolumeLabel := sr.Name;
end;

function OpenWithRetry(fileName, promptMsg: Types.TString80; noPrompt: Byte; var f: file): Boolean;
var
  isFound: Boolean;
  oldDir: string[79];
  dir: DirStr;
  name: NameStr;
  ext: ExtStr;
begin
  FSplit(fileName, dir, name, ext);
  if (dir[1] < 'C') and (GDVars.soundState = C_Sound.DRIVER_AIL) then
    Xmidi.ShutdownDriver;
  if dir = '' then
    dir := GDVars.dataPath;
  repeat
    isFound := DaxIo.FileExists(dir + name + ext);
    if (not isFound) and (dir = GDVars.dataPath) then begin
      oldDir := GDVars.dataPath;
      GDVars.dataPath := GDVars.altPath;
      GDVars.altPath := oldDir;
      dir := GDVars.dataPath;
      isFound := DaxIo.FileExists(dir + name + ext);
    end;
    if (not isFound) and (noPrompt = 0) then begin
      if dir[1] < 'C' then
        DaxIo.PromptBox(14, promptMsg + GDVars.promptDrive + ': <ENTER>')
      else begin
        DaxIo.PromptBox(14, 'Couldn''t find ' + name + ext + '. Check install.');
        GameIo.ExitGame;
      end;
    end;
  until isFound or (noPrompt <> 0);
  if isFound then begin
    Assign(f, dir + name + ext);
    Reset(f, 1);
  end;
  OpenWithRetry := isFound;
end;

function FileExists(name: Types.TString80): Boolean;
var
  sr: SearchRec;
begin
  FindFirst(name, 0, sr);
  FileExists := (DosError = 0) and (name <> '');
end;

function SanitizeString(src, del: string): string;
var
  limit: Byte;
  delLen: Byte;
  i: Byte;
begin
  delLen := Length(del);
  limit := Length(src) - delLen + 1;
  for i := 1 to limit do
    if Copy(src, i, delLen) = del then
      Delete(src, i, delLen);
  SanitizeString := src;
end;

function SanitizeFileName(name: string): Types.TString80;
var
  i: Byte;
begin
  for i := 1 to SizeOf(GDConsts.invalidFileChars) do
    name := DaxIo.SanitizeString(name, GDConsts.invalidFileChars[i]);
  name := Copy(name, 1, 8);
  for i := 1 to Length(name) do
    name[i] := UpCase(name[i]);
  SanitizeFileName := name;
end;

procedure DecompressDax(var dst: Types.PByteArr; var lenDecompressed: Word; var f: file);
var
  { Unused in this version; see the other implementations of this routine. }
  srcIdx: Word;
  dstIdx: Word;
  b: ShortInt;
  fillByte: Byte;
  { Unused in this version; see the other implementations of this routine. }
  inputBuffer: array[0..511] of Byte;
begin
  srcIdx := 0;
  dstIdx := 0;
  repeat
    BlockRead(f, b, SizeOf(b));
    case b of
      0..126: begin
        BlockRead(f, dst^[dstIdx], b + 1);
        Inc(dstIdx, b + 1);
      end;
      -127..-1: begin
        b := -b;
        BlockRead(f, fillByte, SizeOf(fillByte));
        FillChar(dst^[dstIdx], b, fillByte);
        Inc(dstIdx, b);
      end;
    end;
  until dstIdx >= lenDecompressed;
end;

function OpenDax(fileName, ext: TString20; var headerSize: Word; var dataFile, indexFile: file): Boolean;
var
  nread: Word;
  { Unused in this version; see the other implementations of this routine. }
  ioStatus: Word;
begin
  if DaxIo.OpenWithRetry(fileName + ext, GDConsts.diskPrompts[GDVars.dataSet], GDVars.suppressDiskPrompt,
                         dataFile) then begin
    if not DaxIo.OpenWithRetry(fileName + ext, GDConsts.diskPrompts[GDVars.dataSet],
                               GDVars.suppressDiskPrompt, indexFile) then begin
      OpenDax := False;
      Exit;
    end;
    BlockRead(indexFile, headerSize, SizeOf(headerSize), nread);
    Inc(headerSize, SizeOf(headerSize));
    Seek(dataFile, headerSize);
    OpenDax := True;
    Exit;
  end;
  OpenDax := False;
end;

procedure CloseDax(var dataFile, indexFile: file);
begin
  Close(dataFile);
  Close(indexFile);
end;

procedure LoadDax(fileName, ext: Types.TString80; fileId: Byte; var sizeRead: Word; var data: Types.PByteArr);
var
  { each index entry's compressed size, read and not used }
  compSize: Word;
  offset: LongInt;
  id: Byte;
  n: Word;
  dataFile: file;
  indexFile: file;
  hdrSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  numberText: array[0..7] of Byte;
begin
  DaxIo.PushSoundState;
  if not DaxIo.OpenDax(fileName, ext, hdrSize, dataFile, indexFile) then begin
    sizeRead := 0;
    data := nil;
    DaxIo.PopSoundState;
    Exit;
  end;
  repeat
    BlockRead(indexFile, id, SizeOf(id), n);
    BlockRead(indexFile, offset, SizeOf(offset), n);
    BlockRead(indexFile, sizeRead, SizeOf(sizeRead), n);
    BlockRead(indexFile, compSize, SizeOf(compSize), n);
  until (id = fileId) or (FilePos(indexFile) >= hdrSize);
  if id <> fileId then begin
    sizeRead := 0;
    data := nil;
    DaxIo.CloseDax(dataFile, indexFile);
    DaxIo.PopSoundState;
    Exit;
  end;
  GetMem(data, sizeRead);
  Seek(dataFile, hdrSize + offset);
  DaxIo.DecompressDax(data, sizeRead, dataFile);
  DaxIo.CloseDax(dataFile, indexFile);
  DaxIo.PopSoundState;
end;

procedure PushState(newDataSet: Byte);
begin
  GDVars.savedDataSet := GDVars.dataSet;
  GDVars.dataSet := newDataSet;
end;

procedure PopState;
begin
  GDVars.dataSet := GDVars.savedDataSet;
end;

begin
end.
