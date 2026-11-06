{ Ship-to-ship combat. The unit's one interface routine, ShipCombat, runs the whole encounter: it loads the enemy ship,
  then alternates the crew's turns (fire, target a system, reload, jury-rig, take command, aid, boost engines, sensors,
  close, withdraw, ram, board) with the enemy's, and hands the outcome to PostCbt. Every other routine is nested in
  ShipCombat and shares the encounter's state in its locals. }
{$F+,O+,S-,R-,V-,B-,I-}
unit ShipCbt;

interface

{ Runs a ship combat from the ECL's four arguments (the enemy ship, a spare value, and the enemy's pilot skill and
  to-hit number) through to PostCbt.PostCombat. The enemy ship sets the experience the fight is worth (300 .. 12600),
  which PostCbt shares out. The enemy ship's final state is saved in zone 0 for the script; when the enemy recedes off
  the scanners the experience is lost and the saved state is cleared. }
procedure ShipCombat;

implementation

uses Types, C_Pic, C_Ship, C_Status, GDConsts, GDVars, Blit, Music, Crt, CharHlp,
  MenuCore, TextRend, FxEngine, ViewChar, Border, EclMenu, SaveLoad, PostCbt, OrbitMap, C_Skill, C_Sys, C_Ifc, C_PostCb,
  C_Career, C_Keys, C_Menu;

