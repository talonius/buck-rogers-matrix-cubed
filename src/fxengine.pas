{ The effects engine. It keeps each character's effect list, runs an effect's handler from GDVars' effectHandlers and
  the handlers a trigger condition names, rolls attacks and saving throws, deals non-weapon damage, takes creatures out
  of play, and clears the arena's lingering clouds (GDVars' areaEffects) as their countdowns run out. The THAC0
  modifiers it reads are zone 1 cells. }
{$F+,O+,S-,R-,V-,B-,I-}
unit FxEngine;

interface

uses Types, C_Status, C_Terr, GDConsts, GDVars, CharHlp, CbtMap, MenuCore, TextRend, Blit, Debug,
  C_Effect, C_Dir, C_Armor, C_Ifc, C_Diff, C_Side, C_Cond, C_Save;

{ Counts every cloud on the arena down a round. A cloud whose count has run out is cleared: each cell it covers gets
  back the terrain beneath it, or CORPSE_TERRAIN where downedCreatures holds a character on the cell. When one clears,
  the rest are laid again (LayAreaEffectMarkers) and 'The air clears a little...' is shown. }
procedure CountDownAreaEffects;

{ Shows message; unless the character is already dead or gone, gives it status, disables it with 0 hit points, clears
  its incapacitating effects, runs C_Cond.HIT_POINTS_ZERO, and takes its icon down while it stays disabled.
  @param(character The creature killed.)
  @param(status The status it is given.)
  @param(message The message shown after its name.) }
procedure KillCreature(character: Types.PCharRecord; status: Byte; message: Types.TString40);

{ Removes an effect from the character's list, running its handler first when the effect asks for that on removal.
  @param(character The character whose effect is removed.)
  @param(effectId The effect looked for when effect is nil; it also selects the handler.)
  @param(effect The node to remove, or nil for the first with effectId.) }
procedure RemoveEffect(character: Types.PCharRecord; effectId: Byte; effect: Types.PEffectRec);

{ When the character is enabled, stands in gas (as ProbeDirection reports), is not already helpless and lacks breathing
  protection in its armor flags, a failed saving throw 1 makes it helpless ('is helpless') for 1d6+1 and runs that
  effect's handler.
  @param(character The character on the cell.)
  @param(terrain Unused.) }
procedure ConsiderTerrainEffects(character: Types.PCharRecord; terrain: Byte);

{ A d20 roll with no attacker: 1 misses, 20 counts as 100, COND_ATTACK_ROLL_DEF runs for the defender, and the roll hits
  when roll + target exceeds the defender's armorClass[0].
  @param(defender The character attacked.)
  @param(target The value added to the roll.)
  @returns(True when the roll hits.) }
function AttackRollNoAttacker(defender: Types.PCharRecord; target: Byte): Boolean;

{ A d20 roll: 1 misses, 20 counts as 100, C_Cond.ATTACK_ROLL_ATTACKER and COND_ATTACK_ROLL_DEF run for the attacker and
  the defender, and the roll hits when roll + attackBonus + the side's THAC0 modifier (the party's shifted by the
  difficulty) reaches target.
  @param(attacker The character attacking.)
  @param(defender The character attacked.)
  @param(target The value the roll must reach.)
  @returns(True when the roll hits.) }
function AttackRoll(attacker, defender: Types.PCharRecord; target: Byte): Boolean;

{ Rolls a d20 saving throw: 1 fails, 20 saves; otherwise roll + modifier, after COND_SAVING_THROW, saves when it reaches
  the character's saves[saveType]. The result is also kept for later checks.
  @param(character The character saving.)
  @param(saveType The saving throw, an index into saves.)
  @param(modifier The value added to the roll.)
  @returns(True when the save is made.) }
function RollSavingThrow(character: Types.PCharRecord; saveType, modifier: Byte): Boolean;

{ CharHlp's RollDice, with count left in currentDiceCount.
  @param(count The number of dice.)
  @param(sides The faces per die.)
  @returns(The sum.) }
function RollDamageDice(count, sides: Byte): Byte;

