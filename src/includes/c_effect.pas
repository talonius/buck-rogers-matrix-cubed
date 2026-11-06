{ The effect numbers a creature can be under. GDConsts' postCombatClearedEffects lists five of them. }
unit C_Effect;

interface

const
  { Effect numbers, TEffectRec.effectId and effectHandlers' index; effectStatusNames names five of them, and the rest
    are named for what EffHndlr's handler for each does. 4..12, 15 and 17 have no constant: InitEffectHandlers files
    handlers under them, and FxEngine's TriggerEffectsWithCondition also runs 17, whose handler is empty }
  HELPLESS = 1;
  SCARED = 2;
  { EffHndlr's EffUnkillable: blocks every new effect and caps effectDamage at the holder's hit points }
  UNKILLABLE = 3;
  BLIND = 13;
  STUNNED = 14;
  BLOCK_SCARED = 16;
  IMMUNE_TO_MICROWAVE = 18;
  BLOCK_HELPLESS = 19;
  IMMUNE_TO_ROCKET = 20;
  BLOCK_DAZZLE_GRENADE = 21;
  BLOCK_STUN_WEAPONS = 22;
  IMMUNE_TO_HEAT_AND_PLASMA = 23;
  IMMUNE_TO_LASER = 24;
  DODGE_SLUG_HITS = 25;
  RESIST_RANGED_HITS = 26;
  RESIST_MELEE_HITS = 27;
  DIZZYING_POISON = 28;
  DIZZY = 29;
  LETHAL_POISON = 30;
  STRIKE_ADJACENT = 31;
  SPIT_ACID = 32;

implementation

end.