const
  { TShipSlot.kind's bit for a mount the crew fires, not the pilot }
  CREW_MOUNT = $80;
  { the Sensor Operation skill's skillDefinitions row and TCharRecord.skillLevels index }
  SKILL_SENSOR_OPERATION = 10;
  { TShipRec.systemNow's index for life support }
  SYS_LIFE_SUPPORT = 3;
  { the hit target when systemHitChances picks the system }
  ANY_SYSTEM = 7;

  { weapon kinds, GDConsts.shipWeapons' index }
  BEAM_LASER = 1;
  { the last laser: the kinds above it fire ammunition }
  PUMPED_LASER = 2;
  K_CANNON = 6;

  { the range a ship combat opens at; an enemy that gets beyond it is lost }
  SCANNER_RANGE = 8;

  { WeaponStatus's answers }
  WEAPON_READY = 0;
  { the crew asked to fire a mount without CREW_MOUNT }
  PILOT_ONLY_MOUNT = 1;
  { the pilot asked to fire a mount with CREW_MOUNT }
  CREW_ONLY_MOUNT = 2;
  WEAPON_DESTROYED = 3;
  WEAPON_OUT_OF_AMMO = 4;
  { it has fired as many times this round as it has working points }
  WEAPON_FIRED_OUT = 5;
  WEAPON_OUT_OF_RANGE = 6;
  MOUNT_EMPTY = 7;

type
  { The encounter's flags and ECL operands. }
  TEncounterState = record
    { FireWeapon reports each shot; False while the enemy fires, whose hits ReportEnemyDamage sums up per mount }
    isReportingShots: Boolean;
    { the mount firing, or -1 when none can }
    firingSlot: ShortInt;
    { the enemy mount whose hits ReportEnemyDamage reports, or -1 }
    damageSlot: ShortInt;
    damage: Word;
    isReportPending: Boolean;
    { the enemy has jury-rigged something this round }
    hasEnemyJuryRigged: Boolean;
    { a hull destroyed, the enemy boarded, or the enemy lost off the scanners }
    isCombatOver: Boolean;
    { a crew member has taken the controls this round; cleared when the pilot falls }
    isCommandTaken: Boolean;
    { ECL operand 3, the enemy ship's alternateSkill }
    enemyPilotSkill: Byte;
    { ECL operand 4, a to-hit number, lower being better: systemValue is 60 less it }
    enemyToHit: Byte;
    { ECL operand 2; unused }
    secondArgument: Byte;
    { ECL operand 1 less 1, the ship id SaveLoad.LoadShipData loads (0..4 here) }
    enemyShipId: Byte
  end;

procedure ShipCombat;
var
  encounter: TEncounterState;
  { points jury-rigged per system: row 0 the party's ship, row 1 the enemy's }
  systemJuryRigs: array[0..1, 0..5] of Integer;
  { points jury-rigged per weapon mount, rows as systemJuryRigs }
  weaponJuryRigs: array[0..1, 0..7] of Byte;
  { shots per mount this round, rows as systemJuryRigs }
  shotsFired: array[0..1, 0..7] of Byte;
  savedInterfaceState: Byte;
  combatRange: ShortInt;
  { the party won PilotContest, so the enemy moves first each round }
  isEnemyFirst: Boolean;
  { the crew has been hurt once for losing life support }
  hasLifeSupportFailed: Boolean;
  member: Types.PCharRecord;
  { set once the range falls below 4; until then a losing enemy neither retreats nor boosts }
  canEnemyManeuver: Boolean;

  { The window color of ship's messages: LightCyan for the party's ship, Yellow for the enemy's, else LightRed. }
  function ShipTextColor(ship: Types.PShipRec): Byte;
  begin
    if ship = GDVars.partyShip then
      ShipTextColor := LightCyan
    else if ship = GDVars.enemyShip then
      ShipTextColor := Yellow
    else
      ShipTextColor := LightRed
  end;

  { The ship name a message gives: actor's, the party ship's, or for another ship a random form of its name. }
  function FormatShipName(ship: Types.PShipRec; actor: Types.PCharRecord): String;
  begin
    if actor <> nil then
      FormatShipName := actor^.name
    else if ship = GDVars.partyShip then
      FormatShipName := ship^.name
    else
      case CharHlp.RollDice(1, 4) of
        1: FormatShipName := 'Enemy ship';
        2: FormatShipName := GDConsts.raceNames[ship^.race] + ' ' + GDConsts.shipTypeNames[ship^.shipType]
      else
        FormatShipName := ship^.name
      end
  end;

  { A percentile check of source's skill or the ship's own value, plus bonus and scaled; wholeParty is never read. }
  function SkillCheck(selector, scale, wholeParty: Byte; ship: Types.PShipRec; source: Types.PCharRecord;
                      bonus: Byte): Boolean;
  var value: Byte;
  begin
    if source <> nil then
      value := CharHlp.SkillValue(source, selector)
    else
      case selector of
        C_Skill.REPAIR_ENGINE: value := ship^.systemSkill;
        C_Skill.JURY_RIG: value := ship^.systemSkill;
        C_Skill.PILOT_ROCKET: value := ship^.alternateSkill
      else
        value := 0
      end;
    Inc(value, bonus);
    case scale of
      0: value := value * 4;
      1: value := value shl 1;
      3: value := value shr 1;
      4: value := value div 4
    end;
    SkillCheck := CharHlp.PercentileRoll(value)
  end;

  { Takes the party ship's jury-rigged points away as the combat ends, leaving a mount no better destroyed. }
  procedure RemoveJuryRigs;
  var localLoop: ShortInt;
  begin
    with GDVars.partyShip^ do begin
        for localLoop := 0 to SizeOf(systemNow) div SizeOf(Integer) - 1 do
          if systemJuryRigs[0, localLoop] < systemNow[localLoop] then
            Dec(systemNow[localLoop], systemJuryRigs[0, localLoop]);
        for GDVars.loopIndex := 0 to SizeOf(slots) div SizeOf(Types.TShipSlot) - 1 do
          if weaponJuryRigs[0, GDVars.loopIndex] > slots[GDVars.loopIndex].current then
            slots[GDVars.loopIndex].current := 0
          else
            Dec(slots[GDVars.loopIndex].current, weaponJuryRigs[0, GDVars.loopIndex])
      end
  end;

  { @returns(True when 1d10 less 1d10, plus the party ship's reaction less the enemy's, is above 0.) }
  function PilotContest: Boolean;
  var score: ShortInt;
  begin
    score := CharHlp.RollDice(1, 10) - CharHlp.RollDice(1, 10);
    Inc(score, GDVars.partyShip^.reaction);
    Dec(score, GDVars.enemyShip^.reaction);
    if score <= 0 then
      PilotContest := False
    else
      PilotContest := True
  end;

  { WEAPON_READY when ship's mount slot can fire for mode (0 the pilot, else the crew), else why not. }
  function WeaponStatus(ship: Types.PShipRec; mode, slot: Byte): Byte;
  var shipIndex: ShortInt;
  begin
    if ship = GDVars.partyShip then
      shipIndex := 0
    else
      shipIndex := 1;
    with ship^.slots[slot] do
      if (kind and C_Ship.KIND_MASK) = 0 then
        WeaponStatus := ShipCbt.MOUNT_EMPTY
      else if (mode <> 0) and (kind < ShipCbt.CREW_MOUNT) then
        WeaponStatus := ShipCbt.PILOT_ONLY_MOUNT
      else if (mode = 0) and (kind >= ShipCbt.CREW_MOUNT) then
        WeaponStatus := ShipCbt.CREW_ONLY_MOUNT
      else if current = 0 then
        WeaponStatus := ShipCbt.WEAPON_DESTROYED
      else if ((kind and C_Ship.KIND_MASK) > ShipCbt.PUMPED_LASER) and (ammo = 0) then
        WeaponStatus := ShipCbt.WEAPON_OUT_OF_AMMO
      else if shotsFired[shipIndex, slot] >= current then
        WeaponStatus := ShipCbt.WEAPON_FIRED_OUT
      else if GDVars.shipCombatRange > GDConsts.shipWeapons[kind and C_Ship.KIND_MASK].maxRange then
        WeaponStatus := ShipCbt.WEAPON_OUT_OF_RANGE
      else
        WeaponStatus := ShipCbt.WEAPON_READY
  end;

  { @returns(The mount WeaponStatus clears that does the most damage, or -1.) }
  function BestWeapon(ship: Types.PShipRec; mode: Byte): ShortInt;
  var localLoop: ShortInt;
      bestPriority: Byte;
  begin
    BestWeapon := -1;
    bestPriority := 0;
    with ship^ do
      for localLoop := 0 to SizeOf(slots) div SizeOf(Types.TShipSlot) - 1 do
        if (WeaponStatus(ship, mode, localLoop) = ShipCbt.WEAPON_READY) and
            (GDConsts.shipWeapons[slots[localLoop].kind and C_Ship.KIND_MASK].damage > bestPriority) then begin
            BestWeapon := localLoop;
            bestPriority := GDConsts.shipWeapons[slots[localLoop].kind and C_Ship.KIND_MASK].damage
          end
  end;

  { Flashes a hit's five frames at a random point in the view; a negative kind picks one of kinds 1..6. }
  procedure AnimateHit(kind: Byte);
  var
    drawX: Integer;
    drawY: Integer;
    temp: Integer;
      selector: Byte;
      savedPicture: Types.PImgBuf;
      { Unused in this version; see the other implementations of this routine. }
      color: Byte;
  begin
    savedPicture := GDVars.saveUnder;
    GDVars.saveUnder := nil;
    if ShortInt(kind) < 0 then begin
        color := 15;
        kind := CharHlp.RollDice(1, 6)
      end else
      color := 30;
    temp := CharHlp.RollDice(1, 8) - 1;
    drawX := temp + 9;
    drawY := 7 - temp div 2;
    Inc(drawX, CharHlp.RollDice(1, 3) - 2);
    Inc(drawY, CharHlp.RollDice(1, 3) - 2);
    case kind of
      ShipCbt.BEAM_LASER, ShipCbt.PUMPED_LASER: selector := 2;
      ShipCbt.K_CANNON: selector := 1
    else
      selector := 3
    end;
    with GDConsts.shipPictures[selector] do begin
        Dec(drawX, width div 2);
        Dec(drawY, height div 16);
        if drawX < 0 then drawX := 0;
        if drawY < 0 then drawY := 0;
        temp := height div 8 + drawY - 11
      end;
    if temp > 0 then Dec(drawY, temp);
    for GDVars.loopIndex := 4 downto 0 do begin
        with GDConsts.shipPictures[selector + GDVars.loopIndex * 3] do begin
            Blit.AllocPic(height, width, 1, 0, GDVars.saveUnder);
            Blit.BlitTileClipped(x + drawX, y + drawY, 0, 5,
                                 GDVars.shipPictureBuffers[selector + GDVars.loopIndex * 3], GDVars.viewPicture);
            Blit.FlushView;
            Delay(60);
            Blit.BlitTileClipped(x + drawX, y + drawY, 0, 0, GDVars.saveUnder, GDVars.viewPicture)
          end;
        Blit.FreePic(GDVars.saveUnder)
      end;
    Blit.FlushView;
    GDVars.saveUnder := savedPicture
  end;

  { Hurts the crew members who are okay, chance percent of the time or, with isExplosion, all of them. }
  procedure DamageCrew(chance: Byte; isExplosion: Boolean);
  var crewMember: Types.PCharRecord;
      damage: Byte;
      numberText: String[4];
      { Unused in this version; see the other implementations of this routine. }
      index: Byte;
  begin
    crewMember := GDVars.partyHead;
    while crewMember <> nil do begin
        if crewMember^.status = C_Status.OKAY then
          if (CharHlp.PercentileRoll(chance)) or isExplosion then
            if FxEngine.RollSavingThrow(crewMember, 2, 0) and not isExplosion and (chance < 100) then
              TextRend.DisplayWindowText(LightCyan, crewMember^.name + ' leaps clear of an explosion.')
            else begin
                if isExplosion then
                  damage := crewMember^.hpMax + 30
                else
                  damage := CharHlp.RollDice(1, 9) + 1;
                Str(LongInt(damage), numberText);
                CharHlp.InflictDamage(crewMember, damage);
                TextRend.DisplayWindowText(LightCyan,
                                           crewMember^.name + ' takes ' + numberText + ' points of damage!');
                if not isExplosion then
                  case crewMember^.status of
                    C_Status.DEAD_STATUS: TextRend.DisplayWindowText(LightRed, crewMember^.name + ' is dead!!');
                    C_Status.DYING: TextRend.DisplayWindowText(Yellow, crewMember^.name + ' is dying!');
                    C_Status.UNCONSCIOUS: TextRend.DisplayWindowText(Yellow,
                                                                        crewMember^.name + ' is unconscious!')
                  else
                    if crewMember^.hitPoints < 10 then
                      TextRend.DisplayWindowText(Yellow, crewMember^.name + ' is seriously injured.')
                  end;
                if (crewMember = GDVars.activePilot) and (crewMember^.status <> C_Status.OKAY) then begin
                    crewMember^.activeFlag := 0;
                    GDVars.activePilot := nil;
                    encounter.isCommandTaken := False
                  end
              end;
        crewMember := crewMember^.nextCharAddr
      end
  end;

  { Prints the pending report for the enemy mount damageSlot, lets DamageCrew hurt the crew, and clears it. }
  procedure ReportEnemyDamage;
  var message: String;
      numberText: String[5];
  begin
    if encounter.isReportPending then begin
        message := ' fires ' + GDConsts.shipWeapons[GDVars.enemyShip^.slots[encounter.damageSlot].kind and
                                                    C_Ship.KIND_MASK].name + 's and ';
        if encounter.damage > 0 then begin
            Str(LongInt(encounter.damage), numberText);
            message := message + 'hits for ' + numberText + ' points of damage!'
          end else
          message := message + 'misses.';
        TextRend.DisplayWindowText(Yellow, FormatShipName(GDVars.enemyShip, nil) + message);
        DamageCrew(encounter.damage div 5, False);
        encounter.damage := 0;
        encounter.isReportPending := False
      end
  end;

  { Takes value off ship's system systemIndex, or a point off a mount for C_Sys.WEAPONS, and reports losses. }
  procedure DamageShip(ship: Types.PShipRec; systemIndex: ShortInt; value: Word);
  { Unused in this version; see the other implementations of this routine. }
  var systemCount: Byte;
      localLoop: ShortInt;
      { Unused in this version; see the other implementations of this routine. }
      numberText: array[0..3] of Byte;
      total: ShortInt;
      isExploding: Boolean;
  begin
    isExploding := False;
    with ship^ do
      if systemIndex = C_Sys.WEAPONS then begin
          total := 0;
          for localLoop := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do
            Inc(total, ship^.slots[localLoop].current);
          if total <= 0 then Exit;
          total := CharHlp.RollDice(1, total);
          for localLoop := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do begin
              if total > 0 then begin
                  Dec(total, ship^.slots[localLoop].current);
                  if total < 1 then begin
                      if ship = GDVars.partyShip then begin
                          ReportEnemyDamage;
                          CharHlp.DrawShipWeapons(ship, False, localLoop)
                        end;
                      TextRend.DisplayWindowText(ShipTextColor(ship),
                                                 GDConsts.shipWeapons[ship^.slots[localLoop].kind and
                                                                      C_Ship.KIND_MASK].name + ' destroyed on ' +
                                                                       FormatShipName(ship, nil) + '!');
                      Dec(ship^.slots[localLoop].current);
                      if ship = GDVars.partyShip then
                        CharHlp.DrawShipWeapons(ship, False, -1)
                    end
                end
            end
        end else begin
          if systemNow[systemIndex] = 0 then systemIndex := C_Sys.HULL;
          if LongInt(value) > systemNow[systemIndex] then
            value := systemNow[systemIndex];
          if value = 0 then Exit;
          CharHlp.DrawSystemMeter(ship, systemIndex, True);
          Dec(systemNow[systemIndex], value);
          CharHlp.DrawSystemMeter(ship, systemIndex, False);
          if systemNow[systemIndex] = 0 then begin
              if ship = GDVars.partyShip then ReportEnemyDamage;
              TextRend.DisplayWindowText(ShipTextColor(ship), GDConsts.shipSystemNames[systemIndex] + ' destroyed!');
              if systemIndex = C_Sys.HULL then begin
                  encounter.isCombatOver := True;
                  if ship = GDVars.enemyShip then begin
                      GDVars.zone0^.shipCombatOutcome := 0;
                      Music.SendSoundCommand(GDConsts.explosionSound);
                      for localLoop := 1 to 6 do AnimateHit(ShipCbt.K_CANNON)
                    end else begin
                      GDVars.zone0^.shipCombatOutcome := 1;
                      isExploding := True
                    end
                end else if (systemIndex = ShipCbt.SYS_LIFE_SUPPORT) and (ship = GDVars.partyShip) and
                  not hasLifeSupportFailed then begin
                  DamageCrew(100, False);
                  value := 0;
                  hasLifeSupportFailed := True
                end else if (systemIndex = C_Sys.SENSORS) and (ship = GDVars.partyShip) then
                CharHlp.RefreshShipScene
            end
        end;
    if isExploding then DamageCrew(100, True);
    if CharHlp.PercentileRoll(value div 2) and (ship^.crew > 0) then
      Dec(ship^.crew)
  end;

  { @returns(The d20 roll attacker's mount slot needs to hit defender, at most 20.) }
  function TargetValue(attacker, defender: Types.PShipRec; slot: Byte; source: Types.PCharRecord): ShortInt;
  var needed: ShortInt;
  begin
    if source <> nil then begin
        needed := source^.baseCombat + CharHlp.DexMissileAdjust(source);
        if source^.career = C_Career.ROCKET_JOCK then
          Inc(needed, source^.level)
      end else
      needed := attacker^.systemValue;
    if attacker = GDVars.partyShip then
      Inc(needed, 3)
    else begin
      end;
    Inc(needed, GDConsts.shipWeapons[attacker^.slots[slot].kind and C_Ship.KIND_MASK].targetBonus);
    if GDVars.shipCombatRange > 4 then
      Dec(needed, 5)
    else if GDVars.shipCombatRange > 2 then
      Dec(needed, 2);
    if attacker^.systemNow[C_Sys.CONTROL] = 0 then
      Dec(needed, 5);
    if defender^.systemNow[C_Sys.CONTROL] = 0 then
      Inc(needed, 3);
    Inc(needed, defender^.maneuver);
    needed := 60 - defender^.armorClass - needed;
    if needed > 20 then
      needed := 20;
    TargetValue := needed
  end;

  { Applies a hit of weapon kind to ship's system target, or to one systemHitChances picks for ANY_SYSTEM. }
  procedure DispatchWeaponHit(ship: Types.PShipRec; kind, target: Byte);
  var damage: Byte;
      localLoop: ShortInt;
      roll: ShortInt;
  begin
    damage := GDConsts.shipWeapons[kind].damage;
    if ship = GDVars.enemyShip then
      AnimateHit(kind);
    if target = ShipCbt.ANY_SYSTEM then begin
        roll := CharHlp.RollDice(1, 100);
        for localLoop := C_Sys.HULL to C_Sys.WEAPONS do begin
            Dec(roll, GDConsts.systemHitChances[localLoop]);
            if roll <= 0 then begin
                DamageShip(ship, localLoop, damage);
                Exit
              end
          end
      end else
      DamageShip(ship, target, damage)
  end;

  { Fires ship's mount slot at targetShip, printing the shot or adding its damage to the pending report. }
  procedure FireWeapon(ship, targetShip: Types.PShipRec; slot: Byte; source: Types.PCharRecord; target: Byte);
  { Unused in this version; see the other implementations of this routine. }
  var index: Byte;
      { Unused in this version; see the other implementations of this routine. }
      messageCode: Byte;
      isHit: Boolean;
      message: String[50];
      numberText: String[3];
      kind: Byte;
  begin
    kind := ship^.slots[slot].kind and C_Ship.KIND_MASK;
    if encounter.isReportingShots then begin
        if GDVars.windowTextPending <> 0 then
          TextRend.PauseContinue;
        TextRend.ClearTextWindow
      end;
    messageCode := LightCyan;
    encounter.isReportPending := True;
    if ((target = ShipCbt.ANY_SYSTEM) or CharHlp.PercentileRoll(50)) and
        (CharHlp.RollDice(1, 20) >= TargetValue(ship, targetShip, slot, source)) then begin
        isHit := True;
        GDVars.effectDamage := GDConsts.shipWeapons[kind].damage;
        Str(LongInt(GDVars.effectDamage), numberText);
        message := 'hits for ' + numberText + ' points of damage!';
        Inc(encounter.damage, GDVars.effectDamage)
      end else begin
        isHit := False;
        message := 'misses.'
      end;
    if encounter.isReportingShots or (encounter.damageSlot = -1) then
      case kind of
        ShipCbt.BEAM_LASER, ShipCbt.PUMPED_LASER: Music.SendSoundCommand(GDConsts.shipWeaponSounds[2]);
        ShipCbt.K_CANNON: Music.SendSoundCommand(GDConsts.shipWeaponSounds[0])
      else
        Music.SendSoundCommand(GDConsts.shipWeaponSounds[1])
      end;
    if encounter.isReportingShots then begin
        TextRend.DisplayWindowText(ShipTextColor(ship),
                                   FormatShipName(ship,
                                                  source) + ' attacks with a ' + GDConsts.shipWeapons[kind].name +
                                                   ' and ' + message)
      end;
    if isHit then DispatchWeaponHit(targetShip, kind, target);
    if kind > ShipCbt.PUMPED_LASER then Dec(ship^.slots[slot].ammo);
    if ship = GDVars.partyShip then
      Inc(shotsFired[0, slot])
    else
      Inc(shotsFired[1, slot])
  end;

  { Tries a speed boost with a halved Repair Engine check, failure damaging the engines; always True. }
  function AttemptSpeedBoost(ship: Types.PShipRec; source: Types.PCharRecord): Boolean;
  { always 3, so the False branch never runs }
  var boost: ShortInt;
      { Unused in this version; see the other implementations of this routine. }
      messageCode: Byte;
      { Unused in this version; see the other implementations of this routine. }
      roll: Byte;
      message: String;
      damage: Byte;
      increment: Byte;
  begin
    boost := 3;
    increment := 1;
    if boost > 0 then begin
        message := FormatShipName(ship, source) + ' attempts a speed boost and ';
        if SkillCheck(C_Skill.REPAIR_ENGINE, boost, 0, ship, source, 0) then begin
            message := message + 'succeeds!';
            messageCode := White;
            damage := 0
          end else begin
            message := message + 'fails!';
            damage := CharHlp.RollDice(1, 100);
            messageCode := Yellow;
            increment := 0
          end;
        if ship = GDVars.partyShip then
          Inc(GDVars.playerBoosts, increment)
        else
          Inc(GDVars.enemyBoosts, increment);
        TextRend.DisplayWindowText(ShipTextColor(ship), message);
        if damage > 0 then
          DamageShip(ship, C_Sys.ENGINES, damage);
        AttemptSpeedBoost := True
      end else
      AttemptSpeedBoost := False
  end;

  { Jury-rigs a damaged system or mount of ship, for RemoveJuryRigs to undo; False when the player quits. }
  function AttemptJuryRig(ship: Types.PShipRec; source: Types.PCharRecord): Boolean;
  var
    localLoop: ShortInt;
    selected: ShortInt;
      bestScore: Integer;
      score: Integer;
      primary: ShortInt;
      secondary: ShortInt;
      weaponSlot: ShortInt;
      amount: Byte;
      { Unused in this version; see the other implementations of this routine. }
      systemIndex: ShortInt;
      shipIndex: ShortInt;
      choices: String;

    { @returns(True when a mount is below its maximum with fewer jury-rigged points than its maximum.) }
    function CanJuryRig: Boolean;
    begin
      CanJuryRig := False;
      for GDVars.loopIndex := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do
        with ship^.slots[GDVars.loopIndex] do
          if (current < maximum) and (weaponJuryRigs[shipIndex, GDVars.loopIndex] < maximum) then
            CanJuryRig := True
    end;

  begin
    if ship = GDVars.partyShip then
      shipIndex := 0
    else
      shipIndex := 1;
    if source <> nil then begin
        choices := '';
        with ship^ do begin
            if CanJuryRig then
              choices := choices + 'Weap ';
            for localLoop := 0 to SizeOf(systemNow) div SizeOf(Integer) - 1 do
              if (systemNow[localLoop] < systemMax[localLoop]) and (systemJuryRigs[0, localLoop] = 0) and
                  (localLoop <> C_Sys.FUEL) then
                choices := choices + GDConsts.systemShortNames[localLoop] + ' '
          end;
        choices := choices + 'Quit';
        repeat
          MenuCore.MenuHorizontal('', choices, False, False);
          primary := Ord(GDVars.menuKey);
          if primary = Ord('W') then
            begin
              choices := '';
              for GDVars.loopIndex := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do
                with ship^.slots[GDVars.loopIndex] do
                  if (current < maximum) and (weaponJuryRigs[shipIndex, GDVars.loopIndex] < maximum) then
                    choices := choices + GDConsts.weaponShortNames[kind and C_Ship.KIND_MASK] + ' ';
              choices := choices + 'Quit';
              repeat
                MenuCore.MenuHorizontal('', choices, False, False);
                secondary := Ord(GDVars.menuKey);
                if (secondary = Ord('Q')) or (secondary = Ord(C_Keys.NONE)) then
                  primary := secondary
                else
                  primary := Ord('x');
                for GDVars.loopIndex := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do
                  with ship^.slots[GDVars.loopIndex] do
                    if GDConsts.weaponShortNames[kind and C_Ship.KIND_MASK][1] = Char(secondary) then begin
                        primary := Ord('W');
                        weaponSlot := GDVars.loopIndex
                      end
              until Char(primary) in [C_Keys.NONE, 'Q', 'W']
            end
        { Note: meant as Escape, which MenuHorizontal answers as NONE }
        until Char(primary) in [C_Keys.NONE, C_Keys.RIGHT_BRACKET, 'C', 'E', 'F', 'H', 'L', 'Q', 'S', 'W'];
        TextRend.ClearStatusLine;
        case Char(primary) of
          'H': selected := C_Sys.HULL;
          'S': selected := C_Sys.SENSORS;
          'C': selected := C_Sys.CONTROL;
          'L': selected := ShipCbt.SYS_LIFE_SUPPORT;
          'F': selected := C_Sys.FUEL;
          'E': selected := C_Sys.ENGINES;
          'W': selected := C_Sys.WEAPONS
        else begin
            AttemptJuryRig := False;
            Exit
          end
        end
      end else begin
        selected := ShipCbt.ANY_SYSTEM;
        bestScore := 0;
        if CanJuryRig then begin
            weaponSlot := -1;
            for GDVars.loopIndex := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do
              with ship^.slots[GDVars.loopIndex] do
                { Note: localLoop is uninitialized here }
                if (current < maximum) and
                   (localLoop <> C_Sys.FUEL) and
                   (GDConsts.shipWeapons
                    [kind and C_Ship.KIND_MASK].damage > bestScore) then begin
                    weaponSlot := GDVars.loopIndex;
                    bestScore := GDConsts.shipWeapons
                      [kind and C_Ship.KIND_MASK].damage
                  end;
            if weaponSlot >= 0 then
              selected := C_Sys.WEAPONS
          end;
        if selected = ShipCbt.ANY_SYSTEM then begin
            for localLoop := 0 to SizeOf(ship^.systemNow) div SizeOf(Integer) - 1 do
              if (ship^.systemNow[localLoop] <> ship^.systemMax[localLoop]) and
                  (systemJuryRigs[1, localLoop] = 0) then begin
                  score := 10 * ship^.systemNow[localLoop] div ship^.systemMax[localLoop];
                  score := 10 - score;
                  if ship^.systemNow[localLoop] = 0 then
                    Inc(score, 5);
                  if systemJuryRigs[1, localLoop] = 0 then
                    score := score * 2;
                  if score > bestScore then begin
                      bestScore := score;
                      selected := localLoop
                    end
                end;
            if selected = ShipCbt.ANY_SYSTEM then
              Exit
          end
      end;
    if selected = C_Sys.WEAPONS then
      choices := GDConsts.shipWeapons[ship^.slots[weaponSlot].kind and C_Ship.KIND_MASK].name
    else
      choices := GDConsts.shipSystemNames[selected];
    if SkillCheck(C_Skill.JURY_RIG, 2, 0, ship, source, 0) then begin
        if ship = GDVars.partyShip then
          TextRend.DisplayWindowText(ShipTextColor(ship),
                                     FormatShipName(ship,
                                                    source) + ' attempts to jury-rig ' + choices + ' and succeeds!')
        else
          encounter.hasEnemyJuryRigged := True;
        if selected = C_Sys.WEAPONS then begin
            Inc(weaponJuryRigs[shipIndex, weaponSlot]);
            Inc(ship^.slots[weaponSlot].current);
            if ship = GDVars.partyShip then
              CharHlp.DrawShipWeapons(ship, False, -1)
          end else begin
            amount := CharHlp.RollDice(2, 10);
            if ship^.systemNow[selected] + amount > ship^.systemMax[selected] then
              amount := ship^.systemMax[selected] - ship^.systemNow[selected];
            Inc(ship^.systemNow[selected], amount);
            Inc(systemJuryRigs[shipIndex, selected], amount);
            CharHlp.DrawSystemMeter(ship, selected, False);
            if (selected = C_Sys.SENSORS) and (ship = GDVars.partyShip) and
                (ship^.systemNow[selected] = amount) then
              CharHlp.DisplayNoncombatInterface
          end
      end else if shipIndex = 0 then
      TextRend.DisplayWindowText(ShipTextColor(ship),
                                 FormatShipName(ship, source) + ' attempts to jury-rig ' + choices + ' and fails.');
    AttemptJuryRig := True
  end;

  { rammer tries to ram rammed, which may dodge; otherwise each hull takes the other's tonnage. }
  procedure RamAttempt(rammer, rammed: Types.PShipRec; actor: Types.PCharRecord);
  var source: Types.PCharRecord;
      name: String;

    { True when a moving rammed ship tries to dodge and makes its Pilot Rocket check. }
    function DodgesRam: Boolean;
    begin
      DodgesRam := False;
      if CharHlp.ShipSpeed(rammed) > 0 then begin
          if ((rammed = GDVars.enemyShip) and
              (rammed^.systemNow[C_Sys.HULL] < rammer^.systemNow[C_Sys.HULL])) or
              ((rammed = GDVars.partyShip) and
               (MenuCore.YesNoMenu('Try to dodge enemy ship? ', C_Menu.DEFAULT_YES) = 'Y')) then
            if SkillCheck(C_Skill.PILOT_ROCKET, 2, 0, rammed, source,
                          (CharHlp.ShipSpeed(rammed) - CharHlp.ShipSpeed(rammer)) * 10) then
              DodgesRam := True
        end
    end;

  begin
    if rammed = GDVars.partyShip then
      source := GDVars.activePilot
    else
      source := nil;
    TextRend.DisplayWindowText(ShipTextColor(rammer), FormatShipName(rammer, actor) + ' attempts to ram!');
    if DodgesRam then begin
        if source <> nil then
          name := 'Your ship'
        else
          name := FormatShipName(rammed, nil);
        TextRend.DisplayWindowText(ShipTextColor(rammed), name + ' dodges out of the way!')
      end else begin
        TextRend.DisplayWindowText(ShipTextColor(rammer), 'Ramming successful!');
        DamageShip(rammer, C_Sys.HULL, rammed^.tonnage);
        DamageShip(rammed, C_Sys.HULL, rammer^.tonnage)
      end
  end;

  { Moves ship in by its speed; for the enemy it clears enemyRetreating. }
  procedure CloseShip(ship: Types.PShipRec);
  begin
    TextRend.DisplayWindowText(ShipTextColor(ship), FormatShipName(ship, nil) + ' is closing.');
    Dec(combatRange, CharHlp.ShipSpeed(ship));
    if ship = GDVars.enemyShip then
      GDVars.enemyRetreating := False;
    CharHlp.DrawShipSceneText
  end;

  { Moves ship out by amount; for the enemy it sets enemyRetreating. }
  procedure RetreatShip(ship: Types.PShipRec; amount: Byte);
  begin
    TextRend.DisplayWindowText(ShipTextColor(ship), FormatShipName(ship, nil) + ' is retreating.');
    Inc(combatRange, amount);
    if ship = GDVars.enemyShip then
      GDVars.enemyRetreating := True;
    CharHlp.DrawShipSceneText
  end;

  { @returns(True when mount slot fires ammunition (past PUMPED_LASER), is empty and has reloads left.) }
  function CanReload(ship: Types.PShipRec; slot: Byte): Boolean;
  begin
    with ship^.slots[slot] do
      if ((kind and C_Ship.KIND_MASK) > ShipCbt.PUMPED_LASER) and (reloads > 0) and (ammo = 0) then
        CanReload := True
      else
        CanReload := False
  end;

  { @returns(True when any of ship's mounts CanReload.) }
  function HasReloadableWeapon(ship: Types.PShipRec): Boolean;
  begin
    HasReloadableWeapon := False;
    for GDVars.loopIndex := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do
      if CanReload(ship, GDVars.loopIndex) then
        HasReloadableWeapon := True
  end;

  { The crew picks the mount to reload from a menu; the enemy (no source) reloads the last one it can. }
  function ReloadWeapon(ship: Types.PShipRec; source: Types.PCharRecord): Boolean;
  var localLoop: Byte;
      selected: ShortInt;
      choices: String;
      choice: Char;
  begin
    selected := -1;
    if ship = GDVars.partyShip then begin
        TextRend.DisplayWindowText(LightMagenta, 'Select weapon to reload:');
        choices := '';
        for localLoop := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do
          if CanReload(ship, localLoop) then
            choices := choices + GDConsts.weaponShortNames[ship^.slots[localLoop].kind and C_Ship.KIND_MASK] + ' ';
        choices := choices + 'Quit';
        repeat
          MenuCore.MenuHorizontal('', choices, True, False);
          choice := GDVars.menuKey;
          if choice <> C_Keys.NONE then
            for localLoop := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do begin
                with ship^.slots[localLoop] do
                  if GDConsts.weaponShortNames[kind and C_Ship.KIND_MASK][1] = choice then begin
                      selected := localLoop;
                      choice := 'Q'
                    end
              end
        { Note: meant as Escape, which MenuHorizontal answers as NONE }
        until choice in [C_Keys.NONE, C_Keys.RIGHT_BRACKET, 'Q']
      end else
      for localLoop := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do
        if CanReload(ship, localLoop) then selected := localLoop;
    if selected >= 0 then begin
        with ship^.slots[selected] do begin
            Dec(reloads);
            Inc(ammo, GDConsts.shipWeapons[kind and C_Ship.KIND_MASK].reloadAmmo);
            TextRend.DisplayWindowText(ShipTextColor(ship),
              FormatShipName(ship, source) + ' reloads a ' +
              GDConsts.shipWeapons[kind and C_Ship.KIND_MASK].name + '.')
          end;
        ReloadWeapon := True
      end else
      ReloadWeapon := False
  end;

  { True when ship has a system or mount to jury-rig; for the party's ship only when source can Jury Rig. }
  function ShipNeedsRepair(ship: Types.PShipRec; source: Types.PCharRecord): Boolean;
  var
    localLoop: ShortInt;
    shipIndex: ShortInt;
  begin
    if ship = GDVars.partyShip then
      shipIndex := 0
    else
      shipIndex := 1;
    ShipNeedsRepair := False;
    if (shipIndex = 1) or (CharHlp.SkillValue(source, C_Skill.JURY_RIG) > 0) then
      with ship^ do begin
          for localLoop := 0 to SizeOf(systemNow) div SizeOf(Integer) - 1 do
            if (systemNow[localLoop] < systemMax[localLoop]) and (systemJuryRigs[shipIndex, localLoop] = 0) and
                (localLoop <> C_Sys.FUEL) then
              ShipNeedsRepair := True;
          for GDVars.loopIndex := 0 to SizeOf(slots) div SizeOf(Types.TShipSlot) - 1 do
            if (slots[GDVars.loopIndex].current < slots[GDVars.loopIndex].maximum) and
                (weaponJuryRigs[shipIndex, GDVars.loopIndex] < slots[GDVars.loopIndex].maximum) then
              ShipNeedsRepair := True
        end
  end;

  { ship's fighting strength for the enemy's strategy: hull, mobility and weapons' damage; 0 unarmed. }
  function ShipCombatValue(ship: Types.PShipRec): Integer;
  { Unused in this version; see the other implementations of this routine. }
  var index: Byte;
      base: Integer;
      total: Integer;
  begin
    base := 0;
    Inc(base, ship^.systemNow[C_Sys.HULL]);
    if CharHlp.CanShipMove(ship) then
      Inc(base,
          (ship^.systemNow[C_Sys.CONTROL] + ship^.systemNow[C_Sys.FUEL] +
           ship^.systemNow[C_Sys.ENGINES]) div 3);
    total := 0;
    for GDVars.loopIndex := 0 to SizeOf(ship^.slots) div SizeOf(Types.TShipSlot) - 1 do
      with ship^.slots[GDVars.loopIndex] do
        if kind <> 0 then
          Inc(total, GDConsts.shipWeapons[kind and C_Ship.KIND_MASK].damage * current);
    if total = 0 then
      ShipCombatValue := 0
    else
      ShipCombatValue := base + total
  end;

  { The enemy's turn: picks a strategy by ShipCombatValue, then moves, fires, reloads and repairs. }
  procedure EnemyTurnBody;
  var
    strategy: ShortInt;
    firePasses: ShortInt;
    repairPasses: ShortInt;
      isBoostPending: Boolean;
      { Unused in this version; see the other implementations of this routine. }
      actionResult: Boolean;
      activeValue: Integer;
      enemyValue: Integer;
      { Unused in this version; see the other implementations of this routine. }
      numberText: array[0..6] of Byte;

    { True when the enemy should fire rather than ram, weighing its weapons against the party pilot. }
    function EnemyFireWorthwhile: Boolean;
    var
      chosen: Integer;
      score: Integer;

      { @returns(The ready enemy pilot mounts' working points times damage, summed.) }
      function EnemyWeaponPower: ShortInt;
      var total: Byte;
          localLoop: ShortInt;
      begin
        total := 0;
        for localLoop := 0 to SizeOf(GDVars.enemyShip^.slots) div SizeOf(Types.TShipSlot) - 1 do
          if WeaponStatus(GDVars.enemyShip, 0, localLoop) = ShipCbt.WEAPON_READY then
            Inc(total,
              GDVars.enemyShip^.slots[localLoop].current *
              GDConsts.shipWeapons[
                GDVars.enemyShip^.slots[localLoop].kind and
                C_Ship.KIND_MASK].damage);
        EnemyWeaponPower := total
      end;

    begin
      chosen := BestWeapon(GDVars.enemyShip, 0);
      if chosen < 0 then
        EnemyFireWorthwhile := False
      else begin
          score := CharHlp.SkillValue(GDVars.activePilot, C_Skill.PILOT_ROCKET) +
                 (CharHlp.ShipSpeed(GDVars.partyShip) -
                  CharHlp.ShipSpeed(GDVars.enemyShip)) * 10;
          if score < 90 then begin
              if LongInt(100 - score) *
                   LongInt(GDVars.enemyShip^.tonnage div 10) <
                 ((21 - TargetValue(GDVars.enemyShip, GDVars.partyShip,
                                  chosen, nil)) * 5) *
                   (EnemyWeaponPower div 10) then
                EnemyFireWorthwhile := True
              else
                EnemyFireWorthwhile := False
            end else
            EnemyFireWorthwhile := True
        end
    end;

  begin
    if not encounter.isCombatOver then begin
        activeValue := ShipCombatValue(GDVars.partyShip);
        enemyValue := ShipCombatValue(GDVars.enemyShip);
        if enemyValue * 2 < activeValue then
          strategy := 0
        else if enemyValue > activeValue then
          strategy := 2
        else
          strategy := 1;
        isBoostPending := False;
        if CharHlp.CanShipMove(GDVars.enemyShip) then begin
            if (GDVars.shipCombatRange <= 1) and (not EnemyFireWorthwhile) and
                (GDVars.enemyShip^.systemNow[C_Sys.HULL] > GDVars.partyShip^.systemNow[C_Sys.HULL]) and
                (LongInt(GDVars.enemyShip^.systemNow[C_Sys.HULL]) > GDVars.partyShip^.tonnage) then
              RamAttempt(GDVars.enemyShip, GDVars.partyShip, nil)
            else if (strategy = 0) and canEnemyManeuver then
              RetreatShip(GDVars.enemyShip, CharHlp.ShipSpeed(GDVars.enemyShip))
            else if (strategy = 1) and (GDVars.shipCombatRange <= 2) then begin
                if CharHlp.ShipSpeed(GDVars.enemyShip) > 3 then
                  RetreatShip(GDVars.enemyShip, 3)
                else
                  RetreatShip(GDVars.enemyShip, CharHlp.ShipSpeed(GDVars.enemyShip))
              end else if (strategy = 2) or (GDVars.shipCombatRange >= 5) then
              CloseShip(GDVars.enemyShip);
            if (strategy = 0) and (CharHlp.ShipSpeed(GDVars.enemyShip) < CharHlp.ShipSpeed(GDVars.partyShip)) and
                (CharHlp.PercentileRoll(GDVars.enemyShip^.systemSkill)) and canEnemyManeuver then
              isBoostPending := True
          end;

        encounter.damageSlot := -1;
        encounter.damage := 0;
        encounter.isReportingShots := False;
        encounter.isReportPending := False;
        repeat
          encounter.firingSlot := BestWeapon(GDVars.enemyShip, 0);
          if (encounter.damageSlot >= 0) and (encounter.damageSlot <> encounter.firingSlot) then
            ReportEnemyDamage;
          if encounter.firingSlot >= 0 then
            FireWeapon(GDVars.enemyShip, GDVars.partyShip, encounter.firingSlot, nil, ShipCbt.ANY_SYSTEM);
          encounter.damageSlot := encounter.firingSlot
        until (encounter.firingSlot < 0) or encounter.isCombatOver;

        repairPasses := (GDVars.enemyShip^.crew + 9) div 10;
        firePasses := GDVars.enemyShip^.crew - repairPasses;
        while (firePasses > 0) and not encounter.isCombatOver do begin
            Dec(firePasses);
            if HasReloadableWeapon(GDVars.enemyShip) then
              actionResult := ReloadWeapon(GDVars.enemyShip, nil)
            else begin
                encounter.firingSlot := BestWeapon(GDVars.enemyShip, 1);
                if (encounter.damageSlot >= 0) and (encounter.damageSlot <> encounter.firingSlot) then
                  ReportEnemyDamage;
                if encounter.firingSlot >= 0 then
                  FireWeapon(GDVars.enemyShip, GDVars.partyShip, encounter.firingSlot, nil, ShipCbt.ANY_SYSTEM)
                else begin
                    Inc(repairPasses, firePasses);
                    firePasses := 0
                  end;
                encounter.damageSlot := encounter.firingSlot
              end
          end;
        encounter.isReportingShots := True;
        if encounter.damageSlot >= 0 then
          ReportEnemyDamage;
        while (repairPasses > 0) and not encounter.isCombatOver do begin
            Dec(repairPasses);
            if isBoostPending then begin
                actionResult := AttemptSpeedBoost(GDVars.enemyShip, nil);
                isBoostPending := False
              end else if not AttemptJuryRig(GDVars.enemyShip, nil) then
              repairPasses := 0
          end;
        if encounter.hasEnemyJuryRigged then
          TextRend.DisplayWindowText(Yellow, 'The enemy jury-rigs some systems.');
        encounter.hasEnemyJuryRigged := False
      end
  end;

  { The crew's turn: each member who is okay picks from BuildPlayerMenu's menu until an action is taken. }
  procedure PlayerTurnBody;
  var menuPilot: Types.PCharRecord;
      menuChoices: String;
      isActionTaken: Boolean;
      canManeuver: Boolean;
      choice: Char;
      { Unused in this version; see the other implementations of this routine. }
      key: Byte;
      outcome: String[10];
      targetSystem: ShortInt;
      localLoop: ShortInt;

    { Clears or keeps the text window, prompts for menuPilot and builds its menuChoices; menuMode is never read. }
    procedure BuildPlayerMenu(menuMode: Byte);
    begin
      if (GDVars.windowTextPending = 0) or (GDVars.windowTextRow > 21) or
          (menuPilot = GDVars.activePilot) then begin
          if GDVars.windowTextPending <> 0 then
            TextRend.PauseContinue;
          TextRend.ClearTextWindow
        end;
      if menuPilot = GDVars.activePilot then begin
          TextRend.DisplayWindowText(LightMagenta, menuPilot^.name + ' is your pilot.');
          TextRend.DisplayWindowText(Black, '')
        end;
      while GDVars.windowTextRow < 21 do
        TextRend.DisplayWindowText(Black, '');
      TextRend.DisplayWindowText(LightMagenta, 'what does ' + menuPilot^.name + ' want to do?');
      GDVars.windowTextPending := 0;
      menuChoices := '';
      if BestWeapon(GDVars.partyShip, Ord(menuPilot <> GDVars.activePilot)) >= 0 then
        menuChoices := menuChoices + 'Fire Target ';
      if menuPilot <> GDVars.activePilot then begin
          if HasReloadableWeapon(GDVars.partyShip) then
            menuChoices := menuChoices + 'Load ';
          if ShipNeedsRepair(GDVars.partyShip, menuPilot) then
            menuChoices := menuChoices + 'Juryrig '
        end;
      menuChoices := menuChoices + 'Quit View@';
      if menuPilot = GDVars.activePilot then begin
          if canManeuver then begin
              if GDVars.shipCombatRange > 1 then
                menuChoices := menuChoices + 'Close ';
              menuChoices := menuChoices + 'Withdraw ';
              if GDVars.shipCombatRange <= 1 then begin
                  menuChoices := menuChoices + 'Ram ';
                  if not Boolean(CharHlp.ShipSpeed(GDVars.enemyShip)) then
                    menuChoices := menuChoices + 'Board '
                end
            end
        end else begin
          if not encounter.isCommandTaken then
            menuChoices := menuChoices + 'Command ';
          if ViewChar.FindPatients(menuPilot) then
            menuChoices := menuChoices + 'Aid ';
          if (CharHlp.SkillValue(menuPilot, C_Skill.REPAIR_ENGINE) > 0) and
              (GDVars.partyShip^.systemNow[C_Sys.ENGINES] > 0) and (GDVars.playerBoosts < 2) then
            menuChoices := menuChoices + 'Boost engines ';
          if (GDVars.partyShip^.systemNow[C_Sys.SENSORS] > 0) and
              (menuPilot^.skillLevels[ShipCbt.SKILL_SENSOR_OPERATION] > 0) then
            menuChoices := menuChoices + 'Sensors '
        end
    end;

  begin
    canManeuver := CharHlp.CanShipMove(GDVars.partyShip);
    menuPilot := GDVars.partyHead;
    encounter.isCommandTaken := False;
    while (menuPilot <> nil) and not encounter.isCombatOver do begin
        if menuPilot^.status = C_Status.OKAY then begin
            isActionTaken := False;
            repeat
              Border.ClearBox(0, 23, 39, 24);
              BuildPlayerMenu(0);
              MenuCore.MenuHorizontal('', menuChoices, True, False);
              choice := GDVars.menuKey;
              Border.ClearBox(0, 23, 39, 24);
              case choice of
              'A':
                begin
                  ViewChar.TreatPatients(menuPilot);
                  isActionTaken := True
                end;
              'B':
                begin
                  if menuPilot = GDVars.activePilot then begin
                      GDVars.zone0^.postCombatMode := C_PostCb.BOARDED;
                      GDVars.zone0^.shipCombatOutcome := 0;
                      encounter.isCombatOver := True;
                      isActionTaken := True;
                      TextRend.DisplayWindowText(LightCyan,
                                                 'You close with the injured vessel and attempt to board!')
                    end else
                    isActionTaken := AttemptSpeedBoost(GDVars.partyShip, menuPilot)
                end;
              'C':
                begin
                  if menuPilot = GDVars.activePilot then begin
                      CloseShip(GDVars.partyShip);
                      canManeuver := False
                    end else begin
                      TextRend.DisplayWindowText(LightCyan, menuPilot^.name + ' takes over as pilot.');
                      GDVars.activePilot := menuPilot;
                      menuPilot^.activeFlag := 1;
                      encounter.isCommandTaken := True
                    end
                end;
              'F', 'T':
                begin
                  targetSystem := ShipCbt.ANY_SYSTEM;
                  if choice = 'T' then
                    begin
                      menuChoices := '';
                      for localLoop := C_Sys.HULL to C_Sys.WEAPONS do
                        menuChoices := menuChoices + GDConsts.systemShortNames[localLoop] + ' ';
                      TextRend.DisplayWindowText(LightMagenta, 'Target which system?');
                      MenuCore.MenuHorizontal('', menuChoices, False, False);
                      choice := GDVars.menuKey;
                      for localLoop := C_Sys.HULL to C_Sys.WEAPONS do
                        if GDConsts.systemShortNames[localLoop][1] = choice then
                          targetSystem := localLoop
                    end;
                  { Note: meant as Escape, which MenuHorizontal answers as NONE }
                  if choice <> C_Keys.RIGHT_BRACKET then begin
                      TextRend.ClearTextWindow;
                      repeat
                        encounter.firingSlot := BestWeapon(GDVars.partyShip, Ord(menuPilot <> GDVars.activePilot));
                        if encounter.firingSlot >= 0 then
                          FireWeapon(GDVars.partyShip, GDVars.enemyShip, encounter.firingSlot, menuPilot,
                                     targetSystem)
                      until (encounter.firingSlot < 0) or encounter.isCombatOver or (menuPilot <> GDVars.activePilot);
                      isActionTaken := True
                    end
                end;
              'J':
                isActionTaken := AttemptJuryRig(GDVars.partyShip, menuPilot);
              'L':
                isActionTaken := ReloadWeapon(GDVars.partyShip, menuPilot);
              'Q':
                begin
                  if not GDVars.extFlag then isActionTaken := True
                end;
              'R':
                begin
                  if MenuCore.YesNoMenu('Ram ' + FormatShipName(GDVars.enemyShip, nil) + '? ', C_Menu.DEFAULT_NO)
                     = 'Y' then
                    begin
                      RamAttempt(GDVars.partyShip, GDVars.enemyShip, GDVars.activePilot);
                      isActionTaken := True
                    end
                end;
              'S':
                begin
                  isActionTaken := CharHlp.SelectSkillCharacter(ShipCbt.SKILL_SENSOR_OPERATION, 1, False,
                                                                Pointer(menuPilot)) >= 2;
                  if isActionTaken then
                    outcome := 'succeeds'
                  else
                    outcome := 'fails';
                  TextRend.DisplayWindowText(LightCyan, menuPilot^.name + ' ' + outcome + ' at sensor operation!');
                  CharHlp.DrawShipDetails(GDVars.enemyShip, isActionTaken);
                  TextRend.PauseContinue;
                  CharHlp.DisplayNoncombatInterface;
                  isActionTaken := True
                end;
              'V':
                begin
                  repeat
                    MenuCore.MenuHorizontal('', 'Ship Character', False, False);
                    choice := GDVars.menuKey;
                    case choice of
                    'C':
                      begin
                        GDVars.currentCharacter := menuPilot;
                        ViewChar.ViewCharMenu(isActionTaken);
                        CharHlp.DisplayNoncombatInterface;
                        isActionTaken := False
                      end;
                    'S':
                      begin
                        CharHlp.DrawShipDetails(GDVars.partyShip, True);
                        TextRend.PauseContinue;
                        CharHlp.DisplayNoncombatInterface
                      end
                    end;
                  { Note: meant as Escape, which MenuHorizontal answers as NONE }
                  until choice in [C_Keys.NONE, C_Keys.RIGHT_BRACKET, 'C', 'S']
                end;
              'W':
                begin
                  RetreatShip(GDVars.partyShip, CharHlp.ShipSpeed(GDVars.partyShip));
                  canManeuver := False
                end
              end;
            until isActionTaken
          end;
        menuPilot := menuPilot^.nextCharAddr
      end
  end;

begin
  EclMenu.LoadEclVars(4);
  encounter.enemyShipId := EclMenu.GetEclVar(1) - 1;
  encounter.secondArgument := EclMenu.GetEclVar(2);
  encounter.enemyPilotSkill := EclMenu.GetEclVar(3);
  encounter.enemyToHit := EclMenu.GetEclVar(4);
  case encounter.enemyShipId of
    0: GDVars.shipCombatExperience := 300;
    1: GDVars.shipCombatExperience := 3000;
    2: GDVars.shipCombatExperience := 12600;
    3: GDVars.shipCombatExperience := 2500;
    4: GDVars.shipCombatExperience := 4600
  end;
  GDVars.zone0^.postCombatMode := C_PostCb.NORMAL;
  canEnemyManeuver := False;
  encounter.hasEnemyJuryRigged := False;
  encounter.isReportingShots := True;
  savedInterfaceState := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.SHIP;
  OrbitMap.LoadShipPictures;
  GDVars.activePilot := nil;
  member := GDVars.partyHead;
  while member <> nil do begin
      if member^.activeFlag <> 0 then
        if GDVars.activePilot <> nil then
          member^.activeFlag := 0
        else if member^.enabled <> 0 then
          GDVars.activePilot := member;
      member := member^.nextCharAddr
    end;
  GDVars.enemyRetreating := False;
  GetMem(GDVars.enemyShip, SizeOf(Types.TShipRec));
  SaveLoad.LoadShipData(GDVars.enemyShip, ShortInt(encounter.enemyShipId));
  Blit.SetDacPalette(C_Pic.PICTURE_DAC_FIRST, C_Pic.PICTURE_DAC_COUNT, GDVars.picturePalette);
  GDVars.enemyShip^.alternateSkill := encounter.enemyPilotSkill;
  GDVars.enemyShip^.systemValue := 60 - encounter.enemyToHit;
  GDVars.playerBoosts := 0;
  GDVars.enemyBoosts := 0;
  FillChar(systemJuryRigs, SizeOf(systemJuryRigs), 0);
  FillChar(weaponJuryRigs, SizeOf(weaponJuryRigs), 0);
  member := GDVars.partyHead;
  while member <> nil do begin
      GetMem(member^.combatAddr, SizeOf(Types.TCombatRec));
      FillChar(member^.combatAddr^, SizeOf(Types.TCombatRec), 0);
      member := member^.nextCharAddr
    end;
  encounter.isCombatOver := False;
  hasLifeSupportFailed := False;
  GDVars.shipCombatRange := ShipCbt.SCANNER_RANGE;
  combatRange := ShipCbt.SCANNER_RANGE;
  CharHlp.DisplayNoncombatInterface;
  TextRend.SetTextWindow(1, 19, 38, 21, 0);
  isEnemyFirst := PilotContest;
  repeat
    FillChar(shotsFired, SizeOf(shotsFired), 0);
    FillChar(shotsFired, SizeOf(shotsFired), 0);
    if isEnemyFirst = False then PlayerTurnBody;
    EnemyTurnBody;
    if isEnemyFirst = True then PlayerTurnBody;
    if not encounter.isCombatOver then begin
        if combatRange < 0 then
          combatRange := 0
        else if combatRange < 4 then
          canEnemyManeuver := True
        else if combatRange > ShipCbt.SCANNER_RANGE then begin
            TextRend.DisplayWindowText(Yellow, 'The enemy ship recedes off your scanners.');
            encounter.isCombatOver := True;
            GDVars.shipCombatExperience := 0;
            GDVars.zone0^.shipCombatOutcome := 1;
            TextRend.PauseContinue
          end
      end;
    CharHlp.ProcessDyingCharacters;
    GDVars.shipCombatRange := combatRange;
    CharHlp.DrawShipSceneText
  until encounter.isCombatOver;
  RemoveJuryRigs;
  GDVars.zone0^.medicalDone := 0;
  if GDVars.zone0^.postCombatMode = C_PostCb.NORMAL then begin
      GDVars.shipRepairPending := 1;
      GDVars.treatmentPending := 1
    end;
  if GDVars.shipCombatExperience = 0 then begin
      FillChar(GDVars.zone0^.savedStores, SizeOf(GDVars.zone0^.savedStores), 0);
      { savedWeapons through postCombatFlag }
      FillChar(GDVars.zone0^.savedWeapons, 6, 0)
    end else begin
      Move(GDVars.enemyShip^.systemNow, GDVars.zone0^.savedStores, SizeOf(GDVars.zone0^.savedStores));
      GDVars.zone0^.savedShipType := GDVars.enemyShip^.shipType;
      GDVars.zone0^.savedCrewHi := Hi(GDVars.enemyShip^.crew);
      GDVars.zone0^.savedCrewLo := Lo(GDVars.enemyShip^.crew);
      GDVars.zone0^.savedSystem := GDVars.enemyShip^.systemValue;
      GDVars.zone0^.weaponTotal := 0;
      for GDVars.loopIndex := 0 to SizeOf(GDVars.enemyShip^.slots) div SizeOf(Types.TShipSlot) - 1 do
        Inc(GDVars.zone0^.weaponTotal, GDVars.enemyShip^.slots[GDVars.loopIndex].current);
      GDVars.zone0^.postCombatFlag := 0
    end;
  Blit.FreePic(GDVars.bigPicture);
  OrbitMap.FreeShipPictures;
  PostCbt.PostCombat;
  FreeMem(GDVars.enemyShip, SizeOf(Types.TShipRec));
  GDVars.enemyShip := nil;
  GDVars.interfaceState := savedInterfaceState;
  CharHlp.DisplayNoncombatInterface
end;

begin
end.
