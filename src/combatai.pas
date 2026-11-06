{ The computer's turn in ground combat, for monsters and for party members on quick fight: picking an approach and a
  target, readying the best weapon, choosing where to aim an area weapon, stepping toward the target or away in flight,
  attacking, and the morale check. Combat calls CombatAiControl; the other interface routines are called only from
  within this unit. The step history AiMoveStep reads (previousDirection, stuckCount) is GDVars', and the tables
  AiMoveStep steps and SelectAreaTarget aims by (approachPatterns, areaHalfWidths) GDConsts'. }
{$A-,O+,F+,V-,I-,R-,S-}
unit CombatAi;

interface

uses Types, C_Status, C_Terr, GDConsts, GDVars, CharHlp, CbtActs, TextRend, GameIo, CbtMap,
  FxEngine, ViewChar, Pathing, C_Effect, C_Dir, C_WClass, C_Armor, C_Area, C_Item, C_Career, C_Side, C_Cond, C_Keys,
  C_Equip, C_Npc, C_Screen;

{ Plays cr's turn: rerolls its approach when it is unset or 5 or 6, and one time in four when it is 1..4 (a reroll gives
  1..4 seven times in eight, else 5 or 6), checks its morale, then prepares and acts until the turn is done. A key press
  can hand it back to the player.
  @param(cr The combatant whose turn it is.) }
procedure CombatAiControl(cr: Types.PCharRecord);

{ Moves cr toward its target and attacks it, or a target in reach, until the turn ends.
  @param(cr The combatant acting.)
  @returns(True when cr has finished acting.) }
function AiMoveAttack(cr: Types.PCharRecord): Boolean;

{ Ends cr's turn, on guard when it can still act.
  @param(cr The combatant.)
  @returns(True when the turn is over.) }
function FinishRound(cr: Types.PCharRecord): Boolean;

{ Reads a pending key: Space returns the party's quick-fighters to the player, Alt-X checks the debug phrase. Note: a
  plain '-' checks it too, since it is the same byte as Alt-X's scan code and the case does not ask whether the key was
  extended.
  @param(cr The combatant whose turn it is.)
  @returns(True when cr itself came back to the player.) }
function CheckKeystroke(cr: Types.PCharRecord): Boolean;

{ For cr with a non-zero skillLevels[0] (the companion flag), tests its morale against its own wounds, then against the
  hostiles' remaining hit points and zone 1's morale base, which side 0 always fails. One that fails both flees when no
  enemy's movement exceeds half its own; otherwise, if its intelligence is over 5, it surrenders (side 0 as fleeing,
  side 1 as unconscious) and the message pauses.
  @param(cr The companion tested.)
  @returns(True when cr surrendered and its turn is over.) }
function CheckMorale(cr: Types.PCharRecord): Boolean;

{ Readies the combatant's best weapon against its target, by damage, bonuses and what the line to the target crosses;
  the armor with the highest class byte and plus; and, with a grenade weapon readied, a grenade launcher when none is
  readied. Note: with no weapon better than unarmed, the launcher test reads through a nil weapon pointer.
  @param(cr The combatant.)
  @param(mode 0 leaves area weapons out; otherwise they are scored by where they would land.)
  @param(result True when the weapon readied is heavy, which ends the turn.) }
procedure EquipWeaponAndArmor(cr: Types.PCharRecord; mode: Byte; var result: Boolean);

{ Keeps cr's target when it is still a valid enemy, or picks one at random from those in any range (a second pass with
  the arena's distMode 1), and readies a weapon for it when mode is non-zero.
  @param(cr The combatant.)
  @param(mode Non-zero readies a weapon for the target.)
  @param(done Set when readying that weapon ends the turn.)
  @returns(True when cr has a target.) }
function PrepareAiAction(cr: Types.PCharRecord; mode: Byte; var done: Boolean): Boolean;

implementation

