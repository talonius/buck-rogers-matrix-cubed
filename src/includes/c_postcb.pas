{ The post-combat modes, zone 0's postCombatMode: what PostCbt's PostCombat does after a fight. }
unit C_PostCb;

interface

const
  { TZone0.postCombatMode values: ShipCbt sets them, PostCbt acts on them }
  { treat, repair and offer loot; ShipCbt sets it as a ship combat starts }
  NORMAL = 0;
  { ShipCbt: the team boarded the enemy ship; PostCombat skips treatment, repair, the summary and the loot menu }
  BOARDED = 1;

implementation

end.
