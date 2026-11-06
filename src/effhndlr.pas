{ The combat effect handlers. GameInit calls InitEffectHandlers to fill GDVars' effectHandlers, one handler per effect
  number, and FxEngine's CallEffectHandler calls through it. Each handler is named for what its body does; one whose
  body is empty is named for the effect number it serves, as EffNone is. A test of "the weapon" reads currentCharacter's
  readied weapon. EffSpitAcid's combat line is GDConsts.acidMessage. }
{$O+,F+,I-}
unit EffHndlr;

interface

uses Types, C_Item, C_Status, GDConsts, GDVars, FxEngine, CbtActs, CharHlp, CbtMap, TextRend,
  Music, Blit, C_Effect, C_WClass, C_Attack, C_Save, C_Equip;

{ Fills effectHandlers[1..32], each effect number's handler. }
procedure InitEffectHandlers;

{ Helpless effect: ends the owner's combat actions.
  @param(owner The effect's owner.)
  @param(effect The effect's node.)
  @param(isRemoved Set as the effect is removed.) }
procedure EffHelpless(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Ends the owner's combat actions, but not as the effect is removed.
  @param(owner The effect's owner.)
  @param(effect Unused.)
  @param(isRemoved Set as the effect is removed.) }
procedure EffScared(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Blocks any new effect and caps the effect damage at the owner's hit points.
  @param(owner The effect's owner.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffUnkillable(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Does nothing.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffNone(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Blinds the owner: takes 4 off the attack roll, both armor classes and the saving-throw roll, but not as the effect is
  removed.
  @param(owner The effect's owner.)
  @param(effect Unused.)
  @param(isRemoved Set as the effect is removed.) }
procedure EffBlind(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Ends the owner's combat actions (EffEndActions).
  @param(owner The effect's owner.)
  @param(effect The effect's node.)
  @param(isRemoved Set as the effect is removed.) }
procedure EffStunned(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Does nothing.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffNoneB(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Blocks the Scared effect.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffBlockScared(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Does nothing.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffNoneC(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Cancels a hit from a microwave weapon.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffImmuneToMicrowave(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Blocks the Helpless effect.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffBlockHelpless(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Cancels a hit from a rocket weapon.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffImmuneToRocket(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Blocks a new effect while the weapon is a Dazzle Grenade.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffBlockDazzleGrenade(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Blocks a new effect while the weapon is a sonic weapon, the Sonic Stunner, or a Stun Grenade.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffBlockStunWeapons(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Cancels a hit from a heat or plasma weapon.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffImmuneToHeatAndPlasma(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Cancels a hit from a laser weapon.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffImmuneToLaser(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Dodges, half the time, a slug-weapon hit from beyond 1 cell, canceling it and taking it off hitCounts[1].
  @param(owner The effect's owner.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffDodgeSlugHits(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Zeroes, half the time, the damage of a ranged hit, from a slug weapon through a heat weapon, from beyond 1 cell.
  @param(owner The effect's owner.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffResistRangedHits(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Zeroes, half the time, the damage of a melee hit.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffResistMeleeHits(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Poisons the owner's target, making it dizzy ('is poisoned'), unless it makes saving throw 1 against the effect's
  strength.
  @param(owner The effect's owner.)
  @param(effect The effect's node.)
  @param(isRemoved Unused.) }
procedure EffDizzyingPoison(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Halves the movement and attack rates, but not as the effect is removed.
  @param(owner Unused.)
  @param(effect Unused.)
  @param(isRemoved Set as the effect is removed.) }
procedure EffDizzy(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Kills the owner's target as poisoned when it fails saving throw 1 against the effect's strength.
  @param(owner The effect's owner.)
  @param(effect The effect's node.)
  @param(isRemoved Unused.) }
procedure EffLethalPoison(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Strikes an adjacent foe: an enabled enemy target within 1 cell takes 8 damage, or 4 when it makes saving throw 6.
  @param(owner The effect's owner.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffStrikeAdjacent(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

{ Spits acid at an enabled enemy target within 12 cells, with a 30% chance of 2d8 damage. Note: it inflicts the damage
  itself and then hands it to CbtActs' ProcessAttackResult, which inflicts it again, so a hit counts twice.
  @param(owner The effect's owner.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffSpitAcid(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);

implementation

const
  { TItemType.weaponClass of the Heat Gun }
  WEAPON_CLASS_HEAT = 5;
  { TItemType.weaponClass of the Sonic Stunner }
  WEAPON_CLASS_SONIC = 6;

{ Clears pendingEffectId, effectDamage and currentAttackRoll.
  @param(which The mode to clear only while it is set, or 0 to clear whatever is set.) }
procedure ClearEffectMode(which: Byte);
begin
  if (which = 0) or (GDVars.pendingEffectId = which) then begin
    GDVars.effectDamage := 0;
    GDVars.pendingEffectId := 0;
    GDVars.currentAttackRoll := 0
  end
end;

{ Ends the creature's actions for the round.
  @param(owner The creature carrying the effect.)
  @param(effect Unused.)
  @param(isRemoved Unused.) }
procedure EffEndActions(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
{ Unused in this version; see the other implementations of this routine. }
var ignored: Boolean;
begin
  ignored := CharHlp.EndActions(owner)
end;

procedure EffHelpless(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
begin EffHndlr.EffEndActions(owner, effect, isRemoved) end;

procedure EffScared(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
{ Unused in this version; see the other implementations of this routine. }
var ignored: Boolean;
begin
  if not isRemoved then
    ignored := CharHlp.EndActions(owner)
end;

procedure EffUnkillable(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
begin
  GDVars.pendingEffectId := 0;
  if GDVars.effectDamage > owner^.hitPoints then
    GDVars.effectDamage := Lo(owner^.hitPoints)
end;

procedure EffNone(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean); begin end;

procedure EffBlind(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
begin
  if not isRemoved then begin
    Dec(GDVars.currentAttackRoll, 4);
    Dec(owner^.armorClass[0], 4);
    Dec(owner^.armorClass[1], 4);
    Dec(GDVars.saveRoll, 4)
  end
end;

procedure EffStunned(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
begin EffHndlr.EffEndActions(owner, effect, isRemoved) end;

procedure EffNoneB(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean); begin end;

procedure EffBlockScared(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
begin if GDVars.pendingEffectId = C_Effect.SCARED then EffHndlr.ClearEffectMode(0) end;

procedure EffNoneC(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean); begin end;

procedure EffImmuneToMicrowave(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var weapon: Types.PItemRec;
begin
  weapon := GDVars.currentCharacter^.equipped[C_Equip.WEAPON];
  if (weapon <> nil) and (GDVars.itemTypes[weapon^.template.itemType].weaponClass = C_WClass.MICROWAVE) then
    EffHndlr.ClearEffectMode(0)
end;

procedure EffBlockHelpless(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
begin if GDVars.pendingEffectId = C_Effect.HELPLESS then EffHndlr.ClearEffectMode(0) end;

procedure EffImmuneToRocket(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var weapon: Types.PItemRec;
begin
  weapon := GDVars.currentCharacter^.equipped[C_Equip.WEAPON];
  if (weapon <> nil) and (GDVars.itemTypes[weapon^.template.itemType].weaponClass = C_WClass.ROCKET) then
    EffHndlr.ClearEffectMode(0)
end;

procedure EffBlockDazzleGrenade(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var weapon: Types.PItemRec;
begin
  weapon := GDVars.currentCharacter^.equipped[C_Equip.WEAPON];
  if (weapon <> nil) and (weapon^.template.itemType = C_Item.DAZZLE_GRENADE_TYPE) then EffHndlr.ClearEffectMode(0)
end;

procedure EffBlockStunWeapons(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var weapon: Types.PItemRec;
begin
  weapon := GDVars.currentCharacter^.equipped[C_Equip.WEAPON];
  if (weapon <> nil) and
      ((GDVars.itemTypes[weapon^.template.itemType].weaponClass = EffHndlr.WEAPON_CLASS_SONIC) or
       (weapon^.template.itemType = C_Item.STUN_GRENADE_TYPE)) then
    EffHndlr.ClearEffectMode(0)
end;

procedure EffImmuneToHeatAndPlasma(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var weapon: Types.PItemRec;
    weaponClass: Byte;
begin
  weapon := GDVars.currentCharacter^.equipped[C_Equip.WEAPON];
  if weapon <> nil then begin
    weaponClass := GDVars.itemTypes[weapon^.template.itemType].weaponClass;
    if (weaponClass = EffHndlr.WEAPON_CLASS_HEAT) or
        (weaponClass = C_WClass.PLASMA) then EffHndlr.ClearEffectMode(0)
  end
end;

procedure EffImmuneToLaser(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var weapon: Types.PItemRec;
begin
  weapon := GDVars.currentCharacter^.equipped[C_Equip.WEAPON];
  if (weapon <> nil) and (GDVars.itemTypes[weapon^.template.itemType].weaponClass = C_WClass.LASER) then
    EffHndlr.ClearEffectMode(0)
end;

procedure EffDodgeSlugHits(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var weapon: Types.PItemRec;
begin
  weapon := GDVars.currentCharacter^.equipped[C_Equip.WEAPON];
  if (weapon <> nil) and (GDVars.itemTypes[weapon^.template.itemType].weaponClass = C_WClass.SLUG) and
      (CharHlp.CalcDistance(GDVars.currentCharacter, owner) > 1) and CharHlp.PercentileRoll(50) then begin
    CharHlp.PrintCreatureMessage(owner, 'dodges it', 10, True);
    EffHndlr.ClearEffectMode(0);
    Dec(GDVars.hitCounts[1])
  end
end;

procedure EffResistRangedHits(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var weapon: Types.PItemRec;
begin
  weapon := GDVars.currentCharacter^.equipped[C_Equip.WEAPON];
  if (weapon <> nil) and (GDVars.itemTypes[weapon^.template.itemType].weaponClass >= C_WClass.SLUG) and
      (GDVars.itemTypes[weapon^.template.itemType].weaponClass <= EffHndlr.WEAPON_CLASS_HEAT) and
      (CharHlp.CalcDistance(GDVars.currentCharacter, owner) > 1) and CharHlp.PercentileRoll(50) then
    GDVars.effectDamage := 0
end;

procedure EffResistMeleeHits(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var weapon: Types.PItemRec;
begin
  weapon := GDVars.currentCharacter^.equipped[C_Equip.WEAPON];
  if (weapon <> nil) and (GDVars.itemTypes[weapon^.template.itemType].weaponClass = C_WClass.MELEE) and
      CharHlp.PercentileRoll(50) then
    GDVars.effectDamage := 0
end;

procedure EffDizzyingPoison(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var hasSaved: Boolean;
begin
  GDVars.activeTarget := owner^.combatAddr^.target;
  hasSaved := FxEngine.RollSavingThrow(GDVars.activeTarget, 1, effect^.strength);
  FxEngine.AddEffectWithMessage(GDVars.activeTarget, C_Effect.DIZZY, 0, 0, 0, C_Save.CANCELS, Byte(hasSaved),
                                'is poisoned');
  TextRend.PauseOnly;
  if CharHlp.HasEffect(GDVars.activeTarget, C_Effect.DIZZY, effect) then
    CharHlp.PrintCreatureMessage(GDVars.activeTarget, 'is dizzy', 10, True)
end;

procedure EffDizzy(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
begin
  if isRemoved then Exit;
  GDVars.movementRate := GDVars.movementRate div 2;
  GDVars.attackRate := GDVars.attackRate div 2
end;

procedure EffLethalPoison(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
var hasSaved: Boolean;
begin
  GDVars.activeTarget := owner^.combatAddr^.target;
  hasSaved := FxEngine.RollSavingThrow(GDVars.activeTarget, 1, effect^.strength);
  if not hasSaved then
    FxEngine.KillCreature(GDVars.activeTarget, C_Status.POISONED, 'is poisoned')
end;

procedure EffStrikeAdjacent(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
begin
  GDVars.activeTarget := owner^.combatAddr^.target;
  if (GDVars.activeTarget <> nil) and (CharHlp.CalcDistance(owner, GDVars.activeTarget) <= 1) and
      (GDVars.activeTarget^.enabled <> 0) and
      (GDVars.activeTarget^.hostile <> owner^.hostile) then begin
    if FxEngine.RollSavingThrow(GDVars.activeTarget, 6, 0) then
      GDVars.effectDamage := 4
    else
      GDVars.effectDamage := 8;
    GDVars.attackManner := C_Attack.PLAIN;
    CbtActs.ProcessAttackResult(owner, GDVars.activeTarget, GDVars.effectDamage, GDVars.effectDamage, True);
    GDVars.frameScriptDone := True
  end
end;

procedure EffSpitAcid(var owner: Types.PCharRecord; effect: Types.PEffectRec; isRemoved: Boolean);
begin
  GDVars.activeTarget := owner^.combatAddr^.target;
  if (GDVars.activeTarget <> nil) and (CharHlp.CalcDistance(owner, GDVars.activeTarget) <= 12) and
      (GDVars.activeTarget^.enabled <> 0) and
      (GDVars.activeTarget^.hostile <> owner^.hostile) then begin
    GDVars.frameScriptDone := True;
    CharHlp.CombatPrintCreatureInfo(owner);
    owner^.combatAddr^.direction := CbtMap.DirectionToward(owner, GDVars.activeTarget);
    CbtMap.SetCreatureFacing(owner, owner^.combatAddr^.direction, 1, 0);
    owner^.combatAddr^.target := GDVars.activeTarget;
    CharHlp.PrintCreatureMessage(owner, GDConsts.acidMessage, 10, False);
    Music.SendSoundCommand(GDConsts.launchSound);
    Blit.BuildIconFrames(18);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(owner), CbtMap.CombatCellY(owner),
                                    CbtMap.CombatCellX(GDVars.activeTarget),
                                    CbtMap.CombatCellY(GDVars.activeTarget), 4, 45);
    if CharHlp.PercentileRoll(30) then begin
      GDVars.effectDamage := CharHlp.RollDice(2, 8);
      CharHlp.InflictDamage(GDVars.activeTarget, GDVars.effectDamage)
    end else
      GDVars.effectDamage := 0;
    GDVars.attackManner := C_Attack.PLAIN;
    CbtActs.ProcessAttackResult(owner, GDVars.activeTarget, GDVars.effectDamage, GDVars.effectDamage,
                                GDVars.effectDamage > 0)
  end
end;

procedure InitEffectHandlers;
begin
  GDVars.effectHandlers[C_Effect.HELPLESS] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[C_Effect.SCARED] := EffHndlr.EffScared;
  GDVars.effectHandlers[C_Effect.UNKILLABLE] := EffHndlr.EffUnkillable;
  GDVars.effectHandlers[4] := EffHndlr.EffNone;
  for GDVars.loopIndex := 5 to 12 do GDVars.effectHandlers[GDVars.loopIndex] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[C_Effect.BLIND] := EffHndlr.EffBlind;
  GDVars.effectHandlers[C_Effect.STUNNED] := EffHndlr.EffStunned;
  GDVars.effectHandlers[15] := EffHndlr.EffNoneB;
  GDVars.effectHandlers[C_Effect.BLOCK_SCARED] := EffHndlr.EffBlockScared;
  GDVars.effectHandlers[17] := EffHndlr.EffNoneC;
  GDVars.effectHandlers[C_Effect.IMMUNE_TO_MICROWAVE] := EffHndlr.EffImmuneToMicrowave;
  GDVars.effectHandlers[C_Effect.BLOCK_HELPLESS] := EffHndlr.EffBlockHelpless;
  GDVars.effectHandlers[C_Effect.IMMUNE_TO_ROCKET] := EffHndlr.EffImmuneToRocket;
  GDVars.effectHandlers[C_Effect.BLOCK_DAZZLE_GRENADE] := EffHndlr.EffBlockDazzleGrenade;
  GDVars.effectHandlers[C_Effect.BLOCK_STUN_WEAPONS] := EffHndlr.EffBlockStunWeapons;
  GDVars.effectHandlers[C_Effect.IMMUNE_TO_HEAT_AND_PLASMA] := EffHndlr.EffImmuneToHeatAndPlasma;
  GDVars.effectHandlers[C_Effect.IMMUNE_TO_LASER] := EffHndlr.EffImmuneToLaser;
  GDVars.effectHandlers[C_Effect.DODGE_SLUG_HITS] := EffHndlr.EffDodgeSlugHits;
  GDVars.effectHandlers[C_Effect.RESIST_RANGED_HITS] := EffHndlr.EffResistRangedHits;
  GDVars.effectHandlers[C_Effect.RESIST_MELEE_HITS] := EffHndlr.EffResistMeleeHits;
  GDVars.effectHandlers[C_Effect.DIZZYING_POISON] := EffHndlr.EffDizzyingPoison;
  GDVars.effectHandlers[C_Effect.DIZZY] := EffHndlr.EffDizzy;
  GDVars.effectHandlers[C_Effect.LETHAL_POISON] := EffHndlr.EffLethalPoison;
  GDVars.effectHandlers[C_Effect.STRIKE_ADJACENT] := EffHndlr.EffStrikeAdjacent;
  GDVars.effectHandlers[C_Effect.SPIT_ACID] := EffHndlr.EffSpitAcid
end;

begin
end.
