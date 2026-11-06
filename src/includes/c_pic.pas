{ Pictures and animations: the ids that name none, the empty portrait cache slot, the color they are transparent in, and
  the DAC ranges their palettes load into. }
unit C_Pic;

interface

const
  { light magenta, the color tile sets, portrait animations and the wilderness cursor are transparent in: Sym8x8 and
    GameInit load theirs keyed on it, Portrait keys each frame on it and swaps it with 0 in a sprite archive's }
  KEY_COLOR = 13;
  { picArcId and savedPicArcId with no animation loaded; Portrait's LoadAnimation also loads none for this resourceId }
  NO_ANIMATION = 255;
  { bigPictureId with no big picture loaded }
  NO_BIG_PICTURE = 255;
  { TPortraitCacheSlot.pictureId of an empty slot: GameInit, CombatSt and Explore set it }
  EMPTY_PORTRAIT_SLOT = 255;
  { the DAC ranges, first register and count, that more than one unit loads or shadows }
  { $10..$1F, reloaded from viewPalette after FixMain's title menu: GameInit shadows it, and Intro's credits load it }
  VIEW_DAC_FIRST = $10;
  VIEW_DAC_COUNT = 16;
  { $20..$FF, where an animation or the big picture loads outside the orbit map: Portrait, and OrbitMap's and ShipCbt's
    ship pictures }
  PICTURE_DAC_FIRST = $20;
  PICTURE_DAC_COUNT = 224;
  { $40..$FF, where Portrait's LoadAnimation loads an animation on the orbit map, and SaveLoad's LoadShipData the enemy
    ship's picture }
  ORBIT_DAC_FIRST = $40;
  ORBIT_DAC_COUNT = 192;
  { $20..$B3, the viewPalette entries View3D's LoadWallSet fills after a wall set and MapView's DisplayMapView loads
    into the DAC }
  WALL_DAC_FIRST = $20;
  WALL_DAC_COUNT = 148;
  { $60..$8F: MapTiles' LoadIconAnim shadows CHARS icons' colors into combatPalette there, and CharGen's icon editor
    loads it from picturePalette }
  CHARS_ICON_DAC_FIRST = $60;
  CHARS_ICON_DAC_COUNT = 48;

implementation

end.
