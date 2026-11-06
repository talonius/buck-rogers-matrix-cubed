{ The area types the code names, zone 0's areaType values, and its zero-gravity bit. }
unit C_Area;

interface

const
  { zone 0's areaType values the code names }
  { CombatSt lays these arenas from the 'venuscom' tiles }
  VENUS_WILDERNESS = $A2;
  { and these from 'marscom' }
  MARS_WILDERNESS = $A8;
  { EclMenu's WriteGbvm puts the game on the orbit map for it }
  ORBIT = $70;
  { an areaType bit: CbtActs' RollZeroG then rolls skill 67, Maneuver in 0G, for each acting combatant and sets status
    12, a failed zero-G maneuver, on a miss; CbtActs gives a lingering cloud 1 round, not 4; and CombatAi scores no
    chaff or mist grenade }
  ZERO_GRAVITY = $10;

implementation

end.
