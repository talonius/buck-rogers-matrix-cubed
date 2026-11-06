{ The ground-combat loop: rounds of combatants acting in initiative order until one side is gone or the round limit is
  reached, the player's combat menu and move menu for a manually controlled combatant, and the clean-up after. The
  actions themselves are CbtActs', the computer's choices CombatAi's. EclVm calls CombatMain; only the unit itself calls
  the other exports. The round counters and the cloud list are GDVars'. }
{$A-,O+,F+,V-}
unit Combat;

interface

uses Types, C_Combat, C_Status, C_Terr, GDConsts, GDVars, Blit, CbtMap, CbtActs, FxEngine,
  CharHlp, ViewChar, CombatSt, CombatAi, MenuCore, GameTime, Border, TextRend, GameIo, Crt, C_Equip, C_Effect, C_Dir,
  C_Skill, C_WClass, C_Ifc, C_Area, C_Side, C_Cond, C_Keys, C_Menu, C_Time, C_Screen;

{ Runs a ground combat from CombatSt's CombatStart to the clean-up, with interfaceState IN_COMBAT. }
procedure CombatMain;

{ Gives cr its turn: resets its per-turn combat state, returns a dodging or failed zero-g cr to okay, runs its
  turn-start effects and drops the scared effect and, when it still has initiative (a handed-back 20 becomes 19), hands
  it to CombatAi or ManualControl.
  @param(cr The combatant whose turn it is.) }
procedure CreatureAction(cr: Types.PCharRecord);

{ The player's turn for cr: the combat menu until an action ends the turn; a disabled cr just ends it.
  @param(cr The combatant the player controls.) }
procedure ManualControl(cr: Types.PCharRecord);

{ Builds cr's combat menu from what it may do now and reads a key the menu accepts.
  @param(cr The combatant the menu is for.)
  @param(done Unused.)
  @param(key The letter chosen, or an Alt scan code when the extended-key flag is set.) }
procedure CombatMenu(cr: Types.PCharRecord; var done: Boolean; var key: Char);

{ Ends the round: sprinters and jetpackers return to okay, the clock advances one minute, the round counter one, the
  hostiles' hit-point share is recalculated, the lingering clouds are counted down (FxEngine's CountDownAreaEffects),
  and the dying and the view are brought up to date. }
procedure EndOfRound;

{ Moves cr one cell per direction key, attacking whoever stands there, until Enter, 'D' or a canceled move; offers to
  flee when the step meets terrain 0, which is what lies off the arena.
  @param(cr The combatant moving.)
  @param(startKey The first key to act on; ' ' asks for one.)
  @param(done True when the turn has ended.) }
procedure MoveMenu(cr: Types.PCharRecord; startKey: Char; var done: Boolean);

{ Attacks defender in melee unless attacker is sprinting, holds an area weapon or an empty slug weapon, or CbtActs'
  CheckAttackAlly declines.
  @param(attacker The combatant attacking.)
  @param(defender The combatant attacked.)
  @param(done True when the attack ended the attacker's turn.) }
procedure MeleeAttack(attacker, defender: Types.PCharRecord; var done: Boolean);

{ Hands cr to the computer, dropping a target on its own side.
  @param(cr The combatant handed over.) }
procedure TurnOnAuto(cr: Types.PCharRecord);

{ Fills the combat order with the party list by initiative, highest first, a tie going to the higher tiebreak value. }
procedure OrderCreatures;

{ Frees the cloud list, the arena and the combat pictures; returns combat statuses to okay and removes Blind, Helpless
  and Stunned from every member of the party list; clears the team's tactics flag and restores the non-combat palette
  and view size. }
procedure CombatDoneCleanup;

{ Tests whether cr may fight with its readied weapon.
  @param(cr The combatant.)
  @returns(False while cr sprints or its readied weapon is an empty C_WClass.SLUG weapon.) }
function CombatOptionAllowed(cr: Types.PCharRecord): Boolean;

implementation

const
  { scan codes the combat menu takes with extFlag set, with C_Keys.ALT_X }
  KEY_ALT_Q = #16;
  KEY_ALT_R = #19;
  KEY_ALT_A = #30;
  KEY_ALT_M = #50;
  { OrderCreatures compares a combatant with the first SEARCHED_SLOTS of combatOrder; one that outranks none of them
    goes in at SEARCHED_SLOTS + 1 }
  SEARCHED_SLOTS = 64;
  { TItemType.slot of the jetpack: the combat menu offers Jetpack while one is readied }
  EQUIP_JETPACK = 2;

type
  TString12 = String[12];

procedure CombatDoneCleanup;
var
  nextCloud: Types.PAreaEffect;
  cr: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  effectScan: array[0..5] of Byte;
begin
  while GDVars.areaEffects <> nil do begin
    nextCloud := GDVars.areaEffects^.next;
    FreeMem(GDVars.areaEffects, SizeOf(Types.TAreaEffect));
    GDVars.areaEffects := nextCloud
  end;
  cr := GDVars.partyHead;
  while cr <> nil do begin
    if cr^.status in [C_Status.DODGING..C_Status.USING_JETPACK] then cr^.status := C_Status.OKAY;
    FxEngine.RemoveEffect(cr, C_Effect.BLIND, nil);
    FxEngine.RemoveEffect(cr, C_Effect.HELPLESS, nil);
    FxEngine.RemoveEffect(cr, C_Effect.STUNNED, nil);
    cr := cr^.nextCharAddr
  end;
  FreeMem(GDVars.combatArena, SizeOf(Types.TArena));
  GDVars.combatArena := nil;
  Blit.FreePic(GDVars.movingIcon);
  Blit.FreePic(GDVars.arenaTiles);
  CbtMap.SetNoncombatPalette;
  GDVars.tacticsSides[C_Side.TEAM] := 0;
  GDVars.viewPicture^.height := 200;
  GDVars.viewPicture^.width := 40
end;

procedure CombatMain;
var
  done: Boolean;
  cr: Types.PCharRecord;
begin
  GDVars.interfaceState := C_Ifc.IN_COMBAT;
  CbtActs.UseLeadership;
  CombatSt.CombatStart;
  done := False;
  if (GDVars.teamCounts[C_Side.TEAM] = 0) or (GDVars.teamCounts[C_Side.HOSTILE] = 0) then
    done := True
  else
    GDVars.treatmentPending := 1;
  cr := GDVars.partyHead;
  while not done do begin
    CharHlp.CountTeams;
    CbtActs.RollTactics;
    cr := GDVars.partyHead;
    while cr <> nil do begin
      CbtActs.BeginRound(cr);
      cr := cr^.nextCharAddr
    end;
    GDVars.zone1^.sideMask := 0;
    Combat.OrderCreatures;
    cr := GDVars.combatOrder[1];
    GDVars.currentCombatant := 1;
    while (cr <> nil) and not done do begin
      Combat.CreatureAction(cr);
      Inc(GDVars.currentCombatant);
      if GDVars.currentCombatant > C_Combat.MAX_COMBATANTS then
        cr := nil
      else
        cr := GDVars.combatOrder[GDVars.currentCombatant];
      CharHlp.CountTeams;
      if (GDVars.teamCounts[C_Side.TEAM] = 0) or (GDVars.teamCounts[C_Side.HOSTILE] = 0) or
          (GDVars.combatRound >= GDVars.combatEndRound) then
        done := True
    end;
    Combat.EndOfRound
  end;
  Combat.CombatDoneCleanup;
  GDVars.messageDelay := 1
end;

procedure OrderCreatures;
var
  isSearching: Boolean;
  cr: Types.PCharRecord;
  displaced: Types.PCharRecord;
  nextDisplaced: Types.PCharRecord;
  initiative: ShortInt;
  otherInitiative: ShortInt;
  slot: Byte;
  shiftSlot: Byte;
begin
  cr := GDVars.partyHead;
  FillChar(GDVars.combatOrder, SizeOf(GDVars.combatOrder), 0);
  while cr <> nil do begin
    slot := 1;
    isSearching := True;
    initiative := cr^.combatAddr^.initiative;
    while (slot < Combat.SEARCHED_SLOTS + 1) and isSearching do begin
      if GDVars.combatOrder[slot] <> nil then
        otherInitiative := GDVars.combatOrder[slot]^.combatAddr^.initiative
      else
        otherInitiative := -1;
      if (initiative > otherInitiative) or
          ((initiative = otherInitiative) and
           (GDVars.combatOrder[slot]^.combatAddr^.priority < cr^.combatAddr^.priority)) then
        isSearching := False
      else
        Inc(slot)
    end;
    displaced := GDVars.combatOrder[slot];
    GDVars.combatOrder[slot] := cr;
    if displaced <> nil then begin
      shiftSlot := slot;
      isSearching := True;
      while (shiftSlot < C_Combat.MAX_COMBATANTS) and isSearching do begin
        Inc(shiftSlot);
        nextDisplaced := GDVars.combatOrder[shiftSlot];
        GDVars.combatOrder[shiftSlot] := displaced;
        displaced := nextDisplaced;
        if nextDisplaced = nil then isSearching := False
      end
    end;
    cr := cr^.nextCharAddr
  end
end;

procedure CreatureAction(cr: Types.PCharRecord);
{ Unused in this version; see the other implementations of this routine. }
var action: Byte;
begin
  with cr^ do begin
    combatAddr^.directionCount := 0;
    combatAddr^.directionTotal := 0;
    combatAddr^.guarding := 0;
    if (status = C_Status.DODGING) or
        (status = C_Status.FAILED_ZERO_G) then status := C_Status.OKAY;
    FxEngine.TriggerEffectsWithCondition(C_Cond.TURN_START, cr);
    FxEngine.RemoveEffect(cr, C_Effect.SCARED, nil);
    if combatAddr^.initiative <= 0 then Exit;
    if combatAddr^.initiative = 20 then combatAddr^.initiative := 19;
    GDVars.currentCharacter := cr;
    GDVars.mapVisible := Ord((side = C_Side.TEAM) or CbtMap.CombatIconVisible(cr, 0));
    CbtMap.DisplayMapViewCentered(cr, 2, True);
    CharHlp.RecalcStats(cr);
    GDVars.creatureInfoDirty := 1;
    CharHlp.CombatPrintCreatureInfo(cr);
    CbtActs.RollZeroG(cr);
    FxEngine.TriggerEffectsWithCondition(C_Cond.ACTION_START, cr);
    if combatAddr^.initiative > 0 then
      if quickfight <> 0 then
        CombatAi.CombatAiControl(cr)
      else Combat.ManualControl(cr);
    CbtMap.RedrawArenaCell(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr))
  end
end;

function CombatOptionAllowed(cr: Types.PCharRecord): Boolean;
var
  item: Types.PItemRec;
begin
  CombatOptionAllowed := True;
  if cr^.status = C_Status.SPRINTING then
    CombatOptionAllowed := False
  else begin
    item := Types.PItemRec(cr^.equipped[C_Equip.WEAPON]);
    if item <> nil then
      if (GDVars.itemTypes[item^.template.itemType].weaponClass = C_WClass.SLUG) and (item^.template.quantity = 0) then
        CombatOptionAllowed := False
  end
end;

procedure ManualControl(cr: Types.PCharRecord);
var
  key: Char;
  done: Boolean;
  p: Types.PCharRecord;
  { where CombatAimMenu leaves the target it chose; unused here }
  selection: Types.TAimTarget;
  { Unused in this version; see the other implementations of this routine. }
  menuKeys: array[1..2] of Byte;
  { passed to CombatMenu, which neither reads nor writes it }
  menuDone: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
begin
  if cr^.enabled <> 0 then begin
    done := False;
    menuDone := True;
    while not done do begin
      GDVars.horizChoice := 1;
      Combat.CombatMenu(cr, menuDone, key);
      if not GDVars.extFlag then
        case key of
          'M': Combat.MoveMenu(cr, ' ', done);
          'T': CbtActs.CombatAimMenu(cr, 255, C_Combat.AIM_ATTACK, False, Combat.CombatOptionAllowed(cr), done,
                                     selection);
          'V': begin
                 ViewChar.ViewCharMenu(done);
                 CbtActs.RecalcAttacksLeft(cr);
                 CharHlp.DisplayCombatInterface
               end;
          'I': begin
                 CbtActs.IntimidateTarget(cr);
                 done := CharHlp.EndActions(cr)
               end;
          'Q': begin
                 Combat.TurnOnAuto(cr);
                 TextRend.ClearStatusLine;
                 GameIo.FlushKeys;
                 Delay(200);
                 done := True;
                 CombatAi.CombatAiControl(cr)
               end;
          'A': begin
                 ViewChar.TreatPatients(cr);
                 done := CharHlp.EndActions(cr)
               end;
          'S': begin
                 if cr^.status <> C_Status.SPRINTING then begin
                   cr^.status := C_Status.SPRINTING;
                   cr^.combatAddr^.movement := cr^.combatAddr^.movement * 2
                 end;
                 Combat.MoveMenu(cr, ' ', done)
               end;
          'D': begin
                 cr^.status := C_Status.DODGING;
                 done := CharHlp.EndActions(cr)
               end;
          'J': begin
                 CbtActs.CombatUseJetpack(cr);
                 done := cr^.combatAddr^.initiative = 0
               end;
          'W': begin
                 cr^.combatAddr^.initiative := 1;
                 GDVars.loopIndex := GDVars.currentCombatant;
                 p := GDVars.combatOrder[GDVars.loopIndex + 1];
                 while (p <> nil) and (GDVars.loopIndex < C_Combat.MAX_COMBATANTS) do begin
                   GDVars.combatOrder[GDVars.loopIndex] := p;
                   Inc(GDVars.loopIndex);
                   p := GDVars.combatOrder[GDVars.loopIndex + 1]
                 end;
                 GDVars.combatOrder[GDVars.loopIndex] := cr;
                 Dec(GDVars.currentCombatant);
                 done := True
               end;
          'G': done := CbtActs.Guard(cr);
          'E': done := CharHlp.EndActions(cr);
          ' ': begin
                 p := GDVars.partyHead;
                 while p <> nil do begin
                   with p^ do
                     if (side = C_Side.TEAM) and (skillLevels[0] = 0) and (combatAddr^.notPcNpc = 0) then
                       quickfight := 0;
                   p := p^.nextCharAddr
                 end
               end
        end else
        case key of
          Combat.KEY_ALT_Q, Combat.KEY_ALT_A: begin
                 Dec(GDVars.currentCombatant);
                 cr^.combatAddr^.initiative := 20;
                 p := GDVars.partyHead;
                 while p <> nil do begin
                   Combat.TurnOnAuto(p);
                   p := p^.nextCharAddr
                 end;
                 TextRend.ClearStatusLine;
                 Delay(200);
                 done := True
               end;
          C_Keys.ALT_X: if CbtActs.VictoryCheat then begin
                  CbtMap.DisplayMapViewCentered(cr, 3, False);
                  done := True
                end
        end;
      if not done then begin
        CbtMap.DisplayMapViewCentered(cr, 2, True);
        GDVars.creatureInfoDirty := 1;
        CharHlp.CombatPrintCreatureInfo(cr)
      end
    end
  end else
    done := CharHlp.EndActions(cr)
end;

procedure CombatMenu(cr: Types.PCharRecord; var done: Boolean; var key: Char);
var
  menu: String;
  { Unused in this version; see the other implementations of this routine. }
  menuLength: Word;
begin
  Border.ClearBox(0, 23, 39, 24);
  menu := '';
  if cr^.combatAddr^.movement > 0 then menu := menu + 'Move ';
  menu := menu + 'Target View ';
  if (cr^.skillLevels[C_Skill.INTIMIDATE] > 0) and (CharHlp.CountTargets(cr, 1) > 0) and
      (cr^.status <> C_Status.DODGING) and (cr^.status <> C_Status.FAILED_ZERO_G) then
    menu := menu + 'Intimidate ';
  menu := menu + 'Quick ';
  if ViewChar.FindPatients(cr) then menu := menu + 'Aid ';
  menu[Length(menu)] := '@';
  if (cr^.combatAddr^.movement > 0) and (cr^.status <> C_Status.DODGING) then begin
    if cr^.status <> C_Status.SPRINTING then begin
      if (cr^.status <> C_Status.USED_JETPACK) and (cr^.status <> C_Status.FAILED_ZERO_G) then
        menu := menu + 'Sprint ';
      menu := menu + 'Dodge '
    end;
    if (cr^.status <> C_Status.USED_JETPACK) and (ViewChar.FindReadiedItem(cr, Combat.EQUIP_JETPACK) <> nil) and
        (GDVars.zone0^.areaType in [C_Area.VENUS_WILDERNESS, C_Area.MARS_WILDERNESS]) then
      menu := menu + 'Jetpack '
  end;
  menu := menu + 'Wait ';
  if (cr^.status <> C_Status.SPRINTING) and (cr^.status <> C_Status.DODGING) then
    menu := menu + 'Guard ';
  menu := menu + 'End';
  repeat
    MenuCore.MenuHorizontal('', menu, True, False);
    key := GDVars.menuKey;
    if GDVars.extFlag then
      if not (key in [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, Combat.KEY_ALT_A, C_Keys.ALT_X, Combat.KEY_ALT_M]) then
        key := C_Keys.NONE
  until key in
      [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, Combat.KEY_ALT_A, ' ', C_Keys.ALT_X, Combat.KEY_ALT_M, 'A', 'D', 'E',
       'G', 'I', 'J', 'M', 'Q', 'S', 'T', 'V', 'W'];
  Border.ClearBox(0, 23, 39, 24)
end;

procedure EndOfRound;
var
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
  p: Types.PCharRecord;
begin
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.status = C_Status.SPRINTING) or (p^.status = C_Status.USED_JETPACK) then
      p^.status := C_Status.OKAY;
    p := p^.nextCharAddr
  end;
  GameTime.AdvanceTime(1, C_Time.MINUTES);
  Inc(GDVars.combatRound);
  CbtActs.UpdateHostileHpPercent;
  FxEngine.CountDownAreaEffects;
  CharHlp.ProcessDyingCharacters;
  CbtMap.ScrollView(GDVars.combatArena^.viewOriginX + 3, GDVars.combatArena^.viewOriginY + 3, 255, C_Dir.CENTER)
end;

procedure MoveMenu(cr: Types.PCharRecord; startKey: Char; var done: Boolean);
var
  savedMove: Byte;
  savedDir: Byte;
  startX: Byte;
  startY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  slot: Integer;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  key: Char;
  { ProbeDirection's report of gas on the cell; not read here }
  hasGas: Byte;
  cost: Byte;
  prompt: TString12;

  { Puts cr back on the cell the move began on, with its movement and facing; done when it no longer fits there. }
  procedure UndoMove;
  begin
    cr^.combatAddr^.movement := savedMove;
    CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(cr));
    done := not CbtMap.IsValidCreatureLoc(cr, startX, startY, False);
    CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 0, C_Dir.CENTER);
    cr^.combatAddr^.direction := savedDir;
    dir := C_Dir.CENTER
  end;

