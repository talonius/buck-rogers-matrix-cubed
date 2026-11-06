{ The out-of-memory handler: its initialization installs HeapErrorHandler as System's HeapError. The unit owns no
  state. }
{$O+,F+}
unit HeapErr;

interface

{ Installed as HeapError, so the heap manager calls it when an allocation fails. For a nonzero request it shows an
  insufficient-memory warning; while a game is active it runs the save menu and repeats until a save sets the
  recently-saved flag, otherwise it says the program is exiting. Either way it then quits through GameIo.ExitGame. A
  zero-size request returns at once. Note: the result is never assigned.
  @param(size Bytes requested; 0 does nothing.)
  @returns(Nothing: the result is never assigned.) }
function HeapErrorHandler(size: Word): Integer;

implementation

uses Crt, TextRend, GameIo, GDVars, SaveLoad;

function HeapErrorHandler(size: Word): Integer;
var
  exitFlag: Byte;
begin
  if size > 0 then begin
    exitFlag := 0;
    repeat
      TextRend.DisplayAndPause(Yellow, Black, 'WARNING: Insufficient Memory');
      if GDVars.isGameUp then begin
        SaveLoad.SaveGame;
        exitFlag := GDVars.gameSaved
      end else begin
        exitFlag := 1;
        TextRend.DisplayAndPause(Yellow, Black, 'Insufficient Memory. Exiting Program')
      end
    until exitFlag <> 0;
    GameIo.ExitGame
  end
end;

begin
  HeapError := @HeapErr.HeapErrorHandler
end.
