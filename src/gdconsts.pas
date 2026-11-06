{ Initialized data: the data segment's typed constants, grouped by the subsystem that owns them and kept in address
  order. A new section starts wherever the data needs a word boundary. }
unit GDConsts;

interface

uses Types, C_Dir, C_Career, C_Skill, C_Terr, C_Effect, C_Keys, C_Status, C_Group, C_Sys, C_Screen, C_Msg, C_Save;

{ ECL: the sounds a script can play. }
const
  { sound command for each ECL SOUND argument; the scripts use 1..20. Note: EclPlaySound does not bound the argument, so
    21..127 read past the table }
  eclSoundCommands: array[0..20] of Byte = (
    0, 12, 9, 16, 7, 10, 11, 18, 14, 3, 4, 5, 6, 8, 13, 17, 16, 19, 19, 19, 20
  );

{ ECL: the item lists a script's shop can stock. }
const
  { first itemListEntries entry of each list a shop can stock; EclShop does not bound the list number }
  itemListStarts: array[1..16] of Byte = (
    1, 17, 22, 26, 33, 37, 42, 46, 51, 61, 69, 73, 79, 83, 88, 92
  );
  { number of entries in each item list }
  itemListCounts: array[1..16] of Byte = (
    16, 5, 4, 7, 4, 5, 4, 5, 10, 8, 4, 6, 4, 5, 4, 38
  );
  { itemTemplates row of each item-list entry }
  itemListEntries: array[1..129] of Byte = (
    1, 3, 4, 6, 7, 9, 10, 12, 14, 15, 20, 21, 28, 29, 30, 31, 2, 8, 11, 13, 16, 22, 27, 29, 30, 2, 3, 4, 6,
    8, 9, 13, 20, 21, 27, 31, 2, 8, 11, 13, 16, 20, 26, 28, 29, 39, 42, 45, 47, 51, 26, 27, 30, 31, 35, 36,
    37, 38, 92, 93, 1, 2, 3, 4, 8, 19, 40, 41, 9, 13, 45, 48, 26, 34, 35, 36, 37, 38, 1, 3, 14, 16, 20, 21,
    22, 27, 30, 10, 11, 46, 50, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38
  );

{ Ship combat: where a random hit lands. }
const
  { percent chance a random hit strikes each ship system, 100 in all }
  systemHitChances: array[0..6] of ShortInt = (
    28, 9, 9, 13, 10, 18, 13
  );

{ Copy protection: the Log Book challenges. }
const
  { decoded heading: answer }
  logBookEntries: array[1..29] of Types.TLogBookEntry = (
    (page: 31; headingLen: 14; heading: 'SUOaaS[.a5YQcP';
     { BUCK'S MESSAGE: CHECK }
     wordIndex: 5; answerLen: 5; answer: 'PHJMH'),
    (page: 32; headingLen: 14; heading: '\OZ^.a5cZcPcab';
     { TSUBULU'S PLAN: PROBLEM }
     wordIndex: 4; answerLen: 7; answer: 'TLSIVYW'),
    (page: 32; headingLen: 20; heading: 'mfchg4g;fYbcg]fd4Y\h';
     { THE PRISONER'S STORY: TOGETHER }
     wordIndex: 7; answerLen: 8; answer: 'ZMP\MOW\'),
    (page: 34; headingLen: 18; heading: 'VdSidaX2ebWfe2]UgT';
     { BUCK STEPS FORWARD: SIGHS }
     wordIndex: 2; answerLen: 5; answer: 'XMLNX'),
    (page: 35; headingLen: 14; heading: 'aYOS^a.`SR\OSZ';
     { LEANDER SPEAKS: LAB }
     wordIndex: 5; answerLen: 3; answer: 'EDO'),
    (page: 35; headingLen: 22; heading: 'de_jWih[ldeY6W_h[j[\WY';
     { CAFETERIA CONVERSATION: ONE }
     wordIndex: 6; answerLen: 3; answer: 'HQR'),
    (page: 36; headingLen: 22; heading: '_SWdV2e9WfSd[b2WZf';
     { THE PIRATE'S DREAM: STORMRIDERS }
     wordIndex: 8; answerLen: 3; answer: '^]POT]X]Z_^'),
    (page: 38; headingLen: 12; heading: '_WMQ\_,MT_UY';
     { MISHA SPEAKS: SEALED }
     wordIndex: 2; answerLen: 6; answer: 'JKRGKY'),
    (page: 38; headingLen: 19; heading: 'eXYYb3f:XaT^3eX__\^';
     { KILLER KANE'S OFFER: MATRIX }
     wordIndex: 5; answerLen: 6; answer: '^OXZGS'),
    (page: 39; headingLen: 15; heading: 'Wc^^b/^c/aTccT[';
     { LETTER TO SOOTH: ALLOW }
     wordIndex: 4; answerLen: 5; answer: '\TQQF'),
    (page: 40; headingLen: 19; heading: '[VXXcf3f:eb_lTg3AeW';
     { DR. TAYLOR'S SPEECH: SORRY }
     wordIndex: 2; answerLen: 5; answer: '^WWTX'),
    (page: 40; headingLen: 17; heading: '\TReeR1df`ZcVedj^';
     { MYSTERIOUS ATTACK: VIDEO }
     wordIndex: 4; answerLen: 5; answer: 'TJIN['),
    (page: 40; headingLen: 17; heading: 'de`]Za1cVUZc^c`ed';
     { STORMRIDER PILOTS: SOON }
     wordIndex: 7; answerLen: 4; answer: 'RSSW'),
    (page: 41; headingLen: 17; heading: '^`TcVe_Z1VYe1cVg`';
     { OVER THE INTERCOM: PRISON }
     wordIndex: 4; answerLen: 6; answer: 'TUYOXV'),
    (page: 41; headingLen: 12; heading: '\UT_,PQ^aVZU';
     { INJURED SHIP: IGNORANCE }
     wordIndex: 5; answerLen: 9; answer: 'NLWJ[XWPR'),
    (page: 43; headingLen: 13; heading: 'QVNY-]N_a-RUa';
     { THE TRAP LAID: SHARKS }
     wordIndex: 5; answerLen: 6; answer: 'YQXGNY'),
    (page: 43; headingLen: 20; heading: 'Y[UggYa4[b]Vfihg]X4U';
     { A DISTURBING MESSAGE: NEED }
     wordIndex: 2; answerLen: 4; answer: 'HIIR'),
    (page: 44; headingLen: 18; heading: 'e]SWbe2`[SfbSU2WZf';
     { THE CAPTAIN SPEAKS: THROAT }
     wordIndex: 6; answerLen: 6; answer: 'ZGUXNZ'),
    (page: 45; headingLen: 13; heading: '[NY]-`4VYNXNZ';
     { MAKALI'S PLAN: FLYING }
     wordIndex: 4; answerLen: 6; answer: 'MTO_RL'),
    (page: 46; headingLen: 20; heading: 'mfchg4g;fchWYf]X4VU`';
     { LAB DIRECTOR'S STORY: CYBORG }
     wordIndex: 2; answerLen: 6; answer: 'MXUH_I'),
    (page: 47; headingLen: 22; heading: '[X_hjW_Z6i=dd_kg6e_hWc';
     { MARIO QUINN'S DIATRIBE: INVADERS }
     wordIndex: 2; answerLen: 8; answer: '[ZMLI^VQ'),
    (page: 47; headingLen: 24; heading: 'kY[md8]`l8\jYgZY8`lY]\8Y';
     { A DEATH ABOARD THE LUCAS: STATEROOM }
     wordIndex: 6; answerLen: 9; answer: 'VXX[N]J]\'),
    (page: 48; headingLen: 18; heading: 'XhVfXe3f:lXa`be3AeW';
     { DR. ROMNEY'S RESCUE: RUINED }
     wordIndex: 3; answerLen: 6; answer: 'JKTO[X'),
    (page: 48; headingLen: 11; heading: 'OTL]+PNTWZ[';
     { POLICE RAID: BEGIN }
     wordIndex: 5; answerLen: 5; answer: 'SNLJG'),
    (page: 48; headingLen: 12; heading: '`U\,QT`,[`ZU';
     { INTO THE PIT: EXPLAIN }
     wordIndex: 3; answerLen: 7; answer: 'UPHSW_L'),
    (page: 49; headingLen: 21; heading: 'hc^VaemZ5ih^gdZ]i5Z]i';
     { THE THEORIST EXPLAINS: RESCUE }
     wordIndex: 6; answerLen: 6; answer: 'K[IYKX'),
    (page: 49; headingLen: 12; heading: '_WMQ\_,_[XQ`';
     { TELOS SPEAKS: WITH }
     wordIndex: 5; answerLen: 4; answer: 'LXM['),
    (page: 50; headingLen: 16; heading: 'b__T0UXd0^_0Ud_^';
     { NOTE ON THE DOOR: LOOKING }
     wordIndex: 3; answerLen: 7; answer: 'NUPRVVS'),
    (page: 50; headingLen: 15; heading: 'b]XP[_gT/X[PZP\';
     { MAKALI EXPLAINS: CONVINCE }
     wordIndex: 4; answerLen: 8; answer: 'MKVQ^VWK')
  );

{ After combat: the treasure line and the ship repairs. }
const
  { head of the treasure line }
  treasureFoundText: String[21] = 'The team has found ';
  { tail of the treasure line, after 'no ' when there is none }
  treasureBootyText: String[7] = 'booty!';
  { the skill that repairs each ship system; fuel has none (255) and RepairShip skips it }
  repairSkills: array[C_Sys.HULL..C_Sys.WEAPONS] of Byte = (
    C_Skill.REPAIR_HULL, C_Skill.REPAIR_ELECTRICAL, C_Skill.REPAIR_MECHANICAL,
    C_Skill.REPAIR_LIFE_SUPPORT, 255, C_Skill.REPAIR_ENGINE, C_Skill.REPAIR_WEAPON
  );
  { ten-sided dice a success rolls to restore each system }
  repairDice: array[C_Sys.HULL..C_Sys.ENGINES] of Byte = (
    20, 4, 4, 8, 0, 12
  );

{ The combat AI's approach turns and blast reach. }
const
  { the turn, in eighths, AiCanStep adds to its base heading on each of its five tries, by approach. Note: once all five
    fail AiMoveStep reads [approach, 6] -- the next row's first byte, or areaHalfWidths' first for approach 6 -- into a
    direction it never uses }
  approachPatterns: array[1..6, 1..5] of Byte = (
    (8, 7, 6, 1, 2), (8, 1, 2, 7, 6), (7, 1, 8, 6, 2), (1, 7, 8, 2, 6), (8, 7, 6, 5, 4), (8, 1, 2, 3, 4)
  );
  { how far a blast reaches either side of its center, by row offset and area class; -3 fills the rows beyond a class's
    reach, which are never read }
  areaHalfWidths: array[-3..3, 1..3] of ShortInt = (
    (-3, -3, 1), (-3, 1, 2), (1, 2, 3), (1, 2, 3), (1, 2, 3), (-3, 1, 2), (-3, -3, 1)
  );

{ Combat set-up: placement rings, arena wall tiles, wilderness scatter rules; the start-up colors, the acid line and the
  projectile kinds. }
const
  { direction 0..7 from a team's placement origin to the block that ring 1..3 is tried in, by facing quarter; column 0
    holds 8, no direction, and FindPlacement indexes it by ring 1..3 }
  ringBlockDirections: array[0..3, 0..3] of Byte = (
    (8, 4, 6, 2), (8, 6, 4, 0), (8, 0, 6, 2), (8, 2, 0, 4)
  );
  { direction 0..7 a placement ring is laid out facing, by the team's facing quarter and ring; FindPlacement halves it
    to a quarter }
  facingDirections: array[0..3, 0..3] of Byte = (
    (0, 0, 2, 6), (2, 2, 0, 4), (4, 4, 2, 6), (6, 6, 4, 0)
  );
  { direction 0..7 of each quarter, for FindPlacement's steps along a placement ring; PlaceAllCreatures also stores it
    as each listed creature's direction, before placing it }
  quarterDirections: array[0..3] of Byte = (
    7, 2, 3, 6
  );
  { column a placement ring starts at, [ring > 0], by the quarter it faces }
  ringStartColumns: array[Boolean, 0..3] of ShortInt = (
    (5, 4, 5, 6), (3, 8, 7, 2)
  );
  { row a placement ring starts at, [ring > 0], by the quarter it faces }
  ringStartRows: array[Boolean, 0..3] of ShortInt = (
    (3, 2, 2, 3), (0, 2, 5, 3)
  );
  { first and last open column of each row of a ring's placement grid, by facing quarter, 4 for ring 1; lo > hi opens
    none }
  columnRanges: array[0..4, 0..5] of Types.TColumnRange = (
    ((lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)),
    ((lo: 0; hi: 2), (lo: 0; hi: 3), (lo: 1; hi: 4), (lo: 2; hi: 5), (lo: 3; hi: 6), (lo: 4; hi: 7)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0)),
    ((lo: 3; hi: 6), (lo: 4; hi: 7), (lo: 5; hi: 8), (lo: 6; hi: 9), (lo: 7; hi: 10), (lo: 8; hi: 10)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10))
  );
  { tile at rows 0..1, columns 1..2 of a map square's arena block, by the walls at its left corner as a state 1..15; 255
    leaves the cell }
  leftWallTiles: array[1..15, 0..1, 1..2] of Byte = (
    ((24, 24), (25, 25)), ((36, 255), (28, 26)), ((7, 24), (9, 10)), ((31, 255), (32, 255)),
    ((24, 24), (25, 25)), ((14, 255), (13, 26)), ((11, 24), (13, 10)), ((34, 255), (38, 255)),
    ((17, 24), (18, 25)), ((26, 255), (28, 26)), ((15, 24), (28, 10)), ((22, 255), (23, 255)),
    ((21, 24), (25, 25)), ((16, 255), (13, 26)), ((40, 24), (13, 10))
  );
  { tile at rows 0..1, columns 5..6 of a map square's arena block, by the walls at its right corner as a state 1..15;
    255 leaves the cell }
  rightWallTiles: array[1..15, 0..1, 5..6] of Byte = (
    ((255, 31), (255, 33)), ((255, 35), (255, 39)), ((255, 255), (255, 8)), ((24, 24), (25, 25)),
    ((24, 24), (25, 25)), ((24, 24), (25, 12)), ((24, 24), (25, 12)), ((27, 29), (255, 37)),
    ((27, 28), (255, 27)), ((27, 28), (255, 27)), ((27, 28), (255, 27)), ((19, 20), (25, 25)),
    ((19, 20), (25, 25)), ((19, 20), (25, 12)), ((19, 20), (25, 12))
  );
  { the wilderness scatter rules, by the profile number BuildWilderness is handed }
  terrainProfiles: array[1..22] of Types.TTerrainProfile = (
    (chance: 50; diceCount: 6; diceSides: 12; clearance: 0; scatter: 12; scatterBonus: 12;
     flags: $00; tile: 112; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 3; pairVariance: 0),
    (chance: 50; diceCount: 4; diceSides: 10; clearance: 0; scatter: 30; scatterBonus: 0;
     flags: $00; tile: 112; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 3; pairVariance: 0),
    (chance: 80; diceCount: 4; diceSides: 10; clearance: 0; scatter: 10; scatterBonus: 10;
     flags: $00; tile: 115; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 3; pairVariance: 0),
    (chance: 90; diceCount: 3; diceSides: 8; clearance: 0; scatter: 30; scatterBonus: 0;
     flags: $00; tile: 115; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 3; pairVariance: 0),
    (chance: 80; diceCount: 3; diceSides: 8; clearance: 0; scatter: 12; scatterBonus: 0;
     flags: C_Terr.PROFILE_PAIR_BELOW; tile: 118; pairTile: 130; tileVariance: 0; pairVariance: 0),
    (chance: 80; diceCount: 4; diceSides: 10; clearance: 0; scatter: 40; scatterBonus: 0;
     flags: C_Terr.PROFILE_PAIR_BELOW; tile: 119; pairTile: 127; tileVariance: 4; pairVariance: 3),
    (chance: 80; diceCount: 4; diceSides: 20; clearance: 0; scatter: 10; scatterBonus: 10;
     flags: C_Terr.PROFILE_PAIR_BELOW + C_Terr.PROFILE_ONE_ROLL; tile: 119;
     pairTile: 127; tileVariance: 8; pairVariance: 3),
    (chance: 80; diceCount: 2; diceSides: 12; clearance: 0; scatter: 20; scatterBonus: 0;
     flags: $00; tile: 104; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 0; pairVariance: 0),
    (chance: 90; diceCount: 4; diceSides: 10; clearance: 0; scatter: 10; scatterBonus: 5;
     flags: C_Terr.PROFILE_ONE_ROLL; tile: 102; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 6; pairVariance: 0),
    (chance: 80; diceCount: 2; diceSides: 5; clearance: 0; scatter: 8; scatterBonus: 10;
     flags: $00; tile: 110; pairTile: 111; tileVariance: 0; pairVariance: 0),
    (chance: 80; diceCount: 2; diceSides: 10; clearance: 1; scatter: 40; scatterBonus: 0;
     flags: C_Terr.PROFILE_PAIR_FOLLOWS + C_Terr.PROFILE_DOUBLE_VARIANCE; tile: 69;
     pairTile: 70; tileVariance: 5; pairVariance: 0),
    (chance: 80; diceCount: 3; diceSides: 8; clearance: 0; scatter: 15; scatterBonus: 20;
     flags: $00; tile: 79; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 3; pairVariance: 0),
    (chance: 80; diceCount: 4; diceSides: 12; clearance: 0; scatter: 15; scatterBonus: 20;
     flags: $00; tile: 82; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 7; pairVariance: 0),
    (chance: 100; diceCount: 10; diceSides: 20; clearance: 0; scatter: 9; scatterBonus: 4;
     flags: $00; tile: 91; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 0; pairVariance: 0),
    (chance: 80; diceCount: 5; diceSides: 10; clearance: 0; scatter: 10; scatterBonus: 10;
     flags: C_Terr.PROFILE_PAIR_BELOW + C_Terr.PROFILE_ONE_ROLL; tile: 100;
     pairTile: 98; tileVariance: 2; pairVariance: 2),
    (chance: 100; diceCount: 1; diceSides: 6; clearance: 0; scatter: 5; scatterBonus: 0;
     flags: C_Terr.PROFILE_KEEP_CENTER; tile: 92; pairTile: 93; tileVariance: 0; pairVariance: 0),
    (chance: 80; diceCount: 1; diceSides: 10; clearance: 1; scatter: 5; scatterBonus: 10;
     flags: $00; tile: 92; pairTile: 93; tileVariance: 0; pairVariance: 0),
    (chance: 80; diceCount: 5; diceSides: 10; clearance: 0; scatter: 15; scatterBonus: 15;
     flags: C_Terr.PROFILE_ONE_ROLL; tile: 94; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 4; pairVariance: 0),
    (chance: 100; diceCount: 10; diceSides: 8; clearance: 0; scatter: 0; scatterBonus: 0;
     flags: C_Terr.PROFILE_KEEP_CENTER + C_Terr.PROFILE_FIXED_SCATTER; tile: 79;
     pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 10; pairVariance: 0),
    (chance: 80; diceCount: 3; diceSides: 10; clearance: 0; scatter: 10; scatterBonus: 10;
     flags: C_Terr.PROFILE_PAIR_BELOW + C_Terr.PROFILE_ONE_ROLL; tile: 137;
     pairTile: 135; tileVariance: 2; pairVariance: 2),
    (chance: 80; diceCount: 3; diceSides: 10; clearance: 0; scatter: 15; scatterBonus: 15;
     flags: C_Terr.PROFILE_ONE_ROLL; tile: 131; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 4; pairVariance: 0),
    (chance: 80; diceCount: 10; diceSides: 10; clearance: 0; scatter: 15; scatterBonus: 10;
     flags: $00; tile: 154; pairTile: C_Terr.UNSET_TERRAIN; tileVariance: 0; pairVariance: 0)
  );
  { The 16 colors; InitializeGame loads them into the palette. }
  defaultPalette: array[0..15] of Types.TRgb = (
    ($00, $00, $00), ($00, $00, $AA), ($00, $AA, $00), ($00, $AA, $AA), ($AA, $00, $00), ($AA, $00, $AA),
    ($AA, $55, $00), ($AA, $AA, $AA), ($55, $55, $55), ($55, $55, $FF), ($55, $FF, $55), ($55, $FF, $FF),
    ($FF, $55, $55), ($FF, $55, $FF), ($FF, $FF, $55), ($FF, $FF, $FF)
  );
  { EffSpitAcid's combat line after a creature's name }
  acidMessage: String = 'spits acid';
  { area effect of projectile kinds 4..12: MakeAttack launches 5..12, and CombatLaunchProjectile tests kind 4; kinds
    below 4 have no entry }
  projectileKinds: array[4..12] of Types.TProjectileKindInfo = (
    (effectId: C_Effect.HELPLESS; radius: 1; lingering: 1; saveType: 1; saveReduction: C_Save.CANCELS),
    (effectId: C_Effect.BLIND; radius: 1; lingering: 0; saveType: 3; saveReduction: C_Save.CANCELS),
    (effectId: 0; radius: 1; lingering: 0; saveType: 2; saveReduction: C_Save.HALVES),
    (effectId: C_Effect.HELPLESS; radius: 1; lingering: 1; saveType: 1; saveReduction: C_Save.CANCELS),
    (effectId: 0; radius: 1; lingering: 1; saveType: 7; saveReduction: C_Save.NO_EFFECT),
    (effectId: 0; radius: 1; lingering: 1; saveType: 7; saveReduction: C_Save.NO_EFFECT),
    (effectId: 0; radius: 3; lingering: 0; saveType: 2; saveReduction: C_Save.HALVES),
    (effectId: 0; radius: 2; lingering: 0; saveType: 2; saveReduction: C_Save.HALVES),
    (effectId: C_Effect.STUNNED; radius: 1; lingering: 0; saveType: 0; saveReduction: C_Save.CANCELS)
  );

{ The exploration menus, the main menu, the shop's free ammunition, and the character sheet's labels. }
const
  { the 3-D view's main menu line }
  dungeonMenu: Types.TString40 = 'Move Area View Look Change Save';
  { the Change menu's first options, left off on the orbit map }
  changeMenuHead: Types.TString40 = 'Order Purge ';
  { sets zone0^.difficulty }
  difficultyMenu: Types.TString40 = 'Novice Cadet Trooper Veteran Ace Exit';
  { the Change menu's other options }
  changeMenuTail: Types.TString40 = 'Messages Anim Level Exit';
  { words naming a message speed }
  speedWords: array[0..2] of String[7] = ('Slow', 'Average', 'Fast');
  { suffixes that grade a speed word }
  speedSuffixes: array[0..2] of String[3] = ('', 'er', 'est');
  { per message speed, the speed word (high nibble) and suffix (low bits) }
  speedWordCodes: array[0..C_Msg.SLOWEST_MESSAGE_SPEED] of Byte = (
    $22, $21, $21, $20, $10, $10, $00, $01, $01, $02
  );
  { the party order menu line, [0] before a member is picked, [1] after }
  partyOrderMenus: array[0..1] of Types.TString40 = (
    'Select Exit', 'Place Exit'
  );
  { orbit-map column step for directions 0..7 counterclockwise from north }
  mapStepX: array[0..7] of ShortInt = (
    0, -1, -1, -1, 0, 1, 1, 1
  );
  { and row step }
  mapStepY: array[0..7] of ShortInt = (
    -1, -1, 0, 1, 1, 1, 0, -1
  );
  { the main menu's entries, each listed while enabled }
  menuTable: array[0..12] of Types.TMenuRow = (
    (name: 'Create New Character'; isEnabled: True),
    (name: 'Purge Character'; isEnabled: False),
    (name: 'Modify Character'; isEnabled: False),
    (name: 'Icon Select'; isEnabled: False),
    (name: 'Train Character'; isEnabled: False),
    (name: 'View Character'; isEnabled: False),
    (name: 'Add Character to Team'; isEnabled: True),
    (name: 'Remove Character from Team'; isEnabled: False),
    (name: 'Load Saved Game'; isEnabled: True),
    (name: 'Save Current Game'; isEnabled: False),
    (name: 'Begin Adventuring'; isEnabled: False),
    (name: 'JoyStick/Mouse Initialize'; isEnabled: True),
    (name: 'Exit to DOS'; isEnabled: True)
  );
  { a new character's icon by gender and career }
  characterIcons: array[0..1, C_Career.ROCKET_JOCK..C_Career.ROGUE] of Byte = (
    (32, 0, 3, 7, 21),
    (33, 1, 6, 15, 25)
  );
  { item template of each ammunition item a new character gets }
  freeAmmoTemplates: array[1..2] of Byte = (7, 20);
  { quantity each gets in place of its template's }
  freeAmmoQuantities: array[1..2] of Byte = (100, 0);
  { price of one clip of ammunition by weapon type }
  ammoPrices: array[5..18] of Word = (
    10, 5, 10, 0, 35, 50, 100, 50, 35, 100, 80, 0, 80, 100
  );
  { 15 spaces that pad a character name to its full width }
  nameBlanks: String[15] = '               ';
  { the character sheet labels each ability with it }
  abilityAbbreviations: array[0..6] of String[4] = (
    'STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA', 'TCH'
  );

{ Character rules and displays, frames, line colors and text: ability tables, ship meters, frame scripts, the CGA line
  colors, line breaks, file names, and the names of careers, ships, races, skills and items. }
const
  { the effects RemoveIncapacitatingEffects strips }
  incapacitatingEffects: array[1..4] of Byte = (
    C_Effect.SCARED, C_Effect.HELPLESS, C_Effect.STUNNED, C_Effect.DIZZY
  );
  { armor class adjustment by dexterity }
  dexArmorAdjustments: array[1..22] of ShortInt = (
    -5, -5, -4, -3, -2, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 4, 4, 5, 5
  );
  { dexterity adjustment: to-hit for a weapon that is not melee, initiative, gunnery, CombatAi's weapon priority }
  dexMissileAdjustments: array[1..22] of ShortInt = (
    -6, -4, -3, -2, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 3, 3, 4, 4
  );
  { to-hit adjustment by strength, melee and unarmed }
  strengthToHitAdjustments: array[1..22] of ShortInt = (
    -5, -4, -3, -2, -2, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3, 4, 4
  );
  { damage adjustment by strength, melee and unarmed }
  strengthDamageAdjustments: array[1..22] of ShortInt = (
    -4, -3, -2, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 4, 6, 8, 10
  );
  { by strength; carrying over half of it halves movement }
  weightAllowances: array[1..22] of Word = (
    2, 4, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 170, 220, 400, 600, 900, 1200
  );
  { upper line of each ship-system meter bar }
  meterUpperColors: array[0..5] of Byte = (15, 11, 12, 14, 9, 13);
  { lower line of each ship-system meter bar }
  meterLowerColors: array[0..5] of Byte = (7, 3, 4, 12, 1, 5);
  { shown over the ship-combat scene; CharHlp indexes it by enemyRetreating, so 'Maneuvering' never shows }
  maneuverNames: array[0..2] of String[11] = (
    'Closing    ', 'Retreating ', 'Maneuvering'
  );
  { the orbit map's frame script: the picture box (2,2)-(14,14), and the dividers at column 16 and row 16 }
  orbitMapFrame: record runs: array[0..5] of Types.TFrameRun; stop: array[0..1] of Byte end = (
    runs: (
      (x1: 2; y1: 2; x2: 14; y2: 2; firstTile: 0; lastTile: 1),
      (x1: 2; y1: 2; x2: 2; y2: 14; firstTile: 0; lastTile: 3),
      (x1: 14; y1: 2; x2: 14; y2: 14; firstTile: 1; lastTile: 2),
      (x1: 2; y1: 14; x2: 14; y2: 14; firstTile: 3; lastTile: 2),
      (x1: 16; y1: 0; x2: 16; y2: 23; firstTile: 6; lastTile: 8),
      (x1: 0; y1: 16; x2: 16; y2: 16; firstTile: 9; lastTile: 7)
    );
    { the end marker Border.DrawFrameSegments stops at }
    stop: (C_Screen.FRAME_SCRIPT_END, 0)
  );
  { scan code of the key for each direction N, NE .. NW; MenuCore answers an arena click with the key toward the clicked
    cell }
  directionKeys: array[0..7] of Char = 'HIMQPOKG';
  { sky color by zone 0's skyIndexLo, or by skyIndexHi on a square whose mapEvent is above $7F }
  skyCeilingColors: array[0..15] of Byte = (
    0, 15, 4, 11, 13, 2, 9, 14, 0, 15, 4, 11, 13, 2, 9, 14
  );
  { where View3D draws each of the 3-D view's ten wall slots, and which cells of a wall slice fill it }
  viewSlotGeom: Types.TViewSlotGeom = (
    start: (0, 2, 6, 10, 22, 38, 54, 110, 132, 154);
    cols: (1, 1, 1, 3, 2, 2, 7, 2, 2, 1);
    rows: (2, 4, 4, 4, 8, 8, 8, 11, 11, 2);
    xCol: (5, 4, 6, 4, 2, 7, 2, 0, 9, 5);
    yRow: (4, 3, 3, 3, 1, 1, 1, 0, 0, 4)
  );
  { The frame scripts: runs of border tiles, each script ended by FRAME_SCRIPT_END. }
  { the box (0,0)-(39,23): DrawWindowFrame, ScreenText, DrawCharViewFrame and DrawListFrame }
  mainFrame: Types.TBoxFrame = (
    runs: (
      (x1: 0; y1: 0; x2: 39; y2: 0; firstTile: 0; lastTile: 1),
      (x1: 0; y1: 0; x2: 0; y2: 23; firstTile: 0; lastTile: 3),
      (x1: 39; y1: 0; x2: 39; y2: 23; firstTile: 1; lastTile: 2),
      (x1: 0; y1: 23; x2: 39; y2: 23; firstTile: 3; lastTile: 2)
    );
    stop: (C_Screen.FRAME_SCRIPT_END, 0)
  );
  { the box (0,0)-(39,24): ScreenCredits, for Intro's Credits }
  creditsFrame: Types.TBoxFrame = (
    runs: (
      (x1: 0; y1: 0; x2: 39; y2: 0; firstTile: 0; lastTile: 1),
      (x1: 0; y1: 0; x2: 0; y2: 24; firstTile: 0; lastTile: 3),
      (x1: 39; y1: 0; x2: 39; y2: 24; firstTile: 1; lastTile: 2),
      (x1: 0; y1: 24; x2: 39; y2: 24; firstTile: 3; lastTile: 2)
    );
    stop: (C_Screen.FRAME_SCRIPT_END, 0)
  );
  { a divider at column 16 and the picture box (2,2)-(14,14), over ScreenText's frame: DrawExploreFrame, for the
    exploration screen (CharHlp, EclVm) }
  exploreFrame: Types.TBoxLineFrame = (
    runs: (
      (x1: 16; y1: 0; x2: 16; y2: 16; firstTile: 6; lastTile: 8),
      (x1: 2; y1: 2; x2: 14; y2: 2; firstTile: 0; lastTile: 1),
      (x1: 2; y1: 14; x2: 14; y2: 14; firstTile: 3; lastTile: 2),
      (x1: 2; y1: 2; x2: 2; y2: 14; firstTile: 0; lastTile: 3),
      (x1: 14; y1: 2; x2: 14; y2: 14; firstTile: 1; lastTile: 2)
    );
    stop: (C_Screen.FRAME_SCRIPT_END, 0)
  );
  { the box (0,0)-(39,22), row 18 across it, column 25 above that and row 13 right of it: DrawShipFrame, for CharHlp's
    ship screen }
  shipFrame: record runs: array[0..6] of Types.TFrameRun; stop: array[0..1] of Byte end = (
    runs: (
      (x1: 0; y1: 0; x2: 39; y2: 0; firstTile: 0; lastTile: 1),
      (x1: 0; y1: 0; x2: 0; y2: 22; firstTile: 0; lastTile: 3),
      (x1: 39; y1: 0; x2: 39; y2: 22; firstTile: 1; lastTile: 2),
      (x1: 0; y1: 22; x2: 39; y2: 22; firstTile: 3; lastTile: 2),
      (x1: 0; y1: 18; x2: 39; y2: 18; firstTile: 9; lastTile: 7),
      (x1: 25; y1: 0; x2: 25; y2: 18; firstTile: 6; lastTile: 8),
      (x1: 25; y1: 13; x2: 39; y2: 13; firstTile: 9; lastTile: 7)
    );
    stop: (C_Screen.FRAME_SCRIPT_END, 0)
  );
  { the box (0,0)-(39,22) split at column 22: DrawCombatFrame, for CharHlp's combat screen }
  combatFrame: Types.TBoxLineFrame = (
    runs: (
      (x1: 0; y1: 0; x2: 39; y2: 0; firstTile: 0; lastTile: 1),
      (x1: 0; y1: 0; x2: 0; y2: 22; firstTile: 0; lastTile: 3),
      (x1: 39; y1: 0; x2: 39; y2: 22; firstTile: 1; lastTile: 2),
      (x1: 0; y1: 22; x2: 39; y2: 22; firstTile: 3; lastTile: 2),
      (x1: 22; y1: 0; x2: 22; y2: 22; firstTile: 6; lastTile: 8)
    );
    stop: (C_Screen.FRAME_SCRIPT_END, 0)
  );
  { rows 8 and 13 across the main frame and column 11 below row 13: DrawCharViewFrame, for ViewChar }
  characterSheetFrame: record runs: array[0..2] of Types.TFrameRun; stop: array[0..1] of Byte end = (
    runs: (
      (x1: 0; y1: 8; x2: 39; y2: 8; firstTile: 9; lastTile: 7),
      (x1: 0; y1: 13; x2: 39; y2: 13; firstTile: 9; lastTile: 7),
      (x1: 11; y1: 13; x2: 11; y2: 23; firstTile: 6; lastTile: 8)
    );
    stop: (C_Screen.FRAME_SCRIPT_END, 0)
  );
  { CGA color 0..3 standing in for each of the 16 colors, in Hline and Vline }
  cgaLineColors: array[0..15] of Byte = (
    0, 1, 0, 1, 2, 2, 2, 3, 0, 2, 1, 3, 2, 2, 3, 3
  );
  { punctuation a line may break after }
  breakChars: set of ' '..'?' = ['!', ',', '-', '.', ':', ';', '?'];
  { characters SanitizeFileName strips from a file name }
  invalidFileChars: array[1..10] of Char = ' .*,?/\:;|';
  { Names and prompts: careers, ships, races, statuses and skill groups. }
  { each career's eight career skills, by skill number; CharGen, Skills and ViewChar }
  careerSkills: array[C_Career.ROCKET_JOCK..C_Career.SCOUT, 1..8] of Byte = (
    { Rocket Jock }
    (C_Skill.NOTICE, C_Skill.MANEUVER_IN_0G, C_Skill.USE_JETPACK, C_Skill.PILOT_ROCKET, 52,
     C_Skill.DRIVE_GROUND_CAR, 54, C_Skill.DRIVE_JETCAR),
    { Medic }
    (C_Skill.TREAT_LIGHT, C_Skill.TREAT_SERIOUS, C_Skill.TREAT_CRITICAL, C_Skill.DIAGNOSE,
     C_Skill.TREAT_POISONING, C_Skill.TREAT_STUN, C_Skill.TREAT_DISEASE, 16),
    { Warrior }
    (C_Skill.NOTICE, C_Skill.LEADERSHIP, C_Skill.BATTLE_TACTICS, C_Skill.MANEUVER_IN_0G,
     C_Skill.USE_JETPACK, C_Skill.MOVE_SILENTLY, C_Skill.DEMOLITIONS, C_Skill.REPAIR_WEAPON),
    { Engineer }
    (C_Skill.NOTICE, C_Skill.REPAIR_ELECTRICAL, C_Skill.REPAIR_MECHANICAL,
     C_Skill.REPAIR_ENGINE,
     C_Skill.REPAIR_LIFE_SUPPORT, C_Skill.REPAIR_HULL, C_Skill.JURY_RIG,
     C_Skill.MANEUVER_IN_0G),
    { Rogue }
    (C_Skill.NOTICE, C_Skill.BYPASS_SECURITY, C_Skill.OPEN_LOCK, C_Skill.HIDE_IN_SHADOWS,
     C_Skill.MOVE_SILENTLY, C_Skill.PICK_POCKETS, C_Skill.CLIMB, C_Skill.FAST_TALK),
    { Scout }
    (C_Skill.NOTICE, C_Skill.ANIMAL_RIDING, C_Skill.BEFRIEND_ANIMAL, C_Skill.MOVE_SILENTLY,
     C_Skill.CLIMB, C_Skill.TRACKING, C_Skill.PLANETARY_SURVIVAL, C_Skill.PLANETOLOGY)
  );
  { TextRend's PauseContinue and EclMenu's EclInflictDamage pause on it }
  continuePrompt: String[33] = 'Press button or enter to continue';
  { EclVm's continue menus, ~ marking its key }
  continueMenuPrompt: String[34] = '~Press button or enter to continue';
  { GameBoot creates and reads it; CharGen's InitMouseJoystick reads and rewrites it }
  configFileName: String[10] = 'matrix.cfg';
  { name a new ship takes, by [kind, serial]; SaveLoad's LoadShipData; GameInit makes [2, 1] the phrase CbtActs' combat
    debug key wants in ParamStr(1) }
  shipNames: array[0..4, 0..4] of String[10] = (
    ('Van Allen', 'Hubble', 'Copernicus', 'Kepler', 'Goddard'),
    ('Adder', 'Viper', 'Anaconda', 'Sidewinder', 'Boomslang'),
    ('Mohave', 'Sahara', 'Gobi', 'Outback', 'Kalihari'),
    ('Flare', 'Corona', 'Hermes', 'Osiris', 'Apollo'),
    ('Liberator', 'Eclipse', 'Daisy', 'Gambit', 'Dervish')
  );
  { short name of each ship weapon kind; ShipCbt's menus and CharHlp's weapon list index it by a mount's kind and
    KIND_MASK }
  weaponShortNames: array[1..8] of String[8] = (
    'Laser', 'P-laser', 'Gyrocann', 'Missile', 'Hv-missl', 'K-cannon', 'acl-Cann', 'hv-Accel'
  );
  { short name of each ship system; entry 6 is the weapons, which have no long name in shipSystemNames; ShipCbt,
    CharHlp }
  systemShortNames: array[C_Sys.HULL..C_Sys.WEAPONS] of String[4] = (
    'Hull', 'Sens', 'Ctrl', 'Life', 'Fuel', 'Engn', 'Weap'
  );
  { name of each ship system, by TShipRec.systemNow index }
  shipSystemNames: array[C_Sys.HULL..C_Sys.ENGINES] of String[17] = (
    'Hull', 'Sensors', 'Control systems', 'Life support', 'Fuel', 'Engines'
  );
  { name of each ship type, by TShipRec.shipType }
  shipTypeNames: array[1..11] of String[17] = (
    'Fighter', 'Asterover', 'Scout cruiser', 'Lt freighter', 'Hv freighter', 'Md cruiser', 'Lt transport',
    'Hv transport', 'Hv cruiser', 'Space liner', 'Battler'
  );
  { name of each career, by TCharRecord.career }
  careerNames: array[C_Career.ROCKET_JOCK..C_Career.SCOUT] of String[11] = (
    'Rocket Jock', 'Medic', 'Warrior', 'Engineer', 'Rogue', 'Scout'
  );
  { name of each race, a character's or a ship's }
  raceNames: array[0..8] of String[13] = (
    'Monster', 'Terran', 'Martian', 'Venusian', 'Mercurian', 'Tinker', 'Desert Runner', 'lunarian',
    'lowlander'
  );
  { by TCharRecord.gender }
  genderNames: array[0..1] of String[6] = ('Male', 'Female');
  { name of each character status, by TCharRecord.status }
  statusNames: array[0..C_Status.USING_JETPACK] of String[12] = (
    'No status', 'Okay', 'Gone', 'Dead', 'Dying', 'Unconc', 'Fleeing', 'Poisoned', 'Comatose', 'Not here',
    'Dodging', 'Sprinting', 'Failed ZeroG', 'Used Jetpack', 'Using Jetpac'
  );
  { Skills' heading for each TSkill.group; no skill is in group 2 }
  skillGroupNames: array[C_Group.CAREER..C_Group.TECHNICAL] of String[20] = (
    'Career Skills', 'Dexterity Skills', 'Constitution Skills', 'Intelligence Skills', 'Wisdom Skills',
    'Charisma Skills', 'technical Skills'
  );
  { The skills. }
  { indexed as TCharRecord.skillLevels; Skills, CharHlp, ViewChar, EclVm }
  skillDefinitions: array[1..84] of Types.TSkill = (
    (name: 'Repair Electrical'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Repair Mechanical'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Repair Nuclear Engine'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Repair Life Support'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Repair Rocket Hull'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Jury Rig'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Bypass Security'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Open Lock'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Commo Operation'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Sensor Operation'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Demolitions'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Cook'; enabled: 0; group: C_Group.TECHNICAL),
    (name: 'First Aid'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Repair Weapon'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Repair Computer'; enabled: 0; group: C_Group.TECHNICAL),
    (name: 'Life Suspension Tech'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Treat Light Wounds'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Treat Serious Wounds'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Treat Critical Wounds'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Treat Poisoning'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Treat Stun/Paralysis'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Treat Disease'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'Diagnose'; enabled: 1; group: C_Group.TECHNICAL),
    (name: 'General Knowledge'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Ship Lore'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Composition'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Mathematics'; enabled: 1; group: C_Group.INTELLIGENCE),
    (name: 'Physics'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Geology'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Planetology'; enabled: 1; group: C_Group.INTELLIGENCE),
    (name: 'Battle Tactics'; enabled: 1; group: C_Group.INTELLIGENCE),
    (name: 'Chemistry'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Biology'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Design Engineering'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'History'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Astronomy'; enabled: 1; group: C_Group.INTELLIGENCE),
    (name: 'Botany'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Literature'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Economics'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Metallurgy'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Speak/Read Lang.'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Law'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Programming'; enabled: 1; group: C_Group.INTELLIGENCE),
    (name: 'Crytography'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Library Search'; enabled: 1; group: C_Group.INTELLIGENCE),
    (name: 'Astrogation'; enabled: 1; group: C_Group.INTELLIGENCE),
    (name: 'Navigation'; enabled: 1; group: C_Group.INTELLIGENCE),
    (name: 'Mimic'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Memorize'; enabled: 0; group: C_Group.INTELLIGENCE),
    (name: 'Disguise'; enabled: 1; group: C_Group.INTELLIGENCE),
    (name: 'Pilot Rocket'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Pilot Fixed Wing'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Drive Ground Car'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Pilot Rotor Wing'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Drive Motorcycle'; enabled: 0; group: C_Group.DEXTERITY),
    (name: 'Use Jetpack'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Pilot Ship/Sub'; enabled: 0; group: C_Group.DEXTERITY),
    (name: 'Drive Hvy Grnd Vehc'; enabled: 0; group: C_Group.DEXTERITY),
    (name: 'Drive Jetcar'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Animal Riding'; enabled: 0; group: C_Group.DEXTERITY),
    (name: 'Hide in Shadows'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Move Silently'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Pick Pockets'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Acrobatics'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Climb'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Swimming'; enabled: 0; group: C_Group.DEXTERITY),
    (name: 'Maneuver in 0G'; enabled: 1; group: C_Group.DEXTERITY),
    (name: 'Play Instrumnt'; enabled: 0; group: C_Group.DEXTERITY),
    (name: 'Paint/Draw'; enabled: 0; group: C_Group.DEXTERITY),
    (name: 'Hypnosis'; enabled: 0; group: C_Group.CHARISMA),
    (name: 'Act'; enabled: 1; group: C_Group.CHARISMA),
    (name: 'Intimidate'; enabled: 1; group: C_Group.CHARISMA),
    (name: 'Leadership'; enabled: 1; group: C_Group.CHARISMA),
    (name: 'Befriend Animal'; enabled: 1; group: C_Group.CHARISMA),
    (name: 'Animal Training'; enabled: 0; group: C_Group.CHARISMA),
    (name: 'Fast Talk/Convince'; enabled: 1; group: C_Group.CHARISMA),
    (name: 'Singing'; enabled: 1; group: C_Group.CHARISMA),
    (name: 'Distract'; enabled: 1; group: C_Group.CHARISMA),
    (name: 'Etiquette'; enabled: 1; group: C_Group.CHARISMA),
    (name: 'Tracking'; enabled: 1; group: C_Group.WISDOM),
    (name: 'Shadowing'; enabled: 1; group: C_Group.WISDOM),
    (name: 'Read Lips'; enabled: 0; group: C_Group.WISDOM),
    (name: 'Notice'; enabled: 1; group: C_Group.WISDOM),
    (name: 'Planetary Survival'; enabled: 1; group: C_Group.WISDOM)
  );
  { Epithet words. Note: EclVm's ECL skill check reads these bytes as skillDefinitions[85..92] when a skill number is
    past 84. }
  epithetWords: array[0..9] of String[20] = (
    'Evil', 'Nuclear', 'Death', 'Martian', 'From', 'Chicago', 'Good', 'Wholesome', 'Space', 'Cadet'
  );
  { Item names. }
  { the words an item's name is built from, by its nameIds, 0 for none; CharHlp's PrintItemString }
  itemNameParts: array[1..45] of String[20] = (
    'Knife', 'Mono', 'Cutlass', 'Sword', 'D.R. X-bow', 'Needle', 'Gun', 'Bolt', 'Laser', 'Pistol', 'Rocket',
    'Microwave', 'Rifle', 'Heat', 'Sonic Stunner', 'Grenade', 'Lnchr.', 'Plasma Thrwr', 'Martian', 'Venusian',
    'Mercurian', 'Lunarian', 'Spacesuit', 'Smartsuit', 'Heavy Body', 'Armor', 'Battle armor', 'w/fields', 'Explosive',
    'Gas', 'Stun', 'Dazzle', 'Chaff', 'Aerosol Mist', 'Demo Charge', 'ECM package', 'Protective', 'Goggles',
    'Breathing Mask', 'Rope', 'Jetpack', 'Poison Antidote', 'Polearm', 'mini', 'BLANK ITEM'
  );

{ Direction names and steps, and the CGA and EGA drawing tables. }
const
  { by direction, clockwise from north; CharHlp's PrintMiscInfo }
  directionNames: array[C_Dir.NORTH..C_Dir.NORTHWEST] of String[2] = (
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'
  );
  { A step's direction, and the CGA and EGA drawing tables. }
  { direction 0..7 of a step by [dy + 1, dx + 1], 8 for none; Pathing's NextPathStep }
  directionByDelta: array[0..2, 0..2] of Byte = (
    (C_Dir.NORTHWEST, C_Dir.NORTH, C_Dir.NORTHEAST),
    (C_Dir.WEST, C_Dir.CENTER, C_Dir.EAST),
    (C_Dir.SOUTHWEST, C_Dir.SOUTH, C_Dir.SOUTHEAST)
  );
  { EGA map-mask bit of planes 3..0; unused }
  egaPlaneMask: array[0..3] of Byte = ($08, $04, $02, $01);
  { CGA fill word of colors 0..3: Blit's Hline and Vline fill with its low byte, and TextRend's FillRect indexes
    cgaTextColors with the word. Note: FillRect indexes this table by text color unmasked (Portrait passes up to 12),
    past its four entries }
  cgaFillWords: array[0..3] of Word = ($0000, $5555, $AAAA, $FFFF);
  { CGA color 0..3 of each text color; DaxIo, TextRend and textrend.asm }
  cgaTextColors: array[0..15] of Byte = (
    0, 0, 0, 1, 2, 2, 2, 3, 0, 1, 1, 1, 2, 2, 3, 3
  );
  { mask of each 2-bit CGA pixel in a word, leftmost first; Blit }
  cgaPixelMasks: array[0..7] of Word = (
    $C000, $3000, $0C00, $0300, $00C0, $0030, $000C, $0003
  );

{ Drawing tables and color maps, the sound commands, the disk prompts, the ships' weapons and pictures, and the orbit
  layout. }
const
  { EGA map-mask bit of planes 0..3; Blit }
  egaPlaneBits: array[0..3] of Byte = ($01, $02, $04, $08);
  { CGA color (row) shifted into pixel 0..3 of a byte; Blit }
  cgaPixelColors: array[0..3, 0..3] of Byte = (
    ($00, $00, $00, $00),
    ($40, $10, $04, $01),
    ($80, $20, $08, $02),
    ($C0, $30, $0C, $03)
  );
  { colors 0..15 onto CGA colors 0..3, two to a byte, even color in the high nibble; CharGen and View3D pass it to
    Blit.FillPicRect, whose SrcNibble ignores it }
  packedColorMap: Types.TColorMap = ($00, $11, $22, $12, $01, $21, $30, $33);
  { the colors MapTiles' icon recolor finds }
  identityColors: Types.TPalette16 = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { what it turns each into: 8, dark gray, becomes black }
  iconRecolors: Types.TPalette16 = (0, 1, 2, 3, 4, 5, 6, 7, 0, 9, 10, 11, 12, 13, 14, 15);
  { The sounds. }
  { The sound commands SoundDrv.SoundCommand and Music.SendSoundCommand take: 255, 0 and 1 drive the sound driver, 2..20
    are the game's sounds, and 21 arms SoundDrv's forced exit. }
  { stops the driver and gives back INT 8; GameIo's ExitGame, DaxIo, Music, FixMain }
  soundDriverOff: Word = 255;
  { puts voice 0 on both devices: GameIo's Ctrl-S muting, FixMain, CharGen before it loads the character icons }
  silenceSounds: Word = 0;
  { sets SoundDrv's isOutputOn to 1 (SetSoundOutputEnabled): GameIo's Ctrl-S unmuting, CharGen after the icons }
  soundOutputOn: Word = 1;
  { CharHlp, over a creature an effect hurts in combat }
  damageSound: Word = 2;
  { CbtActs' shot from item types 16..18 (grenade launcher, plasma thrower, rocket launcher); EffHndlr's acid spit }
  launchSound: Word = 3;
  { CbtActs' projectile kinds 7, 8, 9 and 12 }
  cloudGrenadeSound: Word = 4;
  { CbtMap, when a creature goes down }
  downedSound: Word = 5;
  { CbtActs' shot from item type 15, the Sonic Stunner }
  sonicStunnerSound: Word = 6;
  { CbtActs, each attack that hits for damage }
  hitSound: Word = 7;
  { CbtActs' projectile kind 5 }
  dazzleGrenadeSound: Word = 8;
  { CbtActs, an attack round with no damaging hit }
  missSound: Word = 9;
  { Explore's 3-D steps and turns, EclVm after a 3-D move, CbtActs' combat moves }
  stepSound: Word = 10;
  { CbtActs' projectile kinds 6, 10 and 11, CharHlp over effects 15 and 16, ShipCbt when the enemy ship is destroyed }
  explosionSound: Word = 11;
  { CbtActs' shot from item types 5 and 7 (D.R. X-bow, Bolt Gun) }
  boltSound: Word = 12;
  { item type 14 }
  heatGunSound: Word = 13;
  { item types 9 and 13 (Laser Pistol, Laser Rifle) }
  laserSound: Word = 14;
  { item types 10 and 11 (Rocket Pistol, Rocket Rifle) }
  rocketSound: Word = 16;
  { item type 6 }
  needleGunSound: Word = 17;
  { item type 12 }
  microwaveGunSound: Word = 18;
  { ShipCbt's FireWeapon: [0] the K-cannon, [1] the other weapons, [2] the two lasers; [3] and [4] are unused }
  shipWeaponSounds: array[0..4] of Word = (
    16, 11, 19, 20, 21
  );
  { The disk prompts. }
  { the prompt for a game disk by data set (DaxIo's OpenDax, SaveLoad's LoadChar, GameInit's ITEMS load), not by the
    disk it names }
  diskPrompts: array[0..6] of String[29] = (
    'Insert disk 3 in drive ',
    'Insert disk 2 in drive ',
    'Insert disk 3 in drive ',
    'Insert disk 4 in drive ',
    'Insert disk 5 in drive ',
    'Insert disk 6 in drive ',
    'Insert disk 7 in drive '
  );
  { The ships' weapons and pictures. }
  { by weapon kind, a mount's kind and KIND_MASK; ShipCbt, PostCbt }
  shipWeapons: array[1..8] of Types.TShipWeaponDef = (
    (maxRange: 6; maxRangeTail: 1; reloadAmmo: 0; damage: 10; targetBonus: 1;
     targetBonusTail: (0, 0); name: 'Beam laser'),
    (maxRange: 4; maxRangeTail: 2; reloadAmmo: 0; damage: 20; targetBonus: 0;
     targetBonusTail: (0, 0); name: 'Pumped laser'),
    (maxRange: 4; maxRangeTail: 1; reloadAmmo: 50; damage: 10; targetBonus: 1;
     targetBonusTail: (100, 400); name: 'Gyrocannon'),
    (maxRange: 6; maxRangeTail: 1; reloadAmmo: 4; damage: 40; targetBonus: 0;
     targetBonusTail: (300, 400); name: 'Missile mount'),
    (maxRange: 6; maxRangeTail: 2; reloadAmmo: 4; damage: 60; targetBonus: -1;
     targetBonusTail: (900, 1200); name: 'Heavy missile mount'),
    (maxRange: 4; maxRangeTail: 5; reloadAmmo: 6; damage: 100; targetBonus: -3;
     targetBonusTail: (1500, 4000); name: 'K-cannon'),
    (maxRange: 2; maxRangeTail: 1; reloadAmmo: 15; damage: 20; targetBonus: -1;
     targetBonusTail: (200, 1500); name: 'Light acceleration gun'),
    (maxRange: 2; maxRangeTail: 2; reloadAmmo: 10; damage: 30; targetBonus: -2;
     targetBonusTail: (400, 3000); name: 'Heavy acceleration gun')
  );
  { 'ships' picture i + 10 as OrbitMap loads it; CharHlp draws the ship screen from it and ShipCbt the weapon effects }
  shipPictures: array[0..28] of Types.TShipPic = (
    (height: 48; width: 24; widthTail: 1; isTransparent: False; x: 0; y: 11),
    (height: 72; width: 10; widthTail: 1; isTransparent: True; x: 0; y: 0),
    (height: 48; width: 10; widthTail: 1; isTransparent: True; x: 2; y: 0),
    (height: 48; width: 10; widthTail: 1; isTransparent: True; x: 1; y: 0),
    (height: 40; width: 7; widthTail: 1; isTransparent: True; x: 0; y: 2),
    (height: 40; width: 8; widthTail: 1; isTransparent: True; x: 0; y: 1),
    (height: 32; width: 8; widthTail: 1; isTransparent: True; x: 0; y: 2),
    (height: 32; width: 5; widthTail: 1; isTransparent: True; x: 1; y: 2),
    (height: 24; width: 5; widthTail: 1; isTransparent: True; x: 0; y: 3),
    (height: 24; width: 5; widthTail: 1; isTransparent: True; x: 0; y: 3),
    (height: 24; width: 4; widthTail: 1; isTransparent: True; x: 1; y: 3),
    (height: 24; width: 4; widthTail: 1; isTransparent: True; x: 0; y: 3),
    (height: 16; width: 4; widthTail: 1; isTransparent: True; x: 0; y: 4),
    (height: 16; width: 2; widthTail: 1; isTransparent: True; x: 2; y: 4),
    (height: 24; width: 3; widthTail: 1; isTransparent: True; x: 0; y: 3),
    (height: 16; width: 2; widthTail: 1; isTransparent: True; x: 1; y: 4),
    (height: 32; width: 3; widthTail: 1; isTransparent: True; x: 26; y: 14),
    (height: 16; width: 3; widthTail: 1; isTransparent: False; x: 26; y: 1),
    (height: 16; width: 3; widthTail: 1; isTransparent: True; x: 26; y: 3),
    (height: 16; width: 3; widthTail: 1; isTransparent: True; x: 26; y: 5),
    (height: 16; width: 3; widthTail: 1; isTransparent: True; x: 26; y: 7),
    (height: 16; width: 3; widthTail: 1; isTransparent: True; x: 26; y: 9),
    (height: 16; width: 3; widthTail: 1; isTransparent: True; x: 26; y: 11),
    (height: 8; width: 2; widthTail: 1; isTransparent: True; x: 1; y: 12),
    (height: 8; width: 2; widthTail: 1; isTransparent: True; x: 1; y: 13),
    (height: 8; width: 2; widthTail: 1; isTransparent: True; x: 1; y: 14),
    (height: 8; width: 2; widthTail: 1; isTransparent: True; x: 1; y: 15),
    (height: 8; width: 2; widthTail: 1; isTransparent: True; x: 1; y: 16),
    (height: 8; width: 2; widthTail: 1; isTransparent: True; x: 1; y: 17)
  );
  { The orbit map's layout. }
  { orbit-map body positions, orbit by orbit; OrbitMap, GameInit }
  orbitPositions: array[0..57] of Types.TOrbitPosition = (
    (x: 12; y: 10; sprite: 1), (x: 10; y: 10; sprite: 2), (x: 12; y: 9; sprite: 3), (x: 12; y: 11; sprite: 6),
    (x: 10; y: 11; sprite: 5), (x: 10; y: 9; sprite: 4), (x: 11; y: 7; sprite: 9), (x: 13; y: 8; sprite: 8),
    (x: 14; y: 10; sprite: 7), (x: 13; y: 12; sprite: 14), (x: 11; y: 13; sprite: 13), (x: 9; y: 12; sprite: 12),
    (x: 8; y: 10; sprite: 11), (x: 9; y: 8; sprite: 10), (x: 11; y: 4; sprite: 19), (x: 13; y: 5; sprite: 18),
    (x: 15; y: 6; sprite: 17), (x: 16; y: 8; sprite: 16), (x: 17; y: 10; sprite: 15), (x: 16; y: 12; sprite: 30),
    (x: 15; y: 14; sprite: 29), (x: 13; y: 15; sprite: 28), (x: 11; y: 16; sprite: 27), (x: 9; y: 15; sprite: 26),
    (x: 7; y: 14; sprite: 25), (x: 6; y: 12; sprite: 24), (x: 5; y: 10; sprite: 23), (x: 6; y: 8; sprite: 22),
    (x: 7; y: 6; sprite: 21), (x: 9; y: 5; sprite: 20), (x: 12; y: 0; sprite: 66), (x: 14; y: 1; sprite: 65),
    (x: 16; y: 2; sprite: 64), (x: 18; y: 3; sprite: 63), (x: 19; y: 5; sprite: 62), (x: 20; y: 7; sprite: 61),
    (x: 21; y: 9; sprite: 60), (x: 21; y: 11; sprite: 59), (x: 20; y: 13; sprite: 86), (x: 19; y: 15; sprite: 85),
    (x: 18; y: 17; sprite: 84), (x: 16; y: 18; sprite: 83), (x: 14; y: 19; sprite: 82), (x: 12; y: 20; sprite: 81),
    (x: 10; y: 20; sprite: 80), (x: 8; y: 19; sprite: 79), (x: 6; y: 18; sprite: 78), (x: 4; y: 17; sprite: 77),
    (x: 3; y: 15; sprite: 76), (x: 2; y: 13; sprite: 75), (x: 1; y: 11; sprite: 74), (x: 1; y: 9; sprite: 73),
    (x: 2; y: 7; sprite: 72), (x: 3; y: 5; sprite: 71), (x: 4; y: 3; sprite: 70), (x: 6; y: 2; sprite: 69),
    (x: 8; y: 1; sprite: 68), (x: 10; y: 0; sprite: 67)
  );
  { each orbit's first entry in orbitPositions; OrbitMap, GameInit }
  orbitFirstPositions: array[0..4] of Byte = (0, 2, 6, 14, 30);
  { positions per orbit; OrbitMap }
  orbitLengths: array[0..4] of Byte = (2, 4, 8, 16, 28);
  { phases of orbit 4's eight extra bodies; OrbitMap }
  outerBodyPhases: array[0..7] of Byte = (3, 6, 9, 12, 17, 19, 22, 26);
  { each orbit's starting phase; OrbitMap, GameInit }
  orbitStartPhases: array[0..4] of Byte = (0, 0, 7, 9, 7);

{ Tile-set ranges, and the combat tables: direction steps, terrain, icon cells, the effects cleared after combat and the
  effect names. }
const
  { first tile of each tile-set slot, slot 6 the borders; Sym8x8, View3D }
  symSetFirst: array[0..6] of Word = (0, 46, 116, 186, 256, 296, 391);
  { last tile of each tile-set slot; Sym8x8 }
  symSetLast: array[0..6] of Word = (255, 115, 185, 255, 295, 390, 402);
  { Direction steps, the combat terrain, combat icon cells and effects. }
  { x step of each direction clockwise from north, 0 for CENTER; CbtActs, CbtMap, CombatSt, CharHlp, FxEngine, Explore,
    Pathing, View3D }
  dirStepX: array[C_Dir.NORTH..C_Dir.CENTER] of ShortInt = (
    0, 1, 1, 1, 0, -1, -1, -1, 0
  );
  { y step of each direction, north -1; the same readers }
  dirStepY: array[C_Dir.NORTH..C_Dir.CENTER] of ShortInt = (
    -1, -1, 0, 1, 1, 1, 0, -1, 0
  );
  { each kind of ground combat terrain, by the value an arena cell holds; CbtMap draws a cell holding 0 or more than
    LAST_COMBAT_TERRAIN as terrain 21 }
  terrainInfo: array[1..C_Terr.LAST_COMBAT_TERRAIN] of Types.TTerrainRec = (
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 0), (cost: 1; lineClass: 0; blastResult: 0; tileId: 1),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 2), (cost: 1; lineClass: 0; blastResult: 0; tileId: 3),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 4), (cost: 1; lineClass: 0; blastResult: 0; tileId: 5),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 0), (cost: 255; lineClass: 1; blastResult: 0; tileId: 1),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 2), (cost: 255; lineClass: 1; blastResult: 0; tileId: 3),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 4), (cost: 255; lineClass: 1; blastResult: 0; tileId: 5),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 6), (cost: 255; lineClass: 1; blastResult: 0; tileId: 7),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 8), (cost: 255; lineClass: 1; blastResult: 0; tileId: 9),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 10), (cost: 255; lineClass: 1; blastResult: 0; tileId: 11),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 12), (cost: 255; lineClass: 1; blastResult: 0; tileId: 13),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 14), (cost: 255; lineClass: 1; blastResult: 0; tileId: 15),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 16), (cost: 1; lineClass: 0; blastResult: 0; tileId: 17),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 18), (cost: 1; lineClass: 0; blastResult: 0; tileId: 19),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 20), (cost: 1; lineClass: 0; blastResult: 0; tileId: 21),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 22), (cost: 255; lineClass: 1; blastResult: 0; tileId: 23),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 24), (cost: 255; lineClass: 1; blastResult: 0; tileId: 25),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 26), (cost: 1; lineClass: 0; blastResult: 0; tileId: 27),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 28), (cost: 1; lineClass: 0; blastResult: 0; tileId: 29),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 30), (cost: 1; lineClass: 0; blastResult: 0; tileId: 31),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 32), (cost: 1; lineClass: 0; blastResult: 0; tileId: 33),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 49), (cost: 255; lineClass: 1; blastResult: 0; tileId: 50),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 51), (cost: 255; lineClass: 1; blastResult: 0; tileId: 52),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 34), (cost: 2; lineClass: 2; blastResult: 0; tileId: 35),
    (cost: 2; lineClass: 2; blastResult: 0; tileId: 36), (cost: 2; lineClass: 2; blastResult: 0; tileId: 37),
    (cost: 2; lineClass: 2; blastResult: 0; tileId: 38), (cost: 2; lineClass: 2; blastResult: 0; tileId: 39),
    (cost: 2; lineClass: 2; blastResult: 0; tileId: 40), (cost: 2; lineClass: 2; blastResult: 0; tileId: 41),
    (cost: 2; lineClass: 2; blastResult: 0; tileId: 42), (cost: 2; lineClass: 2; blastResult: 0; tileId: 43),
    (cost: 2; lineClass: 2; blastResult: 0; tileId: 44), (cost: 1; lineClass: 0; blastResult: 0; tileId: 45),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 46), (cost: 1; lineClass: 0; blastResult: 0; tileId: 47),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 48), (cost: 2; lineClass: 0; blastResult: 0; tileId: 34),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 35), (cost: 2; lineClass: 2; blastResult: 0; tileId: 36),
    (cost: 2; lineClass: 2; blastResult: 0; tileId: 37), (cost: 2; lineClass: 2; blastResult: 0; tileId: 38),
    (cost: 2; lineClass: 2; blastResult: 0; tileId: 39), (cost: 2; lineClass: 2; blastResult: 0; tileId: 40),
    (cost: 2; lineClass: 2; blastResult: 0; tileId: 41), (cost: 2; lineClass: 2; blastResult: 0; tileId: 42),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 1), (cost: 255; lineClass: 1; blastResult: 0; tileId: 2),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 3), (cost: 255; lineClass: 1; blastResult: 0; tileId: 4),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 5), (cost: 255; lineClass: 1; blastResult: 0; tileId: 6),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 7), (cost: 255; lineClass: 1; blastResult: 0; tileId: 8),
    (cost: 255; lineClass: 1; blastResult: 0; tileId: 9), (cost: 255; lineClass: 1; blastResult: 0; tileId: 10),
    (cost: 255; lineClass: 2; blastResult: 0; tileId: 11), (cost: 255; lineClass: 2; blastResult: 0; tileId: 12),
    (cost: 255; lineClass: 2; blastResult: 0; tileId: 13), (cost: 4; lineClass: 2; blastResult: 0; tileId: 14),
    (cost: 4; lineClass: 2; blastResult: 0; tileId: 15), (cost: 4; lineClass: 2; blastResult: 0; tileId: 16),
    (cost: 4; lineClass: 2; blastResult: 0; tileId: 17), (cost: 4; lineClass: 2; blastResult: 0; tileId: 18),
    (cost: 4; lineClass: 2; blastResult: 0; tileId: 19), (cost: 4; lineClass: 2; blastResult: 0; tileId: 20),
    (cost: 1; lineClass: 0; blastResult: 139; tileId: 21), (cost: 1; lineClass: 0; blastResult: 139; tileId: 22),
    (cost: 2; lineClass: 0; blastResult: 0; tileId: 23), (cost: 255; lineClass: 0; blastResult: 0; tileId: 24),
    (cost: 255; lineClass: 0; blastResult: 0; tileId: 25), (cost: 3; lineClass: 2; blastResult: 131; tileId: 26),
    (cost: 3; lineClass: 2; blastResult: 132; tileId: 27), (cost: 3; lineClass: 2; blastResult: 133; tileId: 28),
    (cost: 3; lineClass: 2; blastResult: 134; tileId: 29), (cost: 1; lineClass: 2; blastResult: 135; tileId: 30),
    (cost: 1; lineClass: 2; blastResult: 136; tileId: 31), (cost: 255; lineClass: 2; blastResult: 137; tileId: 32),
    (cost: 255; lineClass: 2; blastResult: 138; tileId: 33), (cost: 3; lineClass: 2; blastResult: 140; tileId: 1),
    (cost: 3; lineClass: 2; blastResult: 141; tileId: 2), (cost: 3; lineClass: 2; blastResult: 142; tileId: 3),
    (cost: 3; lineClass: 2; blastResult: 143; tileId: 4), (cost: 3; lineClass: 2; blastResult: 144; tileId: 5),
    (cost: 3; lineClass: 2; blastResult: 145; tileId: 6), (cost: 1; lineClass: 0; blastResult: 146; tileId: 7),
    (cost: 1; lineClass: 0; blastResult: 146; tileId: 8), (cost: 255; lineClass: 0; blastResult: 0; tileId: 9),
    (cost: 255; lineClass: 0; blastResult: 0; tileId: 10), (cost: 2; lineClass: 0; blastResult: 0; tileId: 11),
    (cost: 2; lineClass: 0; blastResult: 0; tileId: 12), (cost: 2; lineClass: 0; blastResult: 0; tileId: 13),
    (cost: 3; lineClass: 2; blastResult: 147; tileId: 14), (cost: 3; lineClass: 2; blastResult: 148; tileId: 15),
    (cost: 3; lineClass: 0; blastResult: 153; tileId: 16), (cost: 255; lineClass: 2; blastResult: 250; tileId: 17),
    (cost: 255; lineClass: 2; blastResult: 250; tileId: 18), (cost: 255; lineClass: 2; blastResult: 250; tileId: 19),
    (cost: 255; lineClass: 2; blastResult: 250; tileId: 20), (cost: 255; lineClass: 2; blastResult: 250; tileId: 21),
    (cost: 255; lineClass: 2; blastResult: 251; tileId: 22), (cost: 255; lineClass: 2; blastResult: 251; tileId: 23),
    (cost: 255; lineClass: 2; blastResult: 252; tileId: 24), (cost: 255; lineClass: 2; blastResult: 252; tileId: 25),
    (cost: 1; lineClass: 2; blastResult: 151; tileId: 26), (cost: 1; lineClass: 2; blastResult: 151; tileId: 27),
    (cost: 1; lineClass: 2; blastResult: 151; tileId: 28), (cost: 1; lineClass: 2; blastResult: 151; tileId: 29),
    (cost: 2; lineClass: 0; blastResult: 0; tileId: 34), (cost: 2; lineClass: 0; blastResult: 0; tileId: 35),
    (cost: 2; lineClass: 0; blastResult: 0; tileId: 36), (cost: 2; lineClass: 0; blastResult: 0; tileId: 37),
    (cost: 1; lineClass: 2; blastResult: 0; tileId: 38), (cost: 1; lineClass: 2; blastResult: 0; tileId: 39),
    (cost: 255; lineClass: 2; blastResult: 0; tileId: 40), (cost: 255; lineClass: 2; blastResult: 0; tileId: 41),
    (cost: 1; lineClass: 0; blastResult: 0; tileId: 42), (cost: 2; lineClass: 0; blastResult: 0; tileId: 30),
    (cost: 2; lineClass: 0; blastResult: 0; tileId: 31), (cost: 2; lineClass: 2; blastResult: 0; tileId: 42),
    (cost: 2; lineClass: 0; blastResult: 0; tileId: 33), (cost: 2; lineClass: 0; blastResult: 0; tileId: 34),
    (cost: 2; lineClass: 0; blastResult: 0; tileId: 35), (cost: 1; lineClass: 0; blastResult: 0; tileId: 36),
    (cost: 2; lineClass: 2; blastResult: 0; tileId: 37), (cost: 2; lineClass: 0; blastResult: 0; tileId: 38),
    (cost: 255; lineClass: 0; blastResult: 251; tileId: 39), (cost: 255; lineClass: 2; blastResult: 252; tileId: 40),
    (cost: 1; lineClass: 2; blastResult: 0; tileId: 41), (cost: 255; lineClass: 0; blastResult: 250; tileId: 32),
    (cost: 2; lineClass: 0; blastResult: 0; tileId: 43), (cost: 2; lineClass: 0; blastResult: 0; tileId: 44)
  );
  { cells of a size 1..4 combat icon relative to its anchor cell; dx < 0 is no cell; CbtMap }
  iconDelta: array[1..4, 0..3] of Types.TIconCoordinateDelta = (
    ((dx: 0; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 0; dy: 1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: 0; dy: 1), (dx: 1; dy: 1))
  );
  { unused }
  iconDeltaTail: Byte = 1;
  { effects PostCbt removes from each party member after combat: the five that have a name in effectStatusNames }
  postCombatClearedEffects: array[1..5] of Byte = (
    C_Effect.SCARED, C_Effect.DIZZY, C_Effect.STUNNED, C_Effect.BLIND, C_Effect.HELPLESS
  );
  { unused: CbtActs builds its 'is ' message from a literal of its own }
  isText: String = 'is ';
  { unused }
  affectedText: String = 'Affected';
  { unused }
  unaffectedText: String = 'Unaffected';
  { The effect names. }
  { name of each effect a creature can be under, by effect number, '' for most; CbtActs prints a projectile's message by
    it }
  effectStatusNames: array[1..32] of String[40] = (
    'Helpless', 'Scared', '', '', '', '', '', '', '', '', '', '',
    'Blind', 'Stunned', '', '', '', '', '', '', '', '', '', '', '', '', '', '',
    'Dizzy', '', '', ''
  );
  { A cloud's cells. }
  { the directions of a cloud's 3x3 block, center first; CbtActs, CbtMap, FxEngine }
  cloudDir: array[1..9] of Byte = (
    C_Dir.CENTER, C_Dir.EAST, C_Dir.SOUTHEAST, C_Dir.SOUTH, C_Dir.SOUTHWEST, C_Dir.WEST,
        C_Dir.NORTHWEST, C_Dir.NORTH, C_Dir.NORTHEAST
  );

{ The menus' keypad and click-direction scan codes. }
const
  { scan code of the cursor key on keypad digits 1..9, a space for 5; CharGen and MenuCore index it by digit - '1',
    Explore by facing }
  keypadScan: array[0..8] of Char = (
    C_Keys.END_KEY, C_Keys.DOWN, C_Keys.PAGE_DOWN, C_Keys.LEFT, ' ', C_Keys.RIGHT, C_Keys.HOME,
    C_Keys.UP, C_Keys.PAGE_UP
  );
  { [y, x] of a click on MenuCore's 11x11 grid, counted from 3, to the scan code of the arrow key toward it: H up, K
    left, M right, P down }
  vectorScan: array[3..13, 3..13] of Char = (
    'HHHHHHHHHHH',
    'KHHHHHHHHHM',
    'KKHHHHHHHMM',
    'KKKHHHHHMMM',
    'KKKKHHHMMMM',
    'KKKKKHMMMMM',
    'KKKKPPPMMMM',
    'KKKPPPPPMMM',
    'KKPPPPPPPMM',
    'KPPPPPPPPPM',
    'PPPPPPPPPPP'
  );
  { unused }
  vectorScanTail: Byte = 0;

{ Trade prompts, the clock, save files, character rules, the shop and copy-protection prompts, mouse cursors, the
  joystick, fill colors and the music files. }
const
  { prompt to pick who receives a credit trade; ViewChar }
  tradeToPrompt: String[9] = 'Trade to?';
  { unused }
  coinTypePrompt: String[20] = 'Select type of coin ';
  { unused }
  tradeAmountHead: String[9] = 'How much ';
  { unused }
  tradeAmountTail: String[16] = 'will you trade? ';
  { The game clock. }
  { how many of each game-clock unit make one of the next, smallest first; GameTime carries the clock by it }
  clockUnitScale: array[0..6] of Word = (
    10, 10, 6, 24, 30, 12, 100
  );
  { Save files. }
  { extension of a saved character's item file; SaveLoad }
  itemFileExt: String[4] = '.stf';
  { extension of a saved character's second item list file; SaveLoad }
  alternateItemFileExt: String[4] = '.hid';
  { extension of a saved character's effect file; SaveLoad }
  effectFileExt: String[4] = '.sfx';
  { a saved game's file name ahead of its slot letter; SaveLoad }
  saveGameStem: String[6] = 'savgam';
  { prompt ahead of the save disk's drive letter; SaveLoad }
  saveDiskPrompt: String[17] = 'Put save disk in ';
  { Career and race rules. }
  { The race and career rules CharGen makes and trains a character by. }
  { base combat value by career and level; CharGen sets it at creation, [career, 7], and on each training }
  careerBaseCombat: array[C_Career.ROCKET_JOCK..C_Career.SCOUT, 0..20] of Byte = (
    (40, 40, 40, 41, 41, 42, 42, 43, 43, 44, 44, 45, 45, 46, 46, 47, 47, 48, 48, 49, 49),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46, 48, 48, 48, 50, 50, 50, 52, 52),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46, 48, 48, 48, 50, 50, 50, 52, 52),
    (40, 40, 40, 41, 41, 42, 42, 43, 43, 44, 44, 45, 45, 46, 46, 47, 47, 48, 48, 49, 49),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59)
  );
  { Unused: by career, the first level whose hit points are a fixed gain. CharGen's AddLevelHitPoints fixes the gain
    from level 10 for every career. }
  firstFixedHpLevel: array[C_Career.ROCKET_JOCK..C_Career.SCOUT] of Byte = (21, 15, 10, 10, 11, 12);
  { how many careers each race may take, then its careers; CharGen's class menu offers the first count }
  raceCareers: array[1..8] of record count: ShortInt; careers: array[1..6] of ShortInt end = (
    (count: 5; careers: (1, 2, 3, 4, 5, 6)),
    (count: 5; careers: (1, 2, 3, 4, 5, 6)),
    (count: 5; careers: (1, 2, 3, 4, 5, 6)),
    (count: 5; careers: (1, 2, 3, 4, 5, 6)),
    (count: 2; careers: (2, 4, 0, 0, 0, 0)),
    (count: 3; careers: (1, 3, 4, 0, 0, 0)),
    (count: 5; careers: (1, 2, 3, 4, 5, 6)),
    (count: 2; careers: (3, 4, 0, 0, 0, 0))
  );
  { bonus to each level's hit points, by constitution; CharGen's HpMinimum, HpMaximum and AddLevelHitPoints }
  constitutionLevelBonus: array[1..22] of ShortInt = (
    -3, -2, -2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 5, 6, 6
  );
  { experience each career needs for levels 2..20; CharGen and MenuCore. CharGen's TrainingMenu, after training to level
    20, and MenuCore's DisplayCreatureName, for a level-20 character, read [career, 21], past the row }
  experienceNeeded: array[C_Career.ROCKET_JOCK..C_Career.SCOUT, 2..20] of LongInt = (
    (1250, 2500, 5000, 10000, 20000, 40000, 70000, 110000, 160000, 220000, 440000, 880000, 1760000, 3520000,
     7040000, 14080000, 28160000, 56320000, 112640000),
    (1500, 3000, 6000, 12000, 24000, 48000, 96000, 192000, 384000, 768000, 1536000, 3072000, 6144000, 12288000,
     24576000, 49152000, 98304000, 196608000, 393216000),
    (2000, 4000, 8000, 16000, 32000, 64000, 125000, 250000, 500000, 750000, 1000000, 2000000, 4000000, 8000000,
     16000000, 32000000, 64000000, 128000000, 256000000),
    (1250, 2500, 5000, 10000, 20000, 40000, 70000, 110000, 160000, 220000, 440000, 880000, 1760000, 3520000,
     7040000, 14080000, 28160000, 56320000, 112640000),
    (1250, 2500, 5000, 10000, 20000, 40000, 70000, 110000, 160000, 220000, 440000, 880000, 1760000, 3520000,
     7040000, 14080000, 28160000, 56320000, 112640000),
    (2250, 4500, 9000, 18000, 36000, 75000, 150000, 300000, 600000, 900000, 1500000, 3000000, 6000000, 12000000,
     24000000, 48000000, 96000000, 192000000, 384000000)
  );
  { each race's adjustment to a new character's eight saving throws, subtracted from baseSavingThrows; CharGen }
  raceSaveAdjust: array[1..8, 0..7] of ShortInt = (
    (1, 0, 0, 0, 0, 0, 0, 0),
    (-1, 0, 0, 0, 1, 1, -1, 1),
    (1, 3, 0, 1, 1, -2, 3, -2),
    (1, 0, 0, 0, 3, 1, 4, -3),
    (0, -1, -3, -2, 0, 0, 0, 0),
    (2, 0, 1, 1, 2, 2, -3, 4),
    (0, -1, 0, 0, 2, 2, -1, -1),
    (2, 4, 2, 3, 1, -4, 6, -6)
  );
  { a new character's eight saving throws before its race adjusts them; CharGen }
  baseSavingThrows: array[0..7] of Byte = (
    15, 14, 14, 13, 13, 16, 13, 13
  );
  { each race's adjustment to the seven abilities, added to the rolled scores; CharGen, whose ModifyCharacterMenu also
    keeps each ability between it + 3 and it + 18 }
  raceStatAdjust: array[1..8, 0..6] of ShortInt = (
    (0, 0, 1, 0, 1, 0, 0),
    (-1, 1, -1, 0, -1, 1, 0),
    (0, -1, 1, 0, 1, -1, 0),
    (-1, 1, 1, 0, 0, 0, 0),
    (-2, 3, -2, 0, 0, 0, 3),
    (2, 2, 1, 0, 0, -1, 0),
    (-2, 1, -1, 2, 0, 0, 0),
    (3, 0, 1, 0, 0, -3, 1)
  );
  { each career's minimum for the seven abilities; CharGen }
  careerStatMinimum: array[C_Career.ROCKET_JOCK..C_Career.SCOUT, 0..6] of Byte = (
    (1, 13, 1, 11, 1, 12, 1),
    (1, 12, 1, 12, 12, 1, 1),
    (10, 8, 10, 8, 1, 1, 1),
    (10, 1, 12, 8, 1, 1, 13),
    (1, 13, 1, 8, 9, 13, 1),
    (1, 1, 8, 8, 9, 8, 1)
  );
  { the skills a new character of each career starts with, to the first skill 0; Skills' InitializeCareerSkills }
  careerInitialSkills: array[C_Career.ROCKET_JOCK..C_Career.SCOUT, 1..12] of Types.TInitialSkill = (
    { Rocket Jock }
    ((skill: C_Skill.DRIVE_GROUND_CAR; value: 40), (skill: C_Skill.MANEUVER_IN_0G; value: 85),
      (skill: C_Skill.NOTICE; value: 40), (skill: C_Skill.PILOT_ROCKET; value: 85),
      (skill: C_Skill.USE_JETPACK; value: 50), (skill: C_Skill.FIRST_AID; value: 25),
      (skill: C_Skill.MATHEMATICS; value: 25), (skill: C_Skill.ASTRONOMY; value: 20),
      (skill: C_Skill.ASTROGATION; value: 70), (skill: 0; value: 0),
      (skill: 0; value: 0), (skill: 0; value: 0)),
    { Medic }
    ((skill: C_Skill.DIAGNOSE; value: 15), (skill: C_Skill.TREAT_CRITICAL; value: 75),
      (skill: C_Skill.TREAT_LIGHT; value: 50), (skill: C_Skill.TREAT_POISONING; value: 40),
      (skill: C_Skill.TREAT_SERIOUS; value: 40), (skill: C_Skill.TREAT_STUN; value: 60),
      (skill: C_Skill.MANEUVER_IN_0G; value: 80), (skill: C_Skill.BEFRIEND_ANIMAL; value: 55),
      (skill: C_Skill.BATTLE_TACTICS; value: 5), (skill: 0; value: 0),
      (skill: 0; value: 0), (skill: 0; value: 0)),
    { Warrior }
    ((skill: C_Skill.BATTLE_TACTICS; value: 50), (skill: C_Skill.DEMOLITIONS; value: 25),
      (skill: C_Skill.LEADERSHIP; value: 50), (skill: C_Skill.MANEUVER_IN_0G; value: 85),
      (skill: C_Skill.MOVE_SILENTLY; value: 20), (skill: C_Skill.NOTICE; value: 20),
      (skill: C_Skill.REPAIR_WEAPON; value: 10), (skill: C_Skill.USE_JETPACK; value: 20),
      (skill: C_Skill.FIRST_AID; value: 70), (skill: C_Skill.JURY_RIG; value: 50),
      (skill: C_Skill.REPAIR_ELECTRICAL; value: 10), (skill: C_Skill.REPAIR_MECHANICAL; value: 10)),
    { Engineer }
    ((skill: C_Skill.JURY_RIG; value: 20), (skill: C_Skill.MANEUVER_IN_0G; value: 85),
      (skill: C_Skill.NOTICE; value: 25), (skill: C_Skill.REPAIR_ELECTRICAL; value: 30),
      (skill: C_Skill.REPAIR_LIFE_SUPPORT; value: 30), (skill: C_Skill.REPAIR_MECHANICAL; value: 30),
      (skill: C_Skill.REPAIR_ENGINE; value: 30), (skill: C_Skill.REPAIR_HULL; value: 30),
      (skill: C_Skill.FIRST_AID; value: 70), (skill: C_Skill.REPAIR_WEAPON; value: 70),
      (skill: 0; value: 0), (skill: 0; value: 0)),
    { Rogue }
    ((skill: C_Skill.BYPASS_SECURITY; value: 60), (skill: C_Skill.CLIMB; value: 30),
      (skill: C_Skill.FAST_TALK; value: 40), (skill: C_Skill.HIDE_IN_SHADOWS; value: 40),
      (skill: C_Skill.MOVE_SILENTLY; value: 50), (skill: C_Skill.NOTICE; value: 40),
      (skill: C_Skill.OPEN_LOCK; value: 60), (skill: C_Skill.PICK_POCKETS; value: 40),
      (skill: C_Skill.FIRST_AID; value: 10), (skill: C_Skill.MANEUVER_IN_0G; value: 70),
      (skill: C_Skill.MATHEMATICS; value: 10), (skill: C_Skill.PROGRAMMING; value: 50)),
    { Scout }
    ((skill: C_Skill.PLANETOLOGY; value: 10), (skill: C_Skill.ANIMAL_RIDING; value: 10),
      (skill: C_Skill.MOVE_SILENTLY; value: 75), (skill: C_Skill.CLIMB; value: 40),
      (skill: C_Skill.BEFRIEND_ANIMAL; value: 30), (skill: C_Skill.TRACKING; value: 50),
      (skill: C_Skill.NOTICE; value: 45), (skill: C_Skill.PLANETARY_SURVIVAL; value: 45),
      (skill: C_Skill.MANEUVER_IN_0G; value: 70), (skill: C_Skill.BATTLE_TACTICS; value: 70),
      (skill: 0; value: 0), (skill: 0; value: 0))
  );
  { unused }
  careerInitialSkillsTail: array[0..1] of Byte = (0, 0);
  { The shop. }
  { the prompt over Shop's buy menu }
  itemsPrompt: String[7] = 'Items: ';
  { Shop's buy menu option line }
  buyMenu: String[3] = 'Buy';
  { 38 spaces; Shop lays each item's price and name into a copy of it for the buy menu }
  menuBlankLine: String[39] = '                                      ';
  { The copy-protection prompts. }
  { CopyProt's prompt, first line }
  logBookPrompt: String[25] = 'In the Log Book on page';
  { its second line }
  headingPrompt: String[21] = 'following the heading';
  { the question, before the ordinal }
  questionHead: String[12] = 'what is the ';
  { the question, after the ordinal }
  questionTail: String[6] = 'word? ';
  { the ordinal that names the word to type; CopyProt }
  wordOrdinals: array[1..10] of String[18] = (
    'first  ', 'second ', 'third  ', 'fourth ', 'fifth  ', 'sixth  ', 'seventh', 'eighth ', 'ninth', 'tenth'
  );
  { The mouse cursors. }
  { the mouse arrow in every mode but CGA; GameInit and CharGen's InitMouseJoystick }
  arrowCursor: Types.TMouseCursor = (
    screenMask: ($3FFF, $1FFF, $0FFF, $07FF, $03FF, $01FF, $00FF, $007F,
                 $003F, $003F, $01FF, $00FF, $10FF, $F87F, $F87F, $FC7F);
    cursorMask: ($0000, $4000, $6000, $7000, $7800, $7C00, $7E00, $7F00,
                 $7F80, $7C00, $6C00, $4600, $0600, $0300, $0300, $0000)
  );
  { the CGA arrow, two bits a pixel; the same readers, when displayMode is 0 }
  cgaArrowCursor: Types.TMouseCursor = (
    screenMask: ($0FFF, $03FF, $00FF, $003F, $000F, $0003, $0000, $0003,
                 $0003, $3F03, $FF00, $FF00, $FFC3, $FFFF, $FFFF, $FFFF);
    cursorMask: ($0000, $3000, $3C00, $3F00, $3FC0, $3FF0, $3FFC, $3FC0,
                 $3CF0, $00F0, $003C, $003C, $0000, $0000, $0000, $0000)
  );
  { The joystick. }
  { [y band, x band] of a stick reading to its direction 0..7 clockwise from north, 8 centered; Joystick's JoyZone }
  joystickZones: array[0..5, 0..5] of Byte = (
    (C_Dir.NORTHWEST, C_Dir.NORTHWEST, C_Dir.NORTH, C_Dir.NORTH, C_Dir.NORTHEAST,
     C_Dir.NORTHEAST),
    (C_Dir.NORTHWEST, C_Dir.CENTER, C_Dir.CENTER, C_Dir.CENTER, C_Dir.CENTER,
     C_Dir.NORTHEAST),
    (C_Dir.WEST, C_Dir.CENTER, C_Dir.CENTER, C_Dir.CENTER, C_Dir.CENTER, C_Dir.EAST),
    (C_Dir.WEST, C_Dir.CENTER, C_Dir.CENTER, C_Dir.CENTER, C_Dir.CENTER, C_Dir.EAST),
    (C_Dir.SOUTHWEST, C_Dir.CENTER, C_Dir.CENTER, C_Dir.CENTER, C_Dir.CENTER,
     C_Dir.SOUTHEAST),
    (C_Dir.SOUTHWEST, C_Dir.SOUTHWEST, C_Dir.SOUTH, C_Dir.SOUTH, C_Dir.SOUTHEAST,
     C_Dir.SOUTHEAST)
  );
  { the keypad digit GameIo's ReadGameKey answers for each stick direction 0..7; [8] and [9] are unused }
  joystickKeys: array[0..9] of Char = (
    '8', '9', '6', '3', '2', '1', '4', '7', ' ', #0
  );
  { Fill colors. }
  { byte that fills four CGA pixels with each CGA color; Blit's FillPicRect }
  cgaColorFill: array[0..3] of Byte = ($00, $55, $AA, $FF);
  { byte that fills two Tandy pixels with each color; Blit's FillPicRect }
  tandyColorFill: array[0..15] of Byte = (
    $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF
  );
  { The music files and AIL drivers. }
  { the XMIDI music file of each sound mode, less '.xmi'; Xmidi's StartSequence }
  musicFileStems: array[1..5] of String[8] = (
    'buckc', 'bucka', 'bucka', 'buckb', 'buckc'
  );
  { the AIL driver file Xmidi's StartSequence loads for each sound mode }
  driverNames: array[1..5] of String = (
    'pcspkr.adv', 'sbfm.adv', 'adlib.adv', 'mt32mpu.adv', 'tandy.adv'
  );

implementation

end.
