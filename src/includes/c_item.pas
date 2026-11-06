{ Items: the flag bits of TItemTemplate.flags, the itemTypes rows the code names, the most items a character carries,
  and the marker of an empty item template. }
unit C_Item;

interface

const
  { TItemTemplate.flags: never joined with a like item }
  NOT_JOINABLE = $20;
  { TItemTemplate.flags: left out of the treasure PostCbt takes from the fallen }
  NOT_TREASURE = $40;
  { TItemTemplate.flags: the item is readied }
  READIED = $80;
  { the itemTypes rows the code names }
  { CombatAi scores both grenades, EffHndlr's handlers block them }
  STUN_GRENADE_TYPE = 35;
  DAZZLE_GRENADE_TYPE = 36;
  { the Sonic Stunner's itemTypes row: CharHlp's WeaponAdjust adds no plus to its damage, CombatAi scores it by whether
    the target is stunned }
  SONIC_STUNNER_TYPE = 15;
  { itemTypes rows CbtActs animates and CombatAi scores }
  PLASMA_THROWER_TYPE = 17;
  ROCKET_LAUNCHER_TYPE = 18;
  { the most items a character carries: Shop takes a bought copy back past it, and ViewChar offers Halve only below it }
  MAX_CARRIED_ITEMS = 16;
  { the itemType of an empty itemTemplates row: EclMenu's LoadItemTemplates fills the table with it }
  EMPTY_TEMPLATE = 255;

implementation

end.
