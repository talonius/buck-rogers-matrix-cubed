{ TCharRecord.npc's values: the non-player bit and the party member value. }
unit C_Npc;

interface

const
  { TCharRecord.npc at or above it is not a player character }
  NON_PLAYER_FLAG = $80;
  { an npc byte that pools its credits (Money) and stays on the team side when the team attacks an ally (CbtActs) }
  PARTY_MEMBER_NPC = $B3;

implementation

end.
