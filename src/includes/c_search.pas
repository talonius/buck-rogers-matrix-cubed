{ The search flags, zone 1's searchFlags bits. }
unit C_Search;

interface

const
  { zone1^.searchFlags' search bit: Explore's 3-D steps take a turn while it is set, and CharHlp shows ' search'.
    EclVm's GameLoop sets the flags to SEARCHING while it runs entry point 2 and then restores the bit it saved, and
    EclCombat, after a combat, clears every bit but this one; Explore's Look ORs in its own LOOK_PENDING }
  SEARCHING = 1;

implementation

end.
