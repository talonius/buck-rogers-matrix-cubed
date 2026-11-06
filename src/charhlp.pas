{ Character and combat helpers. Dice and percentile rolls; a character's stats, attack and movement rebuilt from its
  items, abilities and status; item names and item-list edits; the combat text lines, the party rows and the non-combat,
  combat and ship screens; team, target and distance counts; effect lookup, damage and dying; skill values,
  prerequisites and rolls; and the ship-combat panels. The tables behind the ability adjustments, the weight allowance,
  the ship meters and the maneuver line are GDConsts'. }
{$F+,O+,S-,R-,V-,B-,I-}
unit CharHlp;

interface

uses Types, C_Map, C_Search, C_Ship, C_Status, GDConsts, GDVars, OrbitMap, MapView,
  Pathing, MenuCore, TextRend, Border, GameIo, Blit, CbtMap, Music, Crt, Mouse, Portrait, C_Equip, C_Effect, C_Dir,
  C_Skill, C_WClass, C_Armor, C_Sys, C_Ifc, C_Item, C_Career, C_Side, C_Screen;

{ Rolls a percentile chance.
  @param(percent The chance in 100.)
  @returns(True with a chance of percent in 100.) }
function PercentileRoll(percent: Byte): Boolean;

{ Rolls dice.
  @param(count The number of dice; 0 rolls nothing.)
  @param(sides The faces per die.)
  @returns(The sum.) }
function RollDice(count, sides: Byte): Byte;

{ Rebuilds an item's name from its name parts and quantity, with a ' Yes' or ' No' readied column when isInventory, and
  draws it when isDrawn.
  @param(character Unused.)
  @param(item The item named.)
  @param(column The text column.)
  @param(row The text row.)
  @param(isInventory True adds the readied column.)
  @param(isDrawn True draws the name.) }
procedure PrintItemString(character: Types.PCharRecord; item: Types.PItemRec; column, row: Byte; isInventory,
                          isDrawn: Boolean);

{ Does nothing on the orbit map, in the wilderness or under the big picture. Sets the party panel's bounds and redraws
  the row of partyRowCharacter (highlight when none is set): name, armor class and hit points, each value placed by its
  band. Then blanks the row below the list and clears partyRowCharacter.
  @param(highlight The character drawn when partyRowCharacter is not set.)
  @param(isPlainName True draws the name in White.) }
procedure DisplayRoster(highlight: Types.PCharRecord; isPlainName: Boolean);

{ While the side panel is marked for redrawing, clears the mark and redraws the ground-combat side panel: the name, hit
  points, armor class, readied weapon, and the status or the first of helpless, blind, stunned and scared (intimidated)
  that applies.
  @param(character The combatant shown.) }
procedure CombatPrintCreatureInfo(character: Types.PCharRecord);

{ Tests a character for C_Effect.HELPLESS.
  @param(character The character.)
  @returns(True while it has the effect.) }
function IsHelpless(character: Types.PCharRecord): Boolean;

{ Gives a character's missile and initiative adjustment for its dexterity, from dexMissileAdjustments.
  @param(character The character.)
  @returns(The adjustment.) }
function DexMissileAdjust(character: Types.PCharRecord): ShortInt;

{ Gives a character's to-hit adjustment for its strength, from the strength to-hit table.
  @param(character The character.)
  @returns(The adjustment.) }
function StrToHitAdjust(character: Types.PCharRecord): ShortInt;

{ Gives a character's damage adjustment for its strength, from the strength damage table.
  @param(character The character.)
  @returns(The adjustment.) }
function StrDamageAdjust(character: Types.PCharRecord): ShortInt;

{ Counts a character's specializations in an item's type.
  @param(character The character.)
  @param(item The weapon, or nil.)
  @returns(How many of the character's weaponSpecializations name item's type; 0 for nil.) }
function SpecializationLevel(character: Types.PCharRecord; item: Types.PItemRec): Byte;

{ Unlinks an item from the character's item list and frees it. When it is not there it warns and searches every
  character on the party list, warning for each that lacks it, and frees it unlinked when none holds it. A nil item only
  warns.
  @param(character The character.)
  @param(item The item removed.) }
procedure RemoveItem(character: Types.PCharRecord; item: Types.PItemRec);

{ Appends a copy of an item to the end of the character's item list.
  @param(character The character.)
  @param(item The item copied.) }
procedure AddItemCopy(character: Types.PCharRecord; item: Types.PItemRec);

{ Shows a message on the status line, STATUS_ROW, waits, and clears the line.
  @param(message The message.) }
procedure PrintBottomLine(message: Types.TString40);

{ Shows the character's name and a message: in ground combat in the side panel from the given row, on the ship screen in
  the text window (never paused), elsewhere from row 17, or 18 while the combat line is lowered.
  @param(character The character.)
  @param(message The message.)
  @param(row The side panel's row.)
  @param(hasPause Waits, then clears the message area.) }
procedure PrintCreatureMessage(character: Types.PCharRecord; message: String; row: Byte; hasPause: Boolean);

{ Clears the ground-combat side panel from row 10 down, or else the text window. }
procedure ClearMessageWindow;

{ Moves movingIcon along Pathing's path between two arena cells, scrolling the view to follow it.
  @param(startX The start column.)
  @param(startY The start row.)
  @param(endX The end column.)
  @param(endY The end row.)
  @param(frames The icon frames it cycles through.)
  @param(pace Milliseconds per step; with 0 only steps on a cell line are drawn.) }
procedure CombatAnimateMovingIcon(startX, startY, endX, endY: Integer; frames, pace: Byte);

{ Recomputes the character's encumbrance (readied armor weighs nothing), readied weapon and armor, damage dice, attack
  bonus, armor flags and classes, and movement from its items, abilities, status and side.
  @param(character The character.) }
procedure RecalcStats(character: Types.PCharRecord);

{ In ground combat with a non-zero animation: draws box animation+13, brings the character into view, plays
  explosionSound (animations 15 and 16) or damageSound, shows the combat line and plays movingIcon over the character.
  Otherwise it shows the combat line and waits, except on the ship screen, where PrintCreatureMessage does not wait.
  @param(character The character.)
  @param(animation The animation, 0 for none.)
  @param(message The combat line.) }
procedure PrintNameStringAnim(character: Types.PCharRecord; animation: Byte; message: String);

{ Takes damage from the character's hit points. Damage past 0 leaves it dying (up to 9 over), comatose (10..29) or dead
  (30 or more), and exactly 0 unconscious; any of these disables it and, in combat, takes it off its side's count.
  @param(character The character.)
  @param(damage The damage.) }
procedure InflictDamage(character: Types.PCharRecord; damage: Word);

{ Gives the side opposing a character's.
  @param(character The character.)
  @returns(The opposing side.) }
function EnemyTeam(character: Types.PCharRecord): ShortInt;

{ Counts the enabled creatures of each side into teamCounts. }
procedure CountTeams;

{ Builds the target list within a range of a creature, narrows it to the creature's enemies and copies their creature
  indices into the target-slot table.
  @param(character The creature at the center.)
  @param(range The range.)
  @returns(The number of targets kept.) }
function CountTargets(character: Types.PCharRecord; range: Byte): Byte;

{ Measures Pathing's distance between two characters, halved. pathTargets is put back as it was; pathTargetCount is left
  as the rebuilt list set it. Note: an absent other gives the last entry's distance.
  @param(character The character measuring.)
  @param(other The character measured to.)
  @returns(The distance.) }
function CalcDistance(character, other: Types.PCharRecord): Byte;

{ Clears the character's initiative, guarding and movement.
  @param(character The character.)
  @returns(Always True.) }
function EndActions(character: Types.PCharRecord): Boolean;

{ Draws the frame and contents of the screen interfaceState names: the main menu, a shop, the wilderness, the 3-D view,
  after combat, the ship, the orbit map or a picture view; the frames are plain, explore, text, ship and orbit map. }
procedure DisplayNoncombatInterface;

{ Shows the position line at (17, 15), except in the wilderness: the readout's or the party's x,y, the facing, the hh:mm
  clock, an asterisk in debug mode, and camping or search. }
procedure PrintMiscInfo;

{ Sets the combat palette, draws the ground-combat frame and redraws the view round its current center. }
procedure DisplayCombatInterface;

{ Tests whether a character's readied weapon has a range above 1.
  @param(character The character.)
  @returns(True for a ranged weapon.) }
function HasRangedWeapon(character: Types.PCharRecord): Boolean;

{ Tests whether a character's readied weapon is an area weapon, weaponClass C_WClass.FIRST_AREA_WEAPON or above.
  @param(character The character.)
  @returns(True for an area weapon.) }
function HasAreaWeapon(character: Types.PCharRecord): Boolean;

{ Tests whether a character's readied area weapon has shots or grenades left.
  @param(character The character.)
  @returns(True for a loaded area weapon.) }
function HasLoadedAreaWeapon(character: Types.PCharRecord): Boolean;

{ Checks the readied weapon, which must not be nil, for a ranged weapon with a quantity.
  @param(character The character.)
  @param(selected Receives the weapon when it qualifies; otherwise left as it was.)
  @returns(True when the weapon has a quantity and a weaponClass above C_WClass.MELEE.) }
function FindDamagingRangedWeapon(character: Types.PCharRecord; var selected: Types.PItemRec): Boolean;

{ Sets currentMovement from baseMovement, halved when encumbrance is over half the weight allowance.
  @param(character The character.)
  @returns(That movement plus the party's movementBonus for C_Side.TEAM, doubled.) }
function RecalcMovement(character: Types.PCharRecord): Byte;

{ With an enemy ship, redraws the ship-combat scene (ship picture 0 and the big picture), DrawShipSceneText and the
  enemy's systems; with none, the party ship's details. }
procedure RefreshShipScene;

{ Shows the maneuver name and the range (0 when negative) at the scene's top left. }
procedure DrawShipSceneText;

{ Draws the ship's weapon list.
  @param(ship The ship.)
  @param(isDetailsList False: the party ship's panel, three weapons; True: the details list, four weapons with ammo and
    reloads.)
  @param(row The weapon to flash, or -1.) }
procedure DrawShipWeapons(ship: Types.PShipRec; isDetailsList: Boolean; row: ShortInt);

{ Draws a system's value and bar, and for the party ship its label; nothing for the enemy while the party ship's sensors
  are out.
  @param(ship The ship.)
  @param(slot The system.)
  @param(isFlashing True flashes the value.) }
procedure DrawSystemMeter(ship: Types.PShipRec; slot: ShortInt; isFlashing: Boolean);

{ Gives the ability score of the skill's group, when MeetsSkillPrerequisite; else 0.
  @param(character The character.)
  @param(skillId The skill.)
  @returns(The ability score.) }
function SkillAbilityScore(character: Types.PCharRecord; skillId: Byte): ShortInt;

{ Gives the skill's level plus its SkillAbilityScore, for an enabled character with the skill; else 0.
  @param(character The character.)
  @param(skillId The skill.)
  @returns(The skill value.) }
function SkillValue(character: Types.PCharRecord; skillId: Byte): Byte;

{ Rolls d100 against the skill value for every party member when isWholeParty, else for character (currentCharacter when
  nil), and leaves the best in character.
  @param(skillId The skill.)
  @param(scale Scales the value: 0 x4, 1 x2, 2 x1, 3 /2, 4 /4.)
  @param(isWholeParty True rolls for every party member.)
  @param(character In, the character rolling, or nil; out, the best.)
  @returns(3 when the best beat the roll by half the last value examined or more, 2 a smaller success, 1 a failure, 0 a
    failure by more than that value.) }
function SelectSkillCharacter(skillId, scale: Byte; isWholeParty: Boolean; var character: Pointer): Byte;

{ Tests a character for the levels in other skills that a skill requires; skills FIRST_MEDICAL_SKILL..LAST_MEDICAL_SKILL
  are open to medics only.
  @param(character The character.)
  @param(skillId The skill.)
  @returns(True when the character meets them.) }
function MeetsSkillPrerequisite(character: Types.PCharRecord; skillId: Byte): Boolean;

{ Gives the smaller of two words.
  @param(first The first word.)
  @param(second The second word.)
  @returns(The smaller.) }
function MinimumWord(first, second: Word): Word;

{ Advances the dying count of every dying creature in play; past 9 it slips into a coma. The others are counted for the
  'Your Teammate(s) ... Dying!' line whichever side they are on, so a dying enemy counts too. }
procedure ProcessDyingCharacters;

{ Gives the ship's speed: 0 unless CanShipMove; else its base plus boosts, halved below half hull, less 3 below a
  quarter of its engines or 1 below half, and at least 1.
  @param(ship The ship.)
  @returns(The speed.) }
function ShipSpeed(ship: Types.PShipRec): ShortInt;

{ Draws the ship's details panel and weapon list.
  @param(ship The ship.)
  @param(isEnemyShown Show the enemy's values, while the party ship's sensors work.) }
procedure DrawShipDetails(ship: Types.PShipRec; isEnemyShown: Boolean);

{ Tests whether the ship can move.
  @param(ship The ship.)
  @returns(True while the ship's control systems, fuel and engines all work.) }
function CanShipMove(ship: Types.PShipRec): Boolean;

{ Finds a character's first effect with an id.
  @param(character The character.)
  @param(effectId The effect to look for.)
  @param(effect Receives that effect, or nil.)
  @returns(True if found.) }
function HasEffect(character: Types.PCharRecord; effectId: Byte; var effect: Types.PEffectRec): Boolean;

implementation

type
  TString5 = String[5];
  TString6 = String[6];

const
  { the level in any one of Singing, Play Instrument and Literature that Composition requires }
  COMPOSITION_NEEDS_ARTS = 20;
  { TItemType.slot of the Protective Goggles: AdjustEquippedItem sets C_Armor.GOGGLES }
  EQUIP_GOGGLES = 3;
  { TItemType.slot of the Breathing Mask: C_Armor.BREATHING_PROTECTION }
  EQUIP_BREATHING_MASK = 4;
  { TItemType.slot of the ECM package: C_Armor.ECM }
  EQUIP_ECM = 7;
  { Battle armor w/fields' itemTypes row }
  BATTLE_ARMOR_FIELDS_TYPE = 24;
  { DrawShipValue's modes }
  VALUE_PLAIN = 0;
  VALUE_TONS = 1;
  VALUE_FEET = 2;
  { '?' for the enemy unless enemyDetailsShown }
  VALUE_SENSED = 3;

function DexterityArmorAdjustment(character: Types.PCharRecord): ShortInt; forward;

function WeightAllowance(character: Types.PCharRecord): Word; forward;

procedure DrawShipSystems(ship: Types.PShipRec); forward;

{ Recomputes the attack bonus and damage of the readied weapon, if any: strength adjusts a melee weapon's
  (C_WClass.MELEE) to-hit and damage, dexterity only the to-hit of the rest, and the specializations in its type plus
  its plus add to both (to damage only for a weapon other than the Sonic Stunner, whose hit stuns).
  @param(character The character.) }
procedure WeaponAdjust(character: Types.PCharRecord);
var weapon: Types.PItemRec;
    weaponType: Byte;
    plus: ShortInt;
begin
  weapon := character^.equipped[C_Equip.WEAPON];
  if weapon <> nil then begin
    weaponType := weapon^.template.itemType;
    character^.attackBonus := character^.baseCombat;
    character^.currentModifiers[1] := GDVars.itemTypes[weaponType].damageBonus;
    if GDVars.itemTypes[weaponType].weaponClass = C_WClass.MELEE then begin
      Inc(character^.attackBonus, CharHlp.StrToHitAdjust(character));
      Inc(character^.currentModifiers[1], CharHlp.StrDamageAdjust(character))
    end else
      Inc(character^.attackBonus, CharHlp.DexMissileAdjust(character));
    plus := CharHlp.SpecializationLevel(character, weapon) + weapon^.template.plus;
    if weaponType <> C_Item.SONIC_STUNNER_TYPE then
      Inc(character^.currentModifiers[1], plus);
    Inc(character^.attackBonus, plus);
    character^.currentRolls[1] := GDVars.itemTypes[weaponType].diceCount;
    character^.currentDice[1] := GDVars.itemTypes[weaponType].diceSides
  end
end;

procedure PrintItemString(character: Types.PCharRecord; item: Types.PItemRec; column, row: Byte; isInventory,
                          isDrawn: Boolean);
var part: Byte;
    { Unused in this version; see the other implementations of this routine. }
    partText: array[1..9] of Byte;
begin
  item^.name := '';
  for part := 1 to SizeOf(item^.template.nameIds) do
    if item^.template.nameIds[part] <> 0 then begin
      item^.name := GDConsts.itemNameParts[item^.template.nameIds[part]] + ' ' + item^.name
    end;
  if item^.template.quantity > 0 then begin
    if (item^.template.flags and C_Item.NOT_JOINABLE) <> 0 then
      item^.name := item^.name + '(' + TextRend.ByteToString(item^.template.quantity) + ')'
    else begin
      item^.name := TextRend.ByteToString(item^.template.quantity) + ' ' + item^.name;
      if item^.template.quantity > 1 then
        item^.name[Length(item^.name)] := 's'
    end
  end;
  if isInventory then begin
    if (item^.template.flags and C_Item.READIED) <> 0 then
      item^.name := ' Yes  ' + item^.name
    else
      item^.name := ' No   ' + item^.name
  end;
  if isDrawn then
    TextRend.DisplayString(column, row, LightGreen, Black, item^.name)
end;

procedure DisplayRoster(highlight: Types.PCharRecord; isPlainName: Boolean);
var character: Types.PCharRecord;
    { Unused in this version; see the other implementations of this routine. }
    numberText: array[1..4] of Byte;
    column: Byte;
    row: Byte;
    band: Byte;
begin
  if (GDVars.interfaceState = C_Ifc.ORBIT_MAP) or (GDVars.interfaceState = C_Ifc.WILDERNESS) or
      (GDVars.bigPictureShown <> 0) then
    Exit;
  if GDVars.partyRowCharacter = nil then
    GDVars.partyRowCharacter := highlight;
  if GDVars.interfaceState = C_Ifc.MAIN_MENU then
    column := 1
  else
    column := 17;
  GDVars.panelLeft := column;
  GDVars.panelTop := 4;
  GDVars.panelRight := 38;
  GDVars.panelBottom := 3;
  row := 4;
  character := GDVars.partyHead;
  while character <> nil do begin
    Inc(GDVars.panelBottom);
    if character = GDVars.partyRowCharacter then begin
      if isPlainName then
        TextRend.DisplayString(column, row, White, Black, character^.name)
      else
        MenuCore.DisplayCreatureName(character, column, row, False);
      case character^.armorClass[0] of
        0..50: band := 1;
        51..60: band := 2;
        61..69: band := 1
      else band := 0
      end;
      MenuCore.PrintArmorClass(character, band + 32, row);
      case character^.hitPoints of
        0..9: band := 2;
        10..99: band := 1
      else band := 0
      end;
      MenuCore.PrintHitPoints(character, band + 36, row, False, False)
    end;
    Inc(row);
    character := character^.nextCharAddr
  end;
  Border.ClearBox(column, row, 38, row);
  GDVars.partyRowCharacter := nil
end;

procedure CombatPrintCreatureInfo(character: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  column: Byte;
  row: Byte;
    message: String[20];
    effect: Types.PEffectRec;
begin
  if GDVars.creatureInfoDirty <> 0 then begin
    GDVars.creatureInfoDirty := 0;
    Border.ClearBox(23, 1, 38, 21);
    row := 1;
    CharHlp.PrintCreatureMessage(character, ' ', row, False);
    Inc(row);
    TextRend.DisplayString(23, row + 1, LightGreen, Black, 'Hitpoints');
    MenuCore.PrintHitPoints(character, 33, row + 1, False, False);
    Inc(row, 2);
    TextRend.DisplayString(23, row + 1, LightGreen, Black, 'AC');
    MenuCore.PrintArmorClass(character, 26, row + 1);
    GDVars.cursorRow := row + 1;
    if character^.equipped[C_Equip.WEAPON] <> nil then begin
      Inc(row, 2);
      column := 23;
      CharHlp.PrintItemString(character, character^.equipped[C_Equip.WEAPON], 0, 0, False, False);
      TextRend.DisplayMessageWindow(23, row + 1, 38, row + 1 + 2, LightGreen, Black, True,
                                    Types.PItemRec(character^.equipped[C_Equip.WEAPON])^.name)
    end;
    row := GDVars.cursorRow + 1;
    message := '';
    if character^.enabled = 0 then
      message := GDConsts.statusNames[ShortInt(character^.status)]
    else if CharHlp.IsHelpless(character) then
      message := '(helpless)'
    else if CharHlp.HasEffect(character, C_Effect.BLIND, effect) then
      message := '(blinded)'
    else if CharHlp.HasEffect(character, C_Effect.STUNNED, effect) then
      message := '(stunned)'
    else if CharHlp.HasEffect(character, C_Effect.SCARED, effect) then
      message := '(intimidated)'
    else
      Exit;
    TextRend.DisplayString(23, row + 1, White, Black, message)
  end
end;

function IsHelpless(character: Types.PCharRecord): Boolean;
var effect: Types.PEffectRec;
begin
  IsHelpless := CharHlp.HasEffect(character, C_Effect.HELPLESS, effect)
end;

function SpecializationLevel(character: Types.PCharRecord; item: Types.PItemRec): Byte;
var
  index: Byte;
  count: Byte;
begin
  count := 0;
  if item <> nil then
    for index := 1 to SizeOf(character^.weaponSpecializations) do
      if character^.weaponSpecializations[index] = item^.template.itemType then
        Inc(count);
  SpecializationLevel := count
end;

{ Gives a character's armor class adjustment for its dexterity, from dexArmorAdjustments.
  @param(character The character.)
  @returns(The adjustment.) }
function DexterityArmorAdjustment(character: Types.PCharRecord): ShortInt;
begin
  DexterityArmorAdjustment := GDConsts.dexArmorAdjustments[character^.dexterity]
end;

function DexMissileAdjust(character: Types.PCharRecord): ShortInt;
begin
  DexMissileAdjust := GDConsts.dexMissileAdjustments[character^.dexterity]
end;

function StrToHitAdjust(character: Types.PCharRecord): ShortInt;
begin
  StrToHitAdjust := GDConsts.strengthToHitAdjustments[character^.strength]
end;

function StrDamageAdjust(character: Types.PCharRecord): ShortInt;
begin
  StrDamageAdjust := GDConsts.strengthDamageAdjustments[character^.strength]
end;

{ Gives the weight a character carries unencumbered, from weightAllowances by its strength.
  @param(character The character.)
  @returns(The allowance.) }
function WeightAllowance(character: Types.PCharRecord): Word;
begin
  WeightAllowance := GDConsts.weightAllowances[character^.strength]
end;

procedure RemoveItem(character: Types.PCharRecord; item: Types.PItemRec);
var current: Types.PItemRec;
    isDisposed: Boolean;
    isScanningParty: Boolean;

  { Frees item and marks it disposed. }
  procedure DisposeTarget;
  begin
    FreeMem(item, SizeOf(Types.TItemRec));
    isDisposed := True
  end;

begin
  isDisposed := False;
  isScanningParty := False;
  if item = nil then begin
    TextRend.DisplayAndPause(Yellow, Black, 'Nil Item pointer...');
    Exit
  end else
    repeat
      current := character^.itemsAddr;
      if current = item then begin
        character^.itemsAddr := item^.next;
        DisposeTarget
      end else begin
        while (current <> nil) and (current^.next <> item) do
          current := current^.next;
        if current = nil then begin
          TextRend.DisplayAndPause(Yellow, Black, 'Tried to Lose item & couldn''t find it!');
          if isScanningParty then begin
            character := character^.nextCharAddr;
            if character = nil then
              DisposeTarget
          end else begin
            character := GDVars.partyHead;
            isScanningParty := True
          end
        end else begin
          current^.next := item^.next;
          DisposeTarget
        end
      end
    until isDisposed
end;

procedure AddItemCopy(character: Types.PCharRecord; item: Types.PItemRec);
var
  current: Types.PItemRec;
  newItem: Types.PItemRec;
begin
  GetMem(newItem, SizeOf(Types.TItemRec));
  Move(item^, newItem^, SizeOf(Types.TItemRec));
  newItem^.next := nil;
  current := character^.itemsAddr;
  if current = nil then
    character^.itemsAddr := newItem
  else begin
    while current^.next <> nil do
      current := current^.next;
    current^.next := newItem
  end
end;

procedure PrintBottomLine(message: Types.TString40);
begin
  Border.ClearBox(0, C_Screen.STATUS_ROW, 39, C_Screen.STATUS_ROW);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, message);
  TextRend.PauseOnly;
  Border.ClearBox(0, C_Screen.STATUS_ROW, 39, C_Screen.STATUS_ROW)
end;

procedure PrintCreatureMessage(character: Types.PCharRecord; message: String; row: Byte; hasPause: Boolean);
var topRow: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    Border.ClearBox(23, row, 38, 21);
    MenuCore.DisplayCreatureName(character, 23, row, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, 21, LightGreen, Black, True, message)
  end else if GDVars.interfaceState = C_Ifc.SHIP then begin
    TextRend.DisplayWindowText(LightCyan, character^.name + ' ' + message + '.');
    hasPause := False
  end else begin
    if GDVars.combatLineLowered <> 0 then
      topRow := 18
    else
      topRow := 17;
    Border.ClearBox(1, topRow, 38, 22);
    MenuCore.DisplayCreatureName(character, 1, topRow + 1, False);
    TextRend.DisplayMessageWindow(1, topRow + 2, 38, 22, LightGreen, Black, True, message)
  end;
  if hasPause then begin
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow
  end
end;

procedure ClearMessageWindow;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    Border.ClearBox(23, 10, 38, 21)
  else
    TextRend.FillRect(GDVars.windowLeft, GDVars.windowTop, GDVars.windowRight, GDVars.windowBottom,
                      GDVars.windowColor)
end;

procedure CombatAnimateMovingIcon(startX, startY, endX, endY: Integer; frames, pace: Byte);
var path: array[0..147] of Byte;
    walk: Types.TPathReq;
    { Unused in this version; see the other implementations of this routine. }
    boltLength: Integer;
    pathIndex: Byte;
    pathCount: Byte;
    frameIndex: Byte;
    { Unused in this version; see the other implementations of this routine. }
    lastFrame: Byte;
    isLastPass: Boolean;
    isDone: Boolean;
    cameraX: Integer;
    cameraY: Integer;
    { Unused in this version; see the other implementations of this routine. }
    previousX: Integer;
    { Unused in this version; see the other implementations of this routine. }
    previousY: Integer;
    accumulatorX: Integer;
    accumulatorY: Integer;
    differenceX: Integer;
    differenceY: Integer;
    stepX: Integer;
    stepY: Integer;
    pixelX: Integer;
    pixelY: Integer;
    overshootX: Integer;
    overshootY: Integer;

begin
  previousX := startX;
  previousY := startY;
  FillChar(path, SizeOf(path), C_Dir.CENTER);
  FillChar(walk, SizeOf(walk), 0);
  pathIndex := 0;
  frameIndex := 0;
  walk.sx := startX * 3;
  walk.sy := startY * 3;
  walk.ex := endX * 3;
  walk.ey := endY * 3;
  Pathing.PathFind(walk);
  repeat
    isDone := not Pathing.NextPathStep(walk);
    path[pathIndex] := walk.step;
    Inc(pathIndex)
  until isDone;
  pathCount := pathIndex - 2;
  if (pathCount < 2) or (pathIndex < 2) then Exit;
  differenceX := endX - startX;
  differenceY := endY - startY;
  if not CbtMap.ViewCoordsValid(startX - GDVars.combatArena^.viewOriginX,
                                startY - GDVars.combatArena^.viewOriginY) or
                                  not CbtMap.ViewCoordsValid(endX - GDVars.combatArena^.viewOriginX,
                                                             endY - GDVars.combatArena^.viewOriginY) then begin
    if (Abs(differenceX) <= 6) and (Abs(differenceY) <= 6) then begin
      isLastPass := True;
      cameraX := startX + differenceX div 2;
      cameraY := startY + differenceY div 2
    end else begin
      isLastPass := False;
      cameraX := GDVars.combatArena^.viewOriginX + 3;
      cameraY := GDVars.combatArena^.viewOriginY + 3
    end
  end else begin
    isLastPass := True;
    cameraX := GDVars.combatArena^.viewOriginX + 3;
    cameraY := GDVars.combatArena^.viewOriginY + 3
  end;
  CbtMap.ScrollView(Byte(cameraX), Byte(cameraY), 255, C_Dir.CENTER);
  pathIndex := 0;
  accumulatorX := 0;
  accumulatorY := 0;
  repeat
    pixelX := (startX - GDVars.combatArena^.viewOriginX) * 3 + accumulatorX;
    pixelY := (startY - GDVars.combatArena^.viewOriginY) * 3 + accumulatorY;
    previousX := startX;
    previousY := startY;
    isDone := False;
    repeat
      stepX := GDConsts.dirStepX[path[pathIndex]];
      stepY := GDConsts.dirStepY[path[pathIndex]];
      Inc(pixelX, stepX);
      Inc(pixelY, stepY);
      Inc(pathIndex);
      if (pixelX < 0) or (pixelX > 18) or (pixelY < 0) or (pixelY > 18) then isDone := True;
      if not isDone then begin
        if (pace > 0) or (pixelX mod 3 = 0) or (pixelY mod 3 = 0) then begin
          Blit.BlitTileClipped(pixelX, pixelY, frameIndex, 5, GDVars.movingIcon, GDVars.viewPicture);
          Blit.FlushView;
          Delay(pace);
          Blit.BlitTileClipped(pixelX, pixelY, 0, 0, GDVars.saveUnder, GDVars.viewPicture);
          Inc(frameIndex);
          if frameIndex >= frames then frameIndex := 0
        end
      end;
      if (not isDone) and (pathIndex < pathCount) then begin
        Inc(accumulatorX, stepX);
        Inc(accumulatorY, stepY);
        if Abs(accumulatorX) = 3 then begin
          Inc(startX, Pathing.SignOf(accumulatorX));
          Inc(cameraX, Pathing.SignOf(accumulatorX));
          accumulatorX := 0
        end;
        if Abs(accumulatorY) = 3 then begin
          Inc(startY, Pathing.SignOf(accumulatorY));
          Inc(cameraY, Pathing.SignOf(accumulatorY));
          accumulatorY := 0
        end
      end
    until (pathIndex >= pathCount) or isDone;
    if pathIndex < pathCount then begin
      overshootX := 0;
      overshootY := 0;
      accumulatorY := 0;
      accumulatorX := 0;
      startX := endX;
      startY := endY;
      previousX := startX;
      previousY := startY;
      if endX + 3 > SizeOf(GDVars.combatArena^.cells[0]) - 1 then
        overshootX := endX - (SizeOf(GDVars.combatArena^.cells[0]) - 1)
      else if endX < 3 then overshootX := 3 - endX;
      if endY + 3 > SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1 then
        overshootY := endY - (SizeOf(GDVars.combatArena^.cells) div SizeOf(GDVars.combatArena^.cells[0]) - 1)
      else if endY < 3 then overshootY := 3 - endY;
      cameraX := endX + overshootX;
      cameraY := endY + overshootY;
      CbtMap.ScrollView(Byte(cameraX), Byte(cameraY), 255, C_Dir.CENTER);
      pixelX := (endX - GDVars.combatArena^.viewOriginX) * 3;
      pixelY := (endY - GDVars.combatArena^.viewOriginY) * 3;
      pathIndex := pathCount;
      isDone := False;
      repeat
        stepX := -GDConsts.dirStepX[path[pathIndex]];
        stepY := -GDConsts.dirStepY[path[pathIndex]];
        Inc(pixelX, stepX);
        Inc(pixelY, stepY);
        if pixelX > 18 then
          startX := GDVars.combatArena^.viewOriginX + 6
        else if pixelX < 0 then startX := GDVars.combatArena^.viewOriginX;
        if pixelY > 18 then
          startY := GDVars.combatArena^.viewOriginY + 6
        else if pixelY < 0 then startY := GDVars.combatArena^.viewOriginY;
        if (pixelX < 0) or (pixelX > 18) or (pixelY < 0) or (pixelY > 18) then isDone := True;
        if not isDone then begin
          Inc(accumulatorX, stepX);
          Inc(accumulatorY, stepY);
          if Abs(accumulatorX) = 3 then begin
            Inc(startX, Pathing.SignOf(accumulatorX));
            Inc(cameraX, Pathing.SignOf(accumulatorX));
            accumulatorX := 0
          end;
          if Abs(accumulatorY) = 3 then begin
            Inc(startY, Pathing.SignOf(accumulatorY));
            Inc(cameraY, Pathing.SignOf(accumulatorY));
            accumulatorY := 0
          end;
          Dec(pathIndex)
        end
      until isDone
    end else begin
      isLastPass := True;
      if not CbtMap.ViewCoordsValid(endX - GDVars.combatArena^.viewOriginX,
                                    endY - GDVars.combatArena^.viewOriginY) then
        CbtMap.ScrollView(Byte(endX), Byte(endY), 3, C_Dir.CENTER);
      pixelX := (endX - GDVars.combatArena^.viewOriginX) * 3;
      pixelY := (endY - GDVars.combatArena^.viewOriginY) * 3;
      Blit.BlitTileClipped(pixelX, pixelY, frameIndex, 5, GDVars.movingIcon, GDVars.viewPicture);
      if pace > 0 then begin
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixelX, pixelY, 0, 0, GDVars.saveUnder, GDVars.viewPicture)
      end
    end
  until isLastPass;
  Blit.FlushView
end;

{ Applies a readied item to the armor: body armor adds its class and plus to the first armor class and sets the body and
  breathing-protection armor flags, and battle armor with fields also the fields flag; the goggles slot sets the goggles
  flag, the breathing-mask slot the breathing-protection flag, and the ECM slot the ECM flag. In ITEMS those slots hold
  only the Protective Goggles, the Breathing Mask and the ECM package.
  @param(character The character.)
  @param(item The readied item.) }
procedure AdjustEquippedItem(character: Types.PCharRecord; item: Types.PItemRec);
{ Unused in this version; see the other implementations of this routine. }
var bonus: Integer;
begin
  with GDVars.itemTypes[item^.template.itemType] do case slot of
    C_Equip.ARMOR: begin
      Inc(character^.armorClass[0], weaponClass - 50 + item^.template.plus);
      character^.armorFlags := character^.armorFlags or (C_Armor.BODY or C_Armor.BREATHING_PROTECTION);
      if item^.template.itemType = CharHlp.BATTLE_ARMOR_FIELDS_TYPE then
        character^.armorFlags := character^.armorFlags or C_Armor.FIELDS
    end;
    CharHlp.EQUIP_GOGGLES: character^.armorFlags := character^.armorFlags or C_Armor.GOGGLES;
    CharHlp.EQUIP_BREATHING_MASK: character^.armorFlags := character^.armorFlags or C_Armor.BREATHING_PROTECTION;
    CharHlp.EQUIP_ECM: character^.armorFlags := character^.armorFlags or C_Armor.ECM
  end
end;

procedure RecalcStats(character: Types.PCharRecord);
var copyIndex: Byte;
    item: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    magicBody: Integer;
    itemWeight: Word;
    slot: Byte;
begin
  with character^ do begin
    equipped[C_Equip.ARMOR] := nil;
    equipped[C_Equip.WEAPON] := nil;
    item := itemsAddr;
    encumbrance := 0;
    while item <> nil do begin
      slot := GDVars.itemTypes[item^.template.itemType].slot;
      if (slot <> C_Equip.ARMOR) or ((item^.template.flags and C_Item.READIED) = 0) then begin
        itemWeight := item^.template.weight;
        if (item^.template.quantity > 0) and ((item^.template.flags and C_Item.NOT_JOINABLE) = 0) then
          itemWeight := item^.template.quantity * itemWeight;
        Inc(encumbrance, itemWeight)
      end;
      if (item^.template.flags and C_Item.READIED) <> 0 then begin
        if slot = C_Equip.WEAPON then equipped[C_Equip.WEAPON] := item
        else if slot = C_Equip.ARMOR then equipped[C_Equip.ARMOR] := item
      end;
      item := item^.next
    end;
    for copyIndex := 1 to SizeOf(currentRolls) do begin
      currentRolls[copyIndex] := unarmedRolls[copyIndex];
      currentDice[copyIndex] := unarmedDice[copyIndex];
      currentModifiers[copyIndex] := unarmedModifiers[copyIndex]
    end;
    attackBonus := baseCombat;
    if equipped[C_Equip.WEAPON] = nil then begin
      attackBonus := CharHlp.StrToHitAdjust(character) + attackBonus;
      currentModifiers[1] := CharHlp.StrDamageAdjust(character) + currentModifiers[1]
    end;
    CharHlp.WeaponAdjust(character);
    if status = C_Status.FAILED_ZERO_G then Dec(attackBonus, 2);
    if GDVars.tacticsSides[side] <> 0 then
      Inc(attackBonus);
    armorFlags := 0;
    armorClass[0] := baseArmorClass;
    item := itemsAddr;
    while item <> nil do begin
      if (item^.template.flags and C_Item.READIED) <> 0 then
        CharHlp.AdjustEquippedItem(character, item);
      item := item^.next
    end;
    currentMovement := CharHlp.RecalcMovement(character) shr 1;
    if status = C_Status.DODGING then begin
      if level < 4 then Inc(armorClass[0], 2)
      else Inc(armorClass[0], level shr 1)
    end;
    armorClass[1] := armorClass[0] - 2;
    Inc(armorClass[0], CharHlp.DexterityArmorAdjustment(character))
  end
end;

function RecalcMovement(character: Types.PCharRecord): Byte;
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
begin
  character^.currentMovement := character^.baseMovement;
  if CharHlp.WeightAllowance(character) div 2 < character^.encumbrance then
    character^.currentMovement := character^.currentMovement div 2;
  GDVars.movementRate := character^.currentMovement;
  if character^.side = C_Side.TEAM then
    GDVars.movementRate := GDVars.movementRate + GDVars.zone1^.movementBonus;
  GDVars.movementRate := GDVars.movementRate * 2;
  RecalcMovement := GDVars.movementRate
end;

procedure PrintNameStringAnim(character: Types.PCharRecord; animation: Byte; message: String);
var
  gridColumn: ShortInt;
  gridRow: ShortInt;
    cell: Byte;
    frame: Byte;
    repetition: Byte;
    repetitions: Byte;
    isExplosion: Boolean;
begin
  if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (animation <> 0) then begin
    cell := animation + 13;
    Blit.BuildIconFrames(cell);
    if not CbtMap.CombatIconVisible(character, 1) then
      CbtMap.ScrollView(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), 3, C_Dir.CENTER);
    isExplosion := animation in [15, 16];
    if isExplosion then
      Music.SendSoundCommand(GDConsts.explosionSound)
    else
      Music.SendSoundCommand(GDConsts.damageSound);
    CharHlp.PrintCreatureMessage(character, message, 10, False);
    if not isExplosion then
      repetitions := GDVars.zone0^.messageSpeed shr 1
    else
      repetitions := 0;
    gridColumn := GDVars.gridX[CbtMap.CombatSlot(character)] * 3;
    gridRow := GDVars.gridY[CbtMap.CombatSlot(character)] * 3;
    for repetition := 0 to repetitions do
      for frame := 0 to 3 do begin
        Blit.BlitTileClipped(gridColumn, gridRow, frame, 5, GDVars.movingIcon, GDVars.viewPicture);
        Blit.FlushView;
        Delay(70);
        Blit.BlitTileClipped(gridColumn, gridRow, 0, 0, GDVars.saveUnder, GDVars.viewPicture)
      end;
    Blit.FlushView;
    if repetitions = 0 then
      TextRend.PauseOnly
  end else
    CharHlp.PrintCreatureMessage(character, message, 10, True)
end;

function HasEffect(character: Types.PCharRecord; effectId: Byte; var effect: Types.PEffectRec): Boolean;
var isFound: Boolean;
begin
  isFound := False;
  effect := character^.effectsAddr;
  while (effect <> nil) and not isFound do begin
    if effect^.effectId = effectId then
      isFound := True
    else
      effect := effect^.next
  end;
  HasEffect := isFound
end;

procedure InflictDamage(character: Types.PCharRecord; damage: Word);
var
  overkill: Word;
  remaining: Word;
begin
  overkill := 0;
  remaining := 0;
  if character^.hitPoints >= damage then
    remaining := character^.hitPoints - damage
  else
    overkill := damage - character^.hitPoints;
  character^.hitPoints := remaining;
  if overkill > 29 then
    character^.status := C_Status.DEAD_STATUS
  else if overkill > 9 then
    character^.status := C_Status.COMATOSE
  else if overkill > 0 then begin
    character^.status := C_Status.DYING;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then
      character^.combatAddr^.overkill := overkill
  end else if remaining = 0 then
    character^.status := C_Status.UNCONSCIOUS
  else
    Exit;
  begin
    character^.enabled := 0;
    character^.hitPoints := 0;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      Dec(GDVars.teamCounts[character^.side]);
      character^.combatAddr^.initiative := 0
    end
  end
end;

function EnemyTeam(character: Types.PCharRecord): ShortInt;
begin
  if character^.side = C_Side.TEAM then
    EnemyTeam := C_Side.HOSTILE
  else
    EnemyTeam := C_Side.TEAM
end;

procedure CountTeams;
var character: Types.PCharRecord;
begin
  GDVars.teamCounts[C_Side.TEAM] := 0;
  GDVars.teamCounts[C_Side.HOSTILE] := 0;
  character := GDVars.partyHead;
  while character <> nil do begin
    if character^.enabled <> 0 then
      Inc(GDVars.teamCounts[character^.side]);
    character := character^.nextCharAddr
  end
end;

function CountTargets(character: Types.PCharRecord; range: Byte): Byte;
var
  numberTargets: Byte;
  numberMatching: Byte;
  index: Byte;
    { Unused in this version; see the other implementations of this routine. }
    targetSide: array[1..5] of Byte;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), range, 255,
                          CbtMap.GetIconSize(character));
  numberTargets := GDVars.pathTargetCount;
  numberMatching := 0;
  if numberTargets > 0 then begin
    for index := 1 to numberTargets do
      if GDVars.creatures[GDVars.pathTargets[index].slot]^.side = CharHlp.EnemyTeam(character) then begin
        Inc(numberMatching);
        Move(GDVars.pathTargets[index], GDVars.pathTargets[numberMatching], SizeOf(Types.TTarget))
      end;
    numberTargets := numberMatching;
    GDVars.pathTargetCount := numberMatching
  end;
  CountTargets := numberTargets;
  for index := 1 to numberTargets do
    GDVars.targetOrder[index] := GDVars.pathTargets[index].slot
end;

function CalcDistance(character, other: Types.PCharRecord): Byte;
{ only pathTargets' 72 entries are saved in it }
var savedTargets: array[1..255] of Types.TTarget;
    index: Byte;
begin
  Move(GDVars.pathTargets, savedTargets, SizeOf(GDVars.pathTargets));
  GDVars.combatArena^.distMode := 1;
  Pathing.BuildTargetList(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), 255, 255,
                          CbtMap.GetIconSize(character));
  GDVars.combatArena^.distMode := 0;
  index := 1;
  while (GDVars.creatures[GDVars.pathTargets[index].slot] <> other) and (index < GDVars.pathTargetCount) do
    Inc(index);
  CalcDistance := GDVars.pathTargets[index].distance div 2;
  Move(savedTargets, GDVars.pathTargets, SizeOf(GDVars.pathTargets))
end;

function EndActions(character: Types.PCharRecord): Boolean;
begin
  character^.combatAddr^.initiative := 0;
  character^.combatAddr^.guarding := 0;
  character^.combatAddr^.movement := 0;
  EndActions := True
end;

{ Draws a value right-aligned in five columns.
  @param(column The text column.)
  @param(row The text row.)
  @param(value The value.)
  @param(ship The ship it belongs to.)
  @param(mode VALUE_TONS adds ' tons', VALUE_FEET ' feet'; VALUE_SENSED shows '?' in LightRed for the enemy while
    enemyDetailsShown is 0.)
  @param(color -1 for White.)
  @param(background -1 for DarkGray.) }
procedure DrawShipValue(column, row: Byte; value: Integer; ship: Types.PShipRec; mode: Byte; color,
                        background: ShortInt);
var suffix: TString5;
    spaces: TString6;
    numeric: TString6;
    spaceCount: Byte;
begin
  spaces := '';
  if (mode = CharHlp.VALUE_SENSED) and (ship = GDVars.enemyShip) and (GDVars.enemyDetailsShown = 0) then begin
    numeric := '?';
    color := LightRed;
    background := DarkGray
  end else
    Str(value:0, numeric);
  spaceCount := 5 - Length(numeric);
  while spaceCount > 0 do begin
    spaces := spaces + ' ';
    Dec(spaceCount)
  end;
  if color < 0 then color := White;
  if background < 0 then background := DarkGray;
  if mode = CharHlp.VALUE_TONS then suffix := ' tons'
  else if mode = CharHlp.VALUE_FEET then suffix := ' feet'
  else suffix := '';
  TextRend.DisplayString(column, row, color, background, spaces + numeric + suffix)
end;

{ Counts a flash down by one, after a 70 ms delay while it is positive; a pending key ends the flash on the normal
  color.
  @param(flash The flash count, stepped in place.) }
procedure StepFlash(var flash: ShortInt);
begin
  if flash > 0 then
    if GameIo.InputPending then flash := flash and 1
    else Delay(70);
  Dec(flash)
end;

procedure DrawSystemMeter(ship: Types.PShipRec; slot: ShortInt; isFlashing: Boolean);
var
  x: Integer;
  y: Integer;
  width: Integer;
  maxWidth: Integer;
  scaled: Integer;
    primaryColor: ShortInt;
    secondaryColor: ShortInt;
    drawColor: ShortInt;
    background: ShortInt;
    flash: ShortInt;
begin
  if (ship = GDVars.enemyShip) and (GDVars.partyShip^.systemNow[C_Sys.SENSORS] = 0) then Exit;
  if ship = GDVars.partyShip then begin
    x := 29; y := slot * 2 + 1; width := 5; maxWidth := 80; background := DarkGray
  end else begin
    x := 3; y := slot + 12; width := 7; maxWidth := 80; background := Black
  end;
  if ship^.systemNow[slot] = 0 then begin
    primaryColor := LightRed; secondaryColor := Black
  end else begin
    secondaryColor := LightRed;
    if ship = GDVars.partyShip then primaryColor := LightCyan
    else primaryColor := LightGreen
  end;
  if ship = GDVars.partyShip then
    TextRend.DisplayString(x, y, primaryColor, background, GDConsts.systemShortNames[slot] + ':');
  if isFlashing then flash := 10 else flash := 0;
  repeat
    if (flash and 1) = 0 then drawColor := primaryColor
    else drawColor := secondaryColor;
    CharHlp.DrawShipValue(x + width, y, ship^.systemNow[slot], ship, CharHlp.VALUE_PLAIN, drawColor, background);
    CharHlp.StepFlash(flash)
  until flash < 0;
  if ship^.systemMax[slot] >= 100 then
    scaled := (((ship^.systemNow[slot] + 15) shr 4) * maxWidth) div (ship^.systemMax[slot] shr 4)
  else
    scaled := (ship^.systemNow[slot] * maxWidth)
           div ship^.systemMax[slot];
  if scaled < 0 then scaled := 0
  else if scaled >= maxWidth then scaled := maxWidth - 1;
  if ship = GDVars.partyShip then begin
    y := slot * 16 + 16; width := 232
  end else begin
    y := slot * 8 + 96; width := 120
  end;
  Mouse.HideMouse;
  x := width + scaled - 1;
  if scaled > 0 then begin
    Blit.Hline(width, x, y + 3, GDConsts.meterUpperColors[slot]);
    Blit.Hline(width, x, y + 4, GDConsts.meterLowerColors[slot])
  end;
  for x := scaled to maxWidth - 1 do begin
    if (x and 7) = 0 then primaryColor := DarkGray else primaryColor := Black;
    Blit.Vline(y + 3, y + 4, x + width, primaryColor)
  end;
  Mouse.ShowMouse
end;

{ Draws the ship's six system pictures and meters, over the panel grid for the party ship; for the enemy, 'Sensors
  Destroyed' while the party's are out.
  @param(ship The ship.) }
procedure DrawShipSystems(ship: Types.PShipRec);
var slot: Byte;
    tile: Word;
    pass: Byte;
    row: Byte;
    pictureBase: Byte;
begin
  if ship = GDVars.partyShip then begin
    row := 1;
    pictureBase := 17;
    for pass := 0 to 5 do begin
      TextRend.FillRect(29, row, 38, row, DarkGray);
      Inc(row);
      TextRend.FillRect(29, row, 38, row, Black);
      Mouse.HideMouse;
      for tile := 0 to 9 do
        Blit.Vline(row * 8, row * 8 + 7, tile * 8 + 232, DarkGray);
      Mouse.ShowMouse;
      Inc(row)
    end
  end else if GDVars.partyShip^.systemNow[C_Sys.SENSORS] = 0 then begin
    TextRend.FillRect(1, 12, 24, 17, DarkGray);
    TextRend.DisplayString(4, 14, LightRed, DarkGray, 'Sensors Destroyed');
    Exit
  end else
    pictureBase := 23;
  Mouse.HideMouse;
  for GDVars.loopIndex := 0 to 5 do
    Blit.ShowPic(GDConsts.shipPictures[GDVars.loopIndex + pictureBase].x,
                 GDConsts.shipPictures[GDVars.loopIndex + pictureBase].y,
                 GDVars.shipPictureBuffers[GDVars.loopIndex + pictureBase]);
  Mouse.ShowMouse;
  for slot := 0 to SizeOf(ship^.systemNow) div SizeOf(Integer) - 1 do
    CharHlp.DrawSystemMeter(ship, slot, False)
end;

procedure DrawShipSceneText;
var displayRange: Byte;
begin
  TextRend.DisplayString(1, 1, LightRed, Black, GDConsts.maneuverNames[Byte(GDVars.enemyRetreating)]);
  if GDVars.shipCombatRange >= 0 then
    displayRange := GDVars.shipCombatRange
  else
    displayRange := 0;
  TextRend.DisplayString(1, 2, LightRed, Black, 'Range: ' + TextRend.ByteToString(displayRange))
end;

procedure RefreshShipScene;
begin
  Mouse.HideMouse;
  if GDVars.enemyShip <> nil then begin
    Blit.BlitTileClipped(GDConsts.shipPictures[0].x, GDConsts.shipPictures[0].y, 0, 0, GDVars.shipPictureBuffers[0],
                         GDVars.viewPicture);
    Blit.BlitTileClipped(0, 0, 0, 0, GDVars.bigPicture, GDVars.viewPicture);
    Blit.FlushView;
    CharHlp.DrawShipSceneText;
    CharHlp.DrawShipSystems(GDVars.enemyShip)
  end else
    CharHlp.DrawShipDetails(GDVars.partyShip, True);
  Mouse.ShowMouse
end;

procedure DrawShipWeapons(ship: Types.PShipRec; isDetailsList: Boolean; row: ShortInt);
var index: ShortInt;
    statusText: Types.TString3;
    color: Byte;
    drawColor: Byte;
    column: Byte;
    startRow: Byte;
    lastIndex: Byte;
    flash: ShortInt;
    valueMode: Byte;
begin
  if (row < 0) and not isDetailsList then
    TextRend.FillRect(29, 14, 38, 17, DarkGray);
  valueMode := CharHlp.VALUE_PLAIN;
  if isDetailsList then begin
    column := 1;
    startRow := 14;
    if ship = GDVars.partyShip then
      lastIndex := 3
    else begin
      lastIndex := 3;
      valueMode := CharHlp.VALUE_SENSED
    end
  end else begin
    column := 29;
    startRow := 15;
    lastIndex := 2
  end;
  TextRend.DisplayString(column, startRow - 1, LightGreen, DarkGray, 'Weapons:');
  if isDetailsList then begin
    TextRend.DisplayString(column + 12, startRow - 1, LightGreen, DarkGray, 'Ammo');
    TextRend.DisplayString(column + 17, startRow - 1, LightGreen, DarkGray, 'Reloads')
  end;
  for index := 0 to lastIndex do begin
    with ship^.slots[index] do begin
    if ((kind and C_Ship.KIND_MASK) > 0) and (maximum > 0) then begin
      if maximum <> current then color := Yellow
      else color := LightGreen;
      if isDetailsList then begin
        CharHlp.DrawShipValue(column + 10, startRow + index, ammo, ship, valueMode, -1, -1);
        CharHlp.DrawShipValue(column + 16, startRow + index, reloads, ship, valueMode, -1, -1)
      end;
      Str(current:0, statusText);
      TextRend.RightAlignString(statusText, 2);
      if row = index then flash := 10
      else flash := 0;
      repeat
        if (flash and 1) = 0 then drawColor := color
        else drawColor := LightRed;
        TextRend.DisplayString(column, startRow + index, drawColor, DarkGray,
                               GDConsts.weaponShortNames[kind and C_Ship.KIND_MASK]);
        TextRend.DisplayString(column + 8, startRow + index, drawColor, DarkGray, statusText);
        CharHlp.StepFlash(flash)
      until flash < 0
    end
    end
  end;
  Blit.ShowPic(GDConsts.shipPictures[16].x, GDConsts.shipPictures[16].y, GDVars.shipPictureBuffers[16])
end;

procedure DisplayNoncombatInterface;
begin
  GDVars.portraitPending := 1;
  GDVars.canClickParty := GDVars.interfaceState in [C_Ifc.MAIN_MENU, C_Ifc.IN_SHOP, C_Ifc.VIEW_3D,
                                                    C_Ifc.POST_COMBAT, C_Ifc.PICTURE_VIEW];
  case GDVars.interfaceState of
    C_Ifc.MAIN_MENU: Border.DrawWindowFrame(1);
    C_Ifc.IN_SHOP: begin
      if GDVars.exploreFrameRedraw <> 0 then
        Border.DrawExploreFrame;
      Portrait.DisplayImageBuf(3, 3, True, 0);
      MenuCore.DisplayParty(GDVars.currentCharacter);
      CharHlp.PrintMiscInfo
    end;
    C_Ifc.VIEW_3D: begin
      Border.DrawExploreFrame;
      MapView.DisplayMapView;
      MenuCore.DisplayParty(GDVars.currentCharacter);
      CharHlp.PrintMiscInfo;
      GDVars.refreshState := 0
    end;
    C_Ifc.WILDERNESS: Border.ScreenText;
    C_Ifc.PICTURE_VIEW: begin
      Border.DrawExploreFrame;
      MenuCore.DisplayParty(GDVars.currentCharacter)
    end;
    C_Ifc.POST_COMBAT: begin
      Border.DrawExploreFrame;
      Portrait.LoadAnimation('PIC', 105, 0);
      Portrait.DisplayImageBuf(3, 3, True, 0);
      MenuCore.DisplayParty(GDVars.currentCharacter)
    end;
    C_Ifc.SHIP: begin
      Border.DrawShipFrame;
      CharHlp.RefreshShipScene;
      CharHlp.DrawShipSystems(GDVars.partyShip);
      CharHlp.DrawShipWeapons(GDVars.partyShip, False, -1);
      GDVars.windowTextPending := 0
    end;
    C_Ifc.ORBIT_MAP: begin
      OrbitMap.EnterOrbitMap;
      MapView.DisplayMapView;
      OrbitMap.PaintOrbitMap
    end
  end
end;

procedure PrintMiscInfo;
var
  x: Byte;
  y: Byte;
    hourText: String[4];
    minuteText: String[4];
    infoText: Types.TString40;
    direction: Byte;
    hasFixedReadout: Boolean;
begin
  if GDVars.interfaceState = C_Ifc.WILDERNESS then Exit;
  infoText := '';
  if GDVars.zone0^.readoutX = C_Map.NO_READOUT then
    hasFixedReadout := False
  else
    hasFixedReadout := True;
  if hasFixedReadout then begin
    x := GDVars.zone0^.readoutX;
    y := GDVars.zone0^.readoutY
  end else begin
    x := GDVars.partyPosition.mapX;
    y := GDVars.partyPosition.mapY
  end;
  hourText := TextRend.WordToString(GDVars.zone0^.clock.hour);
  if Length(hourText) < 2 then hourText := '0' + hourText;
  minuteText := TextRend.WordToString(GDVars.zone0^.clock.turn * 10 + GDVars.zone0^.clock.minute);
  if Length(minuteText) < 2 then minuteText := '0' + minuteText;
  infoText := TextRend.ByteToString(x) + ',' + TextRend.ByteToString(y) + ' ';
  if GDVars.zone0^.areaType <> 0 then
    direction := GDVars.zone0^.directionOffset * 2 + GDVars.partyPosition.facing
  else
    direction := GDVars.zone0^.directionOffset + GDVars.partyPosition.facing;
  direction := direction and 7;
  infoText := infoText + GDConsts.directionNames[direction] + ' ';
  infoText := infoText + hourText + ':' + minuteText;
  if GDVars.isDebugMode then infoText := infoText + '*';
  if GDVars.interfaceState = C_Ifc.CAMPING then
    infoText := infoText + ' camping'
  else if (GDVars.zone1^.searchFlags and C_Search.SEARCHING) > 0 then
    infoText := infoText + ' search';
  Border.ClearBox(17, 15, 38, 15);
  TextRend.DisplayString(17, 15, LightGreen, Black, infoText)
end;

procedure DisplayCombatInterface;
begin
  CbtMap.SetCombatPalette;
  Border.DrawCombatFrame;
  CbtMap.ScrollView(GDVars.combatArena^.viewOriginX + 3, GDVars.combatArena^.viewOriginY + 3, 255, C_Dir.CENTER)
end;

function HasAreaWeapon(character: Types.PCharRecord): Boolean;
begin
  HasAreaWeapon := (character^.equipped[C_Equip.WEAPON] <> nil) and
    (GDVars.itemTypes[Types.PItemRec(character^.equipped[C_Equip.WEAPON])^.template.itemType].weaponClass >=
     C_WClass.FIRST_AREA_WEAPON)
end;

function HasLoadedAreaWeapon(character: Types.PCharRecord): Boolean;
begin
  HasLoadedAreaWeapon := CharHlp.HasAreaWeapon(character) and
      (Types.PItemRec(character^.equipped[C_Equip.WEAPON])^.template.quantity > 0)
end;

function HasRangedWeapon(character: Types.PCharRecord): Boolean;
begin
  HasRangedWeapon := (character^.equipped[C_Equip.WEAPON] <> nil) and
    (GDVars.itemTypes[Types.PItemRec(character^.equipped[C_Equip.WEAPON])^.template.itemType].range > 1)
end;

function FindDamagingRangedWeapon(character: Types.PCharRecord; var selected: Types.PItemRec): Boolean;
var weapon: Types.PItemRec;
    isFound: Boolean;
begin
  isFound := False;
  weapon := character^.equipped[C_Equip.WEAPON];
  if (weapon^.template.quantity > 0) and
      (GDVars.itemTypes[weapon^.template.itemType].weaponClass > C_WClass.MELEE) then begin
    selected := weapon;
    isFound := True
  end;
  FindDamagingRangedWeapon := isFound
end;

function MeetsSkillPrerequisite(character: Types.PCharRecord; skillId: Byte): Boolean;
var isEligible: Boolean;
begin
  isEligible := False;
  with character^ do
    case skillId of
      C_Skill.REPAIR_ENGINE:
        if skillLevels[C_Skill.REPAIR_MECHANICAL] >=
            C_Skill.REPAIR_ENGINE_NEEDS_MECHANICAL then isEligible := True;
      C_Skill.REPAIR_LIFE_SUPPORT:
        if (skillLevels[C_Skill.REPAIR_ELECTRICAL] >= C_Skill.REPAIR_LIFE_SUPPORT_NEEDS_ELECTRICAL) and
            (skillLevels[C_Skill.REPAIR_MECHANICAL] >= C_Skill.REPAIR_LIFE_SUPPORT_NEEDS_MECHANICAL) then
          isEligible := True;
      C_Skill.REPAIR_HULL:
        if skillLevels[C_Skill.REPAIR_MECHANICAL] >= C_Skill.REPAIR_HULL_NEEDS_MECHANICAL then isEligible := True;
      C_Skill.JURY_RIG:
        if (skillLevels[C_Skill.REPAIR_ELECTRICAL] >= C_Skill.JURY_RIG_NEEDS_ELECTRICAL) and
            (skillLevels[C_Skill.REPAIR_MECHANICAL] >= C_Skill.JURY_RIG_NEEDS_MECHANICAL) then
          isEligible := True;
      C_Skill.REPAIR_COMPUTER:
        if skillLevels[C_Skill.REPAIR_ELECTRICAL] >=
            C_Skill.REPAIR_COMPUTER_NEEDS_ELECTRICAL then isEligible := True;
      C_Skill.FIRST_MEDICAL_SKILL..C_Skill.LAST_MEDICAL_SKILL:
        if career = C_Career.MEDIC then
          case skillId of
            C_Skill.TREAT_SERIOUS:
              if skillLevels[C_Skill.TREAT_LIGHT] >=
                  C_Skill.TREAT_SERIOUS_NEEDS_TREAT_LIGHT then isEligible := True;
            C_Skill.TREAT_CRITICAL:
              if skillLevels[C_Skill.TREAT_SERIOUS] >=
                  C_Skill.TREAT_CRITICAL_NEEDS_TREAT_SERIOUS then isEligible := True;
            C_Skill.TREAT_POISONING:
              if skillLevels[C_Skill.DIAGNOSE] >= C_Skill.TREAT_POISONING_NEEDS_DIAGNOSE then isEligible := True;
            { the else below belongs to the case, not this if }
            C_Skill.TREAT_DISEASE: begin
              if skillLevels[C_Skill.DIAGNOSE] >= C_Skill.TREAT_DISEASE_NEEDS_DIAGNOSE then isEligible := True
            end else isEligible := True
          end;
      C_Skill.COMPOSITION:
        if (skillLevels[C_Skill.SINGING] >= CharHlp.COMPOSITION_NEEDS_ARTS) or
            (skillLevels[C_Skill.PLAY_INSTRUMENT] >= CharHlp.COMPOSITION_NEEDS_ARTS) or
            (skillLevels[C_Skill.LITERATURE] >= CharHlp.COMPOSITION_NEEDS_ARTS) then isEligible := True;
      C_Skill.PROGRAMMING:
        if skillLevels[C_Skill.MATHEMATICS] >= C_Skill.PROGRAMMING_NEEDS_MATHEMATICS then isEligible := True;
      C_Skill.ASTROGATION:
        if (skillLevels[C_Skill.ASTRONOMY] >= C_Skill.ASTROGATION_NEEDS_ASTRONOMY) and
            (skillLevels[C_Skill.MATHEMATICS] >= C_Skill.ASTROGATION_NEEDS_MATHEMATICS) then
          isEligible := True;
      C_Skill.NAVIGATION:
        if (skillLevels[C_Skill.ASTRONOMY] >= C_Skill.NAVIGATION_NEEDS_ASTRONOMY) and
            (skillLevels[C_Skill.MATHEMATICS] >= C_Skill.NAVIGATION_NEEDS_MATHEMATICS) then
          isEligible := True;
      C_Skill.ANIMAL_TRAINING:
        if skillLevels[C_Skill.BEFRIEND_ANIMAL] >=
            C_Skill.ANIMAL_TRAINING_NEEDS_BEFRIEND_ANIMAL then isEligible := True;
      { likewise }
      C_Skill.PLANETARY_SURVIVAL: begin
        if skillLevels[C_Skill.PLANETOLOGY] >=
            C_Skill.PLANETARY_SURVIVAL_NEEDS_PLANETOLOGY then isEligible := True
      end else isEligible := True
    end;
  MeetsSkillPrerequisite := isEligible
end;

function SkillAbilityScore(character: Types.PCharRecord; skillId: Byte): ShortInt;
begin
  if CharHlp.MeetsSkillPrerequisite(character, skillId) then
    SkillAbilityScore := character^.abilities[GDConsts.skillDefinitions[ShortInt(skillId)].group]
  else
    SkillAbilityScore := 0
end;

function SkillValue(character: Types.PCharRecord; skillId: Byte): Byte;
begin
  if (character^.skillLevels[ShortInt(skillId)] > 0) and (character^.enabled <> 0) then
    SkillValue := CharHlp.SkillAbilityScore(character, skillId) + character^.skillLevels[ShortInt(skillId)]
  else
    SkillValue := 0
end;

function SelectSkillCharacter(skillId, scale: Byte; isWholeParty: Boolean; var character: Pointer): Byte;
var value: Word;
    isDone: Boolean;
    score: Integer;
    bestScore: Integer;
    bestCharacter: Pointer;
begin
  bestScore := -10000;
  isDone := False;
  if isWholeParty then
    character := GDVars.partyHead
  else if character = nil then
    character := GDVars.currentCharacter;
  while (character <> nil) and not isDone do begin
    value := CharHlp.SkillValue(character, skillId);
    case scale of
      0: value := value shl 1 shl 1;
      1: value := value shl 1;
      3: value := value shr 1;
      4: value := value shr 1 shr 1
    end;
    score := value - CharHlp.RollDice(1, 100);
    if score > bestScore then begin
      bestScore := score;
      bestCharacter := character
    end;
    character := Types.PCharRecord(character)^.nextCharAddr;
    isDone := not isWholeParty
  end;
  if bestScore >= 0 then begin
    if bestScore < value div 2 then
      score := 2
    else
      score := 3
  end else begin
    bestScore := Abs(bestScore);
    if bestScore > value then
      score := 0
    else
      score := 1
  end;
  character := bestCharacter;
  SelectSkillCharacter := score
end;

function RollDice(count, sides: Byte): Byte;
var
  index: Byte;
  total: Byte;
begin
  total := 0;
  if count > 0 then
    for index := 1 to count do
      Inc(total, Random(sides) + 1);
  RollDice := total
end;

function PercentileRoll(percent: Byte): Boolean;
begin
  PercentileRoll := percent > Random(100)
end;

function MinimumWord(first, second: Word): Word;
begin
  MinimumWord := first;
  if second < first then MinimumWord := second
end;

procedure ProcessDyingCharacters;
var character: Types.PCharRecord;
    count: Byte;
    verb: String[6];
begin
  count := 0;
  character := GDVars.partyHead;
  while character <> nil do begin
    if (character^.status = C_Status.DYING) and (character^.combatAddr^.notPcNpc = 0) then begin
      Inc(character^.combatAddr^.overkill);
      if character^.combatAddr^.overkill > 9 then begin
        character^.status := C_Status.COMATOSE;
        CharHlp.PrintBottomLine(character^.name + ' slips into a coma!')
      end else
        Inc(count)
    end;
    character := character^.nextCharAddr
  end;
  if count > 1 then verb := 's are'
  else verb := ' is';
  if count > 0 then
    CharHlp.PrintBottomLine('Your Teammate' + verb + ' Dying!')
end;

function CanShipMove(ship: Types.PShipRec): Boolean;
begin
  CanShipMove := (ship^.systemNow[C_Sys.CONTROL] > 0) and (ship^.systemNow[C_Sys.FUEL] > 0) and
    (ship^.systemNow[C_Sys.ENGINES] > 0)
end;

function ShipSpeed(ship: Types.PShipRec): ShortInt;
var speed: ShortInt;
begin
  if not CharHlp.CanShipMove(ship) then
    speed := 0
  else begin
    speed := ship^.baseMovement;
    if ship = GDVars.partyShip then
      Inc(speed, GDVars.playerBoosts)
    else
      Inc(speed, GDVars.enemyBoosts);
    if ship^.systemMax[C_Sys.HULL] shr 1 > ship^.systemNow[C_Sys.HULL] then
      speed := speed shr 1;
    if ship^.systemMax[C_Sys.ENGINES] shr 2 > ship^.systemNow[C_Sys.ENGINES] then
      Dec(speed, 3)
    else if ship^.systemMax[C_Sys.ENGINES] shr 1 > ship^.systemNow[C_Sys.ENGINES] then
      Dec(speed);
    if speed < 1 then speed := 1
  end;
  ShipSpeed := speed
end;

procedure DrawShipDetails(ship: Types.PShipRec; isEnemyShown: Boolean);
var color: ShortInt;
begin
  GDVars.enemyDetailsShown := Ord(isEnemyShown and (GDVars.partyShip^.systemNow[C_Sys.SENSORS] > 0));
  TextRend.FillRect(1, 1, 24, 17, DarkGray);
  if ship = GDVars.partyShip then color := LightCyan else color := Yellow;
  TextRend.DisplayString(1, 1, color, DarkGray, 'name:');
  TextRend.DisplayString(10, 1, White, DarkGray, ship^.name);
  TextRend.DisplayString(1, 2, color, DarkGray, 'type:');
  TextRend.DisplayString(10, 2, White, DarkGray, GDConsts.shipTypeNames[ship^.shipType]);
  TextRend.DisplayString(1, 3, color, DarkGray, 'race:');
  TextRend.DisplayString(10, 3, White, DarkGray, GDConsts.raceNames[ship^.race]);
  TextRend.DisplayString(1, 4, color, DarkGray, 'tonnage:');
  CharHlp.DrawShipValue(10, 4, ship^.tonnage, ship, CharHlp.VALUE_TONS, -1, -1);
  TextRend.DisplayString(1, 5, color, DarkGray, 'length:');
  CharHlp.DrawShipValue(10, 5, ship^.length, ship, CharHlp.VALUE_FEET, -1, -1);
  TextRend.DisplayString(1, 6, color, DarkGray, 'width:');
  CharHlp.DrawShipValue(10, 6, ship^.width, ship, CharHlp.VALUE_FEET, -1, -1);
  TextRend.DisplayString(1, 7, color, DarkGray, 'cargo:');
  CharHlp.DrawShipValue(10, 7, ship^.cargo, ship, CharHlp.VALUE_TONS, -1, -1);
  TextRend.DisplayString(1, 9, color, DarkGray, 'AC:');
  CharHlp.DrawShipValue(7, 9, ShortInt(ship^.armorClass), ship, CharHlp.VALUE_SENSED, -1, -1);
  TextRend.DisplayString(13, 9, color, DarkGray, 'crew:');
  CharHlp.DrawShipValue(20, 9, ship^.crew, ship, CharHlp.VALUE_SENSED, -1, -1);
  TextRend.DisplayString(1, 10, color, DarkGray, 'speed:');
  CharHlp.DrawShipValue(7, 10, CharHlp.ShipSpeed(ship), ship, CharHlp.VALUE_SENSED, -1, -1);
  TextRend.DisplayString(13, 10, color, DarkGray, 'react:');
  CharHlp.DrawShipValue(20, 10, ship^.reaction, ship, CharHlp.VALUE_SENSED, -1, -1);
  if ship = GDVars.enemyShip then begin
    TextRend.DisplayString(1, 11, color, DarkGray, 'range:');
    if GDVars.shipCombatRange < 1 then
      TextRend.DisplayString(10, 11, Yellow, DarkGray, 'ramming')
    else if GDVars.shipCombatRange < 3 then
      TextRend.DisplayString(10, 11, White, DarkGray, 'short')
    else if GDVars.shipCombatRange < 5 then
      TextRend.DisplayString(10, 11, White, DarkGray, 'medium')
    else if GDVars.shipCombatRange < 7 then
      TextRend.DisplayString(10, 11, White, DarkGray, 'long')
    else
      TextRend.DisplayString(10, 11, White, DarkGray, 'extreme')
  end else begin
    TextRend.DisplayString(1, 11, color, DarkGray, 'medical supplies:');
    CharHlp.DrawShipValue(20, 11, GDVars.zone0^.medicalSupplies, ship, CharHlp.VALUE_SENSED, -1, -1)
  end;
  CharHlp.DrawShipWeapons(ship, True, -1)
end;

begin
end.
