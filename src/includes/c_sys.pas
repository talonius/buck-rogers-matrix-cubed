{ The ship systems, TShipRec.systemNow's index, and ANY_SYSTEM, ShipCbt's let-the-dice-pick hit target. }
unit C_Sys;

interface

const
  { TShipRec.systemNow index, as shipSystemNames names them }
  HULL = 0;
  SENSORS = 1;
  CONTROL = 2;
  FUEL = 4;
  ENGINES = 5;
  { systemShortNames' last entry: the weapon mounts, which systemNow has no entry for }
  WEAPONS = 6;

implementation

end.
