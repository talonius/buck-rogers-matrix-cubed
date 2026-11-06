{ The resident start-up unit. It exports nothing; its initialization is the boot. It starts the overlay manager on
  GAME.OVR with GameIo's OverlayReadWithBeep as the overlay reader, takes the data path from the current directory and
  the alternate path from it (the other floppy drive, or the same path on a hard disk), and, when matrix.cfg is missing,
  runs the first-run dialog that writes it. It then sets the video mode matrix.cfg names (moving HeapEnd down for Tandy
  video memory), sizes the overlay buffer, and reads the rest of matrix.cfg: sound, input device, the save path, the
  Doomsday save path characters import from, the intro flag and the joystick calibration. The dialog's working storage
  is GDVars'. }
{$O+,F+,I-,R-,S-,V-}
unit GameBoot;

interface

implementation

uses Crt, Dos, Overlay, DaxIo, Joystick, GameIo, Blit, TextRend, Types, GDConsts, GDVars, C_Sound,
  C_Vm;

const
  { INT 10h function: AL returns the current mode }
  BIOS_GET_VIDEO_MODE = $0F;
  { 320x200, 16 colors, Tandy 1000 }
  VIDEO_MODE_TANDY = $09;
  { 320x200, 16 colors }
  VIDEO_MODE_EGA = $0D;
  { 320x200, 256 colors }
  VIDEO_MODE_VGA = $13;
  { paragraphs (16 KB) HeapEnd moves down for Tandy video memory }
  GFX_RESERVE_PARAS = 1024;
  { the overlay buffer (120 KB) the boot sets, or halts for want of memory }
  OVERLAY_BUF_BYTES = 122880;
  { soundMode for the first-run dialog's S: sbfm.adv }
  SOUND_MODE_SOUND_BLASTER = 2;
  { A: adlib.adv }
  SOUND_MODE_ADLIB = 3;
  { R, the Roland MT-32: mt32mpu.adv }
  SOUND_MODE_ROLAND = 4;

type
  { a pointer's offset and segment words }
  TPtrWords = record o: Word; s: Word end;

var
  heapEndWords: TPtrWords absolute HeapEnd;

{ Waits for a digit key within a range and echoes it.
  @param(minimum The lowest digit accepted.)
  @param(maximum The highest digit accepted.)
  @returns(The digit's value.) }
function ReadChoice(minimum, maximum: Byte): Byte;
begin
  repeat
    GDVars.cfgChar := ReadKey;
  until (GDVars.cfgChar in ['0'..'9']) and ((Ord(GDVars.cfgChar) - Ord('0')) in [minimum..maximum]);
  Write(GDVars.cfgChar);
  ReadChoice := Ord(GDVars.cfgChar) - Ord('0');
end;

begin
  CheckBreak := False;
  DaxIo.OverlayPrompt;
  OvrInit('GAME.OVR');
  GDVars.originalOvrReader := OvrReadBuf;
  OvrReadBuf := GameIo.OverlayReadWithBeep;

  FSplit(FExpand('*.exe'), GDVars.dataPath, GDVars.fsName, GDVars.fsExt);
  if GDVars.dataPath[1] < 'C' then
  begin
    if GDVars.dataPath[1] = 'A' then
      GDVars.altPath := 'B:\'
    else
      GDVars.altPath := 'A:\';
  end else
    GDVars.altPath := GDVars.dataPath;
  GDVars.promptDrive := GDVars.altPath[1];

  if not DaxIo.FileExists(GDConsts.configFileName) then begin
    Assign(GDVars.cfgText, GDConsts.configFileName);
    Rewrite(GDVars.cfgText);
    GDVars.cfgErr := IOResult;
    if GDVars.cfgErr <> 0 then begin
      ClrScr;
      WriteLn('Sorry, disk A can''t be write-protected.');
      WriteLn;
      WriteLn('If these are your masters, use DISKCOPY to make duplicates.');
      Halt(1);
    end;

    ClrScr;
    Write('GRAPHICS ADAPTER TYPE:  [1] EGA  [2] Tandy  [3] VGA ');
    GDVars.menuChoice := GameBoot.ReadChoice(1, 3);
    case GDVars.menuChoice of
      1: WriteLn(GDVars.cfgText, 'E');
      2: WriteLn(GDVars.cfgText, 'T');
      3: WriteLn(GDVars.cfgText, 'V');
    end;

    ClrScr;
    WriteLn('SOUND TYPE:  [1] PC speaker');
    WriteLn('             [2] Sound Blaster');
    WriteLn('             [3] Adlib');
    WriteLn('             [4] Roland MT32');
    WriteLn('             [5] Tandy 1000');
    WriteLn('             [6] Silent');
    GDVars.menuChoice := GameBoot.ReadChoice(1, 6);
    case GDVars.menuChoice of
      1: WriteLn(GDVars.cfgText, 'P');
      2: WriteLn(GDVars.cfgText, 'S');
      3: WriteLn(GDVars.cfgText, 'A');
      4: WriteLn(GDVars.cfgText, 'R');
      5: WriteLn(GDVars.cfgText, 'T');
      6: WriteLn(GDVars.cfgText, 'Q');
    end;

    GDVars.isJoystickOn := False;
    ClrScr;
    Write('ALTERNATE INPUT TYPE:  [1] JOYSTICK  [2] MOUSE  [3] NEITHER  ');
    GDVars.menuChoice := GameBoot.ReadChoice(1, 3);
    case GDVars.menuChoice of
      1: begin WriteLn(GDVars.cfgText, 'J'); GDVars.isJoystickOn := True; end;
      2: WriteLn(GDVars.cfgText, 'M');
      3: WriteLn(GDVars.cfgText, 'N');
    end;

    ClrScr;
    GDVars.defaultSavePath := GDVars.altPath + 'SAVE';
    Write('PATH TO SAVE DATA (DEFAULT - ' + GDVars.defaultSavePath + '):  ');
    ReadLn(GDVars.pathBuf);
    GDVars.pathBuf[1] := UpCase(GDVars.pathBuf[1]);
    if (Length(GDVars.pathBuf) < 4) or (GDVars.pathBuf[2] <> ':') or
        ((GDVars.pathBuf[1] in ['A'..'B']) and (GDVars.pathBuf[1] = GDVars.dataPath[1])) or
            not (GDVars.pathBuf[1] in ['A'..'P']) then
    begin
      GDVars.pathBuf := GDVars.defaultSavePath;
      WriteLn('USING DEFAULT PATH: ' + GDVars.pathBuf);
      Delay(2000);
    end;
    for GDVars.ix := 1 to Length(GDVars.pathBuf) do
      GDVars.pathBuf[GDVars.ix] := UpCase(GDVars.pathBuf[GDVars.ix]);
    if GDVars.pathBuf[Length(GDVars.pathBuf)] <> '\' then
      GDVars.pathBuf := GDVars.pathBuf + '\';
    WriteLn(GDVars.cfgText, GDVars.pathBuf);

    ClrScr;
    GDVars.pathBuf := '';
    if GDVars.altPath[1] < 'C' then
      GDVars.defaultSavePath := GDVars.altPath[1] + ':\SAVE'
    else
      GDVars.defaultSavePath := GDVars.altPath[1] + ':\BUCK\SAVE';
    WriteLn('PATH TO SAVE DATA FOR COUNTDOWN TO DOOMSDAY');
    Write('(DEFAULT - ' + GDVars.defaultSavePath + '):  ');
    ReadLn(GDVars.pathBuf);
    GDVars.pathBuf[1] := UpCase(GDVars.pathBuf[1]);
    if (Length(GDVars.pathBuf) < 4) or (GDVars.pathBuf[2] <> ':') or
        ((GDVars.pathBuf[1] in ['A'..'B']) and (GDVars.pathBuf[1] = GDVars.dataPath[1])) or
            not (GDVars.pathBuf[1] in ['A'..'P']) then
    begin
      GDVars.pathBuf := GDVars.defaultSavePath;
      WriteLn('USING DEFAULT PATH: ' + GDVars.pathBuf);
      Delay(2000);
    end;
    for GDVars.ix := 1 to Length(GDVars.pathBuf) do
      GDVars.pathBuf[GDVars.ix] := UpCase(GDVars.pathBuf[GDVars.ix]);
    if GDVars.pathBuf[Length(GDVars.pathBuf)] <> '\' then
      GDVars.pathBuf := GDVars.pathBuf + '\';
    WriteLn(GDVars.cfgText, GDVars.pathBuf);
    WriteLn(GDVars.cfgText, 'F');

    Joystick.CalibrateJoystick;
    for GDVars.ix := 0 to SizeOf(Types.TJoyAxis) div SizeOf(Word) - 1 do begin
      WriteLn(GDVars.cfgText, GDVars.joystickCalibration[1].x[GDVars.ix]);
      WriteLn(GDVars.cfgText, GDVars.joystickCalibration[1].y[GDVars.ix]);
    end;
    Close(GDVars.cfgText);
  end;

  ClrScr;
  WriteLn('TANDY 1000 USERS - Make sure NUMLOCK is on.');
  Delay(2000);
  Assign(GDVars.cfgText, GDConsts.configFileName);
  Reset(GDVars.cfgText);
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  GDVars.regs.ah := GameBoot.BIOS_GET_VIDEO_MODE;
  Intr($10, Registers(GDVars.regs));
  GDVars.savedVideoMode := GDVars.regs.al;
  GDVars.curVideoMode := GDVars.savedVideoMode;
  case GDVars.cfgChar of
    'E': begin
      GDVars.displayMode := C_Vm.EGA;
      Blit.SetVideoMode(GameBoot.VIDEO_MODE_EGA);
      GDVars.egaShownPage := 0;
      GDVars.egaDrawPage := 0;
      TextRend.SetupEgaCurrentPage(GDVars.egaShownPage);
      TextRend.SetupEgaOtherPage(GDVars.egaDrawPage);
    end;
    'T': begin
      GDVars.displayMode := C_Vm.TANDY;
      GDVars.newHeapEnd := Ptr(heapEndWords.s - GameBoot.GFX_RESERVE_PARAS, heapEndWords.o);
      HeapEnd := GDVars.newHeapEnd;
      Blit.SetVideoMode(GameBoot.VIDEO_MODE_TANDY);
    end;
    'V': begin
      GDVars.displayMode := C_Vm.VGA;
      Blit.SetVideoMode(GameBoot.VIDEO_MODE_VGA);
    end;
  end;

  if GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf <= MemAvail then
    OvrSetBuf(GameBoot.OVERLAY_BUF_BYTES)
  else begin
    Blit.RestoreVideoMode;
    WriteLn('Not enough memory to run game.  You need ', GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf - MemAvail,
            ' more bytes.');
    Halt;
  end;
  if OvrResult <> 0 then begin
    Blit.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    Halt;
  end;

  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  case GDVars.cfgChar of
    'P': GDVars.soundMode := C_Sound.SPEAKER;
    'S': GDVars.soundMode := GameBoot.SOUND_MODE_SOUND_BLASTER;
    'A': GDVars.soundMode := GameBoot.SOUND_MODE_ADLIB;
    'R': GDVars.soundMode := GameBoot.SOUND_MODE_ROLAND;
    'T': GDVars.soundMode := C_Sound.TANDY;
    'Q': GDVars.soundMode := C_Sound.SILENT;
    else GDVars.soundMode := C_Sound.SILENT;
  end;
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  case GDVars.cfgChar of
    'J': begin GDVars.isJoystickOn := True; GDVars.isMouseOn := False; end;
    'M': begin GDVars.isMouseOn := True; GDVars.isJoystickOn := False; end;
    'N': begin GDVars.isMouseOn := False; GDVars.isJoystickOn := False; end;
  end;
  ReadLn(GDVars.cfgText, GDVars.savePath);
  ReadLn(GDVars.cfgText, GDVars.doomsdaySavePath);
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  if GDVars.cfgChar = 'F' then
    GDVars.isFullIntro := True
  else
    GDVars.isFullIntro := False;
  Joystick.ProbeJoystick;
  if GDVars.isJoystickOn then
    for GDVars.ix := 0 to SizeOf(Types.TJoyAxis) div SizeOf(Word) - 1 do begin
      ReadLn(GDVars.cfgText, GDVars.joystickCalibration[1].x[GDVars.ix]);
      ReadLn(GDVars.cfgText, GDVars.joystickCalibration[1].y[GDVars.ix]);
    end;
  Close(GDVars.cfgText);
end.
