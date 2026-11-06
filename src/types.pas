{ The types several units use. The unit holds no storage: every typed constant is GDConsts', every variable GDVars'. }
{$F+}
{$A-}
unit Types;

interface

type
  PCombatRec = ^TCombatRec;
  PCharRecord = ^TCharRecord;
  TCombatRec = record
    active: Byte;
    initiative: ShortInt;
    attackPhase: Byte;
    movement: Byte;
    guarding: Byte;
    priority: Byte;
    madeAttack: Byte;
    direction: Byte;
    target: PCharRecord;
    overkill: Byte;
    directionCount: Byte;
    directionTotal: Byte;
    notPcNpc: Byte;
    fleeing: Byte;
    approach: Byte
  end;
  { a target choice: the creature, nil if none, and the arena cell chosen }
  TAimTarget = packed record
    character: PCharRecord;
    x: Byte;
    y: Byte;
    { unused; the aim routines clear and fill the whole record }
    yTail: Byte
  end;
  PItemType = ^TItemType;
  { one ITEMS row, a row of itemTypes: what every item of one type shares }
  TItemType = record
    { where it is readied: 0 weapon, 1 armor, 2..7 other gear }
    slot: Byte;
    { attacks per round times two; CbtActs and CombatAi halve it }
    attacksDoubled: Byte;
    { 0 melee, above 0 uses ammunition, 7..9 area; armor: its armor class + 50 }
    weaponClass: Byte;
    { non-zero: readying it in combat ends the turn }
    heavy: Byte;
    { damage dice; the item debug screen's 'dice' }
    diceCount: Byte;
    { the item debug screen's 'sides' }
    diceSides: Byte;
    { the item debug screen's 'adds' }
    damageBonus: ShortInt;
    { reach in cells; above 1 is ranged, and ViewChar counts 0 and 255 as 1 }
    range: Byte;
    { non-zero: the item goes when its quantity runs out }
    consumable: Byte
  end;
  PMenuNode = ^TMenuNode;
  { one line of a list MenuCore's MenuVertical shows; an item's first 46 bytes have the same shape, so an item list is
    shown in place }
  TMenuNode = record
    name: String[40];
    { non-zero: drawn as a label line, not selectable }
    menuLabel: Byte;
    next: PMenuNode
  end;
  PItemRec = ^TItemRec;
  PEffectRec = ^TEffectRec;
  TIconSequence = array[0..15] of Byte;
  { a row of itemTemplates, and TItemRec.template: the fields a new item copies }
  TItemTemplate = record
    { a row of itemTypes; $FF marks an empty template }
    itemType: Byte;
    nameIds: array[1..3] of Byte;
    plus: ShortInt;
    { the item debug screen's 'plussave' }
    saveBonus: ShortInt;
    { C_Item.NOT_JOINABLE, C_Item.NOT_TREASURE, C_Item.READIED }
    flags: Byte;
    { the item debug screen's 'german' }
    unidentifiedMask: Byte;
    weight: Word;
    quantity: Byte;
    value: Word;
    { the item debug screen's 'special 1'..'special 3' }
    special: array[1..3] of Byte
  end;
  TItemRec = record
    name: String[40];
    { non-zero: MenuCore's menus draw the entry as a label line }
    menuLabel: Byte;
    next: PItemRec;
    { the fields a new item copies from GDVars.itemTemplates }
    template: TItemTemplate
  end;
  TEffectRec = record
    effectId: Byte;
    duration: Word;
    strength: Byte;
    { non-zero: FxEngine's RemoveEffect calls the effect's handler }
    onRemove: Byte;
    next: PEffectRec
  end;
  { a character or creature, as EclMenu's InitCreature allocates it }
  TCharRecord = record
    case Byte of
      0: (name: String[15];
          strength: Byte;
          dexterity: Byte;
          constitution: Byte;
          intelligence: Byte;
          intelligenceTail: array[$014..$016] of Byte;
          currentAbilities: array[0..6] of Byte;
          saves: array[0..7] of Byte;
          gender: ShortInt;
          race: ShortInt;
          career: ShortInt;
          level: ShortInt;
          levelTail: Byte;
          credits: LongInt;
          experience: LongInt;
          baseCombat: Byte;
          iconDimensions: Byte;
          iconDimensionsTail: Byte;
          baseMovement: Byte;
          baseArmorClass: Byte;
          age: Byte;
          ageTail: array[$039..$03A] of Byte;
          baseScale: Byte;
          scale: Byte;
          unarmedRolls: array[1..2] of Byte;
          unarmedDice: array[1..2] of Byte;
          unarmedModifiers: array[1..2] of ShortInt;
          unarmedModifiersTail: array[$043..$044] of Byte;
          hpMax: Word;
          hpMaxTail: Byte;
          armorFlags: Byte;
          armorFlagsTail: array[$049..$04B] of Byte;
          skillLevels: array[0..84] of Byte;
          skillLevelsTail: array[$0A1..$0B1] of Byte;
          xpAward: Word;
          alternateItemsAddr: PItemRec;
          icon: Byte;
          orderNumber: Byte;
          weaponSpecializations: array[1..10] of Byte;
          iconSequence: TIconSequence;
          status: Byte;
          enabled: Byte;
          hostile: Byte;
          quickfight: Byte;
          attackBonus: Byte;
          armorClass: array[0..1] of Byte;
          attacks: array[1..2] of Byte;
          currentRolls: array[1..2] of Byte;
          currentDice: array[1..2] of Byte;
          currentModifiers: array[1..2] of ShortInt;
          hitPoints: Word;
          currentMovement: Byte;
          currentMovementTail: Byte;
          npc: Byte;
          encumbrance: Word;
          { ShipCbt sets and tests it }
          activeFlag: Byte;
          equipped: array[0..1] of Pointer;
          combatAddr: PCombatRec;
          itemsAddr: PItemRec;
          effectsAddr: PEffectRec;
          nextCharAddr: PCharRecord);
      1: (raw: array[$000..$102] of Byte);
      2: (sideLead: array[$000..$0D5] of Byte;
          side: ShortInt);
      3: (hpCurLead: array[$000..$0E2] of Byte;
          hpCur: Byte);
      4: (abilitiesLead: array[$000..$00F] of Byte;
          abilities: array[0..6] of Byte);
  end;
  PShipRec = ^TShipRec;
  { a weapon or system mount }
  TShipSlot = record
    { and $7F: the weapon or system }
    kind: Byte;
    maximum: Byte;
    { how many of maximum still work }
    current: Byte;
    currentTail: Byte;
    ammo: Byte;
    reloads: Byte
  end;
  { CharHlp's ship screen labels the fields }
  TShipRec = record
    name: String[15];
    tonnage: Word;
    length: Word;
    width: Word;
    { Hull, Sensors, Control systems, Life support, Fuel, Engines }
    systemNow: array[0..5] of Integer;
    systemMax: array[0..5] of Integer;
    cargo: Word;
    crew: Word;
    { CharHlp's 'AC:' prints it as ShortInt }
    armorClass: Byte;
    alternateSkill: Byte;
    systemSkill: Byte;
    systemValue: Byte;
    baseMovement: Byte;
    reaction: ShortInt;
    maneuver: Byte;
    shipType: Byte;
    race: ShortInt;
    raceTail: Byte;
    slots: array[0..7] of TShipSlot
  end;
  TPoint = record x: Byte; y: Byte end;
  POrbitView = ^TOrbitView;
  { zone 0 from orbitBodies on, where GameInit points orbitView }
  TOrbitView = record
    { the bodies OrbitMap draws: [0..4] one per orbit, [5..12] orbit 4's eight others }
    positions: array[0..12] of TPoint;
    positionsTail: array[$1A..$33] of Byte;
    { Explore adds the turn's ticks, wraps at $20 }
    tick: Byte;
    { zone 0's shipCombatOutcome, which ShipCbt sets }
    shipCombatOutcome: Byte;
    { places the bodies; Explore counts it down mod $E0 }
    phase: Byte;
    phaseTail: Byte;
    { FIRST_ROCKET_ICON..LAST_ROCKET_ICON, the rocket's heading }
    rocketIcon: Byte;
    rocketX: Byte;
    rocketY: Byte
  end;
  { zone 0's game clock, one cell per unit of GameTime's, TIME_SEGMENT..TIME_YEAR, each clockUnitScale of the one
    before }
  TGameClock = record
    case Byte of
      { by GBVM address, a cell per unit from GameTime's GBVM_CLOCK }
      0: (units: array[$4BC6..$4BCC] of Byte);
      1: (segment: Byte;
          minute: Byte;
          turn: Byte;
          hour: Byte;
          day: Byte;
          month: Byte;
          year: Byte)
  end;
  PZone0 = ^TZone0;
  { GBVM zone 0 }
  TZone0 = record
    case Byte of
      { indexed by GBVM address }
      0: (cells: array[$4B00..$4EFF] of Byte);
      1: (medicalDoneLead: array[$000..$07F] of Byte;
          medicalDone: Byte;
          medicalDoneTail: array[$081..$084] of Byte;
          { where OrbitMap last drew each body, reached through orbitView }
          orbitBodies: array[0..12] of TPoint;
          orbitBodiesTail: array[$09F..$0A4] of Byte;
          { 1..4 Mercury, Venus, Earth, Mars; above 4 the asteroids }
          planet: Byte;
          extendedPictureMode: Byte;
          extendedPictureModeTail: array[$0A7..$0A9] of Byte;
          preserveHostiles: Byte;
          preserveHostilesTail: array[$0AB..$0B5] of Byte;
          { 0..4, Novice to Ace }
          difficulty: Byte;
          terrain: Byte;
          listTransferState: Byte;
          listTransferStateTail: Byte;
          { 0 enemy destroyed or boarded, 1 party ship lost or enemy gone }
          shipCombatOutcome: Byte;
          shipCombatOutcomeTail: array[$0BB..$0C2] of Byte;
          partyX: Byte;
          partyY: Byte;
          { the GEO record View3D.Load3DMap loaded }
          mapId: Byte;
          { GameTime advances it through cells; CharHlp's position line shows the hour, turn and minute }
          clock: TGameClock;
          clockTail: array[$0CD..$0E4] of Byte;
          { EclMenu's EclInit clears it as a script loads }
          antimagic: Byte;
          { CombatSt's LoadCombatTileSet picks the arena tiles by it }
          areaType: Byte;
          targetGateA: Byte;
          targetGateB: Byte;
          targetGateBTail: array[$0E9..$0EF] of Byte;
          prevX: Byte;
          prevY: Byte;
          stateValue: Byte;
          stateValueTail: array[$0F3..$0FA] of Byte;
          { non-zero: no area map here }
          areaLock: Byte;
          { 0..9 }
          messageSpeed: Byte;
          skyIndexLo: Byte;
          skyIndexHi: Byte;
          { bit 1 pictures, bit 0 animations }
          displayOptions: Byte;
          { EclMenu's EclInit clears them as a script loads, unless a saved game has just loaded }
          entryBytes: array[$4C00..$4C1F] of Byte;
          entryBytesTail: array[$120..$162] of Byte;
          medicalSupplies: Byte;
          medicalSuppliesTail: array[$164..$1F5] of Byte;
          loopCurrent: Byte;
          loopLimit: Byte;
          loopLimitTail: array[$1F8..$1FC] of Byte;
          { $FF: the status line shows the party's square }
          readoutX: Byte;
          readoutY: Byte;
          directionOffset: Byte;
          { the party's ship, GameInit loads it }
          ship: TShipRec;
          { ShipCbt keeps the enemy ship here }
          savedStores: array[0..5] of Integer;
          savedShipType: Byte;
          savedCrewLo: Byte;
          savedCrewHi: Byte;
          savedSystem: Byte;
          { 1 after a boarding; at 2 PostCbt repairs the ship }
          postCombatMode: Byte;
          savedWeapons: array[0..3] of Byte;
          weaponTotal: Byte;
          postCombatFlag: Byte;
          postCombatFlagTail: array[$283..$290] of Byte;
          { per ship type, the ships SaveLoad has named }
          shipNameCounts: array[$4D91..$4D95] of Byte;
          shipNameCountsTail: array[$296..$3FF] of Byte);
  end;
  { GBVM zones 1..3, one byte per GBVM address (zone 1 through its cells): each starts at its zone's GBVM base, as
    TZone0.cells does, and ends where EclMenu's GbvmZone ends the zone. GameInit allocates and clears each by SizeOf. }
  PZone1 = ^TZone1;
  { GBVM zone 1, saved with the game }
  TZone1 = record
    case Byte of
      { indexed by GBVM address: EclMenu's ReadGbvm, WriteGbvm and EclInit }
      0: (cells: array[$7C00..$7FFF] of Byte);
      1: (trainingMaskLead: array[$000..$2A7] of Byte;
          { CharGen's main menu offers Train Character while it is non-zero; CharGen holds it at $FF through its free
            training and clears it as the team sets out }
          trainingMask: Byte;
          trainingMaskTail: array[$2A9..$2BF] of Byte;
          { how far off ECL's SETUP MONSTER asks for the monster; EclVm stores it }
          monsterMaxDistance: Byte;
          { how far off the encountered monster shows: EclVm sets and caps it, EclMenu's MaxMonsterDist sets 2 when zone
            0's areaType is 0, and CombatSt spaces the sides by it }
          monsterDistance: Byte;
          monsterDistanceTail: array[$2C2..$2C5] of Byte;
          { the fight's morale base: CombatAi's morale check tests morale against 100 less it, and CombatSt gives it,
            NON_PLAYER_FLAG set, as the npc byte of team-side creatures past partyCount that have none }
          moraleBase: Byte;
          { how the last combat ended, a Result* value PostCbt sets }
          combatResult: Byte;
          { PostCbt clears it and counts in each creature it removes that can no longer act }
          monstersDefeated: Byte;
          { $FF cancels the next move once, which Explore's ResolveMovement then clears; EclVm's LOAD FILES clears it
            too }
          moveBlocked: Byte;
          { C_Search.SEARCHING and Explore's LOOK_PENDING: Explore sets them, CharHlp's position line shows ' search' }
          searchFlags: Byte;
          { the sides whose initiative is 6 less, bit side: CbtActs reads it, Combat clears it each round once the
            combatants are set up }
          sideMask: Byte;
          sideMaskTail: array[$2CC..$2D1] of Byte;
          { ECL's rest timing and interruption chance; EclMenu's EclInit clears both }
          restSafeTime: Byte;
          restInterruptChance: Byte;
          restInterruptChanceTail: Byte;
          { 1 when Explore's MoveForward finds the step ahead leads off the map's edge; EclVm's NewEclDone clears it }
          hasLeftMap: Byte;
          hasLeftMapTail: array[$2D6..$2E2] of Byte;
          { 1 keeps the fallen hostiles' items out of PostCbt's treasure; PostCbt clears it after the combat }
          skipsCombatItems: Byte;
          skipsCombatItemsTail: array[$2E4..$2E5] of Byte;
          { non-zero: PostCbt stands the dying and unconscious back up with 1 hit point after the combat, and then
            clears it }
          revivesParty: Byte;
          revivesPartyTail: array[$2E7..$311] of Byte;
          { zone 1's copy of dataSet, which SaveLoad saves with the game and restores dataSet from, and GameInit sets;
            EclMenu answers ECL's reads of the cell with dataSet itself }
          savedDataSet: Byte;
          savedDataSetTail: array[$313..$332] of Byte;
          { 1 once the team attacks an ally: CbtActs' CheckAttackAlly sets it, CombatSt clears it }
          hasAttackedAlly: Byte;
          hasAttackedAllyTail: array[$334..$33D] of Byte;
          { the number of party members, the counted head of the combatant list: GameTime, GameInit, SaveLoad, CharGen,
            EclVm's EclDamage, CombatSt and PostCbt name it }
          partyCount: Byte;
          { the remainder of ECL's last DIVIDE, which EclVm stores }
          divisionRemainder: LongInt;
          divisionRemainderTail: array[$343..$36C] of Byte;
          { Shop's prices in sixteenths of an item's value; 0 sells at the value }
          priceMultiplier: Byte;
          priceMultiplierTail: array[$36E..$36F] of Byte;
          { FxEngine's AttackRoll adds it to a hostile attacker's roll and partyThac0Modifier to a team attacker's;
            PostCbt clears both after the combat }
          monsterThac0Modifier: Byte;
          partyThac0Modifier: Byte;
          { added to a team member's movement (CharHlp); PostCbt clears it after the combat }
          movementBonus: Byte;
          movementBonusTail: array[$373..$378] of Byte;
          { EclMenu's EclInit clears them as a script loads, unless a saved game has just loaded }
          newGameBytes: array[$7F79..$7F82] of Byte;
          newGameBytesTail: array[$383..$3FF] of Byte)
  end;
  PZone2 = ^TZone2;
  TZone2 = array[$7A00..$7BFF] of Byte;
  PZone3 = ^TZone3;
  TZone3 = array[$8000..$A400] of Byte;

  { the first and last open column of one row of a ring's placement grid; lo > hi opens none }
  TColumnRange = record
    lo: ShortInt;
    hi: ShortInt
  end;

  { one border run of a frame script, as Border.DrawFrameSegments reads it }
  TFrameRun = record
    { the run's end cells }
    x1: Byte;
    y1: Byte;
    x2: Byte;
    y2: Byte;
    { Sym8x8.DrawBorderRun's tiles for the run's first and last cells }
    firstTile: Byte;
    lastTile: Byte
  end;

  { a frame script of one box: GDConsts.mainFrame and creditsFrame }
  TBoxFrame = record
    { the box's four sides }
    runs: array[0..3] of TFrameRun;
    { C_Screen.FRAME_SCRIPT_END, 0: where Border.DrawFrameSegments stops }
    stop: array[0..1] of Byte
  end;
  { a frame script of one box and one more line: GDConsts.exploreFrame (the line first) and combatFrame (the box
    first) }
  TBoxLineFrame = record
    { the box's four sides and the line }
    runs: array[0..4] of TFrameRun;
    { C_Screen.FRAME_SCRIPT_END, 0: where Border.DrawFrameSegments stops }
    stop: array[0..1] of Byte
  end;

  { a row of skillDefinitions }
  TSkill = record
    name: String[24];
    { 0 leaves the skill out of Skills' general skill list }
    enabled: Byte;
    { its skillGroupNames heading, and the abilities index of its bonus }
    group: ShortInt
  end;

  { a packed color map, as in packedColorMap: each TImgBuf keeps one, and Blit's SrcNibble and FillPicRect take one by
    value }
  TColorMap = array[0..7] of Byte;
  { colors Blit.RemapPic finds, or the colors it puts in their place }
  TPalette16 = array[0..15] of Byte;

  PByteArr = ^TByteArr;
  { bytes from 0; the bound is a placeholder $R- never checks }
  TByteArr = array[0..65000] of Byte;
  { A decoded VGA animation frame's pixels, one byte each: every buffer VgaFrame and Portrait expand a frame into. }
  TVgaFrame = array[0..7743] of Byte;
  { One EGA scanline in one plane, 8 pixels a byte: GameInit spaces egaRowOffsets by it, Blit's FlushView and TextRend's
    FillRectEga step by it. }
  TEgaRow = array[0..39] of Byte;
  { One mode-13h scanline, a byte a pixel: Blit, Border and TextRend step by it. }
  TVgaRow = array[0..319] of Byte;
  { one CGA scanline, 4 pixels a byte: Blit's Hline and Vline and Border index the CGA banks as arrays of it }
  TCgaRow = array[0..79] of Byte;
  { one Tandy scanline, 2 pixels a byte: Border and TextRend index the Tandy banks as arrays of it }
  TTandyRow = array[0..159] of Byte;

  PImgBuf = ^TImgBuf;
  { a picture in the display mode's layout: Blit builds, draws and frees it }
  TImgBuf = record
    { scanlines per frame }
    height: Word;
    { 8-pixel columns per frame }
    width: Word;
    { copied from the DAX header; Portrait keeps an image's x position here }
    hdrC: Word;
    { likewise; Portrait keeps the y position here }
    hdrD: Word;
    { frames }
    count: Word;
    { copied between pictures and passed to SrcNibble. Note: PreparePic fills it from an uninitialized local }
    colorMap: TColorMap;
    { bytes per frame: height * width * the mode's bytes per 8-pixel row (CGA 2, EGA and Tandy 4, VGA 8); PreparePic's
      buffer picture uses 8 }
    frameSize: Word;
    { size FreePic releases: the header plus frameSize*count, or the loaded file's size when PreparePic builds the
      picture on its buffer }
    allocSize: Word;
    { PreparePic stores transpColor, and the VGA blits key on it, having no mask }
    transparentColor: Byte;
    { mask, one byte per data byte; nil unless requested, and always nil in VGA mode }
    transp: PByteArr;
    { the frames, inline after the header; the length varies, so [0..0] stands for it }
    data: array[0..0] of Byte
  end;

  { one ship weapon kind }
  TShipWeaponDef = record
    { ShipCbt cannot fire it from a longer range }
    maxRange: Byte;
    { unused }
    maxRangeTail: Byte;
    { rounds one reload adds }
    reloadAmmo: Byte;
    { damage of a hit, also ShipCbt's choice priority }
    damage: Byte;
    { added to the firer's hit total }
    targetBonus: ShortInt;
    { unused; 0 for both lasers }
    targetBonusTail: array[0..1] of Word;
    { ShipCbt's combat lines, PostCbt's repair list }
    name: String[24]
  end;

  { one 'ships' picture: its size, load flag and position }
  TShipPic = record
    { pixel rows }
    height: Byte;
    { 8-pixel columns }
    width: Byte;
    { unused; 1 in every record }
    widthTail: Byte;
    { OrbitMap loads the picture transparent }
    isTransparent: Boolean;
    { CharHlp's screen cell; ShipCbt adds it to an effect's origin }
    x: ShortInt;
    y: ShortInt
  end;

  TOrbitPosition = record
    { orbit-map cell }
    x: Byte;
    y: Byte;
    { tile, before OrbitMap adds its tile-set base }
    sprite: Byte
  end;

  { a kind of ground combat terrain, a row of terrainInfo }
  TTerrainRec = record
    { movement cost, doubled for a straight step, tripled for a diagonal; 255 impassable }
    cost: Byte;
    { what Pathing's WalkLine meets: 1 stops the line while the arena's distMode is 0, 2 marks it blocked past its first
      two cells }
    lineClass: Byte;
    { the terrain CbtActs' blast leaves: 0 none; $FA..$FC are codes that pick among fixed results at random }
    blastResult: Byte;
    { the tile CbtMap draws; for terrains 1, 2 and 4 also CbtActs' cloud symbol }
    tileId: Byte
  end;

  { a cell a combat icon covers, relative to its anchor cell }
  TIconCoordinateDelta = record
    dx: ShortInt;
    dy: ShortInt
  end;

  { a skill a new character starts with, by TCharRecord.skillLevels index }
  TInitialSkill = record
    skill: Byte;
    value: Byte
  end;

  { an INT 33h function 9 cursor, as Mouse.SetMouseCursor takes it }
  TMouseCursor = record
    { the AND mask, then the XOR mask }
    screenMask: array[0..15] of Word;
    cursorMask: array[0..15] of Word
  end;
  PMouseCursor = ^TMouseCursor;

  { One 8x8 glyph, a byte per pixel row. }
  TGlyph = array[0..7] of Byte;
  { the 8x8 game font: 256 glyphs, the 2048-byte 8X8D1.DAX resource 201 TextRend's LoadGameFont moves in. Note: GameInit
    allocates only $588 bytes (177 glyphs), so the load overruns the buffer; every RenderChar caller passes ascii 1, so
    only glyphs 0..63 are drawn }
  TFont = array[0..255] of TGlyph;
  PFont = ^TFont;

  { a portrait cache slot }
  TPortraitCacheSlot = record
    { the picture held, EMPTY_PORTRAIT_SLOT when empty }
    pictureId: Byte;
    pic: PImgBuf
  end;

  { where one combatant stands in the ground combat arena }
  TCombatantCell = record
    { arena column and row }
    x: ShortInt;
    y: ShortInt;
    { the combatant's own slot, stored by CombatSt; otherwise unused }
    slot: Byte;
    { icon size, the iconDelta row; 0 takes the combatant out of play }
    size: Byte
  end;

  { one entry of Pathing's target list }
  TTarget = record
    { the target's combatant slot }
    slot: Byte;
    { walking distance, doubled }
    distance: Byte;
    { direction 0..7 toward the target }
    direction: Byte
  end;

  { a combatant down in the arena, one entry of downedCreatures }
  TDownedCreature = record
    character: PCharRecord;
    { the arena cell it lies on }
    x: ShortInt;
    y: ShortInt;
    { the terrain under its corpse marker, which CbtMap's lookups return }
    terrain: Byte
  end;

  PArena = ^TArena;
  { the ground combat arena: CombatSt's LoadCombatTileSet allocates and lays it, Combat frees it }
  TArena = record
    { unused }
    viewOriginXLead: array[0..1] of Byte;
    { the arena cell at the combat map view's top left }
    viewOriginX: ShortInt;
    viewOriginY: ShortInt;
    { CbtMap draws the cursor sprite while it is True }
    cursorShown: Boolean;
    { the icon size of that cursor }
    cursorSize: Byte;
    { non-zero lets Pathing's WalkLine through lineClass 1 terrain }
    distMode: Byte;
    { the terrain of each cell, [row, column], a terrainInfo index }
    cells: array[0..24, 0..49] of Byte
  end;

  PAreaEffect = ^TAreaEffect;
  { a lingering projectile's cloud on the arena, a node of the areaEffects list; CbtActs builds it, CbtMap, Combat and
    FxEngine read it }
  TAreaEffect = record
    { the next cloud, nil after the last }
    next: PAreaEffect;
    { the terrain beneath each cell of the cloud's 3x3 block, by cloudDir index }
    underlyingTerrain: array[1..9] of Byte;
    { non-zero for each block cell the cloud covers }
    active: array[1..9] of Byte;
    { the arena cell at the block's center }
    x: ShortInt;
    y: ShortInt;
    { rounds left: CbtActs starts it at 4, or 1 when areaType has bit $10 set, and FxEngine counts it down and clears
      the cloud once it is at most 1 }
    countdown: Byte;
    { the cloud's marker, one of CLOUD_TERRAINS, which FxEngine lays again }
    marker: Byte
  end;

  { an effect number's handler: removed is True as FxEngine's RemoveEffect ends the effect }
  TEffectHandler = procedure(var cr: PCharRecord; effect: PEffectRec; removed: Boolean);

  { one byte per square of the 16x16 3-D map, [y][x] }
  TGeoPlane = array[0..15, 0..15] of Byte;
  PGeoMap = ^TGeoMap;
  { a 3-D map's four planes, as View3D's Load3DMap copies them from GEO<n>.DAX }
  TGeoMap = record
    { north wall in the high nibble, east in the low }
    wallsNE: TGeoPlane;
    { south wall in the high nibble, west in the low }
    wallsSW: TGeoPlane;
    { each square's event byte }
    events: TGeoPlane;
    { two bits per facing }
    barriers: TGeoPlane
  end;
  { a WALLDEF bank: five wall slices of 156 cells }
  TWallDef = array[1..5, 0..155] of Byte;
  PWallDefs = ^TWallDefs;
  TWallDefs = array[1..4] of TWallDef;

  { where the party stands on the 3-D map; GameInit clears it and SaveLoad saves and loads it whole }
  TPartyPosition = record
    { square on the 16x16 map: Explore and EclMenu step it and wrap it at the edges, GameInit starts the party at 7,
      13 }
    mapX: ShortInt;
    mapY: ShortInt;
    { 0..7 clockwise from north, even in the 3-D view; CombatSt turns it while it places the combatants and puts it
      back }
    facing: Byte;
    { View3D's GetWallType on the facing side of the party's square: EclMenu, Explore and EclVm store it, EclMenu's
      ReadGbvm gives it to ECL }
    wallAhead: Byte;
    { View3D's GetMapEvent of the party's square: bit $80 picks MapView's sky color and View3D's backdrop }
    mapEvent: Byte
  end;

  { a wall-set cache slot, as View3D's LoadWallSet stamps it }
  TWallSet = record
    { the WALLDEF record loaded into the slot, -1 when empty }
    fileId: Integer;
    { the slot it was loaded into, $FFFF when empty }
    slot: Word
  end;

  { the animation Portrait's LoadAnimation has loaded, which MenuCore's MenuHorizontal plays; LoadAnimation and GameInit
    clear it whole }
  TPortraitAnimation = record
    { each frame's time on screen in tens of ticks, byte 2 of its entry in the resource }
    frameDelays: array[0..8] of Byte;
    { bytes of each frame's encoded data, which Portrait and VgaFrame decode }
    encodedSizes: array[0..8] of Word;
    { the frame held whole; the others are XOR deltas of it }
    keyFrameIndex: Byte;
    { the frame MenuHorizontal goes back to after lastFrameIndex }
    loopStartFrame: Byte;
    { the last frame, at most 8: LoadAnimation sets it, FreeAnimation frees the frames up to it }
    lastFrameIndex: Byte;
    { the frame shown: MenuHorizontal steps it, EclVm's EclCall shows it }
    currentFrame: Byte
  end;

  { the loaded animation in VGA mode; GameInit clears it whole }
  TVgaAnimation = record
    { each frame's buffer, not a picture: the key frame's pixels as a TVgaFrame, the others their run-length code;
      Portrait's LoadAnimation fills them, VgaFrame's PrepareVgaFrame decodes one into display }
    frames: array[0..8] of Pointer;
    { the picture Portrait's DisplayImageBuf shows }
    display: PImgBuf
  end;

  { the frame counter EclVm's EclCall steps each time it shows the loaded animation's current frame; GameInit clears it
    whole }
  TDisplayCounter = record
    { the frame count position wraps after; nothing sets it }
    limit: Byte;
    { the frame EclCall shows: it counts it up and back to 1 past limit }
    position: Byte;
    { unused }
    frames: array[$02..$41] of Byte
  end;

  PEclRet = ^TEclRet;
  { one ECL GOSUB return, a node EclMenu's EclGosub allocates }
  TEclRet = record
    { the GBVM address to return to }
    addr: Word;
    { the return below it }
    next: PEclRet
  end;

  { [0] a monster's sprite is shown, [1] its close-up picture }
  TMonFlags = array[0..1] of Boolean;

  { A VGA color: red, green, blue. }
  TRgb = array[0..2] of Byte;
  { The 256 VGA colors. }
  TPalette256 = array[0..255] of TRgb;

  { one axis's readings: 0 low stop, 3 center, 6 high stop }
  TJoyAxis = array[0..6] of Word;
  { a stick's calibration, as Joystick's CalibrateJoystick measures it }
  TJoyCal = record
    x: TJoyAxis;
    y: TJoyAxis
  end;
  { The register block for software interrupts, laid out as Dos.Registers so storage can hold one without using Dos;
    callers pass it to Intr as a Registers. }
  TRegisters = record
    case Integer of
      0: (ax: Word;
          bx: Word;
          cx: Word;
          dx: Word;
          bp: Word;
          si: Word;
          di: Word;
          ds: Word;
          es: Word;
          flags: Word);
      1: (al: Byte;
          ah: Byte;
          bl: Byte;
          bh: Byte;
          cl: Byte;
          ch: Byte;
          dl: Byte;
          dh: Byte);
  end;

  PDriverDesc = ^TDriverDesc;
  { AIL_describe_driver's description of a loaded AIL driver }
  TDriverDesc = record
    minApiVersion: Word;
    { Xmidi's LoadAndInitDriver accepts only 3 }
    driverType: Word;
    { the timbre file's extension, a C string }
    dataSuffix: array[0..3] of Char;
    deviceNames: Pointer;
    defaultIo: Word;
    defaultIrq: Word;
    defaultDma: Word;
    defaultDrq: Word;
    serviceRate: Word;
    displaySize: Word
  end;

  { an overlay read routine, assignable to Overlay's OvrReadBuf; 0 when the read succeeds }
  TOverlayReader = function(overlaySegment: Word): Integer;

  { a line of screen text: a prompt, a menu line or a status-line message; TextRend, DaxIo and the units that call
    them }
  TString40 = String[40];
  { a file name or path: DaxIo's file helpers, SaveLoad's save-file scan }
  TString80 = String[80];
  { CharHlp's DrawShipWeapons count text; ViewChar's too }
  TString3 = String[3];

  { Line-walk state: Pathing's PathFind starts a Bresenham walk from (sx, sy) to (ex, ey), and each NextPathStep
    advances it one cell. }
  TPathReq = record
    { start and end points }
    sx: Integer;
    sy: Integer;
    ex: Integer;
    ey: Integer;
    { error accumulator }
    err: Integer;
    { Abs(ex - sx) }
    adx: Integer;
    { Abs(ey - sy) }
    ady: Integer;
    { current x }
    cx: Integer;
    { current y }
    cy: Integer;
    { x step sign }
    stepX: Integer;
    { y step sign }
    stepY: Integer;
    { distance walked: 2 per straight step, 3 per diagonal }
    dist: Byte;
    { direction of last step (0..8) }
    step: Byte;
  end;

type
  { area effect of one projectile kind }
  TProjectileKindInfo = record
    { effectId: the effect AddEffectWithMessage gives each creature hit, its save allowing; its effectStatusNames entry
      makes the combat message; 0 for none }
    effectId: Byte;
    radius: Byte;
    { 1 leaves a cloud }
    lingering: Byte;
    saveType: Byte;
    saveReduction: Byte
  end;
  { one entry of CharGen's main menu }
  TMenuRow = record
    name: String[40];
    isEnabled: Boolean
  end;
  { one wilderness scatter rule: runs of plots around a center }
  TTerrainProfile = record
    { percent chance that a run happens }
    chance: Byte;
    { a run makes diceCount d diceSides plots }
    diceCount: Byte;
    diceSides: Byte;
    { above 0, every cell within this many of a plot must be open }
    clearance: Byte;
    { how far from the center a plot may fall; 0 plots on the center }
    scatter: Byte;
    { a d scatterBonus roll added to scatter }
    scatterBonus: Byte;
    { C_Terr's PROFILE_* bits }
    flags: Byte;
    { the tile a plot lays, plus a 0..tileVariance - 1 roll }
    tile: Byte;
    { the tile laid beside it, plus a 0..pairVariance - 1 roll; UNSET_TERRAIN lays none }
    pairTile: Byte;
    tileVariance: Byte;
    pairVariance: Byte
  end;
  { One challenge: word number wordIndex under a Log Book heading. Both strings are stored reversed, each character
    raised by the string's length, so they do not show up in a dump of the program; Decode undoes it. }
  TLogBookEntry = record
    page: Byte;
    { the width used to center the heading }
    headingLen: Byte;
    heading: String[30];
    { 1..10, the ordinal the prompt names }
    wordIndex: Byte;
    { the answer's length; not used }
    answerLen: Byte;
    answer: String[15]
  end;
  { where View3D draws each of the 3-D view's ten wall slots }
  TViewSlotGeom = record
    { first cell of the slot's rectangle in a 156-cell wall slice }
    start: array[0..9] of Byte;
    { rectangle width in cells }
    cols: array[0..9] of Byte;
    { rectangle height in cells }
    rows: array[0..9] of Byte;
    { view column of the rectangle's top left }
    xCol: array[0..9] of Integer;
    { view row of the rectangle's top left }
    yRow: array[0..9] of Integer
  end;

implementation

end.
