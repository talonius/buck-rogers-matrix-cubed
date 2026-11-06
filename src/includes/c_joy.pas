{ The joystick: how a calibration samples the stick, and the zone a centered stick reads as. }
unit C_Joy;

interface

const
  { readings a calibration takes at each position: Joystick's CalibrateJoystick and CharGen's copy of it }
  CALIBRATION_SAMPLES = 20;
  { Joystick's JoyZone result when the stick is centered, the joystick is off or the stick cannot be read }
  NO_ZONE = 8;

implementation

end.
