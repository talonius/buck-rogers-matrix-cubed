{ Ground combat's limits: the combatant slots, the party's size and the icon slots past it, how long an idle combat
  lasts, the bits of a combat icon's size, and the aiming mode that attacks. }
unit C_Combat;

interface

const
  { the ground combat slots, from 1, which bound the per-combatant tables }
  MAX_COMBATANTS = 72;
  { zone 1's partyCount at most: CharGen's AddCharacterMenu and SaveLoad's AddCreatureToParty add no one past it }
  MAX_PARTY_SIZE = 8;
  { nextCreatureIconSlot as EclMenu's EclInit and EclVm's EclClearMonsters set it }
  FIRST_CREATURE_ICON_SLOT = 8;
  { rounds without an attack after which ground combat ends: CombatSt starts combatEndRound at it, CbtActs moves it on
    at each attack }
  IDLE_ROUNDS = 15;
  { TCharRecord.iconDimensions' bits holding the combat icon's size, as CbtMap and CbtActs read it }
  ICON_SIZE_MASK = $7F;
  { CbtActs' CombatAimMenu's and ManualAimCursor's mode: the target chosen is attacked }
  AIM_ATTACK = 1;

implementation

end.
