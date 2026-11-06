{ The resident sound router: it routes the game's sounds and music between SoundDrv's speaker and Tandy driver and
  Xmidi's AIL music driver, by GDVars.soundState, the driver that holds the sound (0 none, 1 SoundDrv's, 2 Xmidi's).
  Only one holds it at a time, so SendSoundCommand and StartMusic first stop the other driver. The unit owns no state. }
{$O+,F+}
unit Music;

interface

{ Plays a sound command: stops the music driver if it is installed, installs SoundDrv's driver if none is, then calls
  SoundCommand.
  @param(cmd Sound command for SoundDrv.SoundCommand.) }
procedure SendSoundCommand(cmd: Word);

{ Unless no sound device is configured, stops SoundDrv's driver if it holds the sound, stops the AIL music driver, and
  starts a music sequence through Xmidi.StartSequence, which loads the driver again.
  @param(sequenceId The XMIDI sequence to start.) }
procedure StartMusic(sequenceId: Byte);

{ Shuts down the music driver if it is installed. }
procedure StopMusic;

implementation

uses GDConsts, GDVars, SoundDrv, Xmidi, C_Sound;

procedure SendSoundCommand(cmd: Word);
begin
  if GDVars.soundState = C_Sound.DRIVER_AIL then Music.StopMusic;
  if GDVars.soundState = C_Sound.DRIVER_NONE then
    SoundDrv.StartSound;
  SoundDrv.SoundCommand(cmd);
end;

procedure StartMusic(sequenceId: Byte);
begin
  if GDVars.soundMode = C_Sound.SILENT then Exit;
  if GDVars.soundState = C_Sound.DRIVER_OWN then
    SoundDrv.SoundCommand(GDConsts.soundDriverOff);
  Music.StopMusic;
  Xmidi.StartSequence(sequenceId);
end;

procedure StopMusic;
begin
  if GDVars.soundState = C_Sound.DRIVER_AIL then
    Xmidi.ShutdownDriver;
end;

begin
end.