{ Appends a new effect to the end of the character's list.
  @param(character The character given the effect.)
  @param(effectId The effect.)
  @param(minutes The duration.)
  @param(strength The effect's strength, read by its handler.)
  @param(onRemove True to run the effect's handler when it is removed.) }
procedure AddEffect(character: Types.PCharRecord; effectId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);

{ While the character is enabled: centers the combat map on it, shows message, disables it with status (0 hit points
  unless it is fleeing), takes it off the map, ends its actions (CharHlp's EndActions) and clears its incapacitating
  effects.
  @param(character The character taken out of play.)
  @param(status The status it is given.)
  @param(message The message shown after its name.) }
procedure PutOutOfPlayWithStatus(character: Types.PCharRecord; status: Byte; message: Types.TString40);

{ Removes C_Effect.SCARED, C_Effect.HELPLESS, C_Effect.STUNNED and C_Effect.DIZZY (incapacitatingEffects).
  @param(character The character cleared.) }
procedure RemoveIncapacitatingEffects(character: Types.PCharRecord);

{ Deals damage after COND_NON_WEAPON_DAMAGE and shows it; a character it disables 'Goes Down'.
  @param(character The character hurt.)
  @param(damage The damage before adjustment.)
  @param(saveReduction With hasSaved: C_Save.CANCELS or C_Save.HALVES.)
  @param(hasSaved True when the character made its saving throw.) }
procedure InflictNonWeaponDamage(character: Types.PCharRecord; damage, saveReduction: Byte; hasSaved: Boolean);

{ Gives the character an effect, or lengthens the one it has, and shows message when it is not empty.
  COND_EFFECT_IMMUNITY may cancel the effect, and so may a saved throw when saveReduction is C_Save.CANCELS; either way
  'is Unaffected' is shown instead.
  @param(character The character given the effect.)
  @param(effectId The effect.)
  @param(minutes The duration.)
  @param(strength The effect's strength, read by its handler.)
  @param(onRemove Set to run the effect's handler when it is removed.)
  @param(saveReduction C_Save.CANCELS when a made save cancels the effect.)
  @param(saved Set when the character's saving throw was made.)
  @param(message The message shown after its name, or empty.) }
procedure AddEffectWithMessage(character: Types.PCharRecord; effectId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveReduction, saved: Byte; message: Types.TString40);

{ Runs the handler of each effect the trigger condition names that the character has.
  @param(condition A C_Cond constant, or one of this unit's COND_ constants.)
  @param(character The character whose effects run.) }
procedure TriggerEffectsWithCondition(condition: Byte; var character: Types.PCharRecord);

{ Calls an effect's handler in effectHandlers, with the caller's character variable as the handler's owner.
  @param(effectId The effect whose handler is called.)
  @param(character The character the effect acts on.)
  @param(effect The effect's node, passed on to the handler.)
  @param(removed True as the effect is being removed.) }
procedure CallEffectHandler(effectId: Byte; var character: Types.PCharRecord; effect: Types.PEffectRec;
                            removed: Boolean);

{ Runs an effect's handler when the character has it.
  @param(character The character the effect acts on.)
  @param(effectId The effect.) }
procedure TriggerEffect(var character: Types.PCharRecord; effectId: Byte);

{ Lays each cloud's marker terrain on the arena cells it covers. }
procedure LayAreaEffectMarkers;

implementation

const
  { TriggerEffectsWithCondition's conditions this unit raises itself }
  { a damaging hit from attack slot 2, for the attacker }
  COND_HIT_PHASE_2 = 3;
  { InflictNonWeaponDamage, before the save reduces the damage }
  COND_NON_WEAPON_DAMAGE = 6;
  { AddEffectWithMessage: clearing pendingEffectId makes the character unaffected }
  COND_EFFECT_IMMUNITY = 9;
  { RollSavingThrow, before the roll is compared }
  COND_SAVING_THROW = 12;
  { an attack roll, for the defender }
  COND_ATTACK_ROLL_DEF = 16;
  { the animation AddEffectWithMessage plays as it stuns }
  STUN_ANIMATION = 17;
  KILLED_MESSAGE = 'is killed';
  UNAFFECTED_MESSAGE = 'is Unaffected';
  TAKES_PREFIX = 'takes ';
  POINTS_DAMAGE = ' points of damage ';
  ONE_POINT_DAMAGE = 'takes 1 point of damage ';
  GOES_DOWN = 'Goes Down';
  DYING_SUFFIX = ', and is Dying';
  AIR_CLEARS_MESSAGE = 'The air clears a little...';

procedure KillCreature(character: Types.PCharRecord; status: Byte; message: Types.TString40);
begin
  CharHlp.PrintCreatureMessage(character, message, 10, False);
  case character^.status of
    C_Status.DEAD_STATUS, C_Status.GONE: ;
  else begin
      character^.status := status;
      character^.enabled := 0;
      character^.hitPoints := 0;
      FxEngine.RemoveIncapacitatingEffects(character);
      FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_POINTS_ZERO, character);
      if character^.enabled = 0 then
        CbtMap.CreatureDowned(character);
      TextRend.PauseOnly;
      CharHlp.ClearMessageWindow;
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        MenuCore.DisplayParty(GDVars.currentCharacter)
    end
  end
end;

procedure RemoveEffect(character: Types.PCharRecord; effectId: Byte; effect: Types.PEffectRec);
var
  previous: Types.PEffectRec;
  node: Types.PEffectRec;
begin
  node := effect;
  if node = nil then begin
    node := character^.effectsAddr;
    while (node <> nil) and (node^.effectId <> effectId) do
      node := node^.next
  end;
  if node = nil then
    Exit;
  if node^.onRemove <> 0 then
    FxEngine.CallEffectHandler(effectId, character, node, True);
  if character^.effectsAddr = node then
    character^.effectsAddr := node^.next
  else begin
    previous := character^.effectsAddr;
    while (previous <> nil) and (previous^.next <> node) do
      previous := previous^.next;
    previous^.next := node^.next
  end;
  FreeMem(node, SizeOf(Types.TEffectRec))
end;

procedure TriggerEffect(var character: Types.PCharRecord; effectId: Byte);
var
  effect: Types.PEffectRec;
begin
  if CharHlp.HasEffect(character, effectId, effect) then
    FxEngine.CallEffectHandler(effectId, character, effect, False)
end;

procedure CallEffectHandler(effectId: Byte; var character: Types.PCharRecord; effect: Types.PEffectRec;
                            removed: Boolean);
begin
  GDVars.effectHandlers[effectId](character, effect, removed)
end;

procedure TriggerEffectsWithCondition(condition: Byte; var character: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
begin
  { conditions 0, 1, 8 and 19..22 are never raised }
  case condition of
    0: ;
    1: ;
    C_Cond.HIT_PHASE_1: ;
    FxEngine.COND_HIT_PHASE_2:
      begin
        FxEngine.TriggerEffect(character, C_Effect.DIZZYING_POISON);
        FxEngine.TriggerEffect(character, C_Effect.LETHAL_POISON)
      end;
    C_Cond.WEAPON_DAMAGE_ATTACKER: ;
    C_Cond.WEAPON_DAMAGE_DEFENDER:
      begin
        FxEngine.TriggerEffect(character, C_Effect.IMMUNE_TO_ROCKET); FxEngine.TriggerEffect(character,
            C_Effect.DODGE_SLUG_HITS);
        FxEngine.TriggerEffect(character, C_Effect.IMMUNE_TO_MICROWAVE); FxEngine.TriggerEffect(character,
            C_Effect.IMMUNE_TO_HEAT_AND_PLASMA);
        FxEngine.TriggerEffect(character, C_Effect.IMMUNE_TO_LASER); FxEngine.TriggerEffect(character,
            C_Effect.RESIST_RANGED_HITS);
        FxEngine.TriggerEffect(character, C_Effect.RESIST_MELEE_HITS); FxEngine.TriggerEffect(character,
            C_Effect.UNKILLABLE)
      end;
    FxEngine.COND_NON_WEAPON_DAMAGE:
      begin
        FxEngine.TriggerEffect(character, C_Effect.IMMUNE_TO_HEAT_AND_PLASMA); FxEngine.TriggerEffect(character,
            C_Effect.UNKILLABLE)
      end;
    C_Cond.TURN_START:
      begin
        FxEngine.TriggerEffect(character, C_Effect.HELPLESS); FxEngine.TriggerEffect(character,
                                                                                     C_Effect.SCARED);
        FxEngine.TriggerEffect(character, C_Effect.STUNNED)
      end;
    8: ;
    FxEngine.COND_EFFECT_IMMUNITY:
      begin
        FxEngine.TriggerEffect(character, C_Effect.BLOCK_STUN_WEAPONS); FxEngine.TriggerEffect(character,
            C_Effect.BLOCK_DAZZLE_GRENADE);
        FxEngine.TriggerEffect(character, C_Effect.BLOCK_HELPLESS); FxEngine.TriggerEffect(character,
            C_Effect.BLOCK_SCARED);
        FxEngine.TriggerEffect(character, C_Effect.UNKILLABLE)
      end;
    C_Cond.ATTACK_ROLL_ATTACKER: FxEngine.TriggerEffect(character, C_Effect.BLIND);
    C_Cond.DEFENDER_ARMOR_CLASS: FxEngine.TriggerEffect(character, C_Effect.BLIND);
    FxEngine.COND_SAVING_THROW: FxEngine.TriggerEffect(character, C_Effect.BLIND);
    C_Cond.HIT_POINTS_ZERO: ;
    C_Cond.MONSTER_SPECIAL:
      begin
        FxEngine.TriggerEffect(character, C_Effect.SPIT_ACID); FxEngine.TriggerEffect(character,
                                                                                        C_Effect.STRIKE_ADJACENT);
        FxEngine.TriggerEffect(character, 17)
      end;
    C_Cond.ACTION_START:
      begin
        FxEngine.TriggerEffect(character, C_Effect.STUNNED); FxEngine.TriggerEffect(character, C_Effect.SCARED)
      end;
    FxEngine.COND_ATTACK_ROLL_DEF: ;
    C_Cond.MORALE_CHECK: ;
    C_Cond.MOVE_ATTACK_RATE: FxEngine.TriggerEffect(character, C_Effect.DIZZY);
    19: ;
    20: ;
    21: ;
    22: FxEngine.TriggerEffect(character, C_Effect.DIZZY)
  end
end;

procedure ConsiderTerrainEffects(character: Types.PCharRecord; terrain: Byte);
var
  terrainIndex: Byte;
  creatureIndex: Byte;
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  eff2: Pointer;
  hasSaved: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  savedChar: Pointer;
  { ProbeDirection's report of gas on the cell }
  hasGas: Byte;
begin
  if character^.enabled = 0 then Exit;
  CbtMap.ProbeDirection(character, C_Dir.CENTER, creatureIndex, terrainIndex, hasGas);
  if hasGas = 0 then Exit;
  if CharHlp.IsHelpless(character) then Exit;
  if (character^.armorFlags and C_Armor.BREATHING_PROTECTION) = 0 then begin
    hasSaved := FxEngine.RollSavingThrow(character, 1, 0);
    if not hasSaved then begin
      FxEngine.AddEffectWithMessage(character, C_Effect.HELPLESS, CharHlp.RollDice(1, 6) + 1, 0, 0,
                                    C_Save.NO_EFFECT, Ord(hasSaved), 'is helpless');
      if CharHlp.HasEffect(character, C_Effect.HELPLESS, effect) then
        FxEngine.CallEffectHandler(C_Effect.HELPLESS, character, effect, False)
    end
  end
end;

function AttackRollNoAttacker(defender: Types.PCharRecord; target: Byte): Boolean;
begin
  AttackRollNoAttacker := False;
  GDVars.currentAttackRoll := CharHlp.RollDice(1, 20);
  if GDVars.currentAttackRoll > 1 then begin
    if GDVars.currentAttackRoll = 20 then
      GDVars.currentAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_DEF, defender);
    if GDVars.currentAttackRoll >= 0 then
      if GDVars.currentAttackRoll + target > defender^.armorClass[0] then
        AttackRollNoAttacker := True
  end
end;

function AttackRoll(attacker, defender: Types.PCharRecord; target: Byte): Boolean;
var
  modifier: ShortInt;
begin
  AttackRoll := False;
  GDVars.currentAttackRoll := CharHlp.RollDice(1, 20);
  if GDVars.currentAttackRoll > 1 then begin
    if GDVars.currentAttackRoll = 20 then
      GDVars.currentAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACK_ROLL_ATTACKER, attacker);
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_DEF, defender);
    if attacker^.side = C_Side.TEAM then begin
      modifier := GDVars.zone1^.partyThac0Modifier;
      case GDVars.zone0^.difficulty of
        C_Diff.DIFFICULTY_NOVICE: Inc(modifier, 2);
        C_Diff.DIFFICULTY_CADET: Inc(modifier);
        C_Diff.DIFFICULTY_VETERAN: Dec(modifier);
        C_Diff.DIFFICULTY_ACE: Dec(modifier, 2)
      end
    end else
      modifier := GDVars.zone1^.monsterThac0Modifier;
    Debug.PrintDebug('thac0', attacker^.attackBonus, target, modifier);
    if GDVars.currentAttackRoll >= 0 then
      if GDVars.currentAttackRoll + attacker^.attackBonus + modifier >= target then
        AttackRoll := True
  end
end;

function RollSavingThrow(character: Types.PCharRecord; saveType, modifier: Byte): Boolean;
begin
  GDVars.currentSaveResult := True;
  GDVars.saveRoll := CharHlp.RollDice(1, 20);
  case GDVars.saveRoll of
    1: GDVars.currentSaveResult := False;
    20: GDVars.currentSaveResult := True;
  else begin
      GDVars.saveRoll := GDVars.saveRoll + ShortInt(modifier);
      GDVars.currentSaveType := saveType;
      FxEngine.TriggerEffectsWithCondition(FxEngine.COND_SAVING_THROW, character);
      if character^.saves[ShortInt(saveType)] <= GDVars.saveRoll then
        GDVars.currentSaveResult := True
      else
        GDVars.currentSaveResult := False
    end
  end;
  RollSavingThrow := GDVars.currentSaveResult
end;

function RollDamageDice(count, sides: Byte): Byte;
begin
  GDVars.currentDiceCount := count;
  RollDamageDice := CharHlp.RollDice(count, sides)
end;

procedure AddEffect(character: Types.PCharRecord; effectId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);
var
  newEffect: Types.PEffectRec;
  effect: Types.PEffectRec;
begin
  GetMem(newEffect, SizeOf(Types.TEffectRec));
  if character^.effectsAddr = nil then
    character^.effectsAddr := newEffect
  else begin
    effect := character^.effectsAddr;
    while effect^.next <> nil do
      effect := effect^.next;
    effect^.next := newEffect
  end;
  newEffect^.next := nil;
  newEffect^.effectId := effectId;
  newEffect^.duration := minutes;
  newEffect^.onRemove := Byte(onRemove);
  newEffect^.strength := strength
end;

procedure PutOutOfPlayWithStatus(character: Types.PCharRecord; status: Byte; message: Types.TString40);
var
  slot: Byte;
begin
  if character^.enabled <> 0 then begin
    slot := CbtMap.CombatSlot(character);
    CbtMap.DisplayMapViewCentered(character, 3, False);
    CharHlp.PrintCreatureMessage(character, message, 10, True);
    character^.enabled := 0;
    character^.status := status;
    if character^.status <> C_Status.FLEEING then
      character^.hitPoints := 0;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    Blit.FlushView;
    GDVars.combatantCells[slot].size := 0;
    CbtMap.BuildArenaArrays;
    if CharHlp.EndActions(character) then
      FxEngine.RemoveIncapacitatingEffects(character)
  end
end;

procedure RemoveIncapacitatingEffects(character: Types.PCharRecord);
var
  index: Byte;
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
begin
  for index := 1 to SizeOf(GDConsts.incapacitatingEffects) do
    FxEngine.RemoveEffect(character, GDConsts.incapacitatingEffects[index], nil)
end;

procedure InflictNonWeaponDamage(character: Types.PCharRecord; damage, saveReduction: Byte; hasSaved: Boolean);
var
  message: String;
  { Unused in this version; see the other implementations of this routine. }
  endRes: Boolean;
begin
  GDVars.effectDamage := damage;
  FxEngine.TriggerEffectsWithCondition(FxEngine.COND_NON_WEAPON_DAMAGE, character);
  if hasSaved then
    case Char(saveReduction) of
      Chr(C_Save.CANCELS): GDVars.effectDamage := 0;
      Chr(C_Save.HALVES): GDVars.effectDamage := GDVars.effectDamage div 2
    end;
  if (GDVars.effectDamage > 0) and (character^.enabled <> 0) then begin
    if GDVars.effectDamage <> 1 then
      message := FxEngine.TAKES_PREFIX + TextRend.ByteToString(GDVars.effectDamage) + FxEngine.POINTS_DAMAGE
    else
      message := FxEngine.ONE_POINT_DAMAGE;
    CharHlp.PrintNameStringAnim(character, GDVars.projectileEffect, message);
    CharHlp.InflictDamage(character, GDVars.effectDamage);
    if character^.enabled = 0 then begin
      message := FxEngine.GOES_DOWN;
      if character^.combatAddr^.notPcNpc = 0 then begin
        if character^.status = C_Status.DYING then
          message := message + FxEngine.DYING_SUFFIX;
        if character^.status in [C_Status.GONE, C_Status.DEAD_STATUS] then
          message := FxEngine.KILLED_MESSAGE
      end;
      CharHlp.PrintCreatureMessage(character, message, GDVars.cursorRow + 1, False);
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        TextRend.PauseOnly
      else begin
        FxEngine.RemoveIncapacitatingEffects(character);
        FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_POINTS_ZERO, character);
        CbtMap.CreatureDowned(character)
      end
    end;
    CharHlp.ClearMessageWindow
  end
end;

procedure AddEffectWithMessage(character: Types.PCharRecord; effectId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveReduction, saved: Byte; message: Types.TString40);
var
  { Unused in this version; see the other implementations of this routine. }
  existingEffect: Pointer;
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
  animation: Byte;
begin
  GDVars.pendingEffectId := effectId;
  FxEngine.TriggerEffectsWithCondition(FxEngine.COND_EFFECT_IMMUNITY, character);
  if (GDVars.pendingEffectId = 0) or ((saved <> 0) and (saveReduction = C_Save.CANCELS)) then
    CharHlp.PrintCreatureMessage(character, FxEngine.UNAFFECTED_MESSAGE, 10, True)
  else begin
    if CharHlp.HasEffect(character, GDVars.pendingEffectId, effect) then begin
      if effect^.duration <> 0 then
        if minutes > effect^.duration then
          effect^.duration := minutes
    end else
      FxEngine.AddEffect(character, effectId, minutes, strength, Boolean(onRemove));
    if message[0] <> #0 then begin
      if effectId = C_Effect.STUNNED then
        animation := FxEngine.STUN_ANIMATION
      else
        animation := 0;
      CharHlp.PrintNameStringAnim(character, animation, message);
      CharHlp.ClearMessageWindow
    end
  end
end;

procedure LayAreaEffectMarkers;
var
  current: Types.PAreaEffect;
  index: Byte;
begin
  current := GDVars.areaEffects;
  while current <> nil do begin
    for index := 1 to SizeOf(current^.active) do
      if current^.active[index] <> 0 then
        GDVars.combatArena^.cells[current^.y + GDConsts.dirStepY[GDConsts.cloudDir[index]],
                                    current^.x + GDConsts.dirStepX[GDConsts.cloudDir[index]]] := current^.marker;
    current := current^.next
  end
end;

procedure CountDownAreaEffects;
var
  previous: Types.PAreaEffect;
  current: Types.PAreaEffect;
  next: Types.PAreaEffect;
  hasCleared: Boolean;
  index: Byte;
  cellX: ShortInt;
  cellY: ShortInt;
  downedIndex: Byte;
  hasCorpse: Boolean;
begin
  previous := nil;
  current := GDVars.areaEffects;
  hasCleared := False;
  while current <> nil do begin
    next := current^.next;
    if current^.countdown <= 1 then begin
      with current^ do
        for index := 1 to SizeOf(active) do
          if active[index] <> 0 then begin
            cellX := x + GDConsts.dirStepX[GDConsts.cloudDir[index]];
            cellY := y + GDConsts.dirStepY[GDConsts.cloudDir[index]];
            hasCorpse := False;
            for downedIndex := 1 to GDVars.downedCount do
              if (GDVars.downedCreatures[downedIndex].character <> nil) and
                  (GDVars.downedCreatures[downedIndex].x = cellX) and
                  (GDVars.downedCreatures[downedIndex].y = cellY) then
                hasCorpse := True;
            if hasCorpse then
              GDVars.combatArena^.cells[cellY, cellX] := C_Terr.CORPSE_TERRAIN
            else
              GDVars.combatArena^.cells[cellY, cellX] := underlyingTerrain[index]
          end;
      hasCleared := True;
      if previous = nil then
        GDVars.areaEffects := next
      else
        previous^.next := next;
      FreeMem(current, SizeOf(Types.TAreaEffect))
    end else begin
      previous := current;
      Dec(current^.countdown)
    end;
    current := next
  end;
  if hasCleared then begin
    FxEngine.LayAreaEffectMarkers;
    CharHlp.PrintBottomLine(FxEngine.AIR_CLEARS_MESSAGE)
  end
end;

begin
end.
