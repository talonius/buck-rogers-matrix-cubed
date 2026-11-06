{ The 3-D map's empty markers: no map loaded, an empty wall-set cache slot, and no fixed position readout. }
unit C_Map;

interface

const
  { zone 0's mapId when no 3-D map is loaded: EclVm's LOAD FILES sets it for that operand, and SaveLoad's LoadGame then
    loads no map }
  NO_GEO_MAP = 127;
  { zone 0's readoutX: the status line reads the party's own square; CharHlp, MapView }
  NO_READOUT = 255;
  { TWallSet.fileId and slot of an empty wall-set cache slot: GameInit and EclVm's LOAD PIECES empty slots with them }
  NO_WALL_SET_FILE = -1;
  NO_WALL_SET_SLOT = 65535;

implementation

end.
