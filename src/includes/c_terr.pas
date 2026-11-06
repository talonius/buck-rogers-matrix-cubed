{ The arena terrain values the code names: the last kind of ground combat terrain, the cost no move can pay, the markers
  that clouds and downed combatants lay, the wilderness ground not yet laid, and the flags of a wilderness scatter rule
  (TTerrainProfile.flags). }
unit C_Terr;

interface

const
  { the last kind of ground combat terrain, terrainInfo's; CbtMap draws a cell holding 0 or a higher value as terrain
    21 }
  LAST_COMBAT_TERRAIN = 154;
  { a terrainInfo cost no move can pay }
  IMPASSABLE = 255;
  { The markers a lingering cloud lays on the arena cells it covers (projectile kinds 8, 7 and 9): CbtActs lays them,
    and CbtMap sees through a cell holding one to the terrain its TAreaEffect keeps }
  { the arena marker a chaff cloud lays: Pathing's WalkLine reports it, CbtActs' shots meet it }
  CHAFF_TERRAIN = 1;
  { projectile kind 7's, whose projectile makes its targets Helpless }
  GAS_TERRAIN = 2;
  { the arena marker an aerosol mist cloud lays, which WalkLine reports }
  AEROSOL_MIST_TERRAIN = 4;
  { the marker a downed combatant leaves on its cell, over the terrain its TDownedCreature keeps }
  CORPSE_TERRAIN = 5;
  { wilderness ground not yet given a tile; as a profile's pairTile, no pair }
  UNSET_TERRAIN = 6;
  { the pair tile goes below the tile, not to its right }
  PROFILE_PAIR_BELOW = $01;
  { a run rolls its tiles once, for its first plot }
  PROFILE_ONE_ROLL = $02;
  { the pair tile takes the tile's roll instead of its own }
  PROFILE_PAIR_FOLLOWS = $04;
  { the variance rolls are doubled }
  PROFILE_DOUBLE_VARIANCE = $08;
  { a run keeps the previous run's center }
  PROFILE_KEEP_CENTER = $10;
  { every plot falls exactly scatter cells from the center }
  PROFILE_FIXED_SCATTER = $20;

implementation

end.
