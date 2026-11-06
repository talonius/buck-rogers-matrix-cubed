{ Music through John Miles' Audio Interface Library 2.00 (ail.asm). StartSequence loads the AIL driver for the
  configured sound device, the game's XMIDI file for that device and each sequence's timbres from the global timbre
  library, then starts one sequence; ShutdownDriver releases all of it. The driver's state is GDVars' Xmidi section,
  which GameInit clears at start-up. }
{$O+,F+,I-,R-,S-}
unit Xmidi;

interface

{ Stops the AIL driver and frees the loaded driver, the XMIDI file, the state tables and the timbre cache; saves
  soundState in savedSoundState and clears it. }
procedure ShutdownDriver;

{ Starts one sequence of soundMode's music. Does nothing while soundMode is 0. Loads and starts the AIL driver for
  soundMode only while soundState is not 2 (no AIL driver loaded yet); on every call it then frees and reallocates the
  state tables and the timbre cache, reloads the XMIDI file, registers up to MAX_SEQUENCES sequences and loads their
  timbres from the library. Shuts the driver down when the XMIDI file or a timbre cannot be loaded.
  @param(sequence The sequence to start, a GDVars.sequenceHandles index.) }
procedure StartSequence(sequence: Byte);

implementation

uses Types, GDConsts, GDVars, C_Sound;

