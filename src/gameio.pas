{ Keyboard, mouse and joystick input, the hotkeys, and the game's exit.

  ReadGameKey takes a key from the BIOS keyboard, or a button or joystick zone from the device in use, and runs the
  hotkeys before it answers: Ctrl-S switches sound off and on, Ctrl-U flips musicEnabled and shuts the music driver down
  as it turns it off, Ctrl-D switches logging to debug.txt, Ctrl-Z walks the party list while logging, Ctrl-C ends the
  game through ExitGame. OverlayReadWithBeep is the overlay read routine GameBoot installs. }
{$O+,F+,I-,R-,S-}
unit GameIo;

interface

{ Ends the game at once: hides and resets the mouse, stops the loaded sound driver, restores the saved video mode,
  closes debug.txt while logging, and halts. Note: SoundDrv's driver is not stopped while the sound is off, so after
  Ctrl-S the game halts with INT 8 still hooked. }
procedure ExitGame;

{ Waits for a key or, while a mouse or joystick is in use, for a button (Enter or Escape) or a joystick zone (the keypad
  digit joystickKeys gives); in the demo with neither in use and no key waiting it answers #0 at once. Runs the hotkeys,
  and sets isMouseClick when the mouse poller took a button. Note: both buttons at once (3) are neither Enter nor
  Escape, so the answer is left unset.
  @returns(The key, or #0.) }
function ReadGameKey: Char;

{ Tests for input without taking it.
  @returns(True when a key waits or, while a mouse or joystick is in use, a button is down or the joystick is off
    center.) }
function InputPending: Boolean;

{ Discards every key waiting in the BIOS buffer. }
procedure FlushKeys;

{ Takes one pending input through ReadGameKey, hotkeys included, and discards it. }
procedure DiscardPendingKeys;

{ Reads an overlay for the overlay manager, as installed by GameBoot: calls the saved reader until that succeeds,
  beeping (4000 Hz, 20 ms) after each failure.
  @param(overlaySegment The overlay to read, passed to the saved reader.)
  @returns(0, success.) }
function OverlayReadWithBeep(overlaySegment: Word): Integer;

implementation

uses Dos, Crt, Mouse, Types, C_Video, GDConsts, GDVars, Joystick, SoundDrv, Xmidi, C_Sound, C_Joy,
  C_Keys;

const
  KEY_CTRL_C = #3;
  KEY_CTRL_D = #4;
  KEY_CTRL_S = #19;
  KEY_CTRL_U = #21;
  KEY_CTRL_Z = #26;
  { a mouse's left button, or a joystick's button 1: ENTER }
  FIRST_BUTTON = 1;
  { a mouse's right button, or a joystick's button 2: ESCAPE }
  SECOND_BUTTON = 2;

procedure ExitGame;
var
  { Unused in this version; see the other implementations of this routine. }
  videoMode: Word;
begin
  Mouse.HideMouse;
  Mouse.ResetMouse;
  case GDVars.soundState of
    C_Sound.DRIVER_AIL: Xmidi.ShutdownDriver;
    C_Sound.DRIVER_OWN: SoundDrv.SoundCommand(GDConsts.soundDriverOff);
  end;
  GDVars.regs.ah := C_Video.BIOS_SET_VIDEO_MODE;
  GDVars.regs.al := GDVars.savedVideoMode;
  Intr($10, Registers(GDVars.regs));
  if GDVars.isDebugMode then Close(GDVars.debugFile);
  Halt(0);
end;

{ Does nothing; in debug mode the game-key reader's Ctrl-Z handler calls it for each creature in the party list.
  @param(node Unused.) }
procedure DumpWhoList(node: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  cur: Pointer;
begin
end;

function ReadGameKey: Char;
var
  key: Char;
  node: Types.PCharRecord;
  devButton: Integer;
  devDir: Byte;
  gotKey: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  scanCode: Byte;

  { Waits for a key or for joystick input, turning a button into Enter or Escape and a stick zone into its keypad key. }
  procedure TranslateJoystick;
  begin
    devButton := 0;
    gotKey := False;
    while not (KeyPressed or gotKey) do begin
      Joystick.GetJoystick(devButton, devDir);
      if (devDir < C_Joy.NO_ZONE) or Boolean(devButton <> 0) then begin
        if devDir < C_Joy.NO_ZONE then
          key := GDConsts.joystickKeys[devDir]
        else
          case devButton of
            GameIo.FIRST_BUTTON: key := C_Keys.ENTER;
            GameIo.SECOND_BUTTON: key := C_Keys.ESCAPE;
          end;
        gotKey := True;
      end;
    end;
  end;

  { Waits for a key or a mouse button, turning the button into Enter or Escape and noting the mouse click. }
  procedure TranslateMouse;
  begin
    devButton := 0;
    gotKey := False;
    while not (KeyPressed or gotKey) do begin
      Mouse.GetMouse(devButton, GDVars.mouseX, GDVars.mouseY);
      if devButton <> 0 then begin
        case devButton of
          GameIo.FIRST_BUTTON: key := C_Keys.ENTER;
          GameIo.SECOND_BUTTON: key := C_Keys.ESCAPE;
        end;
        GDVars.isMouseClick := True;
        gotKey := True;
      end;
    end;
  end;

begin
  GDVars.isMouseClick := False;
  if KeyPressed then
    key := ReadKey
  else if GDVars.isJoystickOn or GDVars.isMouseOn then begin
    if GDVars.isMouseOn then TranslateMouse else TranslateJoystick;
    if KeyPressed then key := ReadKey;
  end else begin
    if GDVars.demoMode then key := #0 else key := ReadKey;
  end;

  { sound off, or back on when the soundMode it left is Speaker or Tandy, the devices SoundDrv drives }
  if key = GameIo.KEY_CTRL_S then begin
    if GDVars.soundMode <> C_Sound.SILENT then begin
      GDVars.savedSoundMode := GDVars.soundMode;
      if GDVars.soundState = C_Sound.DRIVER_OWN then
        SoundDrv.SoundCommand(GDConsts.silenceSounds);
      GDVars.soundMode := C_Sound.SILENT;
    end else if GDVars.savedSoundMode in [C_Sound.SPEAKER, C_Sound.TANDY] then begin
      GDVars.soundMode := GDVars.savedSoundMode;
      if GDVars.soundState = C_Sound.DRIVER_OWN then
        SoundDrv.SoundCommand(GDConsts.soundOutputOn);
    end;
  end;

  { flips musicEnabled; turning it on starts nothing }
  if key = GameIo.KEY_CTRL_U then begin
    GDVars.musicEnabled := not GDVars.musicEnabled;
    if not GDVars.musicEnabled then
      Xmidi.ShutdownDriver;
  end;

  case key of
    { logging to debug.txt on or off }
    GameIo.KEY_CTRL_D:
      begin
        GDVars.isDebugMode := not GDVars.isDebugMode;
        if GDVars.isDebugMode then begin
          Assign(GDVars.debugFile, 'debug.txt');
          Rewrite(GDVars.debugFile);
        end else
          Close(GDVars.debugFile);
      end;
    GameIo.KEY_CTRL_Z:
      if GDVars.isDebugMode then begin
        node := GDVars.partyHead;
        while node <> nil do begin
          GameIo.DumpWhoList(node);
          node := node^.nextCharAddr;
        end;
      end;
    GameIo.KEY_CTRL_C:
      GameIo.ExitGame;
  end;

  ReadGameKey := key;
end;

function InputPending: Boolean;
var
  devButton: Integer;
  devDir: Byte;
begin
  InputPending := KeyPressed;
  if GDVars.isJoystickOn or GDVars.isMouseOn then begin
    if GDVars.isMouseOn then begin
      Mouse.GetMouse(devButton, GDVars.mouseX, GDVars.mouseY);
      InputPending := KeyPressed or Boolean(devButton <> 0);
    end else begin
      Joystick.GetJoystick(devButton, devDir);
      InputPending := KeyPressed or Boolean(devButton > 0) or Boolean(devDir < C_Joy.NO_ZONE);
    end;
  end;
end;

procedure FlushKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  while KeyPressed do key := ReadKey;
end;

procedure DiscardPendingKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  if GameIo.InputPending then key := GameIo.ReadGameKey;
end;

function OverlayReadWithBeep(overlaySegment: Word): Integer;
begin
  while GDVars.originalOvrReader(overlaySegment) <> 0 do begin
    Sound(4000);
    Delay(20);
    NoSound;
  end;
  OverlayReadWithBeep := 0;
end;

begin
end.
