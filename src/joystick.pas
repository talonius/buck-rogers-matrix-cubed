{ Game-port joystick input and calibration.

  CalibrateJoystick samples stick 1 at the center and two corners into GDVars.joystickCalibration; JoyZone turns a
  reading into a compass zone through GDConsts.joystickZones, JoyButton tests one button, and GetJoystick combines both
  for GameIo's key input and MenuCore's wait for button release. ReadJoystick is the sampling leaf in joystick.asm.
  CharGen has its own copy of CalibrateJoystick. }
{$O+,F+,I-,R-,S-}
unit Joystick;

interface

{ Clears the calibration, and clears isJoystickOn when stick 1 does not answer. }
procedure ProbeJoystick;

{ Reads a joystick from the game port, timing each axis's capacitor discharge.
  @param(joy Joystick 1 or 2; any other number fails.)
  @param(xRaw Receives the X axis count.)
  @param(yRaw Receives the Y axis count.)
  @param(buttons Receives the button bits, inverted so a set bit is a pressed button.)
  @returns(True when the read succeeded; False for a bad joystick number or when an axis times out.) }
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;

{ Classifies a stick's position.
  @param(joy The stick, 1 or 2.)
  @returns(The zone, 0..7 clockwise from up, or NO_ZONE.) }
function JoyZone(joy: Byte): Byte;

{ Tests one button.
  @param(joy The stick, 1 or 2.)
  @param(button The button, 1 or 2.)
  @returns(True while the button is down; False while the joystick is off or the stick cannot be read.) }
function JoyButton(joy, button: Byte): Boolean;

