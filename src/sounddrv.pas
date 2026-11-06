{ The resident PC-speaker and Tandy sound driver. sounddrv.asm (SOUNDDRV.OBJ) holds the timer interrupt service routine,
  the song tables and the voice writers; this half installs it and dispatches the game's sound commands.
  GDVars.soundMode is the configured device: 0 none, 5 Tandy, and any other plays on the PC speaker here.
  GDVars.soundState is 1 while this driver holds the sound. Music and DaxIo decide when it does; GameIo sends Ctrl-S's
  commands and ExitGame's soundDriverOff straight here. Its initialization points GDVars.timeoutPtr at sounddrv.asm's
  ExitCount countdown and clears it. }
{$F+,I-,R-,S-}
unit SoundDrv;

interface

{ Sends a command to this driver; with no sound device configured every command but 21 is ignored.
  @param(cmd 0 starts song 0 on both devices, which silences them; 1 turns output on; 2..20 start song cmd - 1 on the
    Tandy voices for the Tandy device, else on the speaker; $FF, while this driver holds the sound, silences both
    devices, uninstalls the driver and records that no driver is loaded; 21 arms the timer routine's countdown to its
    fake run-time error.) }
procedure SoundCommand(cmd: Word);

{ Saves the current sound setting and, unless sound is off, marks this driver as the one in use, installs it and starts
  song 0 on both devices. }
procedure StartSound;

implementation

uses GDVars, C_Sound;

{$L SOUNDDRV.OBJ}
{ Installs the driver's timer interrupt handler, saving the old one, and speeds up the timer. }
procedure InstallSoundTimer; external;

{ Restores the old timer interrupt handler and the BIOS timer rate, and silences both banks of voices. }
procedure UninstallSoundTimer; external;

{ Starts a song on the PC-speaker voices; song 0 silences them.
  @param(song The song number.) }
procedure ProgramSpeakerVoices(song: Word); external;

{ Starts a song on the Tandy voices; song 0 silences them.
  @param(song The song number.) }
procedure ProgramTandyVoices(song: Word); external;

{ Turns the driver's output on or off without disturbing the songs.
  @param(value Non-zero turns output on; only the low byte is read.) }
procedure SetSoundOutputEnabled(value: Word); external;

{ a data word, declared as a procedure for its address }
procedure ExitCount; external;

procedure SoundCommand(cmd: Word);
var
  { Unused in this version; see the other implementations of this routine. }
  savedState: Word;
begin
  case cmd of
    0: if GDVars.soundMode <> C_Sound.SILENT then begin
         SoundDrv.ProgramTandyVoices(0);
         SoundDrv.ProgramSpeakerVoices(0);
       end;
    1: if GDVars.soundMode <> C_Sound.SILENT then
         SoundDrv.SetSoundOutputEnabled(1);
    255: if (GDVars.soundMode <> C_Sound.SILENT) and
      (GDVars.soundState = C_Sound.DRIVER_OWN) then begin
           GDVars.soundState := C_Sound.DRIVER_NONE;
           SoundDrv.ProgramTandyVoices(0);
           SoundDrv.ProgramSpeakerVoices(0);
           SoundDrv.UninstallSoundTimer;
         end;
    2..20: if GDVars.soundMode <> C_Sound.SILENT then
             if GDVars.soundMode = C_Sound.TANDY then
               SoundDrv.ProgramTandyVoices(cmd - 1)
             else
               SoundDrv.ProgramSpeakerVoices(cmd - 1);
    21: GDVars.timeoutPtr^ := 5000;
  end;
end;

procedure StartSound;
begin
  GDVars.savedSoundMode := GDVars.soundMode;
  if GDVars.soundMode = C_Sound.SILENT then Exit;
  GDVars.soundState := C_Sound.DRIVER_OWN;
  SoundDrv.InstallSoundTimer;
  SoundDrv.ProgramSpeakerVoices(0);
  SoundDrv.ProgramTandyVoices(0);
end;

begin
  GDVars.timeoutPtr := @SoundDrv.ExitCount;
  GDVars.timeoutPtr^ := 0;
end.
