{ What follows a ground combat: its results and experience, removing the combat's creatures, poison and wound treatment,
  ship repair, the summary and the loot menu. PostCombat runs them in turn, or paints the game-over screen when the team
  is lost. The outcome flags (hasOutcomeToReport, hasPartyFled) and the treasure flags the loot menus share are GDVars',
  the treasure line's text and RepairShip's tables GDConsts'. }
{$O+,F+,A-,I-,V-}
unit PostCbt;

interface

{ Runs everything after a combat: settles the results and removes the combat's creatures, then treatment, ship repair,
  the summary (when there is an experience share) and the loot menu (when there is treasure) -- or the game-over screen
  when the team is lost. In the demo only the creature cleanup runs; after a boarding, treatment, repair, summary and
  loot are skipped. }
procedure PostCombat;

implementation

uses Types, C_Npc, C_Ship, C_Status, GDConsts, GDVars, TextRend, Border, CharHlp, Money,
  FxEngine, CharGen, Shop, MenuCore, ViewChar, EclMenu, Crt, C_Effect, C_Skill, C_Sys, C_Ifc, C_Item, C_PostCb,
  C_Career, C_Side, C_Keys, C_Menu, C_Msg;

const
  { zone 0's postCombatMode as ECL scripts set it: PostCombat repairs the ship, then sets C_PostCb.NORMAL }
  POST_COMBAT_REPAIR_SHIP = 2;

const
  { the antidote's item type }
  ANTIDOTE_TYPE = 31;
  { zone 1's combatResult values }
  RESULT_WON = 0;
  RESULT_MONSTER_FLED = 1;
  RESULT_TEAM_BEATEN = $80;
  RESULT_TEAM_FLED = $81;

{ Disposes the salvage list, then clears it and poolCredits. }
procedure ClearTreasure;
var p: Types.PItemRec;
begin
  p := GDVars.availableItems;
  while p <> nil do begin
    GDVars.availableItems := p^.next;
    Dispose(p);
    p := GDVars.availableItems
  end;
  GDVars.poolCredits := 0;
  GDVars.availableItems := nil
end;

{ Totals the fallen hostiles' experience (those not okay or fleeing whose out-of-play flag is non-zero) and, outside a
  solo combat, the credits of those whose out-of-play flag is 1 and, unless zone 1's skip-combat-items flag is 1, the
  items not marked as non-treasure, copied unreadied into the offered list.
  @param(share The total in a solo combat, else its share per member still able to act; left alone when there is
  none.) }
procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PCharRecord;
  expTotal: LongInt;
  q: Types.PItemRec;
  it: Types.PItemRec;
  { counts the items taken; unused }
  itemCount: Byte;
  divisor: Byte;
begin
  expTotal := 0;
  p := GDVars.partyHead;
  itemCount := 0;
  while p <> nil do begin
    it := Types.PItemRec(p^.itemsAddr);
    if (p^.hostile = C_Side.HOSTILE) and (p^.status <> C_Status.OKAY) and (p^.combatAddr^.notPcNpc <> 0) and
        (p^.status <> C_Status.FLEEING) then begin
      GDVars.hasOutcomeToReport := True;
      Inc(expTotal, p^.xpAward);
      if GDVars.soloCombat = 0 then begin
        if p^.combatAddr^.notPcNpc = 1 then
          Inc(GDVars.poolCredits, p^.credits);
        if GDVars.zone1^.skipsCombatItems <> 1 then
          while it <> nil do begin
            if (it^.template.flags and C_Item.NOT_TREASURE) = 0 then begin
              Inc(itemCount);
              if GDVars.availableItems = nil then
                q := nil
              else
                q := GDVars.availableItems;
              New(GDVars.availableItems);
              CharHlp.PrintItemString(p, it, 0, 0, False, False);
              GDVars.availableItems^ := it^;
              GDVars.availableItems^.template.flags := GDVars.availableItems^.template.flags and not C_Item.READIED;
              GDVars.availableItems^.next := q
            end;
            it := it^.next
          end
      end
    end;
    p := p^.nextCharAddr
  end;
  if GDVars.soloCombat <> 0 then
    share := expTotal
  else begin
    divisor := GDVars.zone1^.partyCount - GDVars.disabledCount;
    if divisor <> 0 then
      share := expTotal div divisor
  end;
end;

{ Gives the experience share to currentCharacter in a solo combat, else to each enabled member.
  @param(expShare The experience each receives.) }
procedure AwardExperience(expShare: LongInt);
var
  p: Types.PCharRecord;
begin
  if GDVars.soloCombat <> 0 then
    Inc(GDVars.currentCharacter^.experience, expShare)
  else begin
    p := GDVars.partyHead;
    while p <> nil do begin
      if p^.enabled <> 0 then
        Inc(p^.experience, expShare);
      p := p^.nextCharAddr
    end
  end
end;

{ Returns combat statuses to okay, decides whether the team was lost, fled or won, clears the post-combat effects,
  awards the experience share and removes the members lost in a flight or a defeat. }
procedure DetermineCombatResults;
var
  p: Types.PCharRecord;
  isDone: Boolean;
  i: Byte;
  hasLiveMember: Boolean;
  next: Types.PCharRecord;
begin
  p := GDVars.partyHead;
  while p <> nil do begin
    if p^.status in [C_Status.OKAY, C_Status.DODGING..C_Status.FAILED_ZERO_G] then begin
      p^.status := C_Status.OKAY;
      p^.enabled := 1
    end;
    p := p^.nextCharAddr
  end;
  GDVars.disabledCount := 0;
  GDVars.partyDefeated := 1;
  GDVars.hasPartyFled := False;
  p := GDVars.partyHead;
  while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) and not GDVars.hasPartyFled do begin
    if p^.status = C_Status.FLEEING then GDVars.hasPartyFled := True;
    p := p^.nextCharAddr
  end;
  p := GDVars.partyHead;
  hasLiveMember := False;
  while (p <> nil) and not hasLiveMember do begin
    hasLiveMember := (p^.enabled <> 0) and (p^.combatAddr^.notPcNpc <> 1) and (p^.hostile = C_Side.TEAM) and
      (p^.skillLevels[0] = 0);
    p := p^.nextCharAddr
  end;
  if hasLiveMember then GDVars.partyDefeated := 0;
  GDVars.combatWon := 0;
  p := GDVars.partyHead;
  if (GDVars.soloCombat = 0) and not GDVars.demoMode then begin
    while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
      next := p^.nextCharAddr;
      if (p^.status = C_Status.FLEEING) or
          ((p^.status = C_Status.OKAY) and (p^.hostile = C_Side.TEAM) and
           (p^.npc < C_Npc.NON_PLAYER_FLAG)) then
        GDVars.partyDefeated := 0;
      if p^.status = C_Status.OKAY then begin
        GDVars.combatWon := 1;
        GDVars.hasPartyFled := False
      end;
      if p^.enabled = 0 then Inc(GDVars.disabledCount);
      for i := 1 to SizeOf(GDConsts.postCombatClearedEffects) do
        FxEngine.RemoveEffect(p, GDConsts.postCombatClearedEffects[i], nil);
      p := p^.nextCharAddr
    end;
    if GDVars.combatWon <> 0 then begin
      PostCbt.DetermineLootExp(GDVars.experienceShare);
      PostCbt.AwardExperience(GDVars.experienceShare)
    end;
    p := GDVars.partyHead;
    if GDVars.partyDefeated = 0 then begin
      while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
        next := p^.nextCharAddr;
        if not GDVars.hasPartyFled then begin
          case p^.status of
            C_Status.FLEEING: begin p^.status := C_Status.OKAY; p^.enabled := 1 end;
            C_Status.DYING: if GDVars.zone1^.revivesParty <> 0 then begin
                           p^.status := C_Status.OKAY; p^.enabled := 1; p^.hitPoints := 1
                         end else p^.status := C_Status.UNCONSCIOUS;
            C_Status.UNCONSCIOUS: if p^.hitPoints > 0 then begin
                                 p^.status := C_Status.OKAY; p^.enabled := 1
                               end else if GDVars.zone1^.revivesParty <> 0 then begin
                                 p^.status := C_Status.OKAY; p^.enabled := 1; p^.hitPoints := 1
                               end
          end
        end else begin
          GDVars.zone1^.combatResult := PostCbt.RESULT_TEAM_FLED;
          if p^.status = C_Status.FLEEING then begin
            p^.status := C_Status.OKAY; p^.enabled := 1
          end else begin
            GDVars.currentCharacter := p;
            CharGen.RemoveCreature(False, True)
          end
        end;
        p := next
      end
    end else begin
      p := GDVars.partyHead;
      isDone := False;
      while (p <> nil) and not isDone do begin
        if p^.combatAddr^.notPcNpc <> 1 then begin
          GDVars.currentCharacter := p;
          CharGen.RemoveCreature(False, True)
        end else
          isDone := True;
        p := p^.nextCharAddr
      end;
      GDVars.zone1^.partyCount := 0
    end
  end else begin
    p := GDVars.currentCharacter;
    if (p^.enabled = 1) and (p^.status = C_Status.OKAY) and (p^.hostile <> C_Side.HOSTILE) then begin
      GDVars.combatWon := 1;
      PostCbt.DetermineLootExp(GDVars.experienceShare);
      PostCbt.AwardExperience(GDVars.experienceShare);
      GDVars.zone1^.combatResult := PostCbt.RESULT_WON
    end else begin
      GDVars.zone1^.combatResult := PostCbt.RESULT_TEAM_BEATEN;
      if p^.status in [C_Status.DEAD_STATUS, C_Status.DYING] then p^.status := C_Status.UNCONSCIOUS;
      if p^.status = C_Status.FLEEING then begin
        p^.status := C_Status.OKAY;
        p^.enabled := 1
      end
    end
  end
end;

{ Prints the outcome, the experience each character receives and whether booty was found. When it reports a flight it
  discards the treasure and prints 0.
  @param(expShare The experience each character receives.) }
procedure PostCombatSummary(expShare: LongInt);
var
  numStr: String[10];
  msg: String;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
  { always empty; unused }
  query: String[1];
  { Unused in this version; see the other implementations of this routine. }
  ext: Boolean;
begin
  query[0] := #0;
  Border.DrawWindowFrame(1);
  if GDVars.hasOutcomeToReport or (GDVars.soloCombat <> 0) then begin
    if GDVars.hasPartyFled then begin
      TextRend.DisplayString(1, 3, LightGreen, Black, 'The team has fled.');
      expShare := 0;
      PostCbt.ClearTreasure
    end else
      TextRend.DisplayString(1, 3, LightGreen, Black, 'The team has won.');
  end;
  Str(expShare, numStr);
  msg := 'Each character receives ' + numStr;
  TextRend.DisplayString(1, 5, LightGreen, Black, msg);
  TextRend.DisplayString(1, 7, LightGreen, Black, 'experience points.');
  GDVars.treasureHasMoney := False;
  GDVars.treasureHasItems := False;
  Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
  if GDVars.treasureHasMoney or GDVars.treasureHasItems then
    TextRend.DisplayString(1, 10, LightGreen, Black, GDConsts.treasureFoundText + GDConsts.treasureBootyText)
  else
    TextRend.DisplayString(1, 10, LightGreen, Black, GDConsts.treasureFoundText + 'no ' + GDConsts.treasureBootyText);
  TextRend.PauseContinue
end;

{ Lists the salvage in a vertical menu.
  @param(c The key that closed the menu.)
  @param(itemToTake The item under the cursor when the menu returns.)
  @param(cursor The item under the cursor, kept between calls.)
  @param(idx The cursor's position, kept between calls.) }
procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItemRec; var cursor: Types.PItemRec;
                                var idx: Integer);
var
  head: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  itemText: String[16];
  { Unused in this version; see the other implementations of this routine. }
  textLength: Byte;
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
  menuNeedsRedraw: Boolean;
  p: Types.PItemRec;
begin
  menuNeedsRedraw := True;
  p := GDVars.availableItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
  head := GDVars.availableItems;
  GDVars.horizChoice := 1;
  c := MenuCore.MenuVertical('Gear: ', 'Take', 1, 1, 38, 22, Types.PMenuNode(head), True, menuNeedsRedraw, idx,
                             Types.PMenuNode(cursor));
  itemToTake := cursor;
end;

{ Gives the salvage items the player picks to currentCharacter until the list is empty or the player leaves. }
procedure LootTakeItemMenu;
var
  itemToTake: Types.PItemRec;
  p: Types.PItemRec;
  c: Char;
  isDone: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
  hasFailed: Boolean;
begin
  itemToTake := nil;
  cursor := GDVars.availableItems;
  idx := 0;
  Border.DrawWindowFrame(1);
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    if (c <> 'T') and (c <> C_Keys.ENTER) then
      isDone := True
    else begin
      isDone := False;
      Shop.GiveItemCopyToCreature(itemToTake, hasFailed);
      if not hasFailed then begin
        p := GDVars.availableItems;
        if p = itemToTake then
          GDVars.availableItems := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        if itemToTake <> nil then begin
          itemToTake^.next := nil;
          Dispose(itemToTake);
        end;
        if GDVars.availableItems = nil then
          isDone := True;
      end;
    end;
  until isDone;
  CharHlp.DisplayNoncombatInterface;
end;

{ The take menu. With both credits and gear to take, the player chooses between them until Exit, or until the category
  just taken from is empty even if the other is not; Money.DetermineTreasure refreshes hasCredits and hasOther after
  each take. With only one, it is taken once and both are left as passed.
  @param(hasCredits True when there are credits to take.)
  @param(hasOther True when there is gear to take.) }
procedure LootTakeMenu(var hasCredits, hasOther: Boolean);
var
  c: Char;
  isDone: Boolean;
begin
  isDone := False;
  if hasCredits then begin
    if hasOther then begin
      repeat
        MenuCore.MenuHorizontal('Take: ', 'Credits Gear Exit', False, True);
        c := GDVars.menuKey;
        if GDVars.extFlag or not (c in [C_Keys.NONE, 'C', 'E', 'G']) then begin
          CharHlp.DisplayRoster(GDVars.currentCharacter, False);
          ViewChar.SelectPrevNextChar(c);
          CharHlp.DisplayRoster(GDVars.currentCharacter, True)
        end else
          case c of
          'C': begin
                 Money.TakeMoneyMenu;
                 CharHlp.DisplayNoncombatInterface;
                 Money.DetermineTreasure(hasCredits, hasOther);
                 isDone := not hasCredits;
                 MenuCore.DisplayParty(GDVars.currentCharacter);
               end;
          'G': begin
                 PostCbt.LootTakeItemMenu;
                 Money.DetermineTreasure(hasCredits, hasOther);
                 isDone := not hasOther;
                 MenuCore.DisplayParty(GDVars.currentCharacter);
               end;
          'E', C_Keys.NONE: isDone := True;
          end;
      until isDone;
    end else begin
      Money.TakeMoneyMenu;
      CharHlp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

{ Shares out the ship combat's experience, repairs the party ship's systems but fuel, and its weapons, with the crew's
  repair skills, plunders fuel from the enemy's ship when the combat gave experience, and reports it all. }
procedure RepairShip;
var
  i: ShortInt;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  isRepaired: Boolean;
  numStr: String[5];
  amount: Byte;
  remain: Byte;
  fuel: Word;
begin
  p := GDVars.partyHead;
  remain := 0;
  while p <> nil do begin
    if p^.enabled <> 0 then Inc(remain);
    p := p^.nextCharAddr
  end;
  GDVars.experienceShare := 0;
  if remain <> 0 then begin
    GDVars.experienceShare := GDVars.shipCombatExperience div remain;
    PostCbt.AwardExperience(GDVars.experienceShare)
  end;
  GDVars.shipCombatExperience := 0;
  PostCbt.ClearTreasure;
  GDVars.shipRepairPending := 0;
  Border.DrawWindowFrame(1);
  TextRend.SetTextWindow(1, 1, 38, 21, Black);
  TextRend.DisplayWindowText(LightMagenta, '  Repairing Ship');
  TextRend.DisplayWindowText(Black, '');
  TextRend.DisplayWindowText(White, 'Engineer         System         Result');
  TextRend.DisplayWindowText(Black, '');
  for i := C_Sys.HULL to C_Sys.ENGINES do
    if i <> C_Sys.FUEL then begin
    isRepaired := False;
    with GDVars.partyShip^ do
    if systemNow[i] < systemMax[i] then begin
      p := GDVars.partyHead;
      while p <> nil do begin
        if (p^.status = C_Status.OKAY) and (i <> C_Sys.FUEL) and
            (CharHlp.SelectSkillCharacter(GDConsts.repairSkills[i], 2, False, Pointer(p)) >= 2) then begin
          amount := CharHlp.RollDice(GDConsts.repairDice[i], 10);
          if amount + systemNow[i] > systemMax[i] then
            amount := systemMax[i] - systemNow[i];
          Inc(systemNow[i], amount);
          Str(amount, numStr);
          TextRend.DisplayString(1, GDVars.windowTextRow, LightGreen, Black, p^.name);
          TextRend.DisplayString(18, GDVars.windowTextRow, LightGreen, Black, GDConsts.shipSystemNames[i]);
          TextRend.DisplayString(34, GDVars.windowTextRow, LightGreen, Black, ' ' + numStr);
          TextRend.DisplayWindowText(Black, '');
          p := nil
        end else
          p := p^.nextCharAddr
      end
    end
  end;
  for GDVars.loopIndex := 0 to SizeOf(GDVars.partyShip^.slots) div SizeOf(Types.TShipSlot) - 1 do begin
    with GDVars.partyShip^.slots[GDVars.loopIndex] do begin
    remain := maximum - current;
    while remain > 0 do begin
      Dec(remain);
      p := GDVars.partyHead;
      while p <> nil do begin
        if (p^.status = C_Status.OKAY) and
            (CharHlp.SelectSkillCharacter(GDConsts.repairSkills[C_Sys.WEAPONS], 2, False, Pointer(p)) >=
             2) then begin
          TextRend.DisplayString(1, GDVars.windowTextRow, LightGreen, Black, p^.name);
          TextRend.DisplayString(18, GDVars.windowTextRow, LightGreen, Black,
                                 GDConsts.shipWeapons[kind and C_Ship.KIND_MASK].name);
          TextRend.DisplayString(32, GDVars.windowTextRow, LightGreen, Black, ' fixed');
          TextRend.DisplayWindowText(Black, '');
          Inc(current);
          p := nil
        end else
          p := p^.nextCharAddr
      end
    end
    end
  end;
  if GDVars.experienceShare <> 0 then begin
    fuel := ((CharHlp.RollDice(2, 4) + 7) * GDVars.enemyShip^.systemNow[C_Sys.FUEL]) shr 4;
    if fuel > 0 then Inc(fuel, CharHlp.RollDice(1, 16));
    if fuel > GDVars.partyShip^.systemMax[C_Sys.FUEL] - GDVars.partyShip^.systemNow[C_Sys.FUEL] then
      fuel := GDVars.partyShip^.systemMax[C_Sys.FUEL] - GDVars.partyShip^.systemNow[C_Sys.FUEL];
    if fuel > 0 then begin
      Str(fuel, numStr);
      TextRend.DisplayWindowText(Black, '');
      TextRend.DisplayWindowText(LightGreen, numStr + ' units of fuel plundered from enemy ship!');
      Inc(GDVars.partyShip^.systemNow[C_Sys.FUEL], fuel)
    end
  end;
  if GDVars.enemyShip <> nil then
    GDVars.enemyShip^.systemNow[C_Sys.FUEL] := 0;
  TextRend.DisplayWindowText(Black, '');
  TextRend.DisplayWindowText(LightMagenta, '  All repairs completed.');
  TextRend.PauseContinue
end;

{ Treats poisoning, then wounds, and reports the results; runs only while treatment is pending, and clears the pending
  flag. }
procedure TreatInjuries;
var
  { Unused in this version; see the other implementations of this routine. }
  message: String;
  { Unused in this version; see the other implementations of this routine. }
  patientName: String;
  medic: Types.PCharRecord;
  { the first medic tried on a poisoning; otherwise unused }
  firstMedic: Types.PCharRecord;
  patient: Types.PCharRecord;
  owner: Types.PCharRecord;
  healAmount: Integer;
  skill: Byte;
  pass: Byte;
  difficulty: Byte;
  isDone: Boolean;
  isNothingTreated: Boolean;
  hasNoInjuries: Boolean;
  hasNoMedics: Boolean;
  hasPoisonHeading: Boolean;
  hasWoundHeading: Boolean;
  hasUsedAntidote: Boolean;
  { HasEffect's result; unused }
  effect: Types.PEffectRec;

  { Offers the first antidote any member carries, setting owner to that member, and uses one if the player accepts. }
  function UseAntidote(var owner: Types.PCharRecord): Boolean;
  var
    item: Types.PItemRec;
    isFound: Boolean;
  begin
    owner := GDVars.partyHead;
    while owner <> nil do begin
      item := Types.PItemRec(owner^.itemsAddr);
      isFound := False;
      while (item <> nil) and not isFound do begin
        if item^.template.itemType = PostCbt.ANTIDOTE_TYPE then
          isFound := True
        else
          item := item^.next
      end;
      if isFound then begin
        if MenuCore.YesNoMenu('Use antidote on ' + patient^.name + '? ', C_Menu.DEFAULT_YES) = 'Y' then begin
          if item^.template.quantity <= 1 then
            CharHlp.RemoveItem(owner, item)
          else
            Dec(item^.template.quantity);
          UseAntidote := True
        end else
          UseAntidote := False;
        Exit
      end else
        owner := owner^.nextCharAddr
    end;
    UseAntidote := False
  end;
begin
  if GDVars.treatmentPending <> 0 then begin
    GDVars.treatmentPending := 0;
    isNothingTreated := True;
    hasPoisonHeading := False;
    hasWoundHeading := False;
    hasNoInjuries := True;
    hasNoMedics := True;
    Border.DrawWindowFrame(1);
    TextRend.SetTextWindow(1, 1, 38, 22, Black);

    patient := GDVars.partyHead;
    firstMedic := nil;
    while patient <> nil do begin
      if patient^.status = C_Status.POISONED then begin
        isDone := False;
        medic := GDVars.partyHead;
        hasNoInjuries := False;
        if not hasPoisonHeading then begin
          TextRend.DisplayWindowText(Black, '');
          TextRend.DisplayWindowText(LightMagenta, '  Treating Poisoning');
          TextRend.DisplayWindowText(Black, '');
          TextRend.DisplayWindowText(White, 'Medic            Patient        Result');
          hasPoisonHeading := True
        end;
        while (not isDone) and (medic <> nil) do begin
          if (medic^.career = C_Career.MEDIC) and (medic^.status = C_Status.OKAY) then begin
            hasNoMedics := False;
            if firstMedic = nil then firstMedic := medic;
            TextRend.DisplayString(1, GDVars.windowTextRow, LightGreen, Black, medic^.name);
            TextRend.DisplayString(18, GDVars.windowTextRow, LightGreen, Black, patient^.name);
            if CharHlp.SelectSkillCharacter(C_Skill.TREAT_POISONING, 2, False, Pointer(medic)) >= 2 then begin
              isDone := True;
              TextRend.DisplayString(32, GDVars.windowTextRow, LightGreen, Black, ' cured');
              patient^.status := C_Status.UNCONSCIOUS;
              patient^.enabled := 0;
              patient^.hitPoints := 0;
              isNothingTreated := False
            end;
            TextRend.DisplayWindowText(Black, '')
          end;
          medic := medic^.nextCharAddr
        end;
        if not isDone then begin
          CharHlp.PrintBottomLine(patient^.name + ' is dying of poison!');
          hasUsedAntidote := UseAntidote(owner);
          if hasUsedAntidote then begin
            TextRend.DisplayWindowText(LightGreen, patient^.name + ' is cured');
            patient^.status := C_Status.UNCONSCIOUS;
            patient^.enabled := 0;
            patient^.hitPoints := 0;
            isNothingTreated := False
          end else begin
            TextRend.DisplayWindowText(LightRed, patient^.name + ' slips into a coma.');
            patient^.status := C_Status.COMATOSE;
            patient^.enabled := 0
          end
        end
      end;
      patient := patient^.nextCharAddr
    end;
    TextRend.DisplayWindowText(Black, '');

    patient := GDVars.partyHead;
    while patient <> nil do begin
      if (patient^.status in [C_Status.OKAY, C_Status.DYING, C_Status.UNCONSCIOUS]) and
          (patient^.hostile = C_Side.TEAM) and (patient^.hitPoints < patient^.hpMax) then begin
        isDone := False;
        hasNoInjuries := False
      end else
        isDone := True;
      patientName := patient^.name;
      for pass := 0 to 3 do begin
        medic := GDVars.partyHead;
        while (not isDone) and (medic <> nil) do begin
          if (medic^.status = C_Status.OKAY) and (medic^.hostile <> C_Side.HOSTILE) and
              (medic^.hitPoints > 0) then begin
            case pass of
              0: begin
                   difficulty := 2; skill := C_Skill.FIRST_AID;
                   healAmount := CharHlp.RollDice(1, 6);
                   if patient^.hitPoints + healAmount > 6 then
                     healAmount := 6 - patient^.hitPoints
                 end;
              1: begin
                   if medic = patient then difficulty := 4
                   else difficulty := 2;
                   skill := C_Skill.TREAT_CRITICAL;
                   healAmount := CharHlp.RollDice(3, 8) + 3
                 end;
              2: begin
                   difficulty := 2; skill := C_Skill.TREAT_SERIOUS;
                   healAmount := CharHlp.RollDice(2, 8) + 1
                 end;
              3: begin
                   difficulty := 2; skill := C_Skill.TREAT_LIGHT;
                   healAmount := CharHlp.RollDice(1, 8)
                 end
            end;
            if pass <> 0 then healAmount := healAmount * 2;
            if healAmount > patient^.hpMax - patient^.hitPoints then
              healAmount := patient^.hpMax - patient^.hitPoints;
            if medic^.skillLevels[skill] > 0 then hasNoMedics := False;
            if (healAmount > 0) and
                (CharHlp.SelectSkillCharacter(skill, difficulty, False, Pointer(medic)) >= 2) then begin
              if not hasWoundHeading then begin
                hasWoundHeading := True;
                TextRend.DisplayWindowText(LightMagenta, '  Treating Wounds');
                TextRend.DisplayWindowText(Black, '');
                TextRend.DisplayWindowText(White, 'Medic            Patient        Result');
                TextRend.DisplayWindowText(Black, '')
              end;
              TextRend.DisplayString(1, GDVars.windowTextRow, LightGreen, Black, medic^.name);
              TextRend.DisplayString(18, GDVars.windowTextRow, LightGreen, Black, patient^.name);
              TextRend.DisplayString(34, GDVars.windowTextRow, LightGreen, Black,
                                     ' ' + TextRend.ByteToString(Byte(healAmount)));
              Inc(patient^.hitPoints, healAmount);
              patient^.status := C_Status.OKAY;
              patient^.enabled := 1;
              if pass <> 0 then isDone := True;
              isNothingTreated := False;
              TextRend.DisplayWindowText(Black, '')
            end
          end;
          medic := medic^.nextCharAddr
        end
      end;
      { a hostile holding UNKILLABLE goes out of play; a member holding it with fewer than 45 hit points is put back on
        its feet with 45 }
      if CharHlp.HasEffect(patient, C_Effect.UNKILLABLE, effect) then begin
        if patient^.hostile = C_Side.HOSTILE then
          patient^.combatAddr^.notPcNpc := 1
        else if patient^.hitPoints < 45 then begin
          patient^.status := C_Status.OKAY;
          patient^.enabled := 1;
          patient^.hitPoints := 45
        end
      end;
      patient := patient^.nextCharAddr
    end;
    TextRend.DisplayWindowText(Yellow, '');
    if hasNoInjuries then
      TextRend.DisplayWindowText(LightMagenta, '  No injuries were sustained.')
    else if hasNoMedics then
      TextRend.DisplayWindowText(LightMagenta, '  No medics are available.')
    else if isNothingTreated then
      TextRend.DisplayWindowText(LightMagenta, '  No injuries were successfully treated.')
    else
      TextRend.DisplayWindowText(LightMagenta, '  Healing completed.');
    TextRend.PauseContinue
  end
end;

{ Runs the loot menu: view, take, divvy or pool the treasure, or, while there is an enemy ship, Status: report it
  destroyed and show the party ship's details. Leaving with treasure left asks first. }
procedure LootMenu;
var
  menu: String;
  c: Char;
  isDone: Boolean;
  { always empty }
  menuQuery: String[1];
  choice: Byte;
  { Unused in this version; see the other implementations of this routine. }
  query: Char;
begin
  menuQuery[0] := #0;
  isDone := False;
  CharHlp.DisplayNoncombatInterface;
  repeat
    Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
    query := #0;
    menu := 'View ';
    if (GDVars.poolCredits <> 0) or (GDVars.availableItems <> nil) then
      menu := menu + 'Take ';
    if GDVars.poolCredits <> 0 then menu := menu + 'Divvy ';
    menu := menu + 'Pool ';
    if GDVars.enemyShip <> nil then
      menu := menu + 'Status ';
    menu := menu + 'Exit';
    GDVars.canClickParty := True;
    MenuCore.MenuHorizontal(menuQuery, menu, True, True);
    GDVars.canClickParty := False;
    c := GDVars.menuKey;
    if not GDVars.extFlag then begin
      case c of
        'D': Money.ShareMoney;
        'P': Money.PoolMoney;
        'V': begin
               ViewChar.ViewCharMenu(GDVars.extFlag);
               CharHlp.DisplayNoncombatInterface
             end;
        'T': PostCbt.LootTakeMenu(GDVars.treasureHasMoney, GDVars.treasureHasItems);
        'S': begin
               GDVars.interfaceState := C_Ifc.SHIP;
               CharHlp.DisplayNoncombatInterface;
               TextRend.DisplayString(1, 19, White, Black, 'Enemy ship destroyed.');
               TextRend.PauseContinue;
               CharHlp.DrawShipDetails(GDVars.partyShip, True);
               GDVars.interfaceState := C_Ifc.POST_COMBAT;
               CharHlp.DisplayNoncombatInterface
             end;
        'E', C_Keys.NONE: begin
                   Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
                   if GDVars.treasureHasMoney or GDVars.treasureHasItems then begin
                     menu := '~Yes ~No';
                     TextRend.DisplayMessageWindow(C_Msg.MESSAGE_LEFT, C_Msg.MESSAGE_TOP, C_Msg.MESSAGE_RIGHT,
                                                   C_Msg.MESSAGE_BOTTOM, LightGreen, Black, True,
                                                   'There is still booty left.  ');
                     TextRend.DisplayMessageWindow(C_Msg.MESSAGE_LEFT, C_Msg.MESSAGE_TOP, C_Msg.MESSAGE_RIGHT,
                                                   C_Msg.MESSAGE_BOTTOM, White, Black, False,
                                                   'Do you want to go back and claim it?');
                     choice := EclMenu.MenuHorizontalCharacterSelect(menuQuery, menu, False, False);
                     if choice = 1 then
                       isDone := True
                     else
                       TextRend.ClearRect(C_Msg.MESSAGE_LEFT, C_Msg.MESSAGE_TOP, C_Msg.MESSAGE_RIGHT,
                                          C_Msg.MESSAGE_BOTTOM)
                   end else
                     isDone := True
                 end
      end
    end else begin
      CharHlp.DisplayRoster(GDVars.currentCharacter, False);
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayRoster(GDVars.currentCharacter, True)
    end
  until isDone;
  GDVars.shipRepairPending := 0
end;

{ Removes the creatures out of play (out-of-play flag 1) and, unless zone 0's preserve-hostiles flag is set, the hostile
  ones, counting in zone 1's monstersDefeated those no longer enabled and recording a fled one as RESULT_MONSTER_FLED
  when the result is still RESULT_WON; frees the combat state of the rest and leaves currentCharacter at the list
  head. }
procedure PostCombatCreatureCleanup;
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
begin
  GDVars.zone1^.monstersDefeated := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.combatAddr^.notPcNpc = 1) or
        ((p^.hostile = C_Side.HOSTILE) and (GDVars.zone0^.preserveHostiles = 0)) then begin
      GDVars.hasOutcomeToReport := True;
      if p^.enabled <> 1 then
        Inc(GDVars.zone1^.monstersDefeated);
      if (p^.status = C_Status.FLEEING) and (GDVars.zone1^.combatResult = PostCbt.RESULT_WON) then
        GDVars.zone1^.combatResult := PostCbt.RESULT_MONSTER_FLED;
      next := p^.nextCharAddr;
      GDVars.currentCharacter := p;
      CharGen.RemoveCreature(p^.combatAddr^.notPcNpc = 1, True);
      p := next
    end else begin
      if p^.combatAddr <> nil then begin
        FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
        p^.combatAddr := nil
      end;
      p := p^.nextCharAddr
    end
  end;
  GDVars.currentCharacter := GDVars.partyHead
end;

procedure PostCombat;
var
  cp: Types.PCharRecord;
begin
  GDVars.interfaceState := C_Ifc.POST_COMBAT;
  GDVars.experienceShare := 0;
  GDVars.zone1^.combatResult := PostCbt.RESULT_WON;
  GDVars.hasOutcomeToReport := False;
  if not GDVars.demoMode then
    PostCbt.DetermineCombatResults;
  PostCbt.PostCombatCreatureCleanup;
  if not GDVars.demoMode then begin
    cp := GDVars.partyHead;
    while cp <> nil do begin
      CharHlp.RecalcStats(cp);
      cp := cp^.nextCharAddr;
    end;
    if GDVars.partyDefeated = 0 then begin
      if GDVars.hasPartyFled then PostCbt.ClearTreasure;
      if not GDVars.demoMode and (GDVars.zone0^.postCombatMode <> C_PostCb.BOARDED) then begin
        if (GDVars.zone0^.postCombatMode <> C_PostCb.BOARDED) and (GDVars.zone0^.medicalDone = 0) then
          PostCbt.TreatInjuries;
        GDVars.zone0^.medicalDone := 0;
        if GDVars.zone0^.postCombatMode = PostCbt.POST_COMBAT_REPAIR_SHIP then GDVars.shipRepairPending := 1;
        if GDVars.shipRepairPending <> 0 then PostCbt.RepairShip;
        if GDVars.zone0^.postCombatMode = PostCbt.POST_COMBAT_REPAIR_SHIP then
          GDVars.zone0^.postCombatMode := C_PostCb.NORMAL;
        if GDVars.experienceShare <> 0 then PostCbt.PostCombatSummary(GDVars.experienceShare);
        if (GDVars.availableItems <> nil) or (GDVars.poolCredits <> 0) then
          PostCbt.LootMenu
      end;
      PostCbt.ClearTreasure
    end else begin
      GDVars.zone1^.combatResult := PostCbt.RESULT_TEAM_BEATEN;
      Border.DrawWindowFrame(1);
      GDVars.cursorColumn := 2;
      GDVars.cursorRow := 6;
      TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, Black, True, 'Your team has met an ');
      TextRend.DisplayMessageWindow(2, 7, 37, 22, LightGreen, Black, True, 'unfortunate end.');
      TextRend.PauseContinue
    end;
    GDVars.messageDelay := 1;
    GDVars.zone1^.monsterThac0Modifier := 0;
    GDVars.zone1^.partyThac0Modifier := 0;
    GDVars.zone1^.movementBonus := 0;
    GDVars.zone1^.skipsCombatItems := 0;
    GDVars.zone1^.revivesParty := 0;
    if GDVars.availableItems <> nil then PostCbt.ClearTreasure
  end;
end;

begin
end.
