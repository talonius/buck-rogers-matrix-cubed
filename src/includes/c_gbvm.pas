{ The GBVM addresses the code names: zone 1's base, the current character's record, and the saved data set cell. }
unit C_Gbvm;

interface

const
  { zone 1's base: the current character's record, as EclMenu's SpecialReadZ1 and SpecialWriteZ1 map it; EclVm's
    EclCheckParty (ECL CHECK PARTY) takes its attribute operand as an offset from it }
  CURRENT_CHARACTER = $7C00;

implementation

end.
