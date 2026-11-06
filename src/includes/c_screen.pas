{ The 40x25 text-cell screen: its last column and row, its status row, and its width in columns. }
unit C_Screen;

interface

const
  { its last column }
  LAST_COLUMN = 39;
  { the status line, the bottom row, where prompts, input and one-line menus show }
  STATUS_ROW = 24;
  TEXT_COLUMNS = 40;
  { the byte that ends one of Border's frame scripts, the runs of border tiles that lay out a screen, in place of a
    run's x1 }
  FRAME_SCRIPT_END = 254;

implementation

end.
