{ The orbit view's rocket tiles, one for each heading. }
unit C_Orbit;

interface

const
  { TOrbitView.rocketIcon for the rocket heading north, as GameInit starts it; the next seven headings counterclockwise
    follow, to Explore's LAST_ROCKET_ICON }
  FIRST_ROCKET_ICON = 87;
  { screen column of the orbit map's left edge }
  MAP_LEFT = 17;
  { screen row of its top edge }
  MAP_TOP = 1;
  { the center body's map cell, which Explore keeps the rocket off }
  CENTER_X = 11;
  CENTER_Y = 10;

implementation

end.