begin
  GDVars.inMoveMenu := 1;
  savedMove := cr^.combatAddr^.movement;
  savedDir := cr^.combatAddr^.direction;
  startX := CbtMap.CombatCellX(cr);
  startY := CbtMap.CombatCellY(cr);
  key := startKey;
  done := False;
  dir := C_Dir.CENTER;
  repeat
    while (key <> C_Keys.NONE) and (key <> C_Keys.ENTER) and (key <> 'D') and (done = False) do begin
      if cr^.status = C_Status.SPRINTING then
        prompt := 'Sprinting'
      else if cr^.status = C_Status.DODGING then
        prompt := 'Dodging'
      else
        prompt := 'Move/Attack';
      Border.ClearBox(24, C_Screen.STATUS_ROW, 39, C_Screen.STATUS_ROW);
      if key = ' ' then begin
        MenuCore.MenuHorizontal(prompt + ', Move Left = ' + TextRend.ByteToString(cr^.combatAddr^.movement div 2),
                                ' Done', True, False);
        key := GDVars.menuKey
      end;
      case key of
        C_Keys.NONE: UndoMove;
        C_Keys.PAGE_UP: dir := C_Dir.NORTHEAST;
        C_Keys.UP: dir := C_Dir.NORTH;
        C_Keys.PAGE_DOWN: dir := C_Dir.SOUTHEAST;
        C_Keys.RIGHT: dir := C_Dir.EAST;
        C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
        C_Keys.DOWN: dir := C_Dir.SOUTH;
        C_Keys.HOME: dir := C_Dir.NORTHWEST;
        C_Keys.LEFT: dir := C_Dir.WEST
      else
        dir := C_Dir.CENTER
      end;
      if dir < C_Dir.CENTER then begin
        CbtMap.SetCreatureFacing(cr, dir, 0, 0);
        CbtMap.ProbeDirection(cr, dir, crIdx, terrIdx, hasGas);
        if crIdx > 0 then
          Combat.MeleeAttack(cr, GDVars.creatures[crIdx], done)
        else if terrIdx = 0 then begin
          case MenuCore.YesNoMenu('Flee:', C_Menu.DEFAULT_NO) of
            'Y': done := CbtActs.AttemptFlee(cr);
            'N': done := False
          end
        end else begin
          if Odd(dir) then
            cost := GDConsts.terrainInfo[terrIdx].cost * 3
          else
            cost := GDConsts.terrainInfo[terrIdx].cost * 2;
          if GDConsts.terrainInfo[terrIdx].cost = C_Terr.IMPASSABLE then cost := C_Terr.IMPASSABLE;
          if cost > cr^.combatAddr^.movement then
            CharHlp.PrintBottomLine('can''t go there')
          else begin
            if cr^.enabled = 0 then
              done := CharHlp.EndActions(cr)
            else begin
              if cr^.combatAddr^.movement > 0 then
                CbtActs.CombatMoveCreature(cr, dir);
              if cr^.enabled = 0 then done := CharHlp.EndActions(cr);
              FxEngine.ConsiderTerrainEffects(cr, 1);
              if CharHlp.IsHelpless(cr) then done := CharHlp.EndActions(cr)
            end
          end
        end
      end;
      if (key <> C_Keys.NONE) and (key <> C_Keys.ENTER) and (key <> 'D') then key := ' '
    end
  until (key <> ' ') or done;
  if cr^.combatAddr^.movement < 2 then cr^.combatAddr^.movement := 0;
  GDVars.inMoveMenu := 0
end;

procedure MeleeAttack(attacker, defender: Types.PCharRecord; var done: Boolean);
begin
  if attacker^.status = C_Status.SPRINTING then
    CharHlp.PrintBottomLine('Not while running')
  else if CharHlp.HasAreaWeapon(attacker) or not Combat.CombatOptionAllowed(attacker) then
    CharHlp.PrintBottomLine('Not with that weapon')
  else if CbtActs.CheckAttackAlly(attacker, defender) then begin
    attacker^.combatAddr^.target := defender;
    CbtActs.NoteAttackDirection(attacker, defender);
    CbtActs.MakeAttack(attacker, defender, False, done)
  end
end;

procedure TurnOnAuto(cr: Types.PCharRecord);
begin
  cr^.quickfight := 1;
  if cr^.combatAddr^.target <> nil then
    if cr^.combatAddr^.target^.side = cr^.side then
      cr^.combatAddr^.target := nil
end;

begin
end.
