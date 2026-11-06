{ Global variables: the data segment's variables, grouped by the subsystem that owns them and kept in address order. A
  new section starts wherever the data needs a word boundary. }
unit GDVars;

interface

uses Types, C_Combat, C_Group, C_Side;

{ Start-up: the title menu's answer and the copy-protection check's loop. }
var
  { the key FixMain's title menu answered, from menuKey; 'D' runs the demo }
  menuResult: Char;
  { unused }
  extendedKey: Byte;
  { FixMain's loop over protectionFlags after CopyProtection, which ends the game at a stage still 0 }
  protectionIndex: Byte;

{ Title sequence and ECL script loading: the data set Intro puts back, and what EclVm has loaded and must redo. }
var
  { unused }
  oldDataSetLead: Byte;
  { the caller's data set, which Intro keeps as the title sequence starts and restores when it ends }
  oldDataSet: Byte;
  { set by a handler that ends the run: CallEclScript loops until it is set }
  isEclStopped: Boolean;
  { EclNewEcl loaded another script: NewEclDone runs its entry points }
  isNewEclLoaded: Boolean;
  { EclLoadCharacter changed the current character; EclExit and EclProgram put it back }
  restoresCharacter: Boolean;
  { a LOAD FILES or LOAD PIECES ran: NewEclDone then redraws the view }
  hasLoadedFiles: Boolean;
  { set by EclLoadFiles when it loads wall sets; with hasLoadedMap it redraws the exploration screen on coming out of
    the wilderness; GameLoop clears it }
  hasLoadedPieces: Boolean;
  { set by EclLoadFiles when it loads a 3-D map; GameLoop clears it }
  hasLoadedMap: Boolean;
  { the creatures EclLoadMonster has added since EclClearMonsters }
  creatureCount: Byte;

{ Post-combat outcome and the combat AI's step history. }
var
  { a hostile fell or a combat creature was removed: PostCombatSummary prints won or fled }
  hasOutcomeToReport: Boolean;
  { the team fled: a member ahead of the first out-of-play creature is fleeing and, outside a solo combat, none of them
    is still okay. A fled team's treasure is discarded }
  hasPartyFled: Boolean;
  { Money's DetermineTreasure answer that the pool holds credits, for PostCbt's summary line and LootTakeMenu }
  treasureHasMoney: Boolean;
  { its answer that the pool holds items; the same readers }
  treasureHasItems: Boolean;
  { the direction AiMoveStep last stepped in, CENTER as AiMoveAttack starts }
  previousDirection: Byte;
  { the times since AiMoveAttack began that AiMoveStep found no step or reversed }
  stuckCount: Byte;
  { unused; AiMoveAttack clears it }
  aiMoveState: Byte;

{ Combat set-up: placing the combatants and laying the arena, and the wilderness scatter's state. }
var
  { 1 for each open placement cell, by team, ring, row, column }
  quadFree: array[0..1, 0..3, 0..5, 0..10] of Byte;
  { the column of each team's placement origin, in map squares from the party }
  placeX: array[0..1] of ShortInt;
  { the row of each team's placement origin }
  placeY: array[0..1] of ShortInt;
  { the tries a first-pass leg of FindPlacement makes, from the team's size }
  teamRows: array[0..1] of ShortInt;
  { each team's facing quarter, 0..3 }
  teamDir: array[0..1] of ShortInt;
  { the map square being laid, -6..6 from the party's column }
  arenaOX: ShortInt;
  { and -2..2 from its row }
  arenaOY: ShortInt;
  { WallBetween's kind on the north side of the square being laid }
  wallNorth: Byte;
  { the kind on its west side }
  wallWest: Byte;
  { the kind on its east side }
  wallEast: Byte;
  { the kind on its south side, set with the others; unused }
  wallSouth: Byte;
  { the team being placed, the creature's side }
  team: ShortInt;
  { unused }
  teamTail: array[0..1] of Byte;
  { the square's map-event bit $40: ScatterWallTiles' richer choices }
  squareVariant: Byte;
  { unused }
  squareVariantTail: array[0..5] of Byte;
  { RandSeed as ReseedRandom found it }
  savedSeed: LongInt;
  { the column of the center BuildWilderness plots a run around, kept for the next run when that has
    PROFILE_KEEP_CENTER }
  randomCenterX: Byte;
  { the row of that center }
  randomCenterY: Byte;
  { above 0, replaces every run's scatter; -1 for none }
  scatterOverride: ShortInt;

{ Game start-up: GameInit's loop counters and its ITEMS open. }
var
  { InitializeGame's and ResetGameState's loop counter }
  index: Byte;
  { the color component defaultPalette's copy steps through }
  component: Byte;
  { unused }
  maskIndex: Word;
  { DaxIo.OpenWithRetry's answer for ITEMS; unused }
  hasOpenedItems: Boolean;

{ Game start-up: the mouse probe and the ITEMS file. }
var
  { unused }
  hasOpenedItemsTail: array[0..41] of Byte;
  { the buttons GameInit's mouse probe reads back; unused }
  mBtn: Integer;
  { the x the probe reads back after moving the mouse to 639: below 321 the driver gives x in screen pixels }
  mX: Integer;
  { the y the probe reads back; unused }
  mY: Integer;
  { ITEMS, which InitializeGame reads into itemTypes }
  itemsFile: file;
  { unused }
  itemsFileTail: Byte;

{ The shop's menus. }
var
  { the redraw flag Shop hands MenuCore's MenuVertical for its item and clip menus; Shop sets it before each menu }
  menuNeedsRedraw: Boolean;

{ The character sheet, trading and treatment. }
var
  { the character ViewChar's sheet shows, the current character as the sheet is drawn }
  sheetCharacter: Types.PCharRecord;
  { the trade selectors' start: the menu's character, then the last one traded with }
  tradePartner: Types.PCharRecord;
  { combat slots of the characters TreatPatients can treat }
  patientSlots: array[1..8] of Byte;
  { patients FindPatients listed; TreatPatients counts it down per treatment }
  patientCount: Byte;

{ The skills editor. }
var
  { the TSkill.group shown }
  currentGroup: ShortInt;
  { the general skills the current character has }
  knownGeneralCount: ShortInt;
  { set while EditSkills only lists the general skills the character has }
  isViewOnly: Boolean;

{ Effects running down, the line-of-fire walk, and the boot's configuration dialog. }
var
  { by position in the party list: 1 while that member may have an effect running down }
  effectFlags: array[1..C_Combat.MAX_COMBATANTS] of Byte;
  { WalkLine sets the three saw flags. Its first GRACE_CELLS cells that are neither chaff nor aerosol mist are grace
    cells: lineClass 2 terrain there does not set sawBlockedTerrain. CbtActs' CalcWeaponDamage also sets sawChaff or
    sawAerosolMist when the cell its WalkLine ends on holds that cloud. }
  { WalkLine crossed a C_Terr.CHAFF_TERRAIN cell }
  sawChaff: Boolean;
  { WalkLine crossed a C_Terr.AEROSOL_MIST_TERRAIN cell }
  sawAerosolMist: Boolean;
  { WalkLine crossed lineClass 2 terrain past its grace cells }
  sawBlockedTerrain: Boolean;
  { WalkLine stops at the first chaff cell; the caller sets it, WalkLine clears it }
  stopsAtChaff: Boolean;
  { HeapEnd lowered for Tandy video memory }
  newHeapEnd: Pointer;
  { a matrix.cfg line's letter, or a digit key the dialog takes }
  cfgChar: Char;
  { the number GameBoot's first-run dialog read for its display, sound and input questions }
  menuChoice: Byte;
  { matrix.cfg, which GameBoot writes on the first run and reads at each start }
  cfgText: Text;
  { unused }
  cfgFile: file;
  { IOResult of creating a missing matrix.cfg; non-zero has GameBoot report a write-protected disk }
  cfgErr: Byte;
  { GameBoot's loop counter over the save path's letters and the joystick calibration }
  ix: Byte;
  { a save path the first-run dialog reads, upper-cased and ending in a backslash, for matrix.cfg }
  pathBuf: String[80];
  { the name part FSplit gives for the program's path; unused }
  fsName: String[8];
  { the extension part FSplit gives; unused }
  fsExt: String[4];
  { the save path the first-run dialog offers, from altPath }
  defaultSavePath: String[79];

{ Disk paths: where the data files are, and the drive the floppy prompt names. }
var
  { the directory the program runs from, FSplit's for the program's path; DaxIo looks for data files there first }
  dataPath: String[79];
  { swapped with dataPath when a file is not found }
  altPath: String[79];
  { the drive letter the floppy prompt names }
  promptDrive: Char;

{ The sound driver's countdown, and the session: start-up flags, the GBVM zones, the ECL entry points and the screen the
  game is in. }
var
  { sounddrv.asm's countdown word, ExitCount }
  timeoutPtr: ^Word;
  { True when matrix.cfg's sixth line is F; set by GameBoot, otherwise unused }
  isFullIntro: Boolean;
  { while it is set HeapErr saves the game before it quits for lack of memory; GameInit's InitializeGame clears it,
    Intro and GameInit's ResetGameState set it }
  isGameUp: Boolean;
  { GBVM zone 0, saved with the game }
  zone0: Types.PZone0;
  { GBVM zone 1, saved with the game: most units index it by GBVM address with C_Gbvm's cell constants or their own;
    CombatSt and PostCbt view it through records of their own }
  zone1: Types.PZone1;
  { GBVM zone 2, saved with the game }
  zone2: Types.PZone2;
  { GBVM zone 3, the ECL script EclMenu's LoadEclScript loads }
  zone3: Types.PZone3;
  { the five entry addresses at the head of the loaded ECL script, which EclMenu's EclInit copies here: EclVm runs [5]
    after a script loads, then [1] and [2], and Explore's Look points eclIp at [2] }
  eclEntryPoints: array[1..5] of Word;
  { the ECL instruction pointer, a GBVM address in zone 3: EclMenu's EclInit and GameInit set it to $8000, EclMenu and
    EclVm advance it and jump it, and Explore's Look sets it to entry point [2] }
  eclIp: Word;
  { unused }
  eclIpTail: array[0..3] of Byte;
  { the screen the game is in: the units that open a screen set it, and the menus, input and drawing branch on it;
    SaveLoad saves it with the game }
  interfaceState: Byte;
  { interfaceState before the current screen; saved with the game, GameInit clears it }
  previousInterfaceState: Byte;
  { True while FixMain runs the demo: GameIo's ReadGameKey then answers #0 when no device is in use, TextRend's
    ReadString takes one key, and CombatSt, CharGen, PostCbt, EclVm and SaveLoad take their demo paths }
  demoMode: Boolean;

{ Display options and run flags: pictures, animations, debug mode, rest, defeat and the message speed. }
var
  { saved with the game in zone 0's displayOptions as twice its value plus animationsEnabled; GameInit sets it to 1 }
  picturesEnabled: Byte;
  { non-zero while EclVm's big picture covers the party list: CharHlp's DisplayRoster and MenuCore's DisplayParty then
    draw no list; EclVm and GameInit clear it }
  bigPictureShown: Byte;
  { Explore's Anim toggle, saved with the game as bit 0 of zone 0's displayOptions; GameInit sets it to 1 }
  animationsEnabled: Byte;
  { non-zero lets EclMenu show a monster's close-up during an encounter menu }
  monsterPictures: Byte;
  { GameIo's ^D toggle, which opens debug.txt as it sets it; while it is set Sym8x8 logs to the file, Debug shows its
    values and CharHlp's PrintMiscInfo adds a *; GameInit clears it }
  isDebugMode: Boolean;
  { SaveLoad sets it when a saved game loads; while it is set EclMenu's EclInit keeps the zone cells it would clear, and
    EclVm's GameLoop redraws the view and clears it; GameInit clears it }
  hasLoadedSave: Byte;
  { ticks toward the next rest interruption roll; GameInit clears it, otherwise unused }
  restTicks: Word;
  { the current portrait's head; unused }
  portHeadId: Byte;
  { the current portrait's body; unused }
  portBodyId: Byte;
  { non-zero ends EclVm's GameLoop and Explore's 3-D menu, and MapView draws nothing: PostCbt sets it when no party
    member is left standing, EclVm when an ECL attack leaves none enabled, CharGen's drop menu when none is; GameInit
    clears it }
  partyDefeated: Byte;
  { non-zero while CharGen trains a new character level after level for free; GameInit clears it }
  freeTraining: Byte;
  { non-zero: TextRend's DisplayMessageWindow waits after each character for the message speed; GameInit, Combat,
    PostCbt and EclVm set it, CombatSt and EclVm clear it }
  messageDelay: Byte;

{ The skills editor's list and group bounds, and the video state: registers, EGA pages and video modes. }
var
  { the skills Skills' editor lists, the career's eight and then the rest by group. Note: a group with no entries reads
    skillList[0], outside the array }
  skillList: array[1..84] of Byte;
  { first skillList position of each skill group; Skills }
  groupStart: array[C_Group.CAREER..C_Group.TECHNICAL] of Byte;
  { last skillList position of each skill group; Skills }
  groupEnd: array[C_Group.CAREER..C_Group.TECHNICAL] of Byte;
  { The video BIOS registers, the EGA pages and the video modes. }
  { the registers of the video BIOS calls (Blit, DaxIo, GameBoot, GameIo, TextRend) and of Mouse's INT 33h calls }
  regs: Types.TRegisters;
  { segment of the EGA page shown, set with it by TextRend's SetupEgaCurrentPage }
  egaShownSegment: Word;
  { segment of the EGA page TextRend's FillRectEga fills, set by SetupEgaOtherPage }
  egaDrawSegment: Word;
  { the EGA page drawn on, which FillRectEga points egaDrawSegment back at; GameBoot sets it to 0 }
  egaDrawPage: Byte;
  { the EGA page shown; GameBoot sets it to 0 }
  egaShownPage: Byte;
  { the BIOS video mode Blit's SetVideoMode replaced, which RestoreVideoMode and GameIo's ExitGame go back to; GameBoot
    starts it at the mode it finds }
  savedVideoMode: Byte;
  { the BIOS video mode SetVideoMode last set; GameBoot starts it at the mode it finds }
  curVideoMode: Byte;
  { the adapter, C_Vm.CGA..VGA: GameBoot sets it from matrix.cfg's E, T or V, and leaves it unset on any other line; the
    drawing units branch on it }
  displayMode: Byte;

{ The view picture, the save-under, the dirty-row tables and the scanline tables. }
var
  { the picture the game draws into, which Blit's FlushView copies to the screen by the dirty rows: GameInit allocates
    it 200 lines by 40 columns, CombatSt sizes it to the combat view's 168 by 21 and Combat back }
  viewPicture: Types.PImgBuf;
  { where Blit's BlitTileClipped saves the pixels a masked tile covers; GameInit allocates it, CharHlp hands it to
    BlitTileClipped, and ShipCbt swaps in a picture of its own for each weapon effect }
  saveUnder: Types.PImgBuf;
  { unused }
  saveUnderTail: array[0..15] of Byte;
  { The four dirty-row tables, one entry per picture row: 168 rows, the combat view's height. blit.asm reads and writes
    them as externals. }
  { non-zero once the row is drawn: blit.asm's tile blits and Blit's FillPicRect set it; FlushView copies the marked
    rows and clears it, GameInit and MapCurs clear it too }
  dirtyRows: array[0..167] of Byte;
  { the row's dirty span's left end on screen, in bytes (in cells for EGA), stored with dirtyRowFirst }
  dirtyRowLeft: array[0..167] of Word;
  { picture offset of the row's first dirty byte, $FFFF when none: blit.asm and FillPicRect lower it, FlushView resets
    it }
  dirtyRowFirst: array[0..167] of Word;
  { picture offset of the row's last dirty byte: blit.asm and FillPicRect raise it, FlushView clears it }
  dirtyRowLast: array[0..167] of Word;
  { spare. Note: blit.asm's row loops and Blit's FillPicRect write its first 64 bytes as dirtyRowLast[168..199] for a
    tile on rows 168..199 of the 200-line viewPicture }
  dirtyRowLastTail: array[0..671] of Byte;
  { screen segment of each CGA scanline; GameInit fills it, Blit reads it }
  cgaRowSegments: array[0..199] of Word;
  { offset of each EGA scanline in display memory; GameInit fills it, Blit reads it }
  egaRowOffsets: array[0..199] of Word;
  { screen segment of each Tandy scanline; GameInit fills it, Blit reads it }
  tandyRowSegments: array[0..199] of Word;
  { GameInit's InitializeGame and ResetGameState set it to 1; otherwise unused }
  clipFlag: Byte;

{ Sound, the data set and save paths, the ships and the orbit map, the party, the text window, the tile sets, and the
  ground combat's arena and combatants. }
var
  { the config file's sound device: 0 none, 1 PC speaker, 2 Sound Blaster, 3 Adlib, 4 Roland, 5 Tandy. GameBoot sets it
    and GameIo's Ctrl-S zeroes and restores it }
  soundMode: ShortInt;
  { soundMode as SoundDrv's StartSound and GameIo's Ctrl-S save it; Ctrl-S restores it only when it is 1 or 5, the
    devices SoundDrv drives itself }
  savedSoundMode: Byte;
  { GameIo's Ctrl-U toggle, which shuts the music driver down when it turns it off; GameInit sets it on, and nothing
    else reads it }
  musicEnabled: Boolean;
  { soundState as DaxIo's PushSoundState and Xmidi save it; DaxIo's PopSoundState restores it }
  savedSoundState: Byte;
  { the driver sound commands go to: 0 none, 1 SoundDrv's own speaker and Tandy driver, 2 Xmidi's AIL driver. SoundDrv,
    Xmidi and DaxIo set it and test it, as Music and GameIo do; GameInit clears it }
  soundState: Byte;
  { GameInit clears it; otherwise unused }
  driverReady: Byte;
  { The data set, the save paths and the disk flags. }
  { the data files' set number, the digit in ECL<n>, GEO<n> and the rest; indexes the insert-disk prompts and is saved
    with the game. FixMain, GameInit and SaveLoad set it, Intro and OrbitMap switch it for a while, DaxIo's PushState
    and PopState save and restore it }
  dataSet: Byte;
  { dataSet as DaxIo's PushState saved it, which PopState puts back; GameInit starts it at 1 }
  savedDataSet: Byte;
  { where saved games and characters go, the config file's fourth line; GameBoot reads it and SaveLoad saves, loads and
    deletes there }
  savePath: String;
  { the config file's fifth line, GameBoot's PATH TO SAVE DATA FOR COUNTDOWN TO DOOMSDAY; SaveLoad loads characters and
    saved games from it when the player picks Countdown }
  doomsdaySavePath: String;
  { non-zero: DaxIo's OpenDax gives up on a missing file instead of asking for the disk; SaveLoad sets it while it loads
    a creature's optional SPC and ITM records, and GameInit clears it }
  suppressDiskPrompt: Byte;
  { SaveLoad's SaveGame sets it, CharGen and GameInit clear it; CharGen and HeapErr test it before quitting }
  gameSaved: Byte;
  { Ships and ship combat, and the text window's line state. }
  { the 'ships' pictures, one per shipPictures entry: OrbitMap loads and frees them, ShipCbt and CharHlp draw them,
    GameInit clears them }
  shipPictureBuffers: array[0..28] of Types.PImgBuf;
  { the party's ship, zone 0's ship: GameInit points it there and loads the ship through it }
  partyShip: Types.PShipRec;
  { the enemy ship in ship combat, nil outside it; ShipCbt allocates, loads and frees it }
  enemyShip: Types.PShipRec;
  { the character flying the party's ship in ship combat; ShipCbt }
  activePilot: Types.PCharRecord;
  { column TextRend's DisplayWindowText starts each line at; ClearTextWindow and Explore's CampSpeedMenu reset it to the
    saved rectangle's left edge }
  textLeft: Byte;
  { row of DisplayWindowText's next line, which it counts up; ClearTextWindow resets it. PostCbt prints its columns on
    it, and ShipCbt pads its menu out to row 21 }
  windowTextRow: Byte;
  { non-zero once DisplayWindowText has printed a line: while it is 0, a line below the top clears the rectangle first,
    and while it is set a full rectangle pauses before it clears. ClearTextWindow clears it; ShipCbt pauses on it and
    clears it, and CharHlp clears it }
  windowTextPending: Byte;
  { distance between the two ships in ship combat, 8 at the start; ShipCbt sets it, CharHlp shows it }
  shipCombatRange: ShortInt;
  { True while the enemy ship retreats; ShipCbt sets it, CharHlp shows it by its maneuver name table }
  enemyRetreating: Boolean;
  { CharHlp's DrawShipDetails sets it from isEnemyShown and the party ship's sensors; while it is 0 the enemy ship's
    values show as ? }
  enemyDetailsShown: Byte;
  { speed boosts the party's ship has taken this ship combat, offered while below 2; ShipCbt counts them, CharHlp adds
    them to its speed }
  playerBoosts: ShortInt;
  { speed boosts the enemy ship has taken; ShipCbt counts them, CharHlp adds them to its speed }
  enemyBoosts: Byte;
  { The orbit map. }
  { non-zero once OrbitMap's LoadOrbitPictures has loaded the orbit-map tiles and the rocket's cell, until
    FreeOrbitPictures frees them with the backdrop; GameInit clears it }
  orbitPicturesLoaded: Byte;
  { non-zero while OrbitMap has shipPictureBuffers loaded; GameInit clears it }
  shipPictureBuffersLoaded: Byte;
  { zone 0's orbit window: GameInit points it at orbitBodies, OrbitMap draws from it and Explore moves the rocket
    through it }
  orbitView: Types.POrbitView;
  { the orbit-map cell under the rocket, which OrbitMap grabs so it can put it back }
  savedOrbitCell: Types.PImgBuf;
  { orbit-map column of savedOrbitCell, -1 when none is saved; Explore sets it too }
  savedCursorX: ShortInt;
  { orbit-map row of savedOrbitCell }
  savedCursorY: ShortInt;
  { The party and the items. }
  { the current character EclVm's ECL interpreter keeps and puts back }
  eclSavedCharacter: Types.PCharRecord;
  { the ITEMS rows, by an item's itemType: GameInit reads the ITEMS file into it, asking for all 129 rows; the file
    holds 39 }
  itemTypes: array[0..128] of Types.TItemType;
  { the character whose party-list row CharHlp's DisplayRoster redraws: it takes the highlight argument while this is
    nil, and clears it after. MenuCore's party click stores the current character here before it moves on, and GameInit
    clears it }
  partyRowCharacter: Types.PCharRecord;
  { the character the menus, ECL commands and combat act on; read by most units }
  currentCharacter: Types.PCharRecord;
  { the first of the party list, the team and the creatures that join it }
  partyHead: Types.PCharRecord;
  { the templates a new item copies: EclMenu's LoadItemTemplates fills all 254 rows with $FF and loads ITEM0.DAX's
    16-byte records from row 1, at most 127. EclVm's item lists, Shop's free ammunition and ViewChar's weapon
    specialization menu read it }
  itemTemplates: array[1..254] of Types.TItemTemplate;
  { experience for a ship combat, by the enemy ship's type: ShipCbt sets it as the combat starts, clears it when the
    enemy recedes off the scanners and saves the enemy ship in zone 0 only while it is non-zero; PostCbt's RepairShip
    shares it out among the enabled members and clears it }
  shipCombatExperience: Word;
  { CombatSt's CombatStart sets it to nil; otherwise unused }
  lastMissileItem: Types.PItemRec;
  { GameTime's ValidateClock sets it when the clock's year count reaches 100 and carries; GameInit clears it; otherwise
    unused }
  hasCenturyPassed: Boolean;
  { File scratch. }
  { the file variable DaxIo's DeleteIfPresent erases a file through }
  deletionFile: file;
  { the bytes of ITEMS GameInit's BlockRead read into itemTypes; unused. ITEMS holds 351 bytes, and the four-argument
    BlockRead stops short there without an I/O error }
  itemsRead: Word;
  { The font, the text cursor and the text window. }
  { the 8x8 font: GameInit allocates it, TextRend loads and draws it, and textrend.asm reads it through EXTRN }
  gameFont: Types.PFont;
  { the pixel rows of the character TextRend's RenderChar draws; textrend.asm reads them through EXTRN }
  glyphBits: Types.TGlyph;
  { column of the next character TextRend's DisplayMessageWindow prints; EclMenu, PostCbt and EclVm also set it }
  cursorColumn: Byte;
  { row of that character. CharHlp's CombatPrintCreatureInfo also sets it, and CbtActs and FxEngine print combat lines
    from the row below it }
  cursorRow: Byte;
  { the text window's left column. TextRend's SetTextWindow sets the window and its color, and Border's ScreenText and
    DrawCombatFrame and OrbitMap's EnterOrbitMap set its four edges themselves }
  windowLeft: Byte;
  { the text window's top row }
  windowTop: Byte;
  { the text window's right column }
  windowRight: Byte;
  { the text window's bottom row }
  windowBottom: Byte;
  { the color the text window is cleared to }
  windowColor: Byte;
  { unused }
  windowColorTail: array[0..20] of Byte;
  { The tile sets and the wilderness cursor's cells. }
  { the 8x8 tile sets Sym8x8's Load8x8Set loads, slot 6 the borders; symSetFirst and symSetLast give each slot's tiles.
    GameInit clears them, OrbitMap frees slot 5 }
  tileSets: array[0..6] of Types.PImgBuf;
  { a one-tile 8x8 picture GameInit allocates; Sym8x8's Put8x8Sym copies a tile into it to show it }
  tileScratch: Types.PImgBuf;
  { the 8x8 cell at the party's square MapCurs's DrawCursor grabs, and RestoreCursorBackground puts back; GameInit
    allocates it }
  savedWildernessCell: Types.PImgBuf;
  { a copy of that cell with cursorPicture drawn over it through its mask, which DrawCursor shows; GameInit allocates
    it }
  wildernessCursorCell: Types.PImgBuf;
  { Ground combat: the arena, the icons, the combatants and their targets. }
  { the combat arena's 59 terrain tiles, 24 by 24: CombatSt allocates it, MapTiles' Load24x24Set fills it, CbtMap draws
    the arena from it, Combat frees it; GameInit sets it to nil }
  arenaTiles: Types.PImgBuf;
  { icon and effect pictures, two frames a row: GameInit clears the table and loads the COMSPR icons into rows 13..37,
    MapTiles loads and draws a row, CharGen's icon editor allocates and fills one, Blit's CopyIconTile copies a frame;
    CbtMap draws row 31, the skull, over a downed creature and rows 33..35 over marked arena cells }
  iconFrames: array[0..37, 0..1] of Types.PImgBuf;
  { combatant slots in use in ground combat; CombatSt counts them as it places the combatants }
  combatantCount: Byte;
  { where each combatant stands, by slot: CombatSt places them, CbtMap and CbtActs move them (CbtActs lifts one off the
    arena while it animates a move); CbtMap and FxEngine take one out of play, and CombatSt zeroes the size of any it
    leaves unplaced }
  combatantCells: array[1..C_Combat.MAX_COMBATANTS] of Types.TCombatantCell;
  { each combatant's column on the combat map view, its arena column less the view's origin: CbtMap works it out and
    draws by it, CharHlp reads it }
  gridX: array[1..C_Combat.MAX_COMBATANTS] of ShortInt;
  { each combatant's row on the combat map view; the same writer and readers }
  gridY: array[1..C_Combat.MAX_COMBATANTS] of ShortInt;
  { the combatant slot on each arena cell, [row, column], 0 for none; CombatSt and CbtMap clear it and CbtMap rebuilds
    it from combatantCells }
  cellCombatant: array[0..24, 0..49] of Byte;
  { each combatant's character record, by slot; CombatSt fills it }
  creatures: array[1..C_Combat.MAX_COMBATANTS] of Types.PCharRecord;
  { corpse records, downedCount of them: CombatSt's PlaceAllCreatures appends one for each combatant already down and
    CbtMap's CreatureDowned one for each that falls; CombatSt's CombatStart clears them. CbtMap, CbtActs and FxEngine
    scan 1..downedCount with no bound at 8 }
  downedCreatures: array[1..8] of Types.TDownedCreature;
  { the records appended to downedCreatures; neither appender tests it against 8 }
  downedCount: Byte;
  { the ground combat arena }
  combatArena: Types.PArena;
  { entries in pathTargets: Pathing's BuildTargetList sets it, CharHlp cuts it }
  pathTargetCount: Byte;
  { the combatants Pathing's BuildTargetList finds, nearest first; CharHlp keeps one side's }
  pathTargets: array[1..C_Combat.MAX_COMBATANTS] of Types.TTarget;

{ Treasure, the team counts, and the combat and effect state the effect handlers share. }
var
  { the credits in the party's pool: Money pools and shares them, PostCbt adds the fallen hostiles' credits, EclVm's ECL
    adds to it and clears it, Shop spends it when a character's credits fall short }
  poolCredits: LongInt;
  { the item list the current event offers, treasure or shop stock: EclVm's ECL builds it, PostCbt adds the treasure and
    its loot menus take items off it, Shop sells copies; GameInit sets it to nil }
  availableItems: Types.PItemRec;
  { The ground combat's sides. }
  { combatants in play on each side, [0] the party's; CharHlp counts them, and takes one off a side as a combatant
    falls; Combat and CombatSt read them }
  teamCounts: array[C_Side.TEAM..C_Side.HOSTILE] of Byte;
  { The attack, save and effect being resolved. }
  { the saving throw FxEngine's RollSavingThrow is making: it rolls it and adds the modifier, runs the effects that may
    change it (EffHndlr's effect-13 handler takes 4 off it), then tests it against the save }
  saveRoll: Byte;
  { The combat and effect scratch the effect handlers share. }
  { the effect FxEngine's AddEffectWithMessage is about to add: it stores the number, runs trigger condition 9, and adds
    nothing when a handler has cleared it; EffHndlr's handlers test it and clear it }
  pendingEffectId: Byte;
  { damage of the hit being resolved: CbtActs' CalcWeaponDamage rolls it, FxEngine's InflictNonWeaponDamage and
    ShipCbt's FireWeapon set it, EffHndlr's handlers set, cap and clear it }
  effectDamage: Byte;
  { the animation FxEngine's InflictNonWeaponDamage hands CharHlp's PrintNameStringAnim: CbtActs sets it by projectile
    kind as it launches one, and CalcWeaponDamage clears it }
  projectileEffect: Byte;
  { attacks per round, doubled, as CbtActs sets up an attack slot; trigger condition 18's handler, effect 29's, halves
    it before CbtActs halves it into the slot }
  attackRate: Byte;
  { moves per turn, doubled: CharHlp's RecalcMovement works it out and returns it; effect 29's handler halves it with
    attackRate, but RecalcMovement sets it before it reads it, so the halving never reaches the rate it returns }
  movementRate: Byte;
  { the dice count FxEngine's RollDamageDice was last called with; unused }
  currentDiceCount: Byte;
  { unused }
  currentDiceCountTail: array[0..1] of Byte;
  { CbtActs' MakeAttack clears it and tests it once CombatLaunchProjectile, which sets it to 1, may have fired }
  projectileActive: Byte;
  { non-zero makes ViewChar's gear screen redraw its heading, which then clears it. Note: nothing sets it }
  gearRefresh: Byte;
  { the d20 roll of the attack being made, 100 for a natural 20, which FxEngine's attack rolls test for at least 0; in
    AttackRoll, trigger condition 10's effect 13 handler takes 4 off it first. EffHndlr's ClearEffectMode and CombatSt's
    CombatStart clear it }
  currentAttackRoll: ShortInt;
  { arena column a shot or thrown weapon is aimed at: CbtActs' AttackGroundTarget sets it and CombatLaunchProjectile
    moves it where the shot strays or hits chaff }
  projectileTargetX: ShortInt;
  { arena row of the same aim }
  projectileTargetY: ShortInt;
  { hits for damage per attack slot: CbtActs' RollAttacks clears and counts them, and effect 25's handler takes one off
    slot 1 when the defender dodges }
  hitCounts: array[1..2] of Byte;
  { a monster's morale as CombatAi's CheckMorale works it out and tests it }
  morale: Byte;
  { the creature an effect acts on: EffHndlr's handlers set it to the combat target of the character the effect is on,
    and CbtActs' IntimidateTarget passes each target through it }
  activeTarget: Types.PCharRecord;
  { the saving throw FxEngine's RollSavingThrow is making, set before its effects run }
  currentSaveType: Byte;
  { the result of FxEngine's RollSavingThrow, which it also returns }
  currentSaveResult: Boolean;
  { each effect number's handler: EffHndlr's InitEffectHandlers fills it and FxEngine's CallEffectHandler calls through
    it; nothing bounds the effect number at 32 }
  effectHandlers: array[1..32] of Types.TEffectHandler;

{ The 3-D view and its map, the portrait animation and the pictures, and the menus and the party list. }
var
  { the WALLDEF banks: GameInit allocates three banks, and View3D's LoadWallSet copies a set loaded into slot n into
    banks n + 1 onward. Note: its guard lets a set reach bank 4, past the allocation }
  wallDefs: Types.PWallDefs;
  { the 3-D map: GameInit allocates it, View3D's Load3DMap fills it and its lookups read it }
  geoMap: Types.PGeoMap;
  { The 3-D view's colors, the automap, the party's position and the wall sets. }
  { color of the 3-D view's sky band: MapView picks it by the square's mapEvent, and View3D's SetView3DColors stores
    it }
  skyColor: Byte;
  { the first horizon color: MapView works it out in CGA mode, SetView3DColors stores it; only MapView and FixMain read
    it, to pass it back to SetView3DColors }
  horizonColor1: Byte;
  { color of the band View3D's DrawBackdrop fills below the sky; the same writers }
  horizonColor2: Byte;
  { color of the 3-D view's floor band; the same writers, and MapView sets 8 in CGA mode while viewColorsChanged is 0 }
  floorColor: Byte;
  { non-zero: View3D draws the automap in place of the 3-D view; Explore's Area command toggles it, EclMenu, MapView and
    GameInit clear it }
  automapOn: Byte;
  { where the party stands and faces on the 3-D map, with the wall ahead and the square's event; saved as one block }
  partyPosition: Types.TPartyPosition;
  { the WALLDEF set in each wall-set cache slot: View3D's LoadWallSet stamps it, GameInit clears all four and on a soft
    restart gives slot 1 set 0 and empties 2 and 3, EclVm empties slots whose set its ECL command leaves out, SaveLoad
    saves and loads slot 0 with the game, FixMain sets slot 0's set to 0 as the demo returns to the title menu }
  wallSets: array[0..3] of Types.TWallSet;
  { The portrait animation and the big picture. }
  { True while the loaded animation comes from a sprite archive, one whose name starts with S: Portrait's LoadAnimation
    sets it, and then decodes every frame into imageFrames, even in VGA mode; MenuCore's MenuHorizontal does not animate
    it }
  spriteArchive: Boolean;
  { the loaded animation's frame table: Portrait's LoadAnimation clears it and reads it from the resource, MenuCore's
    MenuHorizontal and EclVm step through the frames, VgaFrame decodes by it; GameInit clears it }
  portraitAnimation: Types.TPortraitAnimation;
  { GameInit clears it; Portrait's FreeAnimation frees it and clears 66 bytes from here, all of it and 26 bytes into
    imageFrames }
  vgaAnimation: Types.TVgaAnimation;
  { the animation's frames as pictures outside VGA mode, or from a sprite archive: Portrait's LoadAnimation builds them,
    DisplayImageBuf and Show3DSprite draw them, FreeAnimation frees them; GameInit clears them }
  imageFrames: array[0..8] of Types.PImgBuf;
  { The animation counter, the picture caches and the picture state. }
  { EclCall's frame counter, which GameInit clears whole }
  displayCounter: Types.TDisplayCounter;
  { two picture slots GameInit empties, and CombatSt's combat set-up and Explore's 3-D step free and reset }
  portraitSlots: array[1..2] of Types.TPortraitCacheSlot;
  { the archive of the animation Portrait has loaded, which its loader compares with the next one asked for; Portrait's
    FreeAnimation and GameInit clear it }
  picArcName: String[8];
  { EclVm and GameInit clear its length byte; otherwise unused }
  savedPicArcName: String[8];
  { the record of the animation Portrait has loaded, 255 for none: its loader sets it, Explore's orbit-map Rocket
    command loads it again, Portrait's FreeAnimation and GameInit set 255 }
  picArcId: Byte;
  { EclVm and GameInit set it to 255; otherwise unused }
  savedPicArcId: Byte;
  { the big picture: Portrait loads 'bigpic' into it, OrbitMap the orbit map's backdrop and SaveLoad the enemy ship's
    picture; CharHlp draws it behind the ship scene, and Portrait, OrbitMap, CombatSt and ShipCbt free it; GameInit sets
    it to nil }
  bigPicture: Types.PImgBuf;
  { the BIGPIC record in bigPicture, 255 for none: Portrait's LoadBigPic sets it and skips a load that matches while
    bigPicture is loaded. OrbitMap, SaveLoad and GameInit set 255, and so does EclVm's combat command, after keeping it
    to load that picture again }
  bigPictureId: Byte;
  { EclVm's extended picture command sets it to 1 in its mode 4 and to 0 otherwise; MapCurs draws and erases the
    wilderness cursor only while it is non-zero }
  viewActive: Byte;
  { The menus, the party list's edges, the menu colors and the editors' click modes. }
  { True while ViewChar's character picker picks for someone other than the current character: a party click in
    MenuCore's MenuHorizontal then moves selectorAnchor, not the current character; GameInit clears it }
  selectorMode: Boolean;
  { the character that party click picks; ViewChar starts it at the current character }
  selectorAnchor: Types.PCharRecord;
  { the first list line on the page of MenuCore's MenuVertical, which pages and scrolls it; GameInit sets it to 1 }
  vertTop: Integer;
  { the option MenuCore's MenuHorizontal highlights, from 1: it moves it with keys and clicks, and sets it back to 1
    when it is 0, past the last option, or the menu's text sums differently from menuChecksum; the menus' callers set
    the option their next menu starts on, and YesNoMenu the default answer }
  horizChoice: Byte;
  { True when the key MenuHorizontal leaves in menuKey is an extended scan code, for a key or for a click it turns into
    one; the menus' callers test it. CharGen's modify menu sets it for its own key reads, Skills clears it for a clicked
    line, and Shop and PostCbt hand it to ViewChar as a done flag }
  extFlag: Boolean;
  { ticks after which MenuHorizontal answers menuTimeoutKey by itself, 0 for never: FixMain's title menu sets it and
    clears it after }
  menuTimeout: LongInt;
  { the key MenuHorizontal answers when menuTimeout runs out: FixMain sets 'D', for the demo }
  menuTimeoutKey: Char;
  { the screen row of each selectable line on MenuVertical's page, 255 for none: its page drawing fills them, and a
    click on the list reads them }
  menuHotRows: array[1..25] of Byte;
  { the first column a click on MenuVertical's list selects in, 127 with no list }
  menuClickLeft: ShortInt;
  { the last such column, -128 with no list }
  menuClickRight: ShortInt;
  { The party list's edges, which MenuCore's DisplayParty and CharHlp's DisplayRoster set and a party click in
    MenuHorizontal tests. }
  { its first column }
  panelLeft: Byte;
  { its last column, 38 }
  panelRight: Byte;
  { its first row, 4 }
  panelTop: Byte;
  { its last row, counted up from 3 as the writers list each character }
  panelBottom: Byte;
  { the field a click picks on CharGen's modify screen: MenuHorizontal sets it while modifyActive is set, and the modify
    menu sets 255 before each menu }
  modifyFieldSelection: Byte;
  { the line a click picks on Skills' screen: MenuHorizontal sets it from the click's row, or NO_SKILL_LINE for a click
    elsewhere, and Skills selects that skill and sets it back to NO_SKILL_LINE }
  clickedSkillLine: ShortInt;
  { the color of a menu's query: MenuCore's menus draw with it and set it back to 13 after, and YesNoMenu keeps it
    across its loop; CharGen, CbtActs and Explore set 14 before a menu, GameInit sets 13 }
  promptColor: Byte;
  { the color of a menu's options, set back to 10 after each menu; GameInit sets 10 }
  menuColor: Byte;
  { the color of a menu's current option, set back to 15 after each menu; GameInit sets 15 }
  highlightColor: Byte;
  { the byte sum of the menu text MenuHorizontal last showed, which it stores on every call; C_Menu.KEEP_MENU_CHOICE
    keeps horizChoice across a changed menu, as YesNoMenu and the callers that preset horizChoice set it }
  menuChecksum: Byte;
  { the key MenuCore's menus answer, which their callers read after the call; some set it first }
  menuKey: Char;
  { 1 while Explore's party order menu runs, which then clears it; otherwise unused }
  inPartyOrderMenu: Byte;
  { True while MenuVertical runs MenuHorizontal for its list, which then tries a click against the list; GameInit clears
    it }
  verticalMenuActive: Boolean;
  { 1 once a click picks the current character from the party list at CharGen's main menu: MenuHorizontal sets it and
    answers with the highlighted option. The main menu clears it before its menu, and while it is set its commands act
    on the current character without asking which }
  partyClicked: Byte;
  { unused }
  gTargetX: ShortInt;
  { unused }
  gTargetY: ShortInt;
  { the first of the lingering clouds on the arena: CbtActs puts each new cloud first, FxEngine counts them down and
    unlinks them, CbtMap sees through them to the terrain; Combat frees the rest, and GameInit sets it to nil }
  areaEffects: Types.PAreaEffect;
  { unused }
  usingItem: Boolean;
  { True while credits sit in the team's pool; Money sets and clears it, Shop clears it }
  poolActive: Boolean;
  { unused }
  poolActiveTail: array[0..24] of Byte;
  { non-zero moves CharHlp's PrintCreatureMessage message one row down outside ground and ship combat. Note: only
    GameInit writes it, clearing it }
  combatLineLowered: Byte;

{ The big picture's return to the 3-D view. }
var
  { non-zero asks MapView's DisplayMapView to show the big picture again in the $A2 and $A8 areas, and DisplayMapView
    clears it: Explore's 3-D step, EclMenu, CharHlp and EclVm set it, and EclVm also clears it }
  portraitPending: Byte;

{ A start-up flag. }
var
  { GameInit's InitializeGame and ResetGameState clear it; otherwise unused }
  overrideFlag: Byte;

{ Saved games: which game's saves the loader reads. }
var
  { which saves SaveLoad reads: 1 Matrix Cubed's own, in savePath; 0 Doomsday's, in doomsdaySavePath. CharGen's add menu
    and SaveLoad's LoadGame set it from a Matrix/Countdown menu, and saving sets 1 }
  importFormat: ShortInt;

{ Character editing and the ground combat's round. }
var
  { 1 while CharGen's icon editor runs, which sets it and clears it as it ends: MenuHorizontal then takes a click above
    the menu lines as a pick on the icon grid; GameInit clears it }
  iconEditorActive: Byte;
  { non-zero ends CharGen's free-training loop, once the next level needs more experience }
  trainingComplete: Byte;
  { CharGen's main menu, character creation and training clear it, and training tests it for 0; nothing sets it
    otherwise }
  trainingMode: Byte;
  { 1 while CharGen's ModifyCharacterMenu runs, which sets it and clears it on each way out: MenuCore's MenuHorizontal
    then takes a click as a pick of a character-sheet field, which it stores in modifyFieldSelection; GameInit clears
    it }
  modifyActive: Byte;
  { Doors, and the ground combat's round, targets and turn. }
  { GameInit and Explore's 3-D step set all three to 1; otherwise unused }
  doorOpen: array[0..2] of Byte;
  { unused }
  doorOpenTail: array[0..1] of Byte;
  { the ground combat's round, from 0: CombatSt's CombatStart clears it and Combat's EndOfRound counts it up; Combat's
    CombatMain ends the combat once it reaches combatEndRound, and CbtActs adds its low bit to an attack rate before it
    halves it }
  combatRound: Byte;
  { the round at which ground combat ends: CombatSt's CombatStart sets IDLE_ROUNDS, and CbtActs' MakeAttack sets
    combatRound + IDLE_ROUNDS at each attack }
  combatEndRound: Byte;
  { the slots of the targets CharHlp's CountTargets keeps, in the target list's order: CbtActs and CombatAi pick a
    target from them by index 1..count, and CombatAi clears the ones it rules out }
  targetOrder: array[1..C_Combat.MAX_COMBATANTS] of Byte;
  { attacks made in the current action with each of the two attack slots: CbtActs' RollAttacks clears and counts them,
    and MakeAttack takes slot 1's count off the weapon's quantity }
  attackCounts: array[1..2] of Byte;
  { the hostiles' hit points left as a percentage, in steps of 5: CbtActs' UpdateHostileHpPercent works it out for
    CombatSt's CombatStart and Combat's EndOfRound; CombatAi's CheckMorale takes it as a creature's morale once its own
    fails, and AiMoveStep tests morale against it }
  hostileHpPercent: Byte;
  { unused }
  quickMagic: Boolean;
  { a four-frame 24 by 24 picture for combat's moving icons and shots: CombatSt's CombatStart allocates it, Blit's
    CopyIconTile copies a frame into it, CharHlp and CbtActs draw it, Combat frees it }
  movingIcon: Types.PImgBuf;

{ The ground combat's cursor and turn, the ECL registers and commands, and the ECL's redraw flags. }
var
  { arena column of the combat cursor: CbtActs' ManualAimCursor starts and moves it, MenuCore moves it to a clicked
    cell, and CbtActs' CombatUseJetpack flies to it }
  combatCursorX: ShortInt;
  { arena row of the combat cursor; the same writers and reader }
  combatCursorY: ShortInt;
  { 1 while ManualAimCursor runs the combat cursor: MenuCore's MenuHorizontal then takes a click in the arena as a
    cursor move; CombatSt's CombatStart and GameInit clear it }
  cursorActive: Byte;
  { per side, 1 once one of its characters has made the Battle Tactics roll: CbtActs' RollTactics clears and sets them,
    and CharHlp's RecalcStats adds 1 to that side's attackBonus; Combat clears side 0 when combat ends, GameInit clears
    both }
  tacticsSides: array[C_Side.TEAM..C_Side.HOSTILE] of Byte;
  { how the attack being resolved is made, which picks its combat line: CbtActs' RollAttacks sets 0, 1 from behind or 2
    for a backstab, which also multiplies the damage, and EffHndlr sets 0 before its own attacks; ProcessAttackResult
    also tests 3, which nothing sets }
  attackManner: Byte;
  { the sides the hostiles of the next ground combat come from, bit n for facing 2n: EclVm's EclSetupMonster stores its
    fourth ECL operand here, and CombatSt's PlaceAllCreatures sizes the hostiles' placement by the bits set and places
    each hostile on the next side set }
  monsterApproach: Byte;
  { 1 while Combat's MoveMenu runs: MenuCore's MenuHorizontal then takes a click in the arena as a move; CombatSt's
    CombatStart and GameInit clear it }
  inMoveMenu: Byte;
  { set by CombatAi's AiMoveAttack, which clears it first, when the creature's target is within reach, so it attacks
    instead of moving; AiMoveStep shows its step on the map while it is set }
  targetInReach: Byte;
  { 1 asks CharHlp's CombatPrintCreatureInfo to redraw the ground combat's side panel, which it clears as it does;
    Combat and CbtActs set it before they call it }
  creatureInfoDirty: Byte;
  { non-zero while the acting creature's moves and effects are drawn on the combat map: Combat sets it for each
    creature, CombatAi for each step and CbtActs for an attack; CbtMap and CbtActs test it, and GameInit sets it to 1 }
  mapVisible: Byte;
  { the combatants in the order they act this round, highest initiative first: Combat's OrderCreatures sorts them in,
    and a creature that waits moves to the end }
  combatOrder: array[1..C_Combat.MAX_COMBATANTS] of Types.PCharRecord;
  { the position in combatOrder of the creature acting: Combat's round loop steps it, and steps it back when a creature
    waits or takes its turn again }
  currentCombatant: Byte;
  { The view color codes ECL writes. }
  { the floor color code ECL writes through EclMenu's WriteGbvm, which MapView turns into the 3-D view's floor color in
    CGA mode; GameInit and EclMenu's EclInit give it a start value }
  floorColorCode: Byte;
  { the horizon color code ECL writes the same way, which MapView turns into both horizon colors in CGA mode; the same
    writers }
  horizonColorCode: Byte;
  { unused }
  horizonColorCodeTail: array[0..5] of Byte;
  { The ECL interpreter: the GOSUB stack, the comparison, the opcode and the monster shown. }
  { the top of the ECL GOSUB return stack: EclMenu's EclGosub pushes onto it and EclInit empties it; EclVm's EclReturn
    and EclExit pop it }
  eclStack: Types.PEclRet;
  { the node below the top while EclGosub pushes and EclVm pops }
  eclStackPrevious: Types.PEclRet;
  { the last ECL comparison: equal, not equal, less, greater, less or equal, greater or equal; EclMenu's EclCompareStr
    and EclCompareInt and EclVm's comparing commands set them, EclInit clears them, EclVm's EclIf tests them }
  compareFlags: array[0..5] of Boolean;
  { the opcode before currentOpcode, which EclVm's CallEclScript keeps; otherwise unused }
  previousOpcode: Byte;
  { the ECL opcode being run: CallEclScript fetches it from zone3, and EclMenu's SkipEclCmd the one it skips; EclVm's
    dispatch and commands branch on it }
  currentOpcode: Byte;
  { unused }
  currentOpcodeTail: Byte;
  { the SPRIT record ECL's show-monster command names: EclVm's EclSetupMonster sets it and passes it, as EclApproach
    does, to EclMenu's DisplayMonster }
  monsterSpriteId: Byte;
  { the PIC record of that monster's close-up, 255 for none; the same writer and readers }
  monsterPictureId: Byte;
  { the icon slot the next creatures ECL adds are loaded into: EclVm's EclLoadMonster gives it to each and counts it up;
    EclMenu's EclInit and EclClearMonsters set it to 8 }
  nextCreatureIconSlot: Byte;
  { unused }
  nextCreatureIconSlotTail: array[0..129] of Byte;
  { The operands of the ECL command being run. }
  { the type of each operand EclMenu's LoadEclVars reads: 0, 2 and 4 a byte, word or long value, 1, 3 and 5 the GBVM
    address of one, $80 a string, $81 the GBVM address of one; GetEclVar and EclVm's commands read them. Two tables of
    the same shape follow, the operands' high bytes and then their low bytes }
  eclVarTypes: array[1..64] of Byte;
  { The operands EclMenu's LoadEclVars reads from the script, 1..count in order, after eclVarTypes. EclVm's commands
    read operands 1..6 at their fixed cells, and its indexed choice command every operand through a variable index. }
  { byte 1 of each operand, a GBVM address's high byte: LoadEclVars fills it and reads it back for a $81 string
    reference; EclInit, GetEclVar, EclGosub and EclVm's commands read it }
  eclVarHigh: array[1..64] of Byte;
  { byte 0 of each operand, a string's length: the same writer and readers }
  eclVarLow: array[1..64] of Byte;
  { byte 3 of a type 4 operand: LoadEclVars fills it, GetEclVar reads it }
  eclVarByte3: array[1..64] of Byte;
  { byte 2 of a type 4 operand: the same writer and reader }
  eclVarByte2: array[1..64] of Byte;
  { True once Border's DrawFrameSegments reaches the C_Screen.FRAME_SCRIPT_END that ends a frame script: it sets it
    False, then True at the mark, and loops until it is set. CbtActs' ManualAimCursor and EclMenu's EclInit also clear
    it, EffHndlr's EffStrikeAdjacent and EffSpitAcid set it }
  frameScriptDone: Boolean;
  { a loop counter the units share instead of keeping their own: Blit, CombatSt, CharGen, CharHlp, Combat, EffHndlr,
    Joystick, Portrait, PostCbt, ShipCbt, Shop, Skills, TextRend and ViewChar run loops on it, Shop also holds an item
    template number in it, and EclVm's CallEclScript sets it to 1 }
  loopIndex: ShortInt;
  { the string operands in order: LoadEclVars stores the k-th in slot k, and EclVm's commands read them, a menu's slots
    1 to the count ECL gives; EclVm's EclPrint writes slot 1. Note: nothing bounds k at 20, and a 21st string operand
    runs on into the variables after the table }
  eclStrings: array[1..20] of String;
  { The monster's pictures, the ECL selector sound and the redraw flags. }
  { which of the monster's pictures EclMenu's DisplayMonster has shown: EclVm passes it, sets [1] when it shows a
    close-up and clears it; EclInit and UpdateEclDisplay clear it }
  monsterFlags: Types.TMonFlags;
  { unused }
  monsterFlagsTail: array[0..1] of Byte;
  { the sound EclVm's EclCall sends for its selector $3204: above 127 its low seven bits go to Music's StartMusic, else
    it goes to SendSoundCommand. Note: a 21st string operand of 4 or more characters, past the end of eclStrings,
    overwrites it }
  selectorSound: Word;
  { unused }
  selectorSoundTail: array[0..3] of Byte;
  { EclVm's EclLoadCharacter tests it with refreshCharacterB before it removes the creature and redraws the party, and
    clears both; EclMenu's EclInit clears it }
  refreshCharacterA: Byte;
  { set by EclMenu's SpecialWriteZ1 when ECL writes 0 to zone 1's first byte; EclInit and EclLoadCharacter clear it }
  refreshCharacterB: Byte;
  { non-zero makes CharHlp's DisplayNoncombatInterface redraw the exploration frame for interfaceState 1: Shop's
    ShopMainMenu clears it for its own call and sets it to 1 after }
  exploreFrameRedraw: Byte;

{ After combat: the solo fight, the experience shared out, and the treatment and repairs still to come. }
var
  { non-zero while ECL $4A fights a combat with the current character alone: EclVm's EclSoloCombat sets it and runs
    EclCombat, which disables the other members for the fight, enables them after and clears it. While it is set
    CombatSt places no disabled creature, CombatAi bandages no one, and PostCbt credits the whole experience to the
    current character and takes no loot. GameInit clears it }
  soloCombat: Byte;
  { the party members PostCbt's DetermineCombatResults finds disabled after combat; DetermineLootExp takes it off zone
    1's party count before it divides the experience }
  disabledCount: Byte;
  { each character's share of the experience: PostCbt's DetermineLootExp works it out and AwardExperience gives it;
    PostCombat clears it and shows the summary when it is non-zero, and RepairShip shares out the ship combat's
    experience through it }
  experienceShare: LongInt;
  { non-zero once PostCbt's DetermineCombatResults, which clears it first, finds a character still up after combat; it
    then shares out the experience }
  combatWon: Byte;
  { non-zero once a fight has taken place: PostCbt's TreatInjuries treats poison and wounds only while it is set, and
    clears it. Combat's CombatMain sets it when both sides have combatants, ShipCbt after a ship combat that ends
    without boarding; GameInit's orbit set-up clears it }
  treatmentPending: Byte;
  { non-zero makes PostCbt's PostCombat run RepairShip, which repairs the ship and clears it: ShipCbt sets it after a
    ship combat that ends without boarding, PostCombat when zone 0's postCombatMode is POST_COMBAT_REPAIR_SHIP;
    PostCbt's LootMenu and GameInit's orbit set-up clear it }
  shipRepairPending: Byte;

{ ECL display flags, and the overlay manager's own reader. }
var
  { the ECL script loaded: EclVm's EclNewEcl sets it, saving the one before in zone 0's stateValue, and GameLoop sets
    16, 24 or stateValue; View3D's map lookups treat squares off the map as empty in scripts 0 and 80, and CombatSt
    seeds the dungeon arena with it }
  eclId: Byte;
  { bit 0 of zone 1's search flags: EclVm's GameLoop keeps it here while it sets the flags to 1 and runs the script's
    entry point 2, then puts it back; GameInit clears it }
  savedSearchFlag: Byte;
  { EclVm's EclClearBox sets it to 1 and EclExit clears it, as GameInit does; otherwise unused }
  eclDisplaying: Byte;
  { True while a picture covers the 3-D view: EclMenu's DisplayMonster sets it for a close-up and UpdateEclDisplay
    redraws the view and clears it; EclVm's picture command sets it, redraws and clears it, its horizontal menus animate
    while it is set, and its EclExit, EclCombat and GameLoop clear it, as EclInit and GameInit do }
  picturePending: Boolean;
  { EclMenu's EclInit and EclVm's GameLoop clear it; otherwise unused }
  protectionTextShown: Byte;
  { set by EclMenu's DisplayMonster when it loads a monster sprite, where areaType is not 0; UpdateEclDisplay and
    EclVm's picture command then redraw the 3-D view and clear it; GameInit clears it }
  monsterSpriteShown: Byte;
  { 0 makes Explore's MapMainMenu clear the text window on its way out, and it then sets it to 1; EclVm's ECL print and
    vertical menu commands clear it }
  bottomClear: Byte;
  { set by EclMenu's EclInit and by its WriteGbvm when ECL writes floorColorCode or horizonColorCode: in CGA mode
    MapView's DisplayMapView then works out the 3-D view's colors, and UpdateEclDisplay redraws the view and clears it }
  viewColorsChanged: Byte;
  { set by EclMenu when ECL moves the party, and by EclVm's NewEclDone; EclMenu's UpdateEclDisplay then redraws the view
    and clears it }
  partyMoved: Boolean;
  { EclVm's EclLoadMonster sets it as it adds creatures, EclClearMonsters clears it, and EclCombat reads it and sets it
    from its hostile test; EclMenu's SpecialWriteZ1 sets it when ECL makes the current character hostile }
  partyChanged: Byte;
  { set by EclMenu's WriteGbvm when ECL writes zone 0's skyIndexLo or skyIndexHi; UpdateEclDisplay then redraws the view
    and clears it }
  redrawSky: Boolean;
  { while it is 0, EclMenu's DisplayMonster shows a monster's close-up even when monsterPictures is 0; GameInit clears
    it, and a 21st string operand of 35 or more characters writes it }
  inEncounterMenu: Byte;
  { 1 when EclVm's EclLoadCharacter finds no character at the place ECL gives, else 0; EclWho clears it; EclMenu's
    SpecialReadZ1 then answers 0 for zone 1's byte $100 }
  selectFailed: Byte;
  { EclVm's GameLoop sets it to 1, or 0 when zone 0's stateValue is 0, and redraws the noncombat interface while it is
    1; EclLoadFiles redraws the exploration screen while it is set; EclClearBox and CharHlp's DisplayNoncombatInterface
    clear it }
  refreshState: Byte;
  { GameInit's InitializeGame and ResetGameState clear it; otherwise unused }
  victoryStart: Byte;
  { non-zero while the map menu's Move is on: Explore's MapMainMenu sets it for Move in the 3-D view, the wilderness and
    the orbit map, and clears it for Exit; MoveRocket clears it for Done. While it is set MenuCore's MenuHorizontal
    takes a click on the 3-D view, the wilderness or the orbit map as a move and, in the 3-D view, ignores one on the
    party list. EclVm's combat, character choice and menu commands clear it and put it back, its GameLoop clears it
    before the map loop, and CombatSt's CombatStart and GameInit clear it }
  moveMode: Byte;
  { the second operand of ECL $1D, which EclVm's EclSetSpeaker stores; otherwise unused }
  speakerArg2: Byte;
  { the first operand of ECL $1D; the same writer }
  speakerArg1: Byte;
  { the ECL address EclVm's EclLoopInitialize records, which EclLoopAdvance jumps back to while zone 0's loopCurrent is
    at most loopLimit }
  eclLoopStart: Word;
  { unused }
  eclLoopStartTail: array[0..4] of Byte;
  { the overlay manager's own read routine, which GameBoot saves before it installs GameIo's OverlayReadWithBeep as the
    reader; OverlayReadWithBeep calls it, beeping and retrying while it fails }
  originalOvrReader: Types.TOverlayReader;

{ The debug file and the wilderness cursor's picture. }
var
  { debug.txt: GameIo's Ctrl-D opens and closes it, ExitGame closes it while isDebugMode is set, and Sym8x8's Load8x8Set
    writes to it while isDebugMode is set }
  debugFile: Text;
  { unused }
  cursorImageId: Byte;
  { the wilderness cursor's picture: GameInit sets it to nil, then loads 'cursor' into it; MapCurs's DrawCursor draws it
    masked over a copy of the party's cell }
  cursorPicture: Types.PImgBuf;

{ Copy protection, and the combat debug password. }
var
  { ParamStr(1) must match it for CbtActs' combat debug key; GameInit sets it to shipNames[2, 1], 'Sahara' }
  combatDebugPassword: String[20];
  { CopyProt's CopyProtection clears them and sets one by one as the Log Book check reaches each stage; FixMain quits
    the game if one is still 0 }
  protectionFlags: array[1..4] of Byte;

{ Mouse and joystick. }
var
  { True when the driver gives x in screen pixels, so Mouse's GetMouse and SetMouse leave x alone; False halves and
    doubles it. GameInit and CharGen's InitMouseJoystick move the mouse to x 639 and set it by whether the x read back
    is below 321 }
  isMouseScaled: Boolean;
  { lets a click on the party list pick a character: MenuCore's MenuHorizontal takes one only while it is set, in
    interface states 0, 1, 4 (not while moveMode is set), 6 and 10. CharHlp's DisplayNoncombatInterface sets it by
    whether interfaceState is one of those five; menus that pick a character set it for their run, and some others clear
    it for theirs }
  canClickParty: Boolean;
  { True while a mouse is in use: GameBoot sets it from matrix.cfg's input line, Mouse's InitMouse by the driver's
    answer, and CharGen's InitMouseJoystick turns it on and off. Every Mouse call but InitMouse does nothing without it,
    and GameIo reads input from the mouse while it is set }
  isMouseOn: Boolean;
  { True when GameIo's ReadGameKey, which clears it on every call, took its key from a mouse button: MenuCore's menus
    and Explore then act on the click's place in mouseX and mouseY; ViewChar and TextRend test it }
  isMouseClick: Boolean;
  { the mouse driver's button count, which Mouse's InitMouse stores; GameInit and CharGen's InitMouseJoystick clear it
    before they reset the mouse; otherwise unused }
  mouseButtons: Byte;
  { the mouse's x, which GameIo's ReadGameKey and InputPending fetch through Mouse's GetMouse; GameInit and CharGen's
    InitMouseJoystick start it at 160; MenuCore, Explore and CharGen read it }
  mouseX: Integer;
  { the mouse's y; the same writers and readers, starting it at 100 }
  mouseY: Integer;
  { GameInit and CharGen's InitMouseJoystick clear it once they have set the mouse up; otherwise unused }
  mouseOldX: Integer;
  { cleared with mouseOldX }
  mouseOldY: Integer;
  { the cursor GameInit and CharGen's InitMouseJoystick hand to Mouse's SetMouseCursor: arrowCursor, or cgaArrowCursor
    in CGA mode }
  mouseCursorMask: Types.PMouseCursor;
  { GameInit clears it with mouseButtons before it resets the mouse; otherwise unused }
  clearedBeforeMouseReset: Byte;
  { The joystick. }
  { per stick, the readings that bound each axis's zones: Joystick's ProbeJoystick clears both, CalibrateJoystick and
    CharGen's CalibrateJoystickInWindow measure stick 1, GameBoot reads stick 1 from matrix.cfg and GameBoot and CharGen
    write it there; JoyZone reads the thresholds }
  joystickCalibration: array[1..2] of Types.TJoyCal;
  { True while a joystick is in use: GameBoot sets it from matrix.cfg, Joystick's ProbeJoystick keeps it only while
    stick 1 answers and CalibrateJoystick sets it, and CharGen's InitMouseJoystick toggles it; GameIo reads the stick
    while it is set, and Joystick, GameInit and MenuCore test it }
  isJoystickOn: Boolean;
  { 160, the screen's middle x, which GameInit sets when the joystick is on; otherwise unused }
  joystickCenterX: Integer;
  { 100, set with joystickCenterX }
  joystickCenterY: Integer;

{ The 3-D view's backdrops, the palettes, the AIL music driver's state, and FixMain's root scratch pair. }
var
  { the 3-D view's backdrops: View3D's LoadWallSet loads [1] from BACK record fileId + 128 and [0] from fileId, and
    DrawBackdrop draws [0] while bit $80 of the square's event is set, else [1] }
  backdropPictures: array[0..1] of Types.PImgBuf;
  { The palettes and the color tables built from a picture's header. }
  { which table Blit's SrcNibble reads: 1 paletteCgaColors, 0 nibbleCgaColors through paletteNibbles; Blit's PreparePic
    sets it, Portrait's LoadAnimation clears it }
  paletteMode: Byte;
  { in VGA mode, the colors of the big picture Portrait's LoadBigPic has cached, copied in when it loads and set again
    when that picture is asked for again }
  bigPicturePalette: Types.TPalette256;
  { in VGA mode, the colors of the animation Portrait's LoadAnimation has cached, copied in when it loads and set again
    when that animation is asked for again }
  loadedPalette: Types.TPalette256;
  { the ground combat screen's colors in VGA mode: GameInit copies in entries 0..14 at start-up and $40..$5F after the
    COMSPR icons, MapTiles' LoadIconAnim $60..$8F after CHARS icons and $90..$FF after CPIC icons, and CombatSt's
    LoadCombatTileSet $20..$3F after the arena tiles; CombatStart loads DAC $20..$FF from it }
  combatPalette: Types.TPalette256;
  { the exploration screen's colors in VGA mode: GameInit copies in entries 0..14 at start-up and $10..$1F after the
    tile sets, and View3D's LoadWallSet $20..$B3 after a wall set; MapView's DisplayMapView loads DAC $20..$B3 from it
    while viewPaletteStale is set, FixMain and Intro DAC $10..$1F }
  viewPalette: Types.TPalette256;
  { the colors of the picture last loaded: Blit's PreparePic moves each picture's colors in from the first entry its
    header names, Portrait's LoadAnimation an animation's, and GameInit puts its default colors in entries 0..15. In VGA
    mode Blit's ShadowPaletteEntries copies ranges of it into the four palettes above, and GameInit, CharGen, OrbitMap,
    Portrait, ShipCbt, SaveLoad and Intro load DAC ranges from it }
  picturePalette: Types.TPalette256;
  { the 4-bit color of each palette index, from a picture's header: Blit's PreparePic and Portrait's LoadAnimation fill
    it, Blit reads it; GameInit starts entries 0..15 at their own index }
  paletteNibbles: array[0..255] of Byte;
  { the CGA color 0..3 of each 4-bit color, from a picture's header: Blit's PreparePic and Portrait's LoadAnimation fill
    it, SrcNibble reads it; GameInit starts entries 0..3 at their index }
  nibbleCgaColors: array[0..15] of Byte;
  { the CGA color 0..3 of each palette index of a picture whose header names colors $20..$8F: Blit's PreparePic fills
    it, and SrcNibble reads it while paletteMode is 1 }
  paletteCgaColors: array[0..255] of Byte;
  { non-zero once a picture may have loaded DAC entries $20..$B3 over viewPalette's: EclMenu's DisplayMonster, EclVm's
    picture commands and fights, and View3D's LoadWallSet set it; MapView's DisplayMapView reloads those entries from
    viewPalette while it is set, and clears it }
  viewPaletteStale: Byte;
  { The AIL music driver. }
  { The AIL music driver's state, Xmidi's; GameInit clears it at start-up. }
  { bytes Xmidi's LoadDriverImage allocates for the driver file: its size and 64 of slack }
  driverAllocSize: Word;
  { that block }
  driverAlloc: Pointer;
  { the paragraph-aligned address in driverAlloc the driver file is read to and registered at }
  driverImage: Pointer;
  { the XMIDI file LoadXmiFile reads, which StartSequence registers each sequence from }
  xmiData: Pointer;
  { its size }
  xmiSize: Word;
  { the sequence StartSequence starts, a sequenceHandles index }
  activeSequence: Word;
  { AIL_register_driver's handle for the loaded driver, which every other AIL call takes }
  driverHandle: Word;
  { AIL_describe_driver's description of the loaded driver }
  driverDesc: Types.PDriverDesc;
  { AIL_default_timbre_cache_size's answer, the size of timbreCache }
  timbreCacheSize: Word;
  { the timbre cache StartSequence allocates and hands to AIL_define_timbre_cache }
  timbreCache: Pointer;
  { AIL_register_sequence's handle for each sequence StartSequence registers, at most 0..7 }
  sequenceHandles: array[0..8] of Word;
  { the state table StartSequence allocates for each sequence; it and ShutdownDriver free all nine }
  stateTables: array[0..8] of Pointer;
  { AIL_state_table_size's answer, the size of each stateTables block }
  stateAllocSize: LongInt;
  { FixMain's own. }
  { FixMain zeroes it first thing; otherwise unused }
  rootScratchPair: LongInt;

implementation

end.
