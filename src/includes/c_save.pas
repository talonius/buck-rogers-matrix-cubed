{ Saving throws: saveReduction's values, what a saved throw does to an effect or its damage. }
unit C_Save;

interface

const
  { a saved throw changes nothing }
  NO_EFFECT = 0;
  { a saved throw cancels the damage or the effect }
  CANCELS = 1;
  { a saved throw halves the damage }
  HALVES = 2;

implementation

end.
