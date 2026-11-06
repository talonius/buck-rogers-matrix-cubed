{ The weapon classes, TItemType.weaponClass's values, and FIRST_AREA_WEAPON, the first of the area weapons. }
unit C_WClass;

interface

const
  { ITEMS rows 1..4, 8 and 19 }
  MELEE = 0;
  { D.R. X-bow, Needle Gun and Bolt Gun }
  SLUG = 1;
  { Rocket Pistol and Rocket Rifle }
  ROCKET = 2;
  { Laser Pistol and Laser Rifle }
  LASER = 3;
  MICROWAVE = 4;
  { ITEMS row 18; it, the grenades and the plasma thrower are the area weapons }
  ROCKET_LAUNCHER = 7;
  { ITEMS rows 32..38 }
  GRENADE = 8;
  { ITEMS row 17, Plasma Thrwr }
  PLASMA = 9;
  { it, the grenades and the plasma thrower are the area weapons; CharHlp, CombatAi }
  FIRST_AREA_WEAPON = C_WClass.ROCKET_LAUNCHER;

implementation

end.
