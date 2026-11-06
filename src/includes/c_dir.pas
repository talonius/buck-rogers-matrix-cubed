{ The eight compass directions and CENTER. GDConsts' dirStepX and dirStepY are indexed by them, and GDConsts'
  directionByDelta, GDConsts' joystickZones and GDConsts' cloudDir hold them. }
unit C_Dir;

interface

const
  { the directions, dirStepX's and dirStepY's index, clockwise from north; the 3-D view's partyPosition.facing takes the
    four even ones }
  NORTH = 0;
  NORTHEAST = 1;
  EAST = 2;
  SOUTHEAST = 3;
  SOUTH = 4;
  SOUTHWEST = 5;
  WEST = 6;
  NORTHWEST = 7;
  { no direction: dirStepX[8] and dirStepY[8] are 0, and directionByDelta gives it for a step of no change }
  CENTER = 8;

implementation

end.