{ Reads stick 1.
  @param(button 2 while button 2 is down, else 1 while button 1 is, else 0.)
  @param(zone JoyZone's result.) }
procedure GetJoystick(var button: Integer; var zone: Byte);

{ Measures stick 1 at the center and at the upper-left and lower-right corners, sets the zone thresholds between them,
  then turns joystick use on. A failed read, or no button 1 within 20000 readings, aborts with a message and keeps the
  thresholds set so far. }
procedure CalibrateJoystick;

implementation

uses Crt, GDConsts, GDVars, C_Joy;

{$L JOYSTICK.OBJ}
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;
  external;

procedure ProbeJoystick;
var
  x: Word;
  y: Word;
  buttons: Byte;
begin
  FillChar(GDVars.joystickCalibration, SizeOf(GDVars.joystickCalibration), 0);
  if GDVars.isJoystickOn then
    GDVars.isJoystickOn := Joystick.ReadJoystick(1, x, y, buttons);
end;

function JoyZone(joy: Byte): Byte;
var
  x: Word;
  y: Word;
  col: Integer;
  row: Integer;
  buttons: Byte;
  { Unused in this version; see the other implementations of this routine. }
  threshold: array[0..1] of Byte;
begin
  JoyZone := C_Joy.NO_ZONE;
  if not GDVars.isJoystickOn then Exit;
  if not Joystick.ReadJoystick(joy, x, y, buttons) then Exit;
  col := 0;
  for GDVars.loopIndex := 1 to 5 do
    if GDVars.joystickCalibration[joy].x[GDVars.loopIndex] < x then col := GDVars.loopIndex;
  row := 0;
  for GDVars.loopIndex := 1 to 5 do
    if GDVars.joystickCalibration[joy].y[GDVars.loopIndex] < y then row := GDVars.loopIndex;
  JoyZone := GDConsts.joystickZones[row, col];
end;

function JoyButton(joy, button: Byte): Boolean;
var
  mask: Byte;
  x: Word;
  y: Word;
  buttons: Byte;
begin
  JoyButton := False;
  if not GDVars.isJoystickOn then Exit;
  mask := 0;
  buttons := 0;
  if Joystick.ReadJoystick(joy, x, y, buttons) then
    case joy of
      1: case button of
           1: mask := 1;
           2: mask := 2;
         end;
      2: case button of
           1: mask := 4;
           2: mask := 8;
         end;
    end;
  JoyButton := (buttons and mask) > 0;
end;

procedure GetJoystick(var button: Integer; var zone: Byte);
begin
  button := 0;
  if Joystick.JoyButton(1, 2) then
    button := 2
  else if Joystick.JoyButton(1, 1) then
    button := 1;
  zone := Joystick.JoyZone(1);
end;

procedure CalibrateJoystick;
var
  sumX: Word;
  sumY: Word;
  ok: Boolean;
  x: Word;
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  reading: Byte;
  j: Word;
  buttons: Byte;
begin
  Joystick.ProbeJoystick;
  if not GDVars.isJoystickOn then Exit;
  sumX := 0;
  sumY := 0;
  for j := 1 to C_Joy.CALIBRATION_SAMPLES do begin
    ok := Joystick.ReadJoystick(1, x, y, buttons);
    Inc(sumX, x);
    Inc(sumY, y);
  end;
  GDVars.joystickCalibration[1].x[3] := sumX div C_Joy.CALIBRATION_SAMPLES;
  GDVars.joystickCalibration[1].y[3] := sumY div C_Joy.CALIBRATION_SAMPLES;
  repeat
    ClrScr;
    WriteLn('Push JOYSTICK #1 to the extreme upper left position and press BUTTON #1.');
    j := 0;
    repeat
      ok := Joystick.ReadJoystick(1, x, y, buttons);
      Inc(j);
    until (j > 20000) or (ok and ((buttons and 1) <> 0));
    if j > 20000 then begin
      ClrScr;
      WriteLn('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000);
      Exit;
    end;
    sumX := 65535;
    sumY := 65535;
    for GDVars.loopIndex := 1 to C_Joy.CALIBRATION_SAMPLES do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x < sumX then sumX := x;
          if y < sumY then sumY := y;
        end;
      end else begin
        ClrScr;
        WriteLn('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000);
        Exit;
      end;
  until ok;
  GDVars.joystickCalibration[1].x[0] := sumX;
  GDVars.joystickCalibration[1].x[1] :=
    (GDVars.joystickCalibration[1].x[3] - GDVars.joystickCalibration[1].x[0]) div 3 +
    GDVars.joystickCalibration[1].x[0];
  GDVars.joystickCalibration[1].x[2] :=
    (GDVars.joystickCalibration[1].x[3] - GDVars.joystickCalibration[1].x[0]) * 2 div 3 +
    GDVars.joystickCalibration[1].x[0];
  GDVars.joystickCalibration[1].y[0] := sumY;
  GDVars.joystickCalibration[1].y[1] :=
    (GDVars.joystickCalibration[1].y[3] - GDVars.joystickCalibration[1].y[0]) div 3 +
    GDVars.joystickCalibration[1].y[0];
  GDVars.joystickCalibration[1].y[2] :=
    (GDVars.joystickCalibration[1].y[3] - GDVars.joystickCalibration[1].y[0]) * 2 div 3 +
    GDVars.joystickCalibration[1].y[0];
  repeat until not Joystick.JoyButton(1, 1);
  repeat
    ClrScr;
    WriteLn('Push JOYSTICK #1 to the extreme lower right position and press BUTTON #1.');
    j := 0;
    repeat
      ok := Joystick.ReadJoystick(1, x, y, buttons);
      Inc(j);
    until (j > 20000) or (ok and ((buttons and 1) <> 0));
    if j > 20000 then begin
      ClrScr;
      WriteLn('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000);
      Exit;
    end;
    sumX := 0;
    sumY := 0;
    for GDVars.loopIndex := 1 to C_Joy.CALIBRATION_SAMPLES do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x > sumX then sumX := x;
          if y > sumY then sumY := y;
        end;
      end else begin
        ClrScr;
        WriteLn('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000);
        Exit;
      end;
  until ok;
  GDVars.joystickCalibration[1].x[6] := sumX;
  GDVars.joystickCalibration[1].x[4] :=
    (GDVars.joystickCalibration[1].x[6] - GDVars.joystickCalibration[1].x[3]) div 3 +
    GDVars.joystickCalibration[1].x[3];
  GDVars.joystickCalibration[1].x[5] :=
    (GDVars.joystickCalibration[1].x[6] - GDVars.joystickCalibration[1].x[3]) * 2 div 3 +
    GDVars.joystickCalibration[1].x[3];
  GDVars.joystickCalibration[1].y[6] := sumY;
  GDVars.joystickCalibration[1].y[4] :=
    (GDVars.joystickCalibration[1].y[6] - GDVars.joystickCalibration[1].y[3]) div 3 +
    GDVars.joystickCalibration[1].y[3];
  GDVars.joystickCalibration[1].y[5] :=
    (GDVars.joystickCalibration[1].y[6] - GDVars.joystickCalibration[1].y[3]) * 2 div 3 +
    GDVars.joystickCalibration[1].y[3];
  GDVars.isJoystickOn := True;
end;

begin
end.