const
  { Item types (ITEMS rows) of the grenades the computer weighs. SONIC_STUNNER_TYPE, PLASMA_THROWER_TYPE,
    ROCKET_LAUNCHER_TYPE, STUN_GRENADE_TYPE, DAZZLE_GRENADE_TYPE and READIED are C_Item's, and FIRST_AREA_WEAPON and the
    weapon classes are C_WClass's. }
  EXPLOSIVE_GRENADE_TYPE = 33;
  GAS_GRENADE_TYPE = 34;
  CHAFF_GRENADE_TYPE = 37;
  AEROSOL_MIST_GRENADE_TYPE = 38;
  { the farthest SelectAreaTarget scores cells from its origin }
  AREA_REACH = 9;
  { the initiative that marks a combatant handed over between player and computer: set here on Space and by Combat on
    Alt-Q and Alt-A; AiMoveAttack stops acting at it, Combat turns it into 19 }
  HAND_BACK_INITIATIVE = 20;

type
  PShortInt = ^ShortInt;
  TAreaGrid = array[-CombatAi.AREA_REACH..CombatAi.AREA_REACH, -CombatAi.AREA_REACH..CombatAi.AREA_REACH] of ShortInt;
  PAreaGrid = ^TAreaGrid;

procedure CombatAiControl(cr: Types.PCharRecord);
var
  pattern: Byte;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  prepared: Boolean;
begin
  done := CombatAi.CheckKeystroke(cr);
  TextRend.ClearStatusLine;
  CharHlp.ClearMessageWindow;
  if (cr^.enabled = 0) or (cr^.status = C_Status.DODGING) or (cr^.status = C_Status.SPRINTING) then
    done := CharHlp.EndActions(cr);
  pattern := cr^.combatAddr^.approach;
  if (pattern = 0) or (pattern > 4) or (CharHlp.RollDice(1, 4) = 1) then begin
    pattern := CharHlp.RollDice(1, 8);
    if pattern = 8 then
      pattern := CharHlp.RollDice(1, 2) + 4
    else
      pattern := CharHlp.RollDice(1, 4)
  end;
  cr^.combatAddr^.approach := pattern;
  if not done then done := CombatAi.CheckMorale(cr);
  if cr^.combatAddr^.fleeing <> 0 then
    CharHlp.PrintCreatureMessage(cr, 'flees in panic', 10, True);
  if not done then begin
    done := CombatAi.CheckKeystroke(cr);
    while not done do begin
      prepared := CombatAi.PrepareAiAction(cr, 1, done);
      if not done then
        if (cr^.combatAddr^.initiative > 0) and (cr^.enabled <> 0) then
          done := CombatAi.AiMoveAttack(cr)
        else
          done := CombatAi.FinishRound(cr)
    end
  end
end;

{ Scores every cell an area weapon cr has readied could hit, each combatant in the blast counting by side, and aims at
  the best cell a line reaches: fires there when mode is non-zero, or with no cell worth it readies a weapon with
  EquipWeaponAndArmor's mode 0; with mode 0 reports the score.
  @param(cr The combatant with the area weapon.)
  @param(mode Non-zero fires; 0 only scores.)
  @param(choice With mode 0, the best cell's score scaled to a byte.)
  @returns(With mode non-zero, True when cr's turn is over.) }
function SelectAreaTarget(cr: Types.PCharRecord; mode: Byte; var choice: Byte): Boolean;
var
  scores: PAreaGrid;
  areaClass: Byte;
  outerRange: Byte;
  innerRange: Byte;
  item: Types.PItemRec;
  origin: Types.PCharRecord;
  originX: ShortInt;
  originY: ShortInt;
  pX: ShortInt;
  pY: ShortInt;
  bestX: ShortInt;
  bestY: ShortInt;
  crX: ShortInt;
  crY: ShortInt;
  j: ShortInt;
  i: ShortInt;
  cellMin: ShortInt;
  cellMax: ShortInt;
  lowOffset: ShortInt;
  highOffset: ShortInt;
  teamWeight: ShortInt;
  bestWeight: ShortInt;
  outerMaxY: ShortInt;
  outerMaxX: ShortInt;
  outerMinY: ShortInt;
  outerMinX: ShortInt;
  innerMaxY: ShortInt;
  innerMaxX: ShortInt;
  innerMinY: ShortInt;
  innerMinX: ShortInt;
  done: Boolean;
  distance: Word;
  occupant: Byte;
  terrain: Byte;
  weights: array[0..1] of ShortInt;
  { HasEffect's find; not used }
  effect: Types.PEffectRec;
  value: Word;
begin
  SelectAreaTarget := False;
  choice := 0;
  if cr = nil then Exit;
  item := Types.PItemRec(cr^.equipped[C_Equip.WEAPON]);
  if item = nil then Exit;
  case GDVars.itemTypes[item^.template.itemType].weaponClass of
    C_WClass.ROCKET_LAUNCHER: areaClass := 2;
    C_WClass.GRENADE: areaClass := 1;
    C_WClass.PLASMA: areaClass := 3
  else
    Exit
  end;
  origin := nil;
  outerRange := ViewChar.ReadiedWeaponRange(cr) + areaClass;
  if outerRange > CombatAi.AREA_REACH then begin
    outerRange := CombatAi.AREA_REACH;
    if not (item^.template.itemType in [CombatAi.CHAFF_GRENADE_TYPE, CombatAi.AEROSOL_MIST_GRENADE_TYPE]) then
      origin := cr^.combatAddr^.target
  end;
  innerRange := outerRange - areaClass;
  { a chaff or mist cloud counts cr's side 4 and the other 1; any other blast counts cr's enemies 1 and its own side -12
    for side 0, -2 for side 1 }
  if item^.template.itemType in [CombatAi.CHAFF_GRENADE_TYPE, CombatAi.AEROSOL_MIST_GRENADE_TYPE] then begin
    if cr^.side = C_Side.TEAM then begin
      weights[0] := 4;
      weights[1] := 1
    end else begin
      weights[0] := 1;
      weights[1] := 4
    end
  end else begin
    if cr^.side = C_Side.TEAM then begin
      weights[0] := -12;
      weights[1] := 1
    end else begin
      weights[0] := 1;
      weights[1] := -2
    end
  end;
  if origin = nil then origin := cr;
  originX := CbtMap.CombatCellX(origin);
  originY := CbtMap.CombatCellY(origin);
  outerMinX := originX - outerRange;
  outerMaxX := originX + outerRange;
  outerMinY := originY - outerRange;
  outerMaxY := originY + outerRange;
  innerMinX := originX - innerRange;
  innerMaxX := originX + innerRange;
  innerMinY := originY - innerRange;
  innerMaxY := originY + innerRange;
  GetMem(scores, SizeOf(TAreaGrid));
  FillChar(scores^, SizeOf(TAreaGrid), 0);
  { origin now walks the combatants }
  origin := GDVars.partyHead;
  while origin <> nil do begin
    pX := CbtMap.CombatCellX(origin);
    pY := CbtMap.CombatCellY(origin);
    if (origin^.enabled <> 0) and (pX >= outerMinX) and (pX <= outerMaxX) and (pY >= outerMinY) and
        (pY <= outerMaxY) then begin
      teamWeight := weights[origin^.side];
      case item^.template.itemType of
        CombatAi.CHAFF_GRENADE_TYPE, CombatAi.AEROSOL_MIST_GRENADE_TYPE: begin
          CbtMap.GetArenaContents(pX, pY, occupant, terrain);
          if (terrain = C_Terr.CHAFF_TERRAIN) or (terrain = C_Terr.AEROSOL_MIST_TERRAIN) then
            teamWeight := -1
        end;
        C_Item.STUN_GRENADE_TYPE: begin
          if CharHlp.HasEffect(origin, C_Effect.STUNNED, effect) or CharHlp.IsHelpless(origin) then
            teamWeight := 0
        end;
        CombatAi.GAS_GRENADE_TYPE:
          if CharHlp.IsHelpless(origin) then teamWeight := 0
      end;
      lowOffset := -areaClass;
      highOffset := areaClass;
      if lowOffset + pY < innerMinY then
        lowOffset := innerMinY - pY;
      if highOffset + pY > innerMaxY then
        highOffset := innerMaxY - pY;
      for i := lowOffset to highOffset do begin
        cellMin := pX - GDConsts.areaHalfWidths[i, areaClass];
        cellMax := pX + GDConsts.areaHalfWidths[i, areaClass];
        if cellMin < innerMinX then cellMin := innerMinX;
        if cellMax > innerMaxX then cellMax := innerMaxX;
        for j := cellMin to cellMax do
          Inc(scores^[j - originX, i + pY - originY], teamWeight)
      end
    end;
    origin := origin^.nextCharAddr
  end;
  crX := CbtMap.CombatCellX(cr);
  crY := CbtMap.CombatCellY(cr);
  bestWeight := 0;
  for j := -innerRange to innerRange do
    for i := -innerRange to innerRange do begin
      teamWeight := scores^[j, i];
      if (teamWeight > bestWeight) or
          ((teamWeight = bestWeight) and (teamWeight > 0) and CharHlp.PercentileRoll(25)) then begin
        pX := crX;
        pY := crY;
        distance := ViewChar.ReadiedWeaponRange(cr);
        GDVars.stopsAtChaff := True;
        { Note: off by one. The row test excludes its upper bound where the column test includes it, so the arena's last
          row, which WalkLine and CbtMap.GetArenaContents accept, is never aimed at. }
        if (originX + j >= 0) and (originX + j <= SizeOf(GDVars.combatArena^.cells[0]) - 1) and (originY + i >= 0) and
            (originY + i < SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1) and
            Pathing.WalkLine(originX + j, originY + i, pX, pY, distance) and not GDVars.sawChaff then begin
          bestX := j;
          bestY := i;
          bestWeight := teamWeight
        end
      end
    end;
  FreeMem(scores, SizeOf(TAreaGrid));
  if mode <> 0 then begin
    if bestWeight > 0 then begin
      CbtActs.AttackGroundTarget(cr, originX + bestX, originY + bestY, done);
      SelectAreaTarget := CharHlp.EndActions(cr)
    end else begin
      CombatAi.EquipWeaponAndArmor(cr, 0, done);
      SelectAreaTarget := done
    end
  end else if bestWeight > 0 then begin
    case item^.template.itemType of
      CombatAi.CHAFF_GRENADE_TYPE: value := CharHlp.RollDice(1, 6) + 1;
      CombatAi.AEROSOL_MIST_GRENADE_TYPE: value := CharHlp.RollDice(1, 6);
      CombatAi.EXPLOSIVE_GRENADE_TYPE: value := 40;
      CombatAi.GAS_GRENADE_TYPE: value := 5;
      C_Item.DAZZLE_GRENADE_TYPE: value := CharHlp.RollDice(1, 10) + 10;
      C_Item.STUN_GRENADE_TYPE: value := CharHlp.RollDice(1, 10) + 5;
      C_Item.PLASMA_THROWER_TYPE: value := 25;
      C_Item.ROCKET_LAUNCHER_TYPE: value := 30
    end;
    value := value * bestWeight;
    if value > 128 then
      choice := (value shr 4) + 120
    else
      choice := value
  end
end;

{ Scores an area weapon for cr: SelectAreaTarget's mode-0 score with it readied in place of cr's weapon.
  @param(cr The combatant.)
  @param(item The weapon scored.)
  @returns(The score.) }
function EvaluateItem(cr: Types.PCharRecord; item: Pointer): Byte;
var
  choice: Byte;
  savedWeapon: Pointer;
begin
  savedWeapon := cr^.equipped[C_Equip.WEAPON];
  cr^.equipped[C_Equip.WEAPON] := item;
  if CombatAi.SelectAreaTarget(cr, 0, choice) then ;
  EvaluateItem := choice;
  cr^.equipped[C_Equip.WEAPON] := savedWeapon
end;

{ Tests the step cr's approach tries: onto an empty cell whose cost is less than its movement left.
  @param(cr The combatant stepping.)
  @param(attempt The approach's try, which picks the turn from baseDirection.)
  @param(baseDirection The direction toward the target, or away from the fight.)
  @param(edge True when that cell is off the arena.)
  @returns(True when the step can be taken.) }
function AiCanStep(cr: Types.PCharRecord; attempt, baseDirection: Byte; var edge: Boolean): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
  pattern: Byte;
  direction: Byte;
  creatureIndex: Byte;
  terrainIndex: Byte;
  cost: Byte;
  { ProbeDirection's; not used here }
  hasGas: Byte;
  { Unused in this version; see the other implementations of this routine. }
  terrainHazard: Byte;
  ok: Boolean;
begin
  edge := False;
  ok := False;
  pattern := GDConsts.approachPatterns[cr^.combatAddr^.approach, attempt];
  direction := (baseDirection + pattern) mod 8;
  CbtMap.ProbeDirection(cr, direction, creatureIndex, terrainIndex, hasGas);
  if terrainIndex = 0 then
    edge := True
  else begin
    if GDConsts.terrainInfo[terrainIndex].cost = C_Terr.IMPASSABLE then begin
      AiCanStep := False;
      Exit
    end;
    if Odd(direction) then
      cost := GDConsts.terrainInfo[terrainIndex].cost * 3
    else
      cost := GDConsts.terrainInfo[terrainIndex].cost shl 1;
    if (creatureIndex = 0) and (cost < cr^.combatAddr^.movement) then
      if cr^.combatAddr^.movement >= cost then ok := True
  end;
  AiCanStep := ok
end;

{ Steps cr once toward its target, or away from the fight when fleeing, trying its approach's turns in order; a fleeing
  cr at the arena's edge tries to flee the fight. Finding no way, or reversing its last step, turns its approach; the
  second time since AiMoveAttack began it drops its target and seeks another, the third ends its move. It finishes the
  round instead with no move or initiative left, as a medic neither fleeing nor armored, or as a non-player when
  hostileHpPercent exceeds morale plus d100 (unless on side 1).
  @param(cr The combatant stepping.) }
procedure AiMoveStep(cr: Types.PCharRecord);
var
  direction: Byte;
  newDirection: Byte;
  attempt: Byte;
  edge: Boolean;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  combatant: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  steps: Byte;
begin
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, 10, 0,
                         'Move/Attack, Move Left = ' + TextRend.ByteToString(cr^.combatAddr^.movement div 2) + ' ');
  if CombatAi.CheckKeystroke(cr) then Exit;
  if (cr^.combatAddr^.movement div 2 > 0) and (cr^.combatAddr^.initiative > 0) and
      ((cr^.npc < C_Npc.NON_PLAYER_FLAG) or
       ((cr^.npc > C_Npc.NON_PLAYER_FLAG - 1) and
        (GDVars.hostileHpPercent <= GDVars.morale + CharHlp.RollDice(1, 100))) or
      (cr^.side = C_Side.HOSTILE)) and
      ((cr^.combatAddr^.fleeing <> 0) or (cr^.equipped[C_Equip.ARMOR] <> nil) or
       (cr^.career <> C_Career.MEDIC)) then begin
    if cr^.combatAddr^.fleeing = 0 then
      direction := CbtMap.DirectionToward(cr, cr^.combatAddr^.target)
    else begin
      cr^.combatAddr^.approach := CharHlp.RollDice(1, 2);
      direction := GDVars.partyPosition.facing - (GDVars.partyPosition.facing + 2) mod 4 div 2;
      if cr^.side = C_Side.TEAM then direction := direction + 4;
      direction := direction mod 8
    end;
    edge := False;
    done := False;
    attempt := 1;
    while (attempt < 6) and (not done) and (not CombatAi.AiCanStep(cr, attempt, direction, edge)) do
      if (cr^.combatAddr^.fleeing <> 0) and edge then
        done := CbtActs.AttemptFlee(cr)
      else
        Inc(attempt);
    if done then begin
      cr^.combatAddr^.movement := 0;
      cr^.combatAddr^.fleeing := 0;
      done := CharHlp.EndActions(cr)
    end else begin
      newDirection := (direction + GDConsts.approachPatterns[cr^.combatAddr^.approach, attempt]) mod 8;
      if (attempt = 6) or (GDVars.previousDirection = (newDirection + 4) mod 8) then begin
        Inc(GDVars.stuckCount);
        cr^.combatAddr^.approach := cr^.combatAddr^.approach mod 6 + 1;
        if GDVars.stuckCount > 1 then begin
          cr^.combatAddr^.target := nil;
          if GDVars.stuckCount > 2 then begin
            cr^.combatAddr^.movement := 0;
            done := True
          end else if (not CombatAi.PrepareAiAction(cr, 1, done)) and (not done) then
            done := CombatAi.FinishRound(cr)
        end
      end;
      if attempt < 6 then
        GDVars.previousDirection := newDirection
      else
        done := True
    end;
    if not done then begin
      GDVars.mapVisible := Ord((GDVars.targetInReach <> 0) or CbtMap.CombatIconVisible(cr, 0) or
                                 (cr^.side = C_Side.TEAM));
      CbtMap.SetCreatureFacing(cr, newDirection, 0, 0);
      if cr^.enabled = 0 then
        done := CharHlp.EndActions(cr)
      else begin
        if cr^.combatAddr^.movement > 0 then
          CbtActs.CombatMoveCreature(cr, cr^.combatAddr^.direction);
        if (cr^.enabled = 0) or CharHlp.IsHelpless(cr) then
          done := CharHlp.EndActions(cr);
        FxEngine.ConsiderTerrainEffects(cr, 1)
      end
    end
  end else
    done := CombatAi.FinishRound(cr)
end;

function AiMoveAttack(cr: Types.PCharRecord): Boolean;
var
  stop: Boolean;
  acting: Boolean;
  reach: Byte;
  distance: Word;
  targetCount: Byte;
  pick: Byte;
  target: Types.PCharRecord;
  targetX: ShortInt;
  targetY: ShortInt;
  rounds: Byte;
  areaChoice: Byte;
begin
  GDVars.previousDirection := C_Dir.CENTER;
  GDVars.stuckCount := 0;
  GDVars.aiMoveState := 0;
  rounds := 0;
  acting := True;
  stop := False;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MONSTER_SPECIAL, cr);
  if (cr^.side = C_Side.TEAM) and (GDVars.soloCombat = 0) and ViewChar.FindPatients(cr) then begin
    ViewChar.TreatPatients(cr);
    cr^.combatAddr^.initiative := 0
  end;
  if cr^.combatAddr^.initiative = 0 then acting := False;
  while (not stop) and acting do begin
    if cr^.combatAddr^.fleeing <> 0 then
      while (cr^.combatAddr^.movement > 0) and (cr^.combatAddr^.initiative > 0) and
          (cr^.combatAddr^.initiative < CombatAi.HAND_BACK_INITIATIVE) do
        CombatAi.AiMoveStep(cr);
    if (cr^.combatAddr^.initiative = 0) or (cr^.combatAddr^.initiative = CombatAi.HAND_BACK_INITIATIVE) then
      acting := False
    else
      stop := False;
    if (not stop) and acting then begin
      Inc(rounds);
      if rounds > 20 then begin
        stop := True;
        acting := not CombatAi.FinishRound(cr)
      end;
      GDVars.targetInReach := 0;
      target := cr^.combatAddr^.target;
      if target^.enabled = 0 then target := nil;
      reach := ViewChar.ReadiedWeaponRange(cr);
      if target <> nil then
        if CbtActs.CanTarget(cr, target) then begin
          targetX := CbtMap.CombatCellX(target);
          targetY := CbtMap.CombatCellY(target);
          distance := reach;
          GDVars.combatArena^.distMode := 0;
          if Pathing.WalkLine(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), targetX, targetY, distance) then
            if distance div 2 <= reach then
              if (cr^.combatAddr^.movement < 4) or (reach > distance) or CharHlp.HasAreaWeapon(cr) then
                GDVars.targetInReach := 1
        end;
      if GDVars.targetInReach = 0 then begin
        if cr^.combatAddr^.movement > 4 then reach := 1;
        targetCount := CharHlp.CountTargets(cr, reach);
        if targetCount = 0 then begin
          if CombatAi.PrepareAiAction(cr, 0, stop) and (not stop) then
            CombatAi.AiMoveStep(cr)
          else
            stop := CombatAi.FinishRound(cr)
        end else begin
          pick := CharHlp.RollDice(1, targetCount);
          target := GDVars.creatures[GDVars.targetOrder[pick]];
          if (CharHlp.CalcDistance(cr, target) <= reach) or CbtActs.CanTarget(cr, target) then
            GDVars.targetInReach := 1
        end
      end;
      if GDVars.targetInReach <> 0 then begin
        if CharHlp.HasAreaWeapon(cr) then
          stop := CombatAi.SelectAreaTarget(cr, 1, areaChoice)
        else begin
          CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 2, CbtMap.DirectionToward(cr, target));
          CbtActs.NoteAttackDirection(cr, target);
          CbtActs.MakeAttack(cr, target, False, stop)
        end;
        if stop then
          acting := False
        else if target^.enabled = 0 then
          stop := True
      end
    end
  end;
  AiMoveAttack := not acting
end;

function FinishRound(cr: Types.PCharRecord): Boolean;
begin
  CharHlp.ClearMessageWindow;
  if CharHlp.IsHelpless(cr) or (cr^.combatAddr^.initiative = 0) then
    FinishRound := CharHlp.EndActions(cr)
  else
    FinishRound := CbtActs.Guard(cr)
end;

function CheckKeystroke(cr: Types.PCharRecord): Boolean;
var
  p: Types.PCharRecord;
  key: Char;
begin
  CheckKeystroke := False;
  if GameIo.InputPending then begin
    key := GameIo.ReadGameKey;
    if key = #0 then key := GameIo.ReadGameKey;
    case key of
      ' ': begin
        p := GDVars.partyHead;
        while p <> nil do begin
          with p^ do
            if (side = C_Side.TEAM) and (skillLevels[0] = 0) and (combatAddr^.notPcNpc = 0) then
              quickfight := 0;
          p := p^.nextCharAddr
        end;
        if cr^.quickfight = 0 then begin
          cr^.combatAddr^.initiative := CombatAi.HAND_BACK_INITIATIVE;
          CheckKeystroke := True
        end
      end;
      C_Keys.ALT_X: if CbtActs.VictoryCheat then ;
    end
  end;
  GameIo.FlushKeys
end;

function CheckMorale(cr: Types.PCharRecord): Boolean;
var
  enemyMovement: Byte;
  { Unused in this version; see the other implementations of this routine. }
  previousMorale: Byte;
  outStatus: Byte;
begin
  CheckMorale := False;
  cr^.combatAddr^.fleeing := 0;
  if cr^.skillLevels[0] <> 0 then begin
    GDVars.morale := (cr^.npc and not C_Npc.NON_PLAYER_FLAG) shl 1;
    if GDVars.morale > 102 then GDVars.morale := 0;
    FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, cr);
    if (GDVars.morale < 100 - cr^.hitPoints * 100 div cr^.hpMax) or (GDVars.morale = 0) then begin
      previousMorale := GDVars.morale;
      GDVars.morale := GDVars.hostileHpPercent;
      FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, cr);
      if (GDVars.morale < 100 - GDVars.zone1^.moraleBase) or (GDVars.morale = 0) or
          (cr^.side = C_Side.TEAM) then begin
        enemyMovement := CbtActs.HighestEnemyMovement(cr);
        if enemyMovement <= CharHlp.RecalcMovement(cr) div 2 then
          cr^.combatAddr^.fleeing := 1
        else if cr^.intelligence > 5 then begin
          if cr^.side = C_Side.TEAM then outStatus := C_Status.FLEEING
                          else outStatus := C_Status.UNCONSCIOUS;
          FxEngine.PutOutOfPlayWithStatus(cr, outStatus, 'Surrenders');
          TextRend.PauseOnly;
          CheckMorale := CharHlp.EndActions(cr)
        end
      end
    end
  end
end;

procedure EquipWeaponAndArmor(cr: Types.PCharRecord; mode: Byte; var result: Boolean);
var
  targetCharacter: Pointer;
  bestWeapon: Types.PItemRec;
  oldWeapon: Types.PItemRec;
  item: Types.PItemRec;
  slotSixItem: Types.PItemRec;
  bestArmor: Types.PItemRec;
  oldArmor: Types.PItemRec;
  slotSixReadied: Byte;
  baseItem: Types.PItemType;
  bestPriority: Byte;
  priority: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lineReached: Byte;
  { HasEffect's find; not used }
  effect: Types.PEffectRec;
  targetX: Byte;
  targetY: Byte;
  distance: Word;
  laserShift: Byte;
  microwaveShift: Byte;
  rocketShift: Byte;

  { item's score as a weapon from its damage, bonuses and specialization; 0 when it is out of shots or unusable here. }
  function CalcWeaponPriority: Byte;
  var
    priority: Byte;
    multiplier: Byte;
  begin
    if (baseItem^.weaponClass > C_WClass.MELEE) and (item^.template.quantity = 0) then begin
      CalcWeaponPriority := 0;
      Exit
    end;
    priority := baseItem^.diceSides * baseItem^.diceCount + baseItem^.damageBonus * 2;
    if item^.template.itemType = C_Item.SONIC_STUNNER_TYPE then begin
        if (targetCharacter <> nil) and CharHlp.HasEffect(targetCharacter, C_Effect.STUNNED, effect) then
          priority := 0
        else
          priority := 12
    end else if item^.template.itemType in [C_Item.PLASMA_THROWER_TYPE, C_Item.ROCKET_LAUNCHER_TYPE,
                              CombatAi.GAS_GRENADE_TYPE..CombatAi.AEROSOL_MIST_GRENADE_TYPE] then begin
        if (mode <> 0) and
            ((cr^.side = C_Side.HOSTILE) or
             not (item^.template.itemType in [CombatAi.CHAFF_GRENADE_TYPE, CombatAi.AEROSOL_MIST_GRENADE_TYPE])) and
            (((GDVars.zone0^.areaType and C_Area.ZERO_GRAVITY) = 0) or
             not (item^.template.itemType in [CombatAi.CHAFF_GRENADE_TYPE, CombatAi.AEROSOL_MIST_GRENADE_TYPE])) then
          priority := CombatAi.EvaluateItem(cr, item)
        else
          priority := 0
    end
    ;
    Inc(priority, CharHlp.SpecializationLevel(cr, item) * 3 + item^.template.plus * 3);
    if baseItem^.weaponClass = C_WClass.MELEE then
      Inc(priority, CharHlp.StrDamageAdjust(cr) * 2 + CharHlp.StrToHitAdjust(cr) * 2)
    else
      Inc(priority, CharHlp.DexMissileAdjust(cr) * 2);
    multiplier := baseItem^.attacksDoubled shr 1;
    if multiplier = 0 then multiplier := 1;
    if (mode = 0) and (baseItem^.weaponClass >= C_WClass.FIRST_AREA_WEAPON) then
      CalcWeaponPriority := 0
    else
      CalcWeaponPriority := priority * multiplier
  end;

begin
  targetCharacter := cr^.combatAddr^.target;
  bestArmor := nil;
  bestWeapon := nil;
  slotSixItem := nil;
  slotSixReadied := 0;
  bestPriority := cr^.unarmedDice[1] * cr^.unarmedRolls[1] + cr^.unarmedModifiers[1] * 2;
  laserShift := 0;
  microwaveShift := 0;
  rocketShift := 0;
  if targetCharacter <> nil then begin
    targetX := CbtMap.CombatCellX(targetCharacter);
    targetY := CbtMap.CombatCellY(targetCharacter);
    distance := 255;
    lineReached := Byte(Pathing.WalkLine(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), PShortInt(@targetX)^,
                                         PShortInt(@targetY)^, distance));
    if GDVars.sawAerosolMist or CharHlp.HasEffect(targetCharacter, C_Effect.IMMUNE_TO_LASER, effect) then
      laserShift := 3;
    if GDVars.sawChaff then
      rocketShift := 3
    else begin
      if (Types.PCharRecord(targetCharacter)^.armorFlags and C_Armor.ECM <> 0) or
          CharHlp.HasEffect(targetCharacter, C_Effect.IMMUNE_TO_ROCKET, effect) then
        rocketShift := 2
    end;
    if (Types.PCharRecord(targetCharacter)^.armorFlags and C_Armor.BODY <> 0) or
        CharHlp.HasEffect(targetCharacter, C_Effect.IMMUNE_TO_MICROWAVE, effect) then
      microwaveShift := 3
  end;
  item := cr^.itemsAddr;
  while item <> nil do begin
    baseItem := @GDVars.itemTypes[item^.template.itemType];
    case baseItem^.slot of
      C_Equip.WEAPON: begin
        priority := CalcWeaponPriority;
        case baseItem^.weaponClass of
          C_WClass.ROCKET: priority := priority shr rocketShift;
          C_WClass.LASER: priority := priority shr laserShift;
          C_WClass.MICROWAVE: priority := priority shr microwaveShift
        end;
        if priority > bestPriority then begin
          bestPriority := priority;
          bestWeapon := item
        end
      end;
      C_Equip.ARMOR: begin
        if (bestArmor = nil) or
            (GDVars.itemTypes[bestArmor^.template.itemType].weaponClass + bestArmor^.template.plus <
             baseItem^.weaponClass + item^.template.plus) then
          bestArmor := item
      end;
      C_Equip.GRENADE_LAUNCHER: begin
        if item^.template.flags and C_Item.READIED <> 0 then
          slotSixReadied := 1
        else
          slotSixItem := item
      end
    end;
    item := item^.next
  end;
  oldArmor := ViewChar.FindReadiedItem(cr, C_Equip.ARMOR);
  if bestArmor <> oldArmor then begin
    if oldArmor <> nil then
      ViewChar.ToggleReadyItem(oldArmor, result);
    if bestArmor <> nil then
      ViewChar.ToggleReadyItem(bestArmor, result)
  end;
  result := False;
  oldWeapon := ViewChar.FindReadiedItem(cr, C_Equip.WEAPON);
  if (bestWeapon <> oldWeapon) or (bestWeapon <> cr^.equipped[C_Equip.WEAPON]) then
    if (bestWeapon <> nil) and (GDVars.itemTypes[bestWeapon^.template.itemType].heavy <> 0) then
      result := True;
  if oldWeapon <> nil then
    oldWeapon^.template.flags := oldWeapon^.template.flags and not C_Item.READIED;
  cr^.equipped[C_Equip.WEAPON] := bestWeapon;
  if bestWeapon <> nil then
    bestWeapon^.template.flags := bestWeapon^.template.flags or C_Item.READIED;
  { Note: bestWeapon is nil when fighting unarmed scores best; the test below then reads itemType through nil. }
  if not result and (slotSixItem <> nil) and (slotSixReadied = 0) and
      (GDVars.itemTypes[bestWeapon^.template.itemType].weaponClass = C_WClass.GRENADE) then
    ViewChar.ToggleReadyItem(slotSixItem, result);
  if (oldArmor <> bestArmor) or (oldWeapon <> bestWeapon) or result then begin
    CharHlp.RecalcStats(cr);
    CbtActs.RecalcAttacksLeft(cr);
    CharHlp.CombatPrintCreatureInfo(cr);
    if result then begin
      CharHlp.PrintCreatureMessage(cr, 'readies a heavy weapon', 10, False);
      TextRend.PauseOnly
    end
  end
end;

function PrepareAiAction(cr: Types.PCharRecord; mode: Byte; var done: Boolean): Boolean;
var
  targetCount: Byte;
  attempts: Byte;
  index: Byte;
  retryDone: Boolean;
  hasTarget: Boolean;
  secondPass: Boolean;
  target: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  deadPointer: Pointer;
begin
  deadPointer := nil;
  secondPass := False;
  hasTarget := False;
  retryDone := False;
  target := cr^.combatAddr^.target;
  if target <> nil then
    if (target^.side = cr^.side) or (target^.enabled = 0) or not CbtActs.CanTarget(cr, target) then
      cr^.combatAddr^.target := nil;
  if cr^.combatAddr^.target <> nil then hasTarget := True;
  while (not hasTarget) and (not retryDone) do begin
    retryDone := secondPass;
    if secondPass then GDVars.combatArena^.distMode := 1;
    attempts := 20;
    targetCount := CharHlp.CountTargets(cr, 255);
    while (attempts > 0) and (not hasTarget) and (targetCount > 0) do begin
      Dec(attempts);
      index := CharHlp.RollDice(1, targetCount);
      if GDVars.targetOrder[index] > 0 then begin
        target := GDVars.creatures[GDVars.targetOrder[index]];
        if ((mode <> 0) and (GDVars.combatArena^.distMode <> 0)) or CbtActs.CanTarget(cr, target) then begin
          hasTarget := True;
          cr^.combatAddr^.target := target
        end else begin
          GDVars.targetOrder[index] := 0;
          for index := 1 to targetCount do
            if GDVars.targetOrder[index] > 0 then hasTarget := True;
          { some are left: search on }
          if hasTarget then
            hasTarget := False
          else
            targetCount := 0
        end
      end
    end;
    if not secondPass then secondPass := True
  end;
  GDVars.combatArena^.distMode := 0;
  if hasTarget and (mode <> 0) then
    CombatAi.EquipWeaponAndArmor(cr, 1, done);
  PrepareAiAction := hasTarget
end;

begin
end.
