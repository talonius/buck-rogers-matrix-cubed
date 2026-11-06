{ The effect trigger conditions: the points in combat at which FxEngine's TriggerEffectsWithCondition runs effect
  handlers. }
unit C_Cond;

interface

const
  { a damaging hit from attack slot 1, for the attacker; CbtActs adds the attack slot to 1 }
  HIT_PHASE_1 = 2;
  { CbtActs' CalcWeaponDamage, for the attacker }
  WEAPON_DAMAGE_ATTACKER = 4;
  { the same, for the defender }
  WEAPON_DAMAGE_DEFENDER = 5;
  { Combat's CreatureAction, before the initiative test }
  TURN_START = 7;
  { an attack roll or a launch, for the attacker }
  ATTACK_ROLL_ATTACKER = 10;
  { after the defender's stats are rebuilt, before its armor class is read }
  DEFENDER_ARMOR_CLASS = 11;
  { a character disabled by damage or killed }
  HIT_POINTS_ZERO = 13;
  { CombatAi's move-and-attack, as it starts }
  MONSTER_SPECIAL = 14;
  { Combat's CreatureAction, before the combatant acts }
  ACTION_START = 15;
  { CombatAi's morale check }
  MORALE_CHECK = 17;
  { attackRate is being set }
  MOVE_ATTACK_RATE = 18;

implementation

end.
