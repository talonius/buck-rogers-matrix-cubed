{ The sound settings: soundMode's values, the device matrix.cfg names, and soundState's, the driver that holds the
  sound. }
unit C_Sound;

interface

const
  { soundMode values: the sound device matrix.cfg's sound line names, as GameBoot's first-run dialog offers them;
    driverNames and musicFileStems give the AIL files of 1..5 }
  { Q, the dialog's Silent, and any other letter }
  SILENT = 0;
  { P, the PC speaker: pcspkr.adv }
  SPEAKER = 1;
  { T, the Tandy 1000: tandy.adv, and SoundDrv plays its songs on the Tandy voices }
  TANDY = 5;
  { soundState values: the driver that holds the sound }
  { neither: GameInit at start-up, DaxIo around a disk access, and each driver as it stops }
  DRIVER_NONE = 0;
  { SoundDrv's own speaker and Tandy driver }
  DRIVER_OWN = 1;
  { Xmidi's AIL driver }
  DRIVER_AIL = 2;

implementation

end.
