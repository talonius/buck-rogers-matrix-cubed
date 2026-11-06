{ The ground-combat actions. Initiative and attack counts; melee and ranged attacks with their damage and messages;
  guarding, moving and fleeing; missiles and grenades with the clouds they leave; the Aim menu and the combat cursor;
  intimidation, leadership, tactics, Zero-G rolls and jetpacks. Combat and CombatAi call it, EffHndlr calls
  ProcessAttackResult and CombatSt UpdateHostileHpPercent. GDConsts.projectileKinds holds each projectile kind's area
  effect. Each T...Locals record below holds one routine's locals, and TProjectileParent holds CombatLaunchProjectile's,
  which its nested routines share. }
{$F+,O+,S-,R-,V-,B-,I-}
unit CbtActs;

interface

uses Types, C_Combat, C_Item, C_Menu, C_Npc, C_Status, C_Terr, GDConsts, GDVars,
  TextRend, FxEngine, Border, CharHlp, CbtMap, ViewChar, MenuCore, Pathing, Music, Blit, Crt, Mouse, GameIo, C_Equip,
  C_Effect, C_Dir, C_Skill, C_WClass, C_Armor, C_Attack, C_Area, C_Career, C_Side, C_Cond, C_Keys, C_Save;

{ Attacks an arena cell with the readied area weapon, with no defender: sets projectileTargetX/Y and resolves the
  attack.
  @param(character The combatant attacking.)
  @param(x The cell's column.)
  @param(y The cell's row.)
  @param(isDone True when the character's turn is over.) }
procedure AttackGroundTarget(character: Types.PCharRecord; x, y: Byte; var isDone: Boolean);

{ Ends the character's actions and, unless it carries an area weapon, sets it guarding, ready to attack an enemy that
  moves near it.
  @param(character The combatant.)
  @returns(EndActions' result.) }
function Guard(character: Types.PCharRecord): Boolean;

{ Readies a creature for the round: its attacks, the C_Cond.MOVE_ATTACK_RATE effects and, when it is enabled, its
  initiative -- d10 + DexMissileAdjust + 1, at least 2, 6 less for a side named in zone1's sideMask, 0 outside 0..20 --
  with a d127 tie breaker; then its movement.
  @param(creature The combatant.) }
procedure BeginRound(creature: Types.PCharRecord);

{ Shows the attack and its result in the side panel, inflicts damage on a hit, and handles a defender that goes down.
  @param(attacker The combatant attacking.)
  @param(defender The combatant attacked.)
  @param(damage The damage inflicted on a hit.)
  @param(shownDamage The damage shown.)
  @param(isHit True for a hit.) }
procedure ProcessAttackResult(attacker, defender: Types.PCharRecord; damage, shownDamage: Byte; isHit: Boolean);

{ Moves a creature one step on the arena: spends the terrain's cost (times 2, times 3 diagonally; all its movement when
  that is more), moves its icon, scrolling the view for a quick-fighter, plays the step sound and lets guarding
  neighbors strike. A creature knocked down or left helpless loses its movement.
  @param(creature The creature.)
  @param(direction Direction of the step.) }
procedure CombatMoveCreature(creature: Types.PCharRecord; direction: Byte);

{ Tries to flee. It succeeds automatically with no enemy in the target list, and otherwise when the creature's movement
  in whole steps beats the fastest enemy's, or on 1 in 2 when they tie. Success takes the creature out of play as
  running, with 'Got Away'; failure prints 'Escape is blocked'. The creature's actions end either way.
  @param(creature The creature fleeing.)
  @returns(The result of ending its actions.) }
function AttemptFlee(creature: Types.PCharRecord): Boolean;

{ Sets attacks[1] from the readied weapon's attacksDoubled (or the character's baseScale) after C_Cond.MOVE_ATTACK_RATE,
  halved with odd rounds rounding up, and capped by a ranged weapon's quantity. Once the character has attacked this
  round the count can only fall.
  @param(creature The combatant.) }
procedure RecalcAttacksLeft(creature: Types.PCharRecord);

{ Tests whether an attacker may aim at a target.
  @param(attacker The combatant aiming.)
  @param(target The combatant aimed at.)
  @returns(True when target is the attacker itself or on the other side; False when target is nil.) }
function CanTarget(attacker, target: Types.PCharRecord): Boolean;

{ Records an attack on a defender for flanking: the defender's count of attackers goes up, and the angle between its
  facing and the attack's direction (0..4) is added to its spread, mod 8.
  @param(attacker The attacker.)
  @param(defender The defender.) }
procedure NoteAttackDirection(attacker, defender: Types.PCharRecord);

{ Turns the attacker toward the defender, and the defender back toward it while it has drawn fewer than two attacks and
  the attack is not from behind, then makes the attack: a missile or grenade when the readied weapon's special names
  projectile kind 5..12, else the weapon's attacks, spending a ranged weapon's shots.
  @param(attacker The combatant attacking.)
  @param(defender The combatant attacked.)
  @param(fromBehind True for an attack from behind.)
  @param(done True when the attacker's turn is over.) }
procedure MakeAttack(attacker, defender: Types.PCharRecord; fromBehind: Boolean; var done: Boolean);

{ Asks before an attack on an ally.
  @param(attacker The combatant attacking.)
  @param(defender The combatant attacked.)
  @returns(True when the defender is an enemy, the attacker is on quickfight, or the player answers Y to 'Attack Ally:
    '; that answer turns the party's okay NPCs (npc at or above NON_PLAYER_FLAG, not PARTY_MEMBER_NPC) into enemies.) }
function CheckAttackAlly(attacker, defender: Types.PCharRecord): Boolean;

{ Runs the Aim menu: Next, Prev, Manual (the combat cursor), Attack, Center, Exit.
  @param(character The combatant aiming.)
  @param(requestedRange 255 for the readied weapon's range.)
  @param(mode AIM_ATTACK makes an accepted target an attack.)
  @param(allowsGround Passed on to ManualAimCursor, where it has no effect.)
  @param(canAttack True offers Attack.)
  @param(isDone True when the character's turn is over.)
  @param(selection The target accepted.) }
procedure CombatAimMenu(character: Types.PCharRecord; requestedRange, mode: Byte; allowsGround, canAttack: Boolean;
                        var isDone: Boolean; var selection: Types.TAimTarget);

{ Sets hostileHpPercent to the enabled hostiles' hit points as a percentage, in steps of 5, of all the hostiles' maximum
  hit points; a maximum of 0 leaves it unchanged. Note: the sums are Words, so 20 * hit points overflows above 3276 hit
  points and the percentage goes wrong. }
procedure UpdateHostileHpPercent;

{ Gives the fastest of the creature's enabled enemies.
  @param(creature The combatant.)
  @returns(The largest half movement among its enemies.) }
function HighestEnemyMovement(creature: Types.PCharRecord): Byte;

{ Debug cheat: when the first command-line parameter is combatDebugPassword, kills every enemy and ends everyone's
  actions.
  @returns(True then.) }
function VictoryCheat: Boolean;

{ On a C_Skill.INTIMIDATE roll, gives each adjacent enemy that is not helpless C_Effect.SCARED, 'is intimidated', unless
  it saves.
  @param(character The combatant intimidating.) }
procedure IntimidateTarget(character: Types.PCharRecord);

{ Gives a side the tactics bonus when one of its enabled, unstunned creatures that is okay, dodging or just off a
  jetpack flight makes a Battle Tactics roll; each side stops rolling at its first success. }
procedure RollTactics;

{ In a zero-gravity area, an enabled creature with initiative above 1 rolls its zero-gravity maneuvering skill; failing
  marks it as failed in zero gravity and quarters its movement.
  @param(character The combatant.) }
procedure RollZeroG(character: Types.PCharRecord);

{ Puts each creature on quickfight (a party member as its companion setting decides), then lets each okay party leader
  with the Leadership skill take okay companions (Intelligence above 3, and not unkillable) off quickfight on a
  Leadership roll, listing who leads whom. }
procedure UseLeadership;

{ On a C_Skill.USE_JETPACK roll the player picks a landing cell with the combat cursor and the character flies there; on
  a failure it lurches through random cells near it. Enemies on guard attack it on the way.
  @param(character The combatant flying.) }
procedure CombatUseJetpack(character: Types.PCharRecord);

implementation

const
  { ManualAimCursor's mode: the cell chosen is a jetpack landing }
  AIM_JETPACK = 2;
  { item types (ITEMS rows) the shots are drawn and heard by }
  CROSSBOW_TYPE = 5;
  NEEDLE_GUN_TYPE = 6;
  BOLT_GUN_TYPE = 7;
  LASER_PISTOL_TYPE = 9;
  ROCKET_PISTOL_TYPE = 10;
  ROCKET_RIFLE_TYPE = 11;
  MICROWAVE_GUN_TYPE = 12;
  LASER_RIFLE_TYPE = 13;
  HEAT_GUN_TYPE = 14;
  GRENADE_LAUNCHER_TYPE = 16;
  { attackManner values past C_Attack.PLAIN, each picking ProcessAttackResult's attack line }
  ATTACK_FROM_BEHIND = 1;
  { also multiplies the damage }
  ATTACK_BACKSTAB = 2;
  { tested by ProcessAttackResult, but nothing sets it }
  ATTACK_SLAYS_HELPLESS = 3;
  { the Distract skill's skillDefinitions row and TCharRecord.skillLevels index }
  SKILL_DISTRACT = 78;

type
  TDamageLocals = packed record
    computed: Integer;
    distance: Word;
    terrain: Byte;
    occupant: Byte;
    sourceY: ShortInt;
    sourceX: ShortInt;
    { set and not used }
    hasLine: Boolean;
    weapon: Types.PItemRec;
    weaponClass: Byte
  end;
  TGuardLocals = packed record
    distance: Word;
    targetY: ShortInt;
    targetX: ShortInt;
    isDone: Boolean;
    guard: Types.PCharRecord;
    index: Byte;
    count: Byte
  end;
  TMoveLocals = packed record
    { Unused in this version; see the other implementations of this routine. }
    destTerrain: Byte;
    baseY: ShortInt;
    baseX: ShortInt;
    y: ShortInt;
    x: ShortInt;
    slot: Byte;
    cost: Byte
  end;
  TDoAttackLocals = packed record
    stunSave: Byte;
    armorIndex: ShortInt;
    phase: Byte;
    index: Byte;
    armor: Byte;
    isBehind: Byte;
    isDefenderDown: Boolean;
    hasHit: Boolean;
    { Unused in this version; see the other implementations of this routine. }
    base: array[1..9] of Byte
  end;
  TMakeAttackLocals = packed record
    weapon: Types.PItemRec;
    { unused }
    weaponTail: Byte;
    direction: Byte;
    savedCharacter: Types.PCharRecord;
    { Unused in this version; see the other implementations of this routine. }
    thrownCopy: Types.PItemRec
  end;
  TJetpackLocals = packed record
    { where ManualAimCursor leaves the landing cell; not used here }
    selection: Types.TAimTarget;
    terrain: Byte;
    occupant: Byte;
    distance: Word;
    candidateY: ShortInt;
    candidateX: ShortInt;
    y: ShortInt;
    x: ShortInt;
    landingIndex: ShortInt;
    ys: array[0..10] of ShortInt;
    xs: array[0..10] of ShortInt;
    roll: Byte;
    slot: Byte;
    isDone: Boolean;
    index: ShortInt
  end;
  TRangedAnimLocals = packed record
    { Unused in this version; see the other implementations of this routine. }
    imageSize: Word;
    pace: Byte;
    direction: Byte;
    frames: Byte
  end;
  TPercentLocals = packed record
    combatant: Types.PCharRecord;
    hitPointTotal: Word;
    maximumTotal: Word
  end;
  THighestLocals = packed record
    combatant: Types.PCharRecord;
    movement: Byte;
    highest: Byte
  end;
  TManualAimLocals = packed record
    initialRange: Byte;
    distance: Word;
    initialY: ShortInt;
    initialX: ShortInt;
    terrain: Byte;
    occupant: Byte;
    targetY: ShortInt;
    targetX: ShortInt;
    index: Byte;
    direction: Byte;
    weapon: Types.PItemRec;
    key: Char;
    message: Types.TString40
  end;
  TProjectileParent = packed record
    effectY: ShortInt;
    effectX: ShortInt;
    radius: Byte;
    sourceSlot: Byte;
    candidateEffect: Types.PEffectRec;
    sourceY: ShortInt;
    sourceX: ShortInt;
    selectedY: ShortInt;
    selectedX: ShortInt;
    { for kinds 5, 6, 10 and 11, the first enabled creature under UNKILLABLE; nil if none. It leaps for cover only when
      ScanProjectileArea finds a cell, never for kind 5 }
    leaper: Types.PCharRecord;
    distance: Word;
    terrain: Byte;
    occupant: Byte;
    targetCount: Byte;
    targets: array[1..40] of Types.PCharRecord;
    { unused }
    targetsTail: Byte;
    directionCount: Byte;
    directionIndex: Byte;
    isLaunched: Boolean;
    effectMinutes: Byte;
    cursor: Types.PCharRecord;
    { unused }
    cursorTail: array[$0BE..$0C1] of Byte;
    savedEffect: Types.PAreaEffect;
    saveResult: Byte;
    damage: Byte;
    message: String[20];
    targetY: ShortInt;
    targetX: ShortInt;
    yDifference: ShortInt;
    xDifference: ShortInt;
    { unused }
    xDifferenceTail: Byte;
    { scatter tries, then the index of the target and cloud loops }
    scatterCount: Byte;
    { unused }
    scatterCountTail: Byte;
    weaponType: Types.PItemType;
    launcher: Types.PItemRec;
    weapon: Types.PItemRec
  end;

function IsRearAttack(attacker, defender: Types.PCharRecord): Boolean; forward;

function IsBackstab(attacker, defender: Types.PCharRecord): Boolean; forward;

procedure ApplyRangePenalty(attacker, defender: Types.PCharRecord; var armorClass: Byte); forward;

function ProjectileRangePenalty(distance, weaponRange: Byte): ShortInt; forward;

procedure AnimateMissile(sourceX, sourceY, targetX, targetY: ShortInt; weapon: Types.PItemRec); forward;

procedure ManualAimCursor(character, target: Types.PCharRecord; requestedRange, mode: Byte; allowsGround,
                          canAttack: Boolean; var isAcceptable, isChosen: Boolean; var selection: Types.TAimTarget; x,
                          y: ShortInt); forward;

procedure BeginRound(creature: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cellIndex: Byte;
  { Unused in this version; see the other implementations of this routine. }
  inStinkingCloud: Byte;
begin
  with creature^.combatAddr^ do begin
    active := 1;
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.RecalcAttacksLeft(creature);
    GDVars.attackRate := creature^.scale;
    FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
    creature^.attacks[2] := (GDVars.attackRate + (GDVars.combatRound and 1)) shr 1;
    if creature^.enabled <> 0 then begin
      initiative := CharHlp.RollDice(1, 10) + CharHlp.DexMissileAdjust(creature) + 1;
      if initiative < 2 then initiative := 2;
      if Byte(GDVars.zone1^.sideMask and (creature^.side + 1)) <> 0 then
        Dec(initiative, 6);
      if (initiative < 0) or (initiative > 20) then initiative := 0;
      priority := CharHlp.RollDice(1, 127)
    end else
      initiative := 0
  end;
  creature^.combatAddr^.movement := CharHlp.RecalcMovement(creature)
end;

{ Rolls the damage of an attack phase into effectDamage (a backstab multiplies it), runs C_Cond.WEAPON_DAMAGE_ATTACKER
  and C_Cond.WEAPON_DAMAGE_DEFENDER, then cancels it for a rocket fired across chaff or stopped by ECM (50%) or
  force-field (75%) armor, a laser fired across aerosol mist, and a microwave gun against body armor.
  @param(attacker The combatant attacking.)
  @param(defender The combatant attacked.)
  @param(phase The attack phase, 1 or 2.) }
procedure CalcWeaponDamage(attacker, defender: Types.PCharRecord; phase: Byte);
var local: TDamageLocals;
begin
  local.computed := FxEngine.RollDamageDice(attacker^.currentRolls[phase],
                                            attacker^.currentDice[phase]) + attacker^.currentModifiers[phase];
  if local.computed > 0 then GDVars.effectDamage := local.computed
                      else GDVars.effectDamage := 0;
  if GDVars.attackManner = CbtActs.ATTACK_BACKSTAB then
    if attacker^.career = C_Career.ROGUE then
      GDVars.effectDamage := GDVars.effectDamage * (Word(attacker^.level + 7) div 2 div 2)
    else
      GDVars.effectDamage := GDVars.effectDamage shl 1;
  FxEngine.TriggerEffectsWithCondition(C_Cond.WEAPON_DAMAGE_ATTACKER, attacker);
  FxEngine.TriggerEffectsWithCondition(C_Cond.WEAPON_DAMAGE_DEFENDER, defender);
  local.weapon := attacker^.equipped[C_Equip.WEAPON];
  if local.weapon <> nil then begin
    local.sourceX := CbtMap.CombatCellX(attacker);
    local.sourceY := CbtMap.CombatCellY(attacker);
    local.distance := 255;
    local.hasLine := Pathing.WalkLine(CbtMap.CombatCellX(defender), CbtMap.CombatCellY(defender), local.sourceX,
                                      local.sourceY, local.distance);
    CbtMap.GetArenaContents(local.sourceX, local.sourceY, local.occupant, local.terrain);
    if local.terrain = C_Terr.CHAFF_TERRAIN then GDVars.sawChaff := True
    else if local.terrain = C_Terr.AEROSOL_MIST_TERRAIN then GDVars.sawAerosolMist := True;
    local.weaponClass := GDVars.itemTypes[local.weapon^.template.itemType].weaponClass;
    case local.weaponClass of
      C_WClass.ROCKET: if GDVars.sawChaff or
        (((defender^.armorFlags and C_Armor.ECM) <> 0) and CharHlp.PercentileRoll(50)) or
        (((defender^.armorFlags and C_Armor.FIELDS) <> 0) and CharHlp.PercentileRoll(75)) then
          GDVars.effectDamage := 0;
      C_WClass.LASER: if GDVars.sawAerosolMist then GDVars.effectDamage := 0;
      C_WClass.MICROWAVE: if (defender^.armorFlags and C_Armor.BODY) <> 0 then
          GDVars.effectDamage := 0
    end
  end;
  GDVars.projectileEffect := 0
end;

procedure ProcessAttackResult(attacker, defender: Types.PCharRecord; damage, shownDamage: Byte; isHit: Boolean);
var row: Byte;
    message: String[80];
    { Unused in this version; see the other implementations of this routine. }
    isDone: Byte;
begin
  case GDVars.attackManner of
    CbtActs.ATTACK_BACKSTAB: message := '-Backstabs-';
    CbtActs.ATTACK_SLAYS_HELPLESS: message := 'slays helpless'
  else
    message := 'Attacks'
  end;
  CharHlp.PrintCreatureMessage(attacker, message, 10, False);
  row := 12;
  MenuCore.DisplayCreatureName(defender, 23, row, False);
  Inc(row);
  if GDVars.attackManner = CbtActs.ATTACK_FROM_BEHIND then
    message := '(from behind) '
  else
    message := '';
  if isHit then begin
    if GDVars.attackManner = CbtActs.ATTACK_SLAYS_HELPLESS then
      message := 'with one cruel blow'
    else begin
      message := message + 'Hitting for ' + TextRend.ByteToString(shownDamage);
      if shownDamage = 1 then
        message := message + ' point '
      else
        message := message + ' points ';
      message := message + 'of damage'
    end;
    CharHlp.InflictDamage(defender, damage)
  end else
    message := message + 'and Misses';
  if defender^.status <> C_Status.GONE then
    TextRend.DisplayMessageWindow(23, row, 38, row + 3, LightGreen, Black, True, message);
  row := GDVars.cursorRow + 1;
  if damage > 0 then
    TextRend.PauseOnly
  else
    TextRend.PauseOnly;
  if defender^.enabled = 0 then begin
    CharHlp.PrintCreatureMessage(defender, 'goes down', row, False);
    Inc(row, 2);
    if defender^.combatAddr^.notPcNpc = 0 then begin
      if defender^.status = C_Status.DYING then
        TextRend.DisplayString(23, row, LightGreen, Black, 'and is Dying');
      if defender^.status in [C_Status.GONE, C_Status.DEAD_STATUS] then
        CharHlp.PrintCreatureMessage(defender, 'is killed', row, False)
    end;
    Inc(row, 2);
    FxEngine.RemoveIncapacitatingEffects(defender);
    FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_POINTS_ZERO, defender);
    if defender^.enabled = 0 then
      CbtMap.CreatureDowned(defender)
    else
      TextRend.PauseOnly
  end;
  CharHlp.ClearMessageWindow
end;

{ Lets the enemies on guard attack a creature that moves or flies near them. Each guarding enemy from
  CountTargets(creature, 60) that is not helpless and has a ranged weapon or stands adjacent attacks once, and stops
  guarding, when a line from it reaches the creature within its weapon's range; a creature using a jetpack is attacked
  without that test. Once the creature is disabled the remaining guards hold their fire.
  @param(creature The combatant moving.) }
procedure GuardersAttack(creature: Types.PCharRecord);
var local: TGuardLocals;
begin
  local.count := CharHlp.CountTargets(creature, 60);
  for local.index := 1 to local.count do
    if creature^.enabled <> 0 then begin
      local.guard := GDVars.creatures[GDVars.targetOrder[local.index]];
      if local.guard^.combatAddr^.guarding <> 0 then
        if not CharHlp.IsHelpless(local.guard) then
          if CharHlp.HasRangedWeapon(local.guard) or (CharHlp.CalcDistance(local.guard, creature) <= 1) then begin
            local.targetX := CbtMap.CombatCellX(creature);
            local.targetY := CbtMap.CombatCellY(creature);
            local.distance := ViewChar.ReadiedWeaponRange(local.guard);
            if (creature^.status = C_Status.USING_JETPACK) or
                Pathing.WalkLine(CbtMap.CombatCellX(local.guard), CbtMap.CombatCellY(local.guard), local.targetX,
                                 local.targetY, local.distance) then begin
              CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2, C_Dir.CENTER);
              CbtActs.NoteAttackDirection(local.guard, creature);
              CbtActs.MakeAttack(local.guard, creature, False, local.isDone);
              local.guard^.combatAddr^.guarding := 0
            end
          end
    end
end;

procedure CombatMoveCreature(creature: Types.PCharRecord; direction: Byte);
var local: TMoveLocals;
begin
  local.slot := CbtMap.CombatSlot(creature);
  local.baseX := GDVars.combatantCells[local.slot].x;
  local.baseY := GDVars.combatantCells[local.slot].y;
  local.x := local.baseX + GDConsts.dirStepX[direction];
  local.y := local.baseY + GDConsts.dirStepY[direction];
  if Odd(direction) then
    local.cost := GDConsts.terrainInfo[GDVars.combatArena^.cells[local.y, local.x]].cost * 3
  else
    local.cost := GDConsts.terrainInfo[GDVars.combatArena^.cells[local.y, local.x]].cost * 2;
  if local.cost > creature^.combatAddr^.movement then
    creature^.combatAddr^.movement := 0
  else
    Dec(creature^.combatAddr^.movement, local.cost);
  local.cost := 1;
  if creature^.quickfight <> 0 then begin
    local.cost := 3;
    if not CbtMap.ViewCoordsValid(local.x - GDVars.combatArena^.viewOriginX,
                                  local.y - GDVars.combatArena^.viewOriginY) then
      if GDVars.mapVisible <> 0 then
        CbtMap.ScrollView(local.baseX, local.baseY, 2, C_Dir.CENTER)
  end;
  if GDVars.mapVisible <> 0 then
    CbtMap.UpdateCombatMapTile(0, 0, local.slot);
  GDVars.combatantCells[local.slot].x := local.x;
  GDVars.combatantCells[local.slot].y := local.y;
  CbtMap.BuildArenaArrays;
  if GDVars.mapVisible <> 0 then
    CbtMap.ScrollView(local.x, local.y, local.cost, C_Dir.CENTER);
  creature^.combatAddr^.directionCount := 0;
  creature^.combatAddr^.directionTotal := 0;
  Music.SendSoundCommand(GDConsts.stepSound);
  CbtActs.GuardersAttack(creature);
  if (creature^.enabled = 0) or CharHlp.IsHelpless(creature) then
    creature^.combatAddr^.movement := 0
end;

function AttemptFlee(creature: Types.PCharRecord): Boolean;
var hasEscaped: Boolean;
    enemyMove: Byte;
    creatureMove: Byte;
begin
  hasEscaped := False;
  if CharHlp.CountTargets(creature, 255) = 0 then
    hasEscaped := True
  else begin
    creatureMove := CharHlp.RecalcMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < creatureMove then
      hasEscaped := True
    else if enemyMove = creatureMove then
      if CharHlp.RollDice(1, 2) = 1 then
        hasEscaped := True
  end;
  if hasEscaped then
    FxEngine.PutOutOfPlayWithStatus(creature, C_Status.FLEEING, 'Got Away')
  else
    CharHlp.PrintBottomLine('Escape is blocked');
  AttemptFlee := CharHlp.EndActions(creature)
end;

procedure RecalcAttacksLeft(creature: Types.PCharRecord);
var previous: Byte;
    weapon: Types.PItemRec;
begin
  previous := creature^.attacks[1];
  weapon := creature^.equipped[C_Equip.WEAPON];
  if weapon <> nil then
    GDVars.attackRate := GDVars.itemTypes[weapon^.template.itemType].attacksDoubled
  else
    GDVars.attackRate := creature^.baseScale;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
  GDVars.attackRate := (GDVars.attackRate + (GDVars.combatRound and 1)) shr 1;
  if weapon <> nil then
    if GDVars.itemTypes[weapon^.template.itemType].weaponClass <> C_WClass.MELEE then
      if GDVars.attackRate > weapon^.template.quantity then
        GDVars.attackRate := weapon^.template.quantity;
  if (creature^.combatAddr^.madeAttack = 0) or (GDVars.attackRate < previous) then
    creature^.attacks[1] := GDVars.attackRate
  else
    creature^.attacks[1] := previous
end;

function CanTarget(attacker, target: Types.PCharRecord): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  savedTarget: Types.PCharRecord;
begin
  CanTarget := False;
  if target = nil then Exit;
  if attacker = target then
    CanTarget := True
  else
    CanTarget := attacker^.side <> target^.side
end;

{ Makes the attacker's remaining attacks on the defender until they run out or the defender goes down; a sonic stunner
  (SONIC_STUNNER_TYPE) stuns instead of damaging.
  @param(attacker The combatant attacking.)
  @param(defender The combatant attacked.)
  @param(isFromBehind True for an attack from behind.)
  @param(isDone True when the attacker has no attacks left.) }
procedure RollAttacks(attacker, defender: Types.PCharRecord; isFromBehind: Boolean; var isDone: Boolean);
var local: TDoAttackLocals;
begin
  local.isBehind := Byte(isFromBehind);
  isDone := False;
  GDVars.hitCounts[1] := 0;
  GDVars.hitCounts[2] := 0;
  GDVars.attackCounts[1] := 0;
  GDVars.attackCounts[2] := 0;
  local.hasHit := False;
  local.isDefenderDown := False;
  GDVars.effectDamage := 0;
  attacker^.combatAddr^.madeAttack := 1;
  CharHlp.RecalcStats(defender);
  FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, defender);
  local.armorIndex := 0;
  GDVars.attackManner := C_Attack.PLAIN;
  if CbtActs.IsRearAttack(attacker, defender) then begin
    local.isBehind := 1;
    local.armorIndex := 1;
    if CbtActs.IsBackstab(attacker, defender) then
      GDVars.attackManner := CbtActs.ATTACK_BACKSTAB
    else
      GDVars.attackManner := CbtActs.ATTACK_FROM_BEHIND
  end;
  local.armor := defender^.armorClass[local.armorIndex];
  if local.isBehind <> 0 then
    if attacker^.career = C_Career.ROGUE then
      Inc(local.armor, 2);
  CbtActs.ApplyRangePenalty(attacker, defender, local.armor);
  local.phase := attacker^.combatAddr^.attackPhase;
  for local.index := local.phase downto 1 do
    while (attacker^.attacks[local.index] > 0) and (not local.isDefenderDown) do begin
      Dec(attacker^.attacks[local.index]);
      attacker^.combatAddr^.attackPhase := local.index;
      Inc(GDVars.attackCounts[local.index]);
      if FxEngine.AttackRoll(attacker, defender, local.armor) or CharHlp.IsHelpless(defender) then begin
        if (attacker^.equipped[C_Equip.WEAPON] <> nil) and
            (Types.PItemRec(attacker^.equipped[C_Equip.WEAPON])^.template.itemType =
             C_Item.SONIC_STUNNER_TYPE) then begin
          local.stunSave := Byte(FxEngine.RollSavingThrow(defender, 0, 0));
          FxEngine.AddEffectWithMessage(defender, C_Effect.STUNNED, CharHlp.RollDice(1, 4) + 4, 0, 0,
                                        C_Save.CANCELS, local.stunSave, 'is stunned')
        end else begin
          Inc(GDVars.hitCounts[local.index]);
          Music.SendSoundCommand(GDConsts.hitSound);
          local.hasHit := True;
          CbtActs.CalcWeaponDamage(attacker, defender, local.index);
          if defender^.enabled <> 0 then
            CbtActs.ProcessAttackResult(attacker, defender, GDVars.effectDamage, GDVars.effectDamage, True);
          if defender^.enabled <> 0 then
            if GDVars.effectDamage > 0 then
              FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_PHASE_1 - 1 + local.index, attacker);
          if defender^.enabled = 0 then
            local.isDefenderDown := True;
          if attacker^.enabled = 0 then begin
            local.phase := 0;
            attacker^.attacks[local.index] := 0
          end
        end
      end
    end;
  if not local.hasHit then begin
    Music.SendSoundCommand(GDConsts.missSound);
    CbtActs.ProcessAttackResult(attacker, defender, 0, 0, False)
  end;
  isDone := True;
  for local.index := 1 to SizeOf(attacker^.attacks) do
    if attacker^.attacks[local.index] > 0 then
      isDone := False;
  if attacker^.enabled = 0 then
    isDone := True;
  if isDone then
    isDone := CharHlp.EndActions(attacker)
end;

procedure NoteAttackDirection(attacker, defender: Types.PCharRecord);
var
  angle: Byte;
  attackDirection: Byte;
begin
  Inc(defender^.combatAddr^.directionCount);
  attackDirection := CbtMap.DirectionToward(defender, attacker);
  angle := (attackDirection - defender^.combatAddr^.direction + 8) mod 8;
  if angle > 4 then
    angle := 8 - angle;
  defender^.combatAddr^.directionTotal := (defender^.combatAddr^.directionTotal + angle) mod 8
end;

{ Fires the readied missile or grenade at projectileTargetX/Y: a miss scatters it, a chaff cloud on its line stops it,
  creatures in the blast save or take its damage and effect, a lingering kind leaves a cloud, and the ammunition is
  spent. Note: the chaff message test is the wrong way round -- after 'It goes astray' the message becomes 'It hits
  chaff', and with no earlier message ' and hits chaff'.
  @param(character The combatant firing.)
  @param(kind The projectile kind.) }
procedure CombatLaunchProjectile(character: Types.PCharRecord; kind: Byte);
var parent: TProjectileParent;

  { Moves a scattered shot's offset d4 div 2 cells further out, or in a random direction beyond 8 cells or at 0. }
  procedure ScatterOffset(var value: ShortInt);
  { Unused in this version; see the other implementations of this routine. }
  var distance: Byte;
      amount: Byte;
      direction: Byte;
  begin
    amount := CharHlp.RollDice(1, 4) div 2;
    direction := CharHlp.RollDice(1, 2) * 2 - 3;
    if (value < -8) or (value > 8) then
      Inc(value, amount * direction)
    else if value < 0 then
      Dec(value, amount)
    else if value > 0 then
      Inc(value, amount)
    else
      Inc(value, direction)
  end;

  { Blasts the terrain round the target; with a leaper, picks the free cell outside the blast it reaches soonest. }
  procedure ScanProjectileArea;
  var
    tile: Byte;
    terrain: Byte;
    terrainBelow: Byte;
      outer: ShortInt;
      inner: ShortInt;
      x: ShortInt;
      y: ShortInt;
      bestDistance: Word;
  begin
    bestDistance := 255;
    GDVars.combatArena^.distMode := 1;
    for outer := 0 to 6 do
      for inner := 0 to 6 do begin
        x := GDVars.projectileTargetX + outer - 3;
        y := GDVars.projectileTargetY + inner - 3;
        if (x >= 0) and (x <= SizeOf(GDVars.combatArena^.cells[0]) - 1) and (y >= 0) and
            (y <= SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) then begin
          parent.distance := GDConsts.projectileKinds[kind].radius;
          if Pathing.WalkLine(GDVars.projectileTargetX, GDVars.projectileTargetY, x, y, parent.distance) then begin
            tile := CbtMap.ResolveTerrain(x, y);
            terrain := GDConsts.terrainInfo[tile].blastResult;
            if terrain <> 0 then begin
              terrainBelow := 0;
              if (terrain >= 250) and (terrain <= 253) then
                if CharHlp.PercentileRoll(25) then begin
                  terrain := 146;
                  if CharHlp.PercentileRoll(25) then
                    terrainBelow := 147
                  else
                    terrainBelow := 153
                end else begin
                  case terrain of
                    250: terrain := 152;
                    251: terrain := 149;
                    252: terrain := 150
                  end
                end;
              CbtMap.SetTerrain(x, y, terrain);
              if terrainBelow <> 0 then
                CbtMap.SetTerrain(x, y + 1, terrainBelow)
            end
          end else if parent.leaper <> nil then begin
            x := GDVars.projectileTargetX + outer - 3;
            y := GDVars.projectileTargetY + inner - 3;
            parent.distance := 255;
            CbtMap.GetArenaContents(x, y, parent.occupant, parent.terrain);
            if parent.occupant = 0 then
              if GDConsts.terrainInfo[parent.terrain].cost <> C_Terr.IMPASSABLE then
                if Pathing.WalkLine(parent.sourceX, parent.sourceY, x, y, parent.distance) then
                  if parent.distance < bestDistance then begin
                    bestDistance := parent.distance;
                    parent.selectedX := x;
                    parent.selectedY := y
                  end
          end
        end
      end;
    GDVars.combatArena^.distMode := 0
  end;

  { Plays the kind's sound and scatters its burst or cloud tiles over the view, then scrolls back to the target. }
  procedure AnimateProjectileArea;
  var
    symbol: Byte;
    variant: Byte;
      isAnimated: Boolean;
      realRadius: Real;
      angle: Real;
      width: Byte;
      index: Byte;
      particle: Byte;
      color: Byte;
      x: ShortInt;
      y: ShortInt;
      offsetY: ShortInt;
      offsetX: ShortInt;
  begin
    case kind of
      5: begin
          Music.SendSoundCommand(GDConsts.dazzleGrenadeSound);
          symbol := 36;
          isAnimated := True
        end;
      7: begin
          Music.SendSoundCommand(GDConsts.cloudGrenadeSound);
          symbol := GDConsts.terrainInfo[C_Terr.GAS_TERRAIN].tileId;
          isAnimated := False
        end;
      8: begin
          Music.SendSoundCommand(GDConsts.cloudGrenadeSound);
          symbol := GDConsts.terrainInfo[C_Terr.CHAFF_TERRAIN].tileId;
          isAnimated := False
        end;
      9, 12: begin
          Music.SendSoundCommand(GDConsts.cloudGrenadeSound);
          symbol := GDConsts.terrainInfo[C_Terr.AEROSOL_MIST_TERRAIN].tileId;
          isAnimated := False
        end;
      10, 11, 6: begin
          Music.SendSoundCommand(GDConsts.explosionSound);
          symbol := 28;
          isAnimated := True
        end else
      Exit
    end;
    if isAnimated then begin
      Blit.CopyIconTile(symbol, 0, 0, False);
      Blit.CopyIconTile(symbol, 0, 1, True);
      Blit.CopyIconTile(symbol, 1, 2, False);
      Blit.CopyIconTile(symbol, 1, 3, True)
    end else
      Blit.CopyIconTile(symbol div 2 + 33, symbol and 1, 0, False);
    color := 1;
    { offsetX and offsetY move the burst from the view's center cell toward an arena edge, three tiles for each cell the
      radius overhangs that edge }
    offsetX := 0;
    offsetY := 0;
    if GDVars.projectileTargetX < parent.radius then
      offsetX := (GDVars.projectileTargetX - parent.radius) * 3
    else if GDVars.projectileTargetX > SizeOf(GDVars.combatArena^.cells[0]) - 1 - parent.radius then
      offsetX := (GDVars.projectileTargetX - (SizeOf(GDVars.combatArena^.cells[0]) - 1) + parent.radius) * 3;
    if GDVars.projectileTargetY < parent.radius then
      offsetY := (GDVars.projectileTargetY - parent.radius) * 3
    else if GDVars.projectileTargetY >
        SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1 - parent.radius then
      offsetY := (GDVars.projectileTargetY -
        (SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) + parent.radius) * 3;
    width := parent.radius * 3 + 1;
    for index := 1 to width do begin
      realRadius := index;
      for particle := index * 2 - 2 downto 0 do begin
        angle := Random * 2 * Pi;
        x := Trunc(Cos(angle) * realRadius) + offsetX;
        y := Trunc(Sin(angle) * realRadius) + offsetY;
        if (x >= -9) and (x <= 9) and (y >= -9) and (y <= 9) then begin
          if isAnimated then
            variant := CharHlp.RollDice(1, 4) - 1
          else
            variant := 0;
          Blit.BlitTileClipped(x + 9, y + 9, variant, color, GDVars.movingIcon, GDVars.viewPicture)
        end
      end;
      Blit.FlushView
    end;
    CbtMap.ScrollView(GDVars.projectileTargetX, GDVars.projectileTargetY, 255, C_Dir.CENTER)
  end;

begin
  GDVars.projectileActive := 1;
  parent.weapon := character^.equipped[C_Equip.WEAPON];
  parent.weaponType := @GDVars.itemTypes[parent.weapon^.template.itemType];
  parent.damage := CharHlp.RollDice(parent.weaponType^.diceCount,
                                    parent.weaponType^.diceSides) + parent.weaponType^.damageBonus +
                                      parent.weapon^.template.plus;
  GDVars.projectileEffect := 15;
  parent.effectMinutes := 255;
  parent.radius := GDConsts.projectileKinds[kind].radius;
  case kind of
    5: begin
        parent.effectMinutes := CharHlp.RollDice(1, 6) + 1;
        GDVars.projectileEffect := 23
      end;
    7, 12: begin
        parent.effectMinutes := parent.damage;
        GDVars.projectileEffect := 17;
        parent.damage := 0
      end;
    10: GDVars.projectileEffect := 16
  end;
  if (parent.weaponType^.weaponClass = C_WClass.ROCKET_LAUNCHER) or
      (parent.weaponType^.weaponClass = C_WClass.PLASMA) then
    { unreadies it. Note: isLaunched is not set on this path, so the message goes by whatever it holds }
    parent.weapon^.template.flags := parent.weapon^.template.flags and not C_Item.READIED
  else if parent.weaponType^.weaponClass = C_WClass.GRENADE then begin
    parent.launcher := ViewChar.FindReadiedItem(character, C_Equip.GRENADE_LAUNCHER);
    if parent.launcher <> nil then begin
      parent.launcher^.template.flags := parent.launcher^.template.flags and not C_Item.READIED;
      parent.isLaunched := True
    end else
      parent.isLaunched := False
  end else
    parent.isLaunched := True;
  if parent.isLaunched then
    parent.message := 'launches a missile...'
  else
    parent.message := 'throws a grenade...';
  CharHlp.PrintCreatureMessage(character, parent.message, 10, False);
  parent.message := '';
  CharHlp.RecalcStats(character);
  FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACK_ROLL_ATTACKER, character);
  parent.targetX := CbtMap.CombatCellX(character);
  parent.targetY := CbtMap.CombatCellY(character);
  parent.xDifference := Abs(GDVars.projectileTargetX - parent.targetX);
  parent.yDifference := Abs(GDVars.projectileTargetY - parent.targetY);
  if parent.xDifference > parent.yDifference then
    Inc(parent.xDifference, parent.yDifference shr 1)
  else
    parent.xDifference := parent.yDifference + (parent.xDifference shr 1);
  if character^.attackBonus + CharHlp.RollDice(1, 20) -
     CbtActs.ProjectileRangePenalty(parent.xDifference, ViewChar.ReadiedWeaponRange(character)) <= 50 then begin
    parent.scatterCount := 0;
    parent.distance := 4;
    repeat
      parent.xDifference := GDVars.projectileTargetX - parent.targetX;
      parent.yDifference := GDVars.projectileTargetY - parent.targetY;
      ScatterOffset(parent.xDifference);
      ScatterOffset(parent.yDifference);
      Inc(parent.xDifference, parent.targetX);
      Inc(parent.yDifference, parent.targetY);
      Inc(parent.scatterCount)
    until ((parent.xDifference >= 0) and (parent.xDifference <= SizeOf(GDVars.combatArena^.cells[0]) - 1) and
        (parent.yDifference >= 0) and
        (parent.yDifference <= SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) and
        Pathing.WalkLine(parent.targetX, parent.targetY, parent.xDifference, parent.yDifference, parent.distance)) or
        (parent.scatterCount >= 4);
    if parent.scatterCount < 4 then begin
      GDVars.projectileTargetX := parent.xDifference;
      GDVars.projectileTargetY := parent.yDifference;
      parent.message := 'It goes astray'
    end
  end;
  GDVars.stopsAtChaff := True;
  parent.distance := 255;
  parent.xDifference := GDVars.projectileTargetX;
  parent.yDifference := GDVars.projectileTargetY;
  if not Pathing.WalkLine(parent.targetX, parent.targetY, parent.xDifference, parent.yDifference, parent.distance) then
    if GDVars.sawChaff then begin
      { Note: the test is inverted. After 'It goes astray' the message becomes 'It hits chaff', and with no message yet
        ' and hits chaff'. }
      if parent.message = '' then
        parent.message := parent.message + ' and'
      else
        parent.message := 'It';
      parent.message := parent.message + ' hits chaff';
      GDVars.projectileTargetX := parent.xDifference;
      GDVars.projectileTargetY := parent.yDifference
    end;
  CbtActs.AnimateMissile(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), GDVars.projectileTargetX,
                         GDVars.projectileTargetY, parent.weapon);
  CbtMap.ScrollView(GDVars.projectileTargetX, GDVars.projectileTargetY, 255, C_Dir.CENTER);
  parent.leaper := nil;
  parent.sourceX := -1;
  parent.sourceY := -1;
  parent.selectedX := -1;
  parent.selectedY := -1;
  if kind in [5, 6, 10, 11] then begin
    parent.cursor := GDVars.partyHead;
    while parent.cursor <> nil do
      if (parent.cursor^.enabled <> 0) and
          CharHlp.HasEffect(parent.cursor, C_Effect.UNKILLABLE, parent.candidateEffect) then begin
        parent.leaper := parent.cursor;
        parent.sourceSlot := CbtMap.CombatSlot(parent.leaper);
        parent.cursor := nil;
        parent.sourceX := CbtMap.CombatCellX(parent.leaper);
        parent.sourceY := CbtMap.CombatCellY(parent.leaper)
      end else
        parent.cursor := parent.cursor^.nextCharAddr;
    if kind <> 5 then ScanProjectileArea
  end;
  Pathing.BuildTargetList(GDVars.projectileTargetX, GDVars.projectileTargetY, GDConsts.projectileKinds[kind].radius,
                          255, 1);
  parent.targetCount := 0;
  FillChar(parent.targets, SizeOf(parent.targets), 0);
  for parent.scatterCount := 1 to GDVars.pathTargetCount do begin
    parent.cursor := GDVars.creatures[GDVars.pathTargets[parent.scatterCount].slot];
    if parent.cursor^.enabled <> 0 then
      if (parent.cursor = parent.leaper) and (parent.selectedX <> -1) then begin
        CharHlp.CombatPrintCreatureInfo(parent.cursor);
        CharHlp.PrintCreatureMessage(parent.cursor, 'leaps for cover!', 10, False);
        GDVars.combatantCells[parent.sourceSlot].x := -1;
        GDVars.combatantCells[parent.sourceSlot].y := -1;
        CbtMap.ScrollView(GDVars.projectileTargetX, GDVars.projectileTargetY, 255, C_Dir.CENTER);
        Blit.CopyIconTile(parent.cursor^.orderNumber, 0, 0, parent.selectedX < parent.sourceX);
        CharHlp.CombatAnimateMovingIcon(parent.sourceX, parent.sourceY, parent.selectedX, parent.selectedY, 1, 30);
        GDVars.combatantCells[parent.sourceSlot].x := parent.selectedX;
        GDVars.combatantCells[parent.sourceSlot].y := parent.selectedY;
        CbtMap.BuildArenaArrays;
        CbtMap.ScrollView(GDVars.projectileTargetX, GDVars.projectileTargetY, 255, C_Dir.CENTER)
      end else begin
        Inc(parent.targetCount);
        parent.targets[parent.targetCount] := parent.cursor
      end
  end;
  AnimateProjectileArea;
  if parent.message <> '' then begin
    Border.ClearBox(23, 10, 38, 21);
    TextRend.DisplayMessageWindow(23, 10, 38, 21, LightGreen, Black, True, parent.message);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow
  end;
  if GDConsts.projectileKinds[kind].effectId > 0 then
    parent.message := 'is ' + GDConsts.effectStatusNames[GDConsts.projectileKinds[kind].effectId]
  else
    parent.message := '';
  if GDConsts.projectileKinds[kind].lingering <> 0 then begin
    GetMem(parent.savedEffect, SizeOf(Types.TAreaEffect));
    FillChar(parent.savedEffect^, SizeOf(Types.TAreaEffect), 0);
    with parent.savedEffect^ do begin
      x := GDVars.projectileTargetX;
      y := GDVars.projectileTargetY;
      parent.directionCount := 9;
      if (GDVars.zone0^.areaType and C_Area.ZERO_GRAVITY) <> 0 then
        countdown := 1
      else
        countdown := 4;
      case kind of
        7: marker := C_Terr.GAS_TERRAIN;
        8: marker := C_Terr.CHAFF_TERRAIN;
        9: marker := C_Terr.AEROSOL_MIST_TERRAIN
      else
        TextRend.DisplayValue('Bad tileNum in lingering-', marker)
      end;
      for parent.scatterCount := 1 to parent.directionCount do begin
        parent.directionIndex := GDConsts.cloudDir[parent.scatterCount];
        parent.effectX := x + GDConsts.dirStepX[parent.directionIndex];
        parent.effectY := y + GDConsts.dirStepY[parent.directionIndex];
        if (parent.effectX >= 0) and (parent.effectX <= SizeOf(GDVars.combatArena^.cells[0]) - 1) and
            (parent.effectY >= 0) and
            (parent.effectY <=
              SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) then begin
          parent.terrain := CbtMap.ResolveTerrain(x + GDConsts.dirStepX[parent.directionIndex],
                                                  y + GDConsts.dirStepY[parent.directionIndex]);
          active[parent.scatterCount] := Byte((parent.terrain > 0) and
                                              (GDConsts.terrainInfo[parent.terrain].cost < C_Terr.IMPASSABLE));
          underlyingTerrain[parent.scatterCount] := parent.terrain;
          if active[parent.scatterCount] <> 0 then
            GDVars.combatArena^.cells[y + GDConsts.dirStepY[parent.directionIndex],
                                        x + GDConsts.dirStepX[parent.directionIndex]] := marker
        end else
          active[parent.scatterCount] := 0
      end
    end;
    parent.savedEffect^.next := GDVars.areaEffects;
    GDVars.areaEffects := parent.savedEffect;
    CbtMap.ScrollView(GDVars.projectileTargetX, GDVars.projectileTargetY, 255, C_Dir.CENTER);
    TextRend.PauseOnly
  end;
  for parent.scatterCount := 1 to parent.targetCount do begin
    parent.cursor := parent.targets[parent.scatterCount];
    if parent.cursor <> nil then
      if parent.cursor^.enabled <> 0 then
        if (kind <> 4) or
            ((CbtMap.CombatCellX(parent.cursor) >= GDVars.projectileTargetX) and
             (CbtMap.CombatCellY(parent.cursor) >= GDVars.projectileTargetY)) then begin
          if ((kind = 5) and ((parent.cursor^.armorFlags and C_Armor.GOGGLES) <> 0)) or
              ((kind = 7) and ((parent.cursor^.armorFlags and C_Armor.BREATHING_PROTECTION) <> 0)) then
            parent.saveResult := 1
          else
            parent.saveResult := Byte(FxEngine.RollSavingThrow(parent.cursor, GDConsts.projectileKinds[kind].saveType,
                                                               0));
          if parent.damage > 0 then
            FxEngine.InflictNonWeaponDamage(parent.cursor, parent.damage, GDConsts.projectileKinds[kind].saveReduction,
                                            Boolean(parent.saveResult));
          if parent.cursor^.enabled <> 0 then
            if GDConsts.projectileKinds[kind].effectId > 0 then
              FxEngine.AddEffectWithMessage(parent.cursor, GDConsts.projectileKinds[kind].effectId,
                                            parent.effectMinutes, 0, 0, GDConsts.projectileKinds[kind].saveReduction,
                                            parent.saveResult, parent.message)
        end
  end;
  parent.isLaunched := CharHlp.EndActions(character);
  if parent.weapon^.template.quantity > 0 then begin
    Dec(parent.weapon^.template.quantity);
    if parent.weapon^.template.quantity = 0 then
      if parent.weaponType^.consumable = 1 then begin
        CharHlp.RemoveItem(character, parent.weapon);
        character^.equipped[C_Equip.WEAPON] := nil
      end
  end
end;

procedure MakeAttack(attacker, defender: Types.PCharRecord; fromBehind: Boolean; var done: Boolean);
var local: TMakeAttackLocals;
begin
  GDVars.mapVisible := 1;
  GDVars.creatureInfoDirty := 1;
  GDVars.combatEndRound := GDVars.combatRound + C_Combat.IDLE_ROUNDS;
  if defender <> nil then begin
    local.direction := CbtMap.DirectionToward(defender, attacker);
    if (defender^.combatAddr^.directionCount < 2) and not fromBehind then
      defender^.combatAddr^.direction := local.direction;
    if CbtMap.CombatIconVisible(defender, 0) then begin
      CbtMap.SetCreatureFacing(defender, defender^.combatAddr^.direction, 0, 1);
      CbtMap.SetCreatureFacing(defender, defender^.combatAddr^.direction, 0, 0)
    end;
    local.direction := CbtMap.DirectionToward(attacker, defender);
    attacker^.combatAddr^.direction := local.direction
  end;
  CharHlp.CombatPrintCreatureInfo(attacker);
  CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 1, 0);
  attacker^.combatAddr^.target := defender;
  Delay(100);
  GDVars.projectileActive := 0;
  local.weapon := attacker^.equipped[C_Equip.WEAPON];
  if (local.weapon <> nil) and (local.weapon^.template.special[3] <> 0) and
      (local.weapon^.template.special[2] in [5..12]) then
    CbtActs.CombatLaunchProjectile(attacker, local.weapon^.template.special[2]);
  if GDVars.projectileActive = 0 then begin
    if CharHlp.HasAreaWeapon(attacker) then
      TextRend.DisplayValue('Weapon specials incorrectly set!', 0);
    if ViewChar.ReadiedWeaponRange(attacker) > 1 then
      CbtActs.AnimateMissile(CbtMap.CombatCellX(attacker), CbtMap.CombatCellY(attacker), CbtMap.CombatCellX(defender),
                             CbtMap.CombatCellY(defender), attacker^.equipped[C_Equip.WEAPON]);
    done := True;
    if (attacker^.attacks[1] > 0) or (attacker^.attacks[2] > 0) then begin
      local.savedCharacter := GDVars.currentCharacter;
      GDVars.currentCharacter := attacker;
      CbtActs.RollAttacks(attacker, defender, fromBehind, done);
      if local.weapon <> nil then
        if GDVars.itemTypes[local.weapon^.template.itemType].weaponClass > C_WClass.MELEE then begin
          Dec(local.weapon^.template.quantity, GDVars.attackCounts[1]);
          if (local.weapon^.template.quantity <= 0) and
              (GDVars.itemTypes[local.weapon^.template.itemType].consumable <> 0) then
            CharHlp.RemoveItem(attacker, local.weapon)
        end;
      CharHlp.RecalcStats(attacker);
      GDVars.currentCharacter := local.savedCharacter
    end
  end;
  if CbtMap.CombatIconVisible(attacker, 0) then begin
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 1, 1);
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 0, 0)
  end
end;

{ Gives the penalty for a long shot.
  @param(distance The distance to the target.)
  @param(weaponRange The weapon's range.)
  @returns(5 past three quarters of weaponRange, 2 past half, else 0; 0 when weaponRange is 1 or less.) }
function ProjectileRangePenalty(distance, weaponRange: Byte): ShortInt;
begin
  if weaponRange <= 1 then
    ProjectileRangePenalty := 0
  else if distance > ((weaponRange * 3) shr 2) then
    ProjectileRangePenalty := 5
  else if distance > (weaponRange shr 1) then
    ProjectileRangePenalty := 2
  else
    ProjectileRangePenalty := 0
end;

{ Raises the armor value the attack must reach: by 5 against a guarding ranged attacker, else by 2 when the line of fire
  crosses blocked terrain, plus ProjectileRangePenalty.
  @param(attacker The combatant attacking.)
  @param(defender The combatant attacked.)
  @param(armorClass The value, raised in place.) }
procedure ApplyRangePenalty(attacker, defender: Types.PCharRecord; var armorClass: Byte);
var
  distance: Byte;
  targetX: Byte;
  targetY: Byte;
    walkDistance: Word;
begin
  distance := CharHlp.CalcDistance(attacker, defender);
  if CharHlp.HasRangedWeapon(attacker) and (attacker^.combatAddr^.guarding <> 0) then
    Inc(armorClass, 5)
  else begin
    targetX := CbtMap.CombatCellX(defender);
    targetY := CbtMap.CombatCellY(defender);
    walkDistance := 255;
    if Pathing.WalkLine(CbtMap.CombatCellX(attacker), CbtMap.CombatCellY(attacker), ShortInt(targetX),
                        ShortInt(targetY), walkDistance) then;
    if GDVars.sawBlockedTerrain then
      Inc(armorClass, 2);
    Inc(armorClass, CbtActs.ProjectileRangePenalty(distance, ViewChar.ReadiedWeaponRange(attacker)))
  end
end;

procedure CombatUseJetpack(character: Types.PCharRecord);
var local: TJetpackLocals;
begin
  local.slot := CbtMap.CombatSlot(character);
  local.x := GDVars.combatantCells[local.slot].x;
  local.y := GDVars.combatantCells[local.slot].y;
  if CharHlp.SelectSkillCharacter(C_Skill.USE_JETPACK, 2, False, Pointer(character)) >= 2 then begin
    CbtActs.ManualAimCursor(character, nil, 0, CbtActs.AIM_JETPACK, False, False, local.isDone, local.isDone,
                            local.selection, local.x, local.y);
    CbtMap.RedrawArenaCell(GDVars.combatCursorX, GDVars.combatCursorY);
    if character^.status = C_Status.USING_JETPACK then begin
      CbtActs.GuardersAttack(character);
      GDVars.combatantCells[local.slot].x := -128;
      { Note: sets .x twice and never .y }
      GDVars.combatantCells[local.slot].x := -128;
      character^.combatAddr^.movement := 0;
      if character^.enabled <> 0 then begin
        Blit.CopyIconTile(character^.orderNumber, 0, 0, GDVars.combatCursorX < local.x);
        CharHlp.CombatAnimateMovingIcon(local.x, local.y, GDVars.combatCursorX, GDVars.combatCursorY, 1, 15);
        GDVars.combatantCells[local.slot].x := GDVars.combatCursorX;
        GDVars.combatantCells[local.slot].y := GDVars.combatCursorY;
        CbtMap.BuildArenaArrays;
        CbtActs.GuardersAttack(character)
      end;
      if character^.enabled <> 0 then
        character^.status := C_Status.USED_JETPACK
    end
  end else begin
    CharHlp.PrintCreatureMessage(character, 'fails at use jetpack', 10, False);
    character^.status := C_Status.USING_JETPACK;
    character^.combatAddr^.movement := 0;
    local.landingIndex := -1;
    for local.index := 0 to SizeOf(local.xs) - 1 do begin
      repeat
        local.roll := CharHlp.RollDice(1, 24) - 1;
        if local.roll >= 12 then Inc(local.roll);
        local.candidateX := local.x + (local.roll mod 5) - 2;
        local.candidateY := local.y + (local.roll div 5) - 1;
        local.distance := 255
      until (local.candidateX >= 0) and (local.candidateX <= SizeOf(GDVars.combatArena^.cells[0]) - 1) and
          (local.candidateY >= 0) and
          (local.candidateY <= SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1);
      local.xs[local.index] := local.candidateX;
      local.ys[local.index] := local.candidateY;
      local.x := local.candidateX;
      local.y := local.candidateY;
      CbtMap.GetArenaContents(local.x, local.y, local.occupant, local.terrain);
      if (local.occupant = 0) and (GDConsts.terrainInfo[local.terrain].cost <> C_Terr.IMPASSABLE) then
        local.landingIndex := local.index
    end;
    local.x := GDVars.combatantCells[local.slot].x;
    local.y := GDVars.combatantCells[local.slot].y;
    GDVars.combatantCells[local.slot].x := -128;
    GDVars.combatantCells[local.slot].y := -128;
    Mouse.HideMouse;
    for local.index := 0 to local.landingIndex do begin
      Blit.CopyIconTile(character^.orderNumber, 0, 0, local.xs[local.index] < local.x);
      CharHlp.CombatAnimateMovingIcon(local.x, local.y, local.xs[local.index], local.ys[local.index], 1, 40);
      local.x := local.xs[local.index];
      local.y := local.ys[local.index]
    end;
    Mouse.ShowMouse;
    GDVars.combatantCells[local.slot].x := local.x;
    GDVars.combatantCells[local.slot].y := local.y;
    CbtMap.BuildArenaArrays;
    CbtActs.GuardersAttack(character);
    if character^.enabled <> 0 then
      character^.status := C_Status.USED_JETPACK;
    local.isDone := CharHlp.EndActions(character);
    CbtMap.ScrollView(local.x, local.y, 2, C_Dir.CENTER)
  end
end;

function Guard(character: Types.PCharRecord): Boolean;
{ Unused in this version; see the other implementations of this routine. }
var guardMessage: array[0..6] of Byte;
begin
  Guard := CharHlp.EndActions(character);
  if not CharHlp.HasAreaWeapon(character) then begin
    character^.combatAddr^.guarding := 1;
    CharHlp.PrintBottomLine('Guarding')
  end
end;

{ Plays the weapon's sound and animates its shot from source to target.
  @param(sourceX The shooter's column.)
  @param(sourceY The shooter's row.)
  @param(targetX The target's column.)
  @param(targetY The target's row.)
  @param(weapon The weapon fired.) }
procedure AnimateMissile(sourceX, sourceY, targetX, targetY: ShortInt; weapon: Types.PItemRec);
var local: TRangedAnimLocals;

  { Loads the shot's picture for its direction from icon kind firstKind on, mirrored for the westward ones. }
  procedure Animate(firstKind: Byte);
  begin
    if Odd(local.direction) then begin
      if (local.direction = C_Dir.SOUTHEAST) or (local.direction = C_Dir.SOUTHWEST) then
        Blit.CopyIconTile(firstKind + 1, 1, 0, local.direction = C_Dir.SOUTHWEST)
      else
        Blit.CopyIconTile(firstKind + 1, 0, 0, local.direction = C_Dir.NORTHWEST)
    end else
      Blit.CopyIconTile(firstKind + (local.direction mod 4), local.direction div 4, 0, False)
  end;

begin
  case weapon^.template.itemType of
    CbtActs.CROSSBOW_TYPE, CbtActs.BOLT_GUN_TYPE: Music.SendSoundCommand(GDConsts.boltSound);
    CbtActs.NEEDLE_GUN_TYPE: Music.SendSoundCommand(GDConsts.needleGunSound);
    CbtActs.LASER_PISTOL_TYPE, CbtActs.LASER_RIFLE_TYPE: Music.SendSoundCommand(GDConsts.laserSound);
    CbtActs.ROCKET_PISTOL_TYPE, CbtActs.ROCKET_RIFLE_TYPE: Music.SendSoundCommand(GDConsts.rocketSound);
    CbtActs.MICROWAVE_GUN_TYPE: Music.SendSoundCommand(GDConsts.microwaveGunSound);
    CbtActs.HEAT_GUN_TYPE: Music.SendSoundCommand(GDConsts.heatGunSound);
    C_Item.SONIC_STUNNER_TYPE: Music.SendSoundCommand(GDConsts.sonicStunnerSound);
    CbtActs.GRENADE_LAUNCHER_TYPE, C_Item.PLASMA_THROWER_TYPE, C_Item.ROCKET_LAUNCHER_TYPE:
      Music.SendSoundCommand(GDConsts.launchSound)
  end;
  local.direction := CbtMap.DirectionBetween(sourceX, sourceY, targetX, targetY);
  local.frames := 1;
  local.pace := 10;
  local.imageSize := GDVars.movingIcon^.frameSize;
  case weapon^.template.itemType of
    C_Item.PLASMA_THROWER_TYPE: Animate(13);
    CbtActs.HEAT_GUN_TYPE: Animate(13);
    CbtActs.LASER_PISTOL_TYPE, CbtActs.LASER_RIFLE_TYPE: Animate(16);
    CbtActs.CROSSBOW_TYPE: Animate(19);
    CbtActs.BOLT_GUN_TYPE, CbtActs.NEEDLE_GUN_TYPE: Animate(22);
    C_Item.ROCKET_LAUNCHER_TYPE, CbtActs.ROCKET_PISTOL_TYPE, CbtActs.ROCKET_RIFLE_TYPE: Animate(25);
    CbtActs.MICROWAVE_GUN_TYPE, C_Item.SONIC_STUNNER_TYPE: begin
      Blit.CopyIconTile(30, 0, 0, False);
      Blit.CopyIconTile(30, 1, 1, False);
      local.frames := 2
    end else begin
      Blit.CopyIconTile(37, 0, 0, False);
      Blit.CopyIconTile(37, 1, 1, False);
      local.frames := 2
    end
  end;
  CharHlp.CombatAnimateMovingIcon(sourceX, sourceY, targetX, targetY, local.frames, local.pace)
end;

procedure UpdateHostileHpPercent;
var local: TPercentLocals;
begin
  local.maximumTotal := 0;
  local.hitPointTotal := 0;
  local.combatant := GDVars.partyHead;
  while local.combatant <> nil do begin
    if local.combatant^.hostile = C_Side.HOSTILE then begin
      if local.combatant^.enabled <> 0 then
        local.hitPointTotal := local.hitPointTotal + local.combatant^.hitPoints;
      local.maximumTotal := local.maximumTotal + local.combatant^.hpMax
    end;
    local.combatant := local.combatant^.nextCharAddr
  end;
  if local.maximumTotal > 0 then
    GDVars.hostileHpPercent := ((20 * local.hitPointTotal) div local.maximumTotal) * 5
end;

function HighestEnemyMovement(creature: Types.PCharRecord): Byte;
var local: THighestLocals;
begin
  local.highest := 0;
  local.combatant := GDVars.partyHead;
  while local.combatant <> nil do begin
    if (Byte(CharHlp.EnemyTeam(creature)) = local.combatant^.hostile) and (local.combatant^.enabled <> 0) then begin
      local.movement := CharHlp.RecalcMovement(local.combatant) div 2;
      if local.movement > local.highest then
        local.highest := local.movement
    end;
    local.combatant := local.combatant^.nextCharAddr
  end;
  HighestEnemyMovement := local.highest
end;

function CheckAttackAlly(attacker, defender: Types.PCharRecord): Boolean;
var combatant: Types.PCharRecord;
begin
  if (Byte(CharHlp.EnemyTeam(defender)) = attacker^.hostile) or (attacker^.quickfight <> 0) then
    CheckAttackAlly := True
  else begin
    GDVars.promptColor := Yellow;
    if MenuCore.YesNoMenu('Attack Ally: ', C_Menu.DEFAULT_NO) <> 'Y' then
      CheckAttackAlly := False
    else begin
      CheckAttackAlly := True;
      GDVars.zone1^.hasAttackedAlly := 1;
      combatant := GDVars.partyHead;
      while combatant <> nil do begin
        if (combatant^.status = C_Status.OKAY) and (combatant^.npc <> C_Npc.PARTY_MEMBER_NPC) and
            (combatant^.npc > C_Npc.NON_PLAYER_FLAG - 1) then begin
          combatant^.hostile := C_Side.HOSTILE;
          combatant^.combatAddr^.target := nil;
          combatant^.quickfight := 1
        end;
        combatant := combatant^.nextCharAddr
      end;
      CharHlp.CountTeams
    end
  end
end;

{ Shows the range on row 23, with short, medium or long when within the weapon's range.
  @param(distance The distance to the target.)
  @param(weaponRange The weapon's range.) }
procedure DisplayCombatRange(distance, weaponRange: Byte);
var message: String[25];
begin
  message := '';
  if distance <= weaponRange then
    case CbtActs.ProjectileRangePenalty(distance, weaponRange) of
      0: message := '(short)';
      2: message := '(medium)';
      5: message := '(long)'
    end;
  message := 'Range = ' + TextRend.WordToString(distance) + ' ' + message;
  TextRend.DisplayString(0, 23, LightGreen, Black, message);
  Border.ClearBox(Length(message), 23, 39, 23)
end;

{ Shows the range to the target cell and the Aim menu, offering Attack when in range, isAccepted, canAttack and the
  weapon can take the target.
  @param(character The combatant aiming.)
  @param(target The target, or nil.)
  @param(range The range accepted.)
  @param(mode Unused.)
  @param(allowsGround Unused.)
  @param(canAttack True offers Attack.)
  @param(isAccepted True when the cell can be accepted.)
  @param(targetX The target cell's column.)
  @param(targetY The target cell's row.)
  @returns(The key chosen.) }
function AimTargetMenu(character, target: Types.PCharRecord; range, mode: Byte; allowsGround, canAttack,
                       isAccepted: Boolean; targetX, targetY: ShortInt): Byte;
var message: Types.TString40;
    weapon: Types.PItemRec;
    distance: Word;
    { Unused in this version; see the other implementations of this routine. }
    hasLine: Byte;
    savedMode: Byte;
    rangeValue: Byte;
begin
  message := 'Next Prev Manual ';
  distance := 255;
  savedMode := GDVars.combatArena^.distMode;
  GDVars.combatArena^.distMode := 1;
  hasLine := Byte(Pathing.WalkLine(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), targetX, targetY,
                                   distance));
  GDVars.combatArena^.distMode := savedMode;
  distance := distance shr 1;
  rangeValue := ViewChar.ReadiedWeaponRange(character);
  CbtActs.DisplayCombatRange(distance, rangeValue);
  if (range >= distance) and isAccepted and canAttack then
    if CharHlp.HasLoadedAreaWeapon(character) or
        ((character <> target) and
         (not CharHlp.HasRangedWeapon(character) or CharHlp.FindDamagingRangedWeapon(character, weapon))) then
      message := message + 'Attack ';
  message := message + 'Center Exit';
  if target <> nil then begin
    CbtMap.DisplayMapViewCentered(target, 3, True);
    GDVars.creatureInfoDirty := 1;
    CharHlp.CombatPrintCreatureInfo(target)
  end;
  MenuCore.MenuHorizontal('Aim:', message, True, False);
  AimTargetMenu := Ord(GDVars.menuKey)
end;

{ Fills selection with target and its cell; with AIM_ATTACK it first asks about an ally (CheckAttackAlly) and then
  attacks.
  @param(attacker The combatant aiming.)
  @param(target The combatant accepted.)
  @param(mode AIM_ATTACK makes it an attack.)
  @param(isDone True when the attacker's turn is over.)
  @param(selection Receives the target and its cell, or zeros when the attack is called off.) }
procedure ConfirmAttackTarget(attacker, target: Types.PCharRecord; mode: Byte; var isDone: Boolean;
                              var selection: Types.TAimTarget);
{ Unused in this version; see the other implementations of this routine. }
var targetDirection: Byte;
    { Unused in this version; see the other implementations of this routine. }
    weapon: Types.PItemRec;
begin
  weapon := nil;
  isDone := True;
  if mode = C_Combat.AIM_ATTACK then
    if not CbtActs.CheckAttackAlly(attacker, target) then
      isDone := False;
  if isDone then begin
    selection.character := target;
    selection.x := CbtMap.CombatCellX(target);
    selection.y := CbtMap.CombatCellY(target);
    GDVars.combatArena^.cursorShown := False;
    CbtMap.ScrollView(GDVars.combatArena^.viewOriginX + 3, GDVars.combatArena^.viewOriginY + 3, 3,
                      C_Dir.CENTER);
    if mode = C_Combat.AIM_ATTACK then begin
      CbtActs.NoteAttackDirection(attacker, target);
      CbtActs.MakeAttack(attacker, target, False, isDone)
    end
  end else
    FillChar(selection, SizeOf(Types.TAimTarget), 0)
end;

procedure AttackGroundTarget(character: Types.PCharRecord; x, y: Byte; var isDone: Boolean);
begin
  isDone := True;
  GDVars.projectileTargetX := x;
  GDVars.projectileTargetY := y;
  CbtActs.MakeAttack(character, nil, False, isDone)
end;

{ Runs the combat cursor: cursor keys move it, A accepts the cell, L lands a jetpack flight there, E puts it back.
  @param(character The combatant aiming.)
  @param(target The target the cursor starts on, or nil.)
  @param(requestedRange The range accepted.)
  @param(mode AIM_ATTACK aims an attack, AIM_JETPACK a jetpack flight.)
  @param(allowsGround Has no effect: it is OR-ed with target <> nil in the acceptance test, and a nil target then fails
    CanTarget anyway.)
  @param(canAttack True lets it accept a target.)
  @param(isAcceptable Whether the cell under the cursor can be accepted.)
  @param(isChosen True when A accepted it.)
  @param(selection The cell, and creature, accepted.)
  @param(x The cursor's starting column.)
  @param(y The cursor's starting row.) }
procedure ManualAimCursor(character, target: Types.PCharRecord; requestedRange, mode: Byte; allowsGround,
                          canAttack: Boolean; var isAcceptable, isChosen: Boolean; var selection: Types.TAimTarget; x,
                          y: ShortInt);
var local: TManualAimLocals;
begin
  GDVars.cursorActive := 1;
  local.initialRange := ViewChar.ReadiedWeaponRange(character);
  local.initialX := x;
  local.initialY := y;
  GDVars.combatCursorX := x;
  GDVars.combatCursorY := y;
  FillChar(selection, SizeOf(Types.TAimTarget), 0);
  GDVars.combatArena^.cursorShown := True;
  GDVars.combatArena^.cursorSize := 1;
  local.key := ' ';
  local.direction := C_Dir.CENTER;
  GDVars.frameScriptDone := False;
  while not (local.key in [C_Keys.NONE, 'A', 'E', 'L']) do begin
    CbtMap.ScrollView(GDVars.combatCursorX, GDVars.combatCursorY, 2, local.direction);
    Inc(GDVars.combatCursorX, GDConsts.dirStepX[local.direction]);
    Inc(GDVars.combatCursorY, GDConsts.dirStepY[local.direction]);
    if GDVars.combatCursorX < 0 then GDVars.combatCursorX := 0;
    if GDVars.combatCursorY < 0 then GDVars.combatCursorY := 0;
    if GDVars.combatCursorX > SizeOf(GDVars.combatArena^.cells[0]) - 1 then
      GDVars.combatCursorX := SizeOf(GDVars.combatArena^.cells[0]) - 1;
    if GDVars.combatCursorY > SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1 then
      GDVars.combatCursorY := SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1;
    CbtMap.GetArenaContents(GDVars.combatCursorX, GDVars.combatCursorY, local.occupant, local.terrain);
    GameIo.FlushKeys;
    isAcceptable := False;
    local.distance := 255;
    local.targetX := GDVars.combatCursorX;
    local.targetY := GDVars.combatCursorY;
    if mode = CbtActs.AIM_JETPACK then begin
      TextRend.DisplayString(0, 23, LightGreen, Black, 'Flying');
      if (GDConsts.terrainInfo[local.terrain].cost <> C_Terr.IMPASSABLE) and (local.occupant = 0) then begin
        local.message := 'Land ';
        isAcceptable := True
      end else
        local.message := ''
    end else begin
      if Pathing.WalkLine(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), local.targetX, local.targetY,
                          local.distance) then begin
        isAcceptable := True;
        CbtActs.DisplayCombatRange(local.distance shr 1, local.initialRange)
      end else
        Border.ClearBox(0, 23, 39, 23);
      local.distance := local.distance shr 1;
      target := nil;
      if isAcceptable then begin
        if local.occupant > 0 then
          target := GDVars.creatures[local.occupant]
        else if local.terrain = C_Terr.CORPSE_TERRAIN then begin
          { Note: no bound at 8; see GDVars' downedCount }
          for local.index := 1 to GDVars.downedCount do
            if (GDVars.downedCreatures[local.index].x = GDVars.combatCursorX) and
                (GDVars.downedCreatures[local.index].y = GDVars.combatCursorY) then
              target := GDVars.downedCreatures[local.index].character
        end
      end;
      if target <> nil then begin
        GDVars.creatureInfoDirty := 1;
        CharHlp.CombatPrintCreatureInfo(target)
      end else
        Border.ClearBox(23, 1, 38, 21);
      if not ((requestedRange >= local.distance) and (GDConsts.terrainInfo[local.terrain].cost <> C_Terr.IMPASSABLE) and
              canAttack and
              (CharHlp.HasLoadedAreaWeapon(character) or
               (((target <> nil) or allowsGround) and CbtActs.CanTarget(character, target) and
                ((mode <> C_Combat.AIM_ATTACK) or
                 ((character <> target) and ((local.occupant <> 0) or (local.terrain <> C_Terr.CORPSE_TERRAIN)))) and
                   ((not CharHlp.HasRangedWeapon(character)) or
                    CharHlp.FindDamagingRangedWeapon(character, local.weapon))))) then
        isAcceptable := False;
      if isAcceptable then
        local.message := 'Attack'
      else
        local.message := 'Exit'
    end;
    MenuCore.MenuHorizontal('(Use Cursor keys) ', local.message, True, False);
    local.key := GDVars.menuKey;
    case local.key of
      'L': begin
        isChosen := False;
        GDVars.frameScriptDone := False;
        character^.status := C_Status.USING_JETPACK;
        CbtMap.RedrawArenaCell(GDVars.combatCursorX, GDVars.combatCursorY)
      end;
      'A': begin
        isChosen := True;
        selection.x := GDVars.combatCursorX;
        selection.y := GDVars.combatCursorY;
        if target <> nil then
          selection.character := target
        else
          selection.character := nil;
        GDVars.combatArena^.cursorShown := False;
        CbtMap.RedrawArenaCell(GDVars.combatCursorX, GDVars.combatCursorY);
        GDVars.frameScriptDone := False
      end;
      C_Keys.UP: local.direction := C_Dir.NORTH;
      C_Keys.PAGE_UP: local.direction := C_Dir.NORTHEAST;
      C_Keys.RIGHT: local.direction := C_Dir.EAST;
      C_Keys.PAGE_DOWN: local.direction := C_Dir.SOUTHEAST;
      C_Keys.DOWN: local.direction := C_Dir.SOUTH;
      C_Keys.END_KEY: local.direction := C_Dir.SOUTHWEST;
      C_Keys.LEFT: local.direction := C_Dir.WEST;
      C_Keys.HOME: local.direction := C_Dir.NORTHWEST;
      ' ', '5': begin
        CbtMap.ScrollView(GDVars.combatCursorX, GDVars.combatCursorY, 0, C_Dir.CENTER);
        local.direction := C_Dir.CENTER
      end;
      'E', C_Keys.NONE: begin
        isChosen := False;
        CbtMap.RedrawArenaCell(GDVars.combatCursorX, GDVars.combatCursorY);
        FillChar(selection, SizeOf(Types.TAimTarget), 0);
        selection.x := local.initialX;
        selection.y := local.initialY;
        selection.character := nil;
        CbtMap.ScrollView(local.initialX, local.initialY, 0, C_Dir.CENTER);
        GDVars.combatArena^.cursorShown := False;
        CbtMap.RedrawArenaCell(local.initialX, local.initialY);
        GDVars.frameScriptDone := False
      end else local.direction := C_Dir.CENTER
    end
  end;
  GDVars.cursorActive := 0
end;

procedure CombatAimMenu(character: Types.PCharRecord; requestedRange, mode: Byte; allowsGround, canAttack: Boolean;
                        var isDone: Boolean; var selection: Types.TAimTarget);
type TAimMenuLocals = packed record
       { Unused in this version; see the other implementations of this routine. }
       aimDelay: Word;
       initialY: ShortInt;
       initialX: ShortInt;
       currentY: ShortInt;
       currentX: ShortInt;
       isChosen: Boolean;
       isAccepted: Boolean;
       key: Char;
       target: Types.PCharRecord;
       newY: ShortInt;
       newX: ShortInt;
       oldY: ShortInt;
       oldX: ShortInt;
       oldXTail: Byte;
       index: Byte;
       count: Byte;
       weaponRange: Byte;
       entries: array[1..C_Combat.MAX_COMBATANTS] of Types.TTarget
     end;
var local: TAimMenuLocals;

  { Steps delta entries round the target list and moves the cursor icon there; an empty list stops the game. }
  function AdvanceAimTarget(delta: ShortInt): Types.PCharRecord;
  var
    previous: Types.PCharRecord;
    current: Types.PCharRecord;
  begin
    previous := GDVars.creatures[local.entries[local.index].slot];
    if previous = nil then previous := character;
    if local.count < 1 then begin
      TextRend.DisplayValue('NumTargets < 1!!!', 0);
      GameIo.ExitGame
    end;
    local.oldX := GDVars.combatantCells[local.entries[local.index].slot].x;
    local.oldY := GDVars.combatantCells[local.entries[local.index].slot].y;
    Inc(local.index, delta);
    if local.index = 0 then local.index := local.count;
    if local.index > local.count then local.index := 1;
    current := GDVars.creatures[local.entries[local.index].slot];
    local.newX := GDVars.combatantCells[local.entries[local.index].slot].x;
    local.newY := GDVars.combatantCells[local.entries[local.index].slot].y;
    if (current = nil) or (local.newX < 0) or (local.newY < 0) then begin
      AdvanceAimTarget := previous;
      local.newX := local.oldX;
      local.newY := local.oldY
    end else begin
      AdvanceAimTarget := current;
      CharHlp.CombatAnimateMovingIcon(local.oldX, local.oldY, local.newX, local.newY, 1, 0);
      local.oldX := local.newX;
      local.oldY := local.newY
    end
  end;

  { Lists the targets CanTarget allows round the character and preselects Attack for a target other than itself. }
  procedure BuildAimTargets;
  var index: Byte;
      candidate: Types.PCharRecord;
  begin
    local.index := 1;
    Pathing.BuildTargetList(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), 255, 255,
                            CbtMap.GetIconSize(character));
    local.count := 0;
    for index := 1 to GDVars.pathTargetCount do begin
      candidate := GDVars.creatures[GDVars.pathTargets[index].slot];
      if CbtActs.CanTarget(character, candidate) then begin
        Inc(local.count);
        local.entries[local.count] := GDVars.pathTargets[index];
        if candidate = character^.combatAddr^.target then
          local.index := local.count
      end
    end;
    local.target := AdvanceAimTarget(0);
    if local.target <> character then begin
      GDVars.menuChecksum := C_Menu.KEEP_MENU_CHOICE;
      GDVars.horizChoice := 4
    end
  end;

begin
  Blit.CopyIconTile(32, 0, 0, False);
  FillChar(selection, SizeOf(Types.TAimTarget), 0);
  isDone := False;
  local.weaponRange := requestedRange;
  if local.weaponRange = 255 then
    local.weaponRange := ViewChar.ReadiedWeaponRange(character);
  if local.weaponRange = 0 then local.weaponRange := 1;
  local.initialX := CbtMap.CombatCellX(character);
  local.initialY := CbtMap.CombatCellY(character);
  CbtMap.RedrawArenaCell(local.initialX, local.initialY);
  BuildAimTargets;
  local.key := ' ';
  local.currentX := CbtMap.CombatCellX(local.target);
  local.currentY := CbtMap.CombatCellY(local.target);
  local.isAccepted := True;
  while not (local.key in [C_Keys.NONE, 'A', 'E']) do begin
    local.key := Chr(CbtActs.AimTargetMenu(character, local.target, local.weaponRange, mode, allowsGround, canAttack,
                                   local.isAccepted, local.currentX, local.currentY));
    if not GDVars.extFlag then
      case local.key of
        'N': begin
          local.isAccepted := True;
          local.target := AdvanceAimTarget(1)
        end;
        'P': begin
          local.isAccepted := True;
          local.target := AdvanceAimTarget(-1)
        end;
        'M': begin
          CbtActs.ManualAimCursor(character, local.target, local.weaponRange, mode, allowsGround, canAttack,
                                  local.isAccepted, local.isChosen, selection, local.currentX, local.currentY);
          if local.isAccepted and local.isChosen then begin
            local.target := selection.character;
            local.currentX := selection.x;
            local.currentY := selection.y;
            local.key := 'A';
            GDVars.horizChoice := 4;
            isDone := True;
            if mode = C_Combat.AIM_ATTACK then begin
              if CharHlp.HasAreaWeapon(character) then
                CbtActs.AttackGroundTarget(character, local.currentX, local.currentY, isDone)
              else
                CbtActs.ConfirmAttackTarget(character, local.target, mode, isDone, selection)
            end;
            if not isDone then begin
              GDVars.combatArena^.cursorShown := False;
              CbtMap.ScrollView(local.currentX, local.currentY, 0, C_Dir.CENTER)
            end
          end else begin
            GDVars.horizChoice := 3;
            local.currentX := CbtMap.CombatCellX(character);
            local.currentY := CbtMap.CombatCellY(character);
            local.target := character
          end
        end;
        'A': begin
          selection.x := local.currentX;
          selection.y := local.currentY;
          if local.target <> nil then
            selection.character := local.target
          else
            selection.character := nil;
          isDone := True;
          if mode = C_Combat.AIM_ATTACK then begin
            if CharHlp.HasAreaWeapon(character) then
              CbtActs.AttackGroundTarget(character, local.currentX, local.currentY, isDone)
            else
              CbtActs.ConfirmAttackTarget(character, local.target, mode, isDone, selection)
          end;
          if not isDone then begin
            GDVars.combatArena^.cursorShown := False;
            CbtMap.ScrollView(local.currentX, local.currentY, 0, C_Dir.CENTER)
          end
        end;
        'C': begin
          GDVars.combatArena^.cursorShown := True;
          GDVars.combatArena^.cursorSize := 1;
          CbtMap.ScrollView(local.currentX, local.currentY, 0, C_Dir.CENTER);
          GDVars.combatArena^.cursorShown := False
        end;
        'E': begin
          GDVars.combatArena^.cursorShown := False;
          CbtMap.ScrollView(local.currentX, local.currentY, 0, C_Dir.CENTER)
        end;
        C_Keys.NONE: begin
          GDVars.combatArena^.cursorShown := False;
          CbtMap.RedrawArenaCell(local.currentX, local.currentY);
          CbtMap.ScrollView(local.initialX, local.initialY, 0, C_Dir.CENTER)
        end
      end;
    if (local.key = 'N') or (local.key = 'P') or (local.key = 'A') then begin
      local.currentX := CbtMap.CombatCellX(local.target);
      local.currentY := CbtMap.CombatCellY(local.target)
    end
  end;
  Border.ClearBox(0, 23, 39, 23)
end;

function VictoryCheat: Boolean;
{ Unused in this version; see the other implementations of this routine. }
var isEnded: Boolean;
    character: Types.PCharRecord;
begin
  VictoryCheat := False;
  if ParamStr(1) <> GDVars.combatDebugPassword then Exit;
  VictoryCheat := True;
  CharHlp.PrintBottomLine('Life was empty til I met buck!');
  character := GDVars.partyHead;
  while character <> nil do begin
    if character^.side = C_Side.HOSTILE then begin
      character^.enabled := 0;
      character^.status := C_Status.DEAD_STATUS;
      GDVars.combatantCells[CbtMap.CombatSlot(character)].size := 0
    end;
    isEnded := CharHlp.EndActions(character);
    character := character^.nextCharAddr
  end;
  CbtMap.ScrollView(GDVars.combatArena^.viewOriginX + 3, GDVars.combatArena^.viewOriginY + 3, 255, C_Dir.CENTER)
end;

{ Tests for a backstab: a melee attack along the defender's facing when a roll of C_Skill.MOVE_SILENTLY or
  SKILL_DISTRACT succeeds (at scale 1 for a rogue, else 2).
  @param(attacker The combatant attacking.)
  @param(defender The combatant attacked.)
  @returns(True for a backstab.) }
function IsBackstab(attacker, defender: Types.PCharRecord): Boolean;
var scale: Byte;
begin
  if (ViewChar.ReadiedWeaponRange(attacker) < 2) and
      (CbtMap.DirectionToward(attacker, defender) = defender^.combatAddr^.direction) then begin
    if attacker^.career = C_Career.ROGUE then scale := 1 else scale := 2;
    IsBackstab := (CharHlp.SelectSkillCharacter(C_Skill.MOVE_SILENTLY, scale, False, Pointer(attacker)) >= 2) or
      (CharHlp.SelectSkillCharacter(CbtActs.SKILL_DISTRACT, scale, False, Pointer(attacker)) >= 2)
  end else
    IsBackstab := False
end;

{ Tests for a rear attack: a size-1 defender that has drawn more than one attack is attacked along its own facing or one
  direction either side, its facing less DirectionToward(attacker, defender) being -1, 0, 1 or 7. Note: the wrap is
  one-sided -- facing 7 against direction 0 counts, facing 0 against 7 does not.
  @param(attacker The combatant attacking.)
  @param(defender The combatant attacked.)
  @returns(True for a rear attack.) }
function IsRearAttack(attacker, defender: Types.PCharRecord): Boolean;
var direction: ShortInt;
begin
  direction := defender^.combatAddr^.direction - CbtMap.DirectionToward(attacker, defender);
  if (defender^.combatAddr^.directionCount > 1) and ((defender^.iconDimensions and C_Combat.ICON_SIZE_MASK) <= 1) and
      ((direction = -1) or (direction in [0, 1, 7])) then
    IsRearAttack := True
  else
    IsRearAttack := False
end;

procedure IntimidateTarget(character: Types.PCharRecord);
var
  count: Byte;
  index: Byte;
  saveResult: Byte;
begin
  count := CharHlp.CountTargets(character, 1);
  if count = 0 then Exit;
  if CharHlp.SelectSkillCharacter(C_Skill.INTIMIDATE, 2, False, Pointer(character)) >= 2 then
    CharHlp.PrintBottomLine(character^.name + ' looks real menacing.')
  else begin
    CharHlp.PrintBottomLine(character^.name + ' fails to intimidate.');
    Exit
  end;
  for index := 1 to count do begin
    GDVars.activeTarget := GDVars.creatures[GDVars.targetOrder[index]];
    if not CharHlp.IsHelpless(GDVars.activeTarget) then begin
      saveResult := Byte(FxEngine.RollSavingThrow(GDVars.activeTarget, 0, 0));
      FxEngine.AddEffectWithMessage(GDVars.activeTarget, C_Effect.SCARED, 10, 12, 0, C_Save.CANCELS,
                                    saveResult, 'is intimidated')
    end
  end
end;

procedure UseLeadership;
var
  leader: Types.PCharRecord;
  follower: Types.PCharRecord;
    isHeadingShown: Boolean;
    effect: Types.PEffectRec;
begin
  isHeadingShown := False;
  follower := GDVars.partyHead;
  while follower <> nil do begin
    if follower^.side = C_Side.TEAM then
      follower^.quickfight := follower^.skillLevels[0]
    else
      follower^.quickfight := 1;
    follower := follower^.nextCharAddr
  end;
  leader := GDVars.partyHead;
  while leader <> nil do begin
    if (leader^.side = C_Side.TEAM) and (leader^.skillLevels[0] = 0) and
        (leader^.skillLevels[C_Skill.LEADERSHIP] > 0) and
        (leader^.status = C_Status.OKAY) then begin
      follower := GDVars.partyHead;
      while follower <> nil do begin
        if (follower^.side = C_Side.TEAM) and (follower^.skillLevels[0] <> 0) and (follower^.quickfight <> 0) and
            (follower^.status = C_Status.OKAY) and (follower^.intelligence > 3) and
            (not CharHlp.HasEffect(follower, C_Effect.UNKILLABLE, effect)) and
            (CharHlp.SelectSkillCharacter(C_Skill.LEADERSHIP, 2, False, Pointer(leader)) >= 2) then begin
          if not isHeadingShown then begin
            isHeadingShown := True;
            Border.DrawWindowFrame(0);
            TextRend.SetTextWindow(1, 1, 38, 22, Black);
            TextRend.DisplayWindowText(White, '  Using Leadership Skill');
            TextRend.DisplayWindowText(Black, '')
          end;
          TextRend.DisplayWindowText(LightGreen, leader^.name + ' leads ' + follower^.name + '.');
          TextRend.DisplayWindowText(Black, '');
          follower^.quickfight := 0
        end;
        follower := follower^.nextCharAddr
      end
    end;
    leader := leader^.nextCharAddr
  end;
  if isHeadingShown then
    TextRend.PauseContinue
end;

procedure RollTactics;
var character: Types.PCharRecord;
    message: Types.TString40;
    effect: Types.PEffectRec;
begin
  Border.ClearBox(0, 23, 39, 23);
  GDVars.tacticsSides[C_Side.TEAM] := 0;
  GDVars.tacticsSides[C_Side.HOSTILE] := 0;
  character := GDVars.partyHead;
  while character <> nil do begin
    if (character^.enabled <> 0) and
        (character^.status in [C_Status.OKAY, C_Status.DODGING, C_Status.USED_JETPACK]) and
        (not CharHlp.HasEffect(character, C_Effect.STUNNED, effect)) and
        (GDVars.tacticsSides[character^.side] = 0) and
        (CharHlp.SelectSkillCharacter(C_Skill.BATTLE_TACTICS, 2, False, Pointer(character)) >= 2) then begin
      message := character^.name + ' makes ';
      if character^.gender = 0 then
        message := message + 'his'
      else
        message := message + 'her';
      message := message + ' tactics roll.';
      GDVars.tacticsSides[character^.side] := 1;
      GDVars.creatureInfoDirty := 1;
      CharHlp.CombatPrintCreatureInfo(character);
      CharHlp.PrintCreatureMessage(character, message, 10, False);
      TextRend.PauseOnly
    end else
      character := character^.nextCharAddr
  end
end;

procedure RollZeroG(character: Types.PCharRecord);
{ Unused in this version; see the other implementations of this routine. }
var roll: Byte;
    message: String[10];
    hasSucceeded: Boolean;
begin
  if (GDVars.zone0^.areaType and C_Area.ZERO_GRAVITY <> 0) and (character^.enabled <> 0) and
      (character^.combatAddr^.initiative > 1) then begin
    hasSucceeded := CharHlp.SelectSkillCharacter(C_Skill.MANEUVER_IN_0G, 2, False, Pointer(character)) >= 2;
    if hasSucceeded then message := 'made ' else message := 'failed ';
    if character^.gender = 0 then
      message := message + 'his'
    else if character^.gender = 1 then
      message := message + 'her'
    else
      { a gender neither genderNames entry names. Note: 'its' replaces the whole message, dropping 'made' or 'failed' }
      message := 'its';
    CharHlp.PrintCreatureMessage(character, message, 10, False);
    TextRend.DisplayMessageWindow(23, 12, 38, 21, LightGreen, Black, False, 'Zero-G skill roll');
    TextRend.PauseOnly;
    if not hasSucceeded then begin
      character^.status := C_Status.FAILED_ZERO_G;
      character^.combatAddr^.movement := character^.combatAddr^.movement shr 2;
      CharHlp.RecalcStats(character)
    end
  end
end;

begin
end.