const
  { sequences StartSequence registers at most }
  MAX_SEQUENCES = 8;
  { bytes LoadDriverImage allocates past the file, room to align it to a paragraph }
  DRIVER_SLACK = 64;
  { XMIDI, the only AIL driver type LoadAndInitDriver accepts }
  MUSIC_DRIVER_TYPE = 3;
  { AIL_register_sequence's answer when the file has no such sequence }
  NO_SEQUENCE = 65535;
  { the bank byte that ends the timbre library's index }
  GTL_INDEX_END = 255;
  { the bank byte of AIL_timbre_request's answer once no timbre is wanted }
  NO_TIMBRE_REQUEST = 255;

type
  TCName = array[0..80] of Char;
  PWord = ^Word;
  { one entry of the timbre library's index }
  TGtlHeader = record
    patch: Byte;
    bank: Byte;
    { where the timbre starts in the library file }
    offset: LongInt;
  end;
  { a timbre as AIL_timbre_request answers it, a Word with the bank in the high byte }
  TTimbreId = record
    patch: Byte;
    bank: Byte;
  end;

{$L AIL.OBJ}
{ AIL_startup: readies the library's timer service before a driver is registered. }
procedure AilStartup; external;

{ AIL_shutdown: stops every registered driver and the timer service.
  @param(signoff A message for the drivers to show, or nil.) }
procedure AilShutdown(signoff: Pointer); external;

{ AIL_register_driver: hooks up a driver loaded at offset 0 of a segment.
  @param(image The driver's image.)
  @returns(The driver's handle.) }
function AilRegisterDriver(image: Pointer): Word; external;

{ AIL_describe_driver: the driver's description, its type, default I/O settings and data-file suffix.
  @param(driver The driver's handle.)
  @returns(The description.) }
function AilDescribeDriver(driver: Word): Types.PDriverDesc; external;

{ AIL_detect_device: asks the driver whether its card answers at the given settings.
  @param(driver The driver's handle.)
  @param(ioPort The I/O port.)
  @param(irq The interrupt line.)
  @param(dma The DMA channel.)
  @param(drq The DMA request line.)
  @returns(True when the card is there.) }
function AilDetectDevice(driver, ioPort, irq, dma, drq: Word): Boolean;
  external;

{ AIL_init_driver: starts the driver on its card at the given settings.
  @param(driver The driver's handle.)
  @param(ioPort The I/O port.)
  @param(irq The interrupt line.)
  @param(dma The DMA channel.)
  @param(drq The DMA request line.) }
procedure AilInitDriver(driver, ioPort, irq, dma, drq: Word); external;

{ AIL_state_table_size: the bytes the driver needs for each registered sequence's state.
  @param(driver The driver's handle.)
  @returns(The size.) }
function AilStateTableSize(driver: Word): Word; external;

{ AIL_default_timbre_cache_size: the timbre cache the driver asks for.
  @param(driver The driver's handle.)
  @returns(The size, 0 for a driver that keeps no cache.) }
function AilDefaultTimbreCacheSize(driver: Word): Word; external;

{ AIL_define_timbre_cache: gives the driver its timbre cache.
  @param(driver The driver's handle.)
  @param(cache The cache.)
  @param(cacheSize Its size.) }
procedure AilDefineTimbreCache(driver: Word; cache: Pointer; cacheSize: Word); external;

{ AIL_register_sequence: readies one sequence of an XMIDI file for playing.
  @param(driver The driver's handle.)
  @param(image The XMIDI file in memory.)
  @param(number The sequence's number in the file.)
  @param(state The sequence's state table.)
  @param(controllers The controller table, or nil.)
  @returns(The sequence's handle, or NO_SEQUENCE when the file has no such sequence.) }
function AilRegisterSequence(driver: Word; image: Pointer; number: Word; state: Pointer;
                                  controllers: Pointer): Word; external;

{ AIL_timbre_request: the next timbre a sequence needs that the driver does not hold.
  @param(driver The driver's handle.)
  @param(sequence The sequence's handle.)
  @returns(The timbre, bank in the high byte and patch in the low; bank NO_TIMBRE_REQUEST once none is wanted.) }
function AilTimbreRequest(driver, sequence: Word): Word; external;

{ AIL_install_timbre: hands the driver a timbre.
  @param(driver The driver's handle.)
  @param(bank The timbre's bank.)
  @param(patch The timbre's patch.)
  @param(image The timbre, starting with its size word.) }
procedure AilInstallTimbre(driver, bank, patch: Word; image: Pointer); external;

{ AIL_start_sequence: starts a registered sequence playing.
  @param(driver The driver's handle.)
  @param(sequence The sequence's handle.) }
procedure AilStartSequence(driver, sequence: Word); external;

{ AIL_sequence_status: whether a sequence is stopped, playing or done. Nothing calls it.
  @param(driver The driver's handle.)
  @param(sequence The sequence's handle.)
  @returns(The status.) }
function AilSequenceStatus(driver, sequence: Word): Word; external;

{ Reads a timbre from the timbre library into a new block that starts with its size word.
  @param(sourceFile The file variable the library is opened through.)
  @param(name The library's file name.)
  @param(request The timbre, bank in the high byte and patch in the low.)
  @returns(The block, or nil when the library cannot be opened or its index ends first.) }
function LoadGlobalTimbre(var sourceFile: File; name: String; request: Word): Pointer;
var
  timbre: Pointer;
  timbreSize: Word;
  header: TGtlHeader;
begin
  LoadGlobalTimbre := nil;
  Assign(sourceFile, name);
  Reset(sourceFile, 1);
  if (IOResult = 0) and (name <> '') then
  begin
    repeat
      BlockRead(sourceFile, header, SizeOf(header));
      if header.bank = Xmidi.GTL_INDEX_END then begin
        Close(sourceFile);
        Exit;
      end;
    until (header.bank = Hi(request)) and (header.patch = Lo(request));
    Seek(sourceFile, header.offset);
    BlockRead(sourceFile, timbreSize, SizeOf(timbreSize));
    GetMem(timbre, timbreSize);
    Move(timbreSize, timbre^, SizeOf(timbreSize));
    BlockRead(sourceFile, Types.PByteArr(LongInt(timbre) + SizeOf(timbreSize))^, timbreSize - SizeOf(timbreSize));
    LoadGlobalTimbre := timbre;
  end;
  Close(sourceFile);
end;

{ Loads an AIL driver file into a block with DRIVER_SLACK bytes to spare and points driverImage at the first paragraph
  boundary in it, as a segment with offset 0.
  @param(name The driver's file name.)
  @returns(True when the file opened and was not empty.) }
function LoadDriverImage(name: String): Boolean;
var
  sourceFile: File;
  bytesRead: Word;
  aligned: Types.PByteArr;
begin
  Assign(sourceFile, name);
  Reset(sourceFile, 1);
  if IOResult = 0 then
    if FileSize(sourceFile) <> 0 then begin
      GDVars.driverAllocSize := FileSize(sourceFile) + Xmidi.DRIVER_SLACK;
      GetMem(GDVars.driverAlloc, GDVars.driverAllocSize);
      { the driver must start at offset 0 of its segment }
      aligned := GDVars.driverAlloc;
      while Byte(LongInt(aligned) and $F) <> 0 do
        Inc(LongInt(aligned));
      LongInt(aligned) := LongInt(aligned) + ((LongInt(aligned) and $FFF0) shl 12);
      LongInt(aligned) := LongInt(aligned) and $FFFF0000;
      GDVars.driverImage := aligned;
      BlockRead(sourceFile, Types.PByteArr(GDVars.driverImage)^, FileSize(sourceFile), bytesRead);
      Close(sourceFile);
      LoadDriverImage := True;
      Exit;
    end;
  LoadDriverImage := False;
end;

{ Frees the loaded driver's block, if any, and clears driverAlloc and driverImage. }
procedure FreeDriverImage;
begin
  if GDVars.driverAlloc <> nil then begin
    FreeMem(GDVars.driverAlloc, GDVars.driverAllocSize);
    GDVars.driverAlloc := nil;
    GDVars.driverImage := nil;
  end;
end;

{ Frees the loaded XMIDI file, if any, and clears xmiData. }
procedure FreeXmiData;
begin
  if GDVars.xmiData <> nil then begin
    FreeMem(GDVars.xmiData, GDVars.xmiSize);
    GDVars.xmiData := nil;
  end;
end;

procedure ShutdownDriver;
var slot: Byte;
begin
  Xmidi.AilShutdown(nil);
  Xmidi.FreeDriverImage;
  Xmidi.FreeXmiData;
  for slot := 0 to SizeOf(GDVars.stateTables) div SizeOf(Pointer) - 1 do
    if GDVars.stateTables[slot] <> nil then begin
      FreeMem(GDVars.stateTables[slot], GDVars.stateAllocSize);
      GDVars.stateTables[slot] := nil;
    end;
  if GDVars.timbreCache <> nil then begin
    FreeMem(GDVars.timbreCache, GDVars.timbreCacheSize);
    GDVars.timbreCache := nil;
  end;
  GDVars.savedSoundState := GDVars.soundState;
  GDVars.soundState := C_Sound.DRIVER_NONE;
end;

{ Frees any XMIDI file already loaded and loads a new one into xmiData, its size in xmiSize.
  @param(name The file's name.)
  @returns(True when the file opened and was not empty.) }
function LoadXmiFile(name: String): Boolean;
var
  sourceFile: File;
  bytesRead: Word;
begin
  Xmidi.FreeXmiData;
  Assign(sourceFile, name);
  Reset(sourceFile, 1);
  if (IOResult = 0) and (FileSize(sourceFile) <> 0) then begin
    GDVars.xmiSize := FileSize(sourceFile);
    GetMem(GDVars.xmiData, GDVars.xmiSize);
    BlockRead(sourceFile, Types.PByteArr(GDVars.xmiData)^, GDVars.xmiSize, bytesRead);
    Close(sourceFile);
    LoadXmiFile := True;
  end else
    LoadXmiFile := False;
end;

{ Converts a zero-terminated name, at most 80 characters, to a Pascal string.
  @param(source The name.)
  @returns(The string.) }
function CNameToPascal(source: TCName): String;
var
  index: Byte;
  temp: String;
begin
  index := 0;
  temp := '';
  while (index < 80) and (source[index] <> #0) do begin
    temp := temp + source[index];
    Inc(index);
  end;
  CNameToPascal := temp;
end;

{ Loads an AIL driver, registers it and, when it is an XMIDI driver whose card answers at its default settings, starts
  it there. A failure after the load frees the driver image again.
  @param(name The driver's file name.)
  @returns(True when the driver is running.) }
function LoadAndInitDriver(name: String): Boolean;
begin
  LoadAndInitDriver := False;
  GDVars.activeSequence := 0;
  if not Xmidi.LoadDriverImage(name) then Exit;
  Xmidi.AilStartup;
  GDVars.driverHandle := Xmidi.AilRegisterDriver(GDVars.driverImage);
  { Note: never true, since the Word zero-extends }
  if LongInt(GDVars.driverHandle) = -1 then begin
    Xmidi.FreeDriverImage;
    Exit;
  end;
  GDVars.driverDesc := Xmidi.AilDescribeDriver(GDVars.driverHandle);
  if GDVars.driverDesc^.driverType <> Xmidi.MUSIC_DRIVER_TYPE then begin
    Xmidi.FreeDriverImage;
    Exit;
  end;
  if not Xmidi.AilDetectDevice(GDVars.driverHandle, GDVars.driverDesc^.defaultIo,
                                    GDVars.driverDesc^.defaultIrq, GDVars.driverDesc^.defaultDma,
                                    GDVars.driverDesc^.defaultDrq) then begin
    Xmidi.FreeDriverImage;
    Exit;
  end;
  Xmidi.AilInitDriver(GDVars.driverHandle, GDVars.driverDesc^.defaultIo, GDVars.driverDesc^.defaultIrq,
                     GDVars.driverDesc^.defaultDma, GDVars.driverDesc^.defaultDrq);
  LoadAndInitDriver := True;
end;

procedure StartSequence(sequence: Byte);
var
  stop: Boolean;
  ok: Boolean;
  suffix: TCName;
  slot: Word;
  request: Word;
  bankPatch: TTimbreId;
  timbre: Types.PByteArr;
  gtl: File;
  gtlName: String[32];
begin
  ok := False;
  if GDVars.soundMode = C_Sound.SILENT then Exit;
  if GDVars.soundState <> C_Sound.DRIVER_AIL then begin
    GDVars.savedSoundState := GDVars.soundState;
    ok := Xmidi.LoadAndInitDriver(GDConsts.driverNames[GDVars.soundMode]);
    if ok then GDVars.soundState := C_Sound.DRIVER_AIL;
  end else
    ok := True;
  if not ok then Exit;

  for slot := 0 to SizeOf(GDVars.stateTables) div SizeOf(Pointer) - 1 do
    if GDVars.stateTables[slot] <> nil then begin
      FreeMem(GDVars.stateTables[slot], GDVars.stateAllocSize);
      GDVars.stateTables[slot] := nil;
    end;
  GDVars.stateAllocSize := Xmidi.AilStateTableSize(GDVars.driverHandle);
  if not Xmidi.LoadXmiFile(GDConsts.musicFileStems[GDVars.soundMode] + '.xmi') then
  begin
    Xmidi.ShutdownDriver;
    Exit;
  end;
  Move(GDVars.driverDesc^.dataSuffix, suffix, SizeOf(GDVars.driverDesc^.dataSuffix));
  gtlName := 'fatv9.' + Xmidi.CNameToPascal(suffix);
  if GDVars.timbreCache <> nil then begin
    FreeMem(GDVars.timbreCache, GDVars.timbreCacheSize);
    GDVars.timbreCache := nil;
  end;
  GDVars.timbreCacheSize := Xmidi.AilDefaultTimbreCacheSize(GDVars.driverHandle);
  if GDVars.timbreCacheSize <> 0 then begin
    GetMem(GDVars.timbreCache, GDVars.timbreCacheSize);
    Xmidi.AilDefineTimbreCache(GDVars.driverHandle, GDVars.timbreCache, GDVars.timbreCacheSize);
  end;

  slot := 0;
  stop := False;
  while (slot < Xmidi.MAX_SEQUENCES) and not stop do begin
    GetMem(GDVars.stateTables[slot], GDVars.stateAllocSize);
    GDVars.sequenceHandles[slot] := Xmidi.AilRegisterSequence(GDVars.driverHandle, GDVars.xmiData, slot,
                                                               GDVars.stateTables[slot], nil);
    if GDVars.sequenceHandles[slot] = Xmidi.NO_SEQUENCE then begin
      FreeMem(GDVars.stateTables[slot], GDVars.stateAllocSize);
      GDVars.stateTables[slot] := nil;
      stop := True;
    end;
    if not stop then begin
      request := Xmidi.AilTimbreRequest(GDVars.driverHandle, GDVars.sequenceHandles[slot]);
      Move(request, bankPatch, SizeOf(bankPatch));
      while bankPatch.bank <> Xmidi.NO_TIMBRE_REQUEST do begin
        timbre := Xmidi.LoadGlobalTimbre(gtl, gtlName, PWord(@bankPatch)^);
        if timbre <> nil then begin
          Xmidi.AilInstallTimbre(GDVars.driverHandle, bankPatch.bank, bankPatch.patch, timbre);
          FreeMem(timbre, PWord(timbre)^);
        end else begin
          Xmidi.ShutdownDriver;
          Exit;
        end;
        request := Xmidi.AilTimbreRequest(GDVars.driverHandle, GDVars.sequenceHandles[slot]);
        Move(request, bankPatch, SizeOf(bankPatch));
      end;
      Inc(slot);
    end;
  end;
  GDVars.activeSequence := sequence;
  Xmidi.AilStartSequence(GDVars.driverHandle, GDVars.sequenceHandles[GDVars.activeSequence]);
end;

begin
end.
