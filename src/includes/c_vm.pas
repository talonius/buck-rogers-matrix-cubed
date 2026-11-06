{ The video modes, GDVars' displayMode values. }
unit C_Vm;

interface

const
  { displayMode values. GameBoot stores only EGA, TANDY or VGA, for matrix.cfg's E, T or V; the drawing units still test
    for CGA, which nothing sets. }
  CGA = 0;
  EGA = 1;
  TANDY = 2;
  VGA = 3;

implementation

end.
