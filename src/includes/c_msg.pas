{ The text window's message area: its first and last column and row; and the slowest message speed. }
unit C_Msg;

interface

const
  { zone 0's highest messageSpeed, the slowest: Explore's Messages menu goes no higher, and FixMain's demo sets it }
  SLOWEST_MESSAGE_SPEED = 9;
  { the text window's message area, where ECL's prints and menus and the shop's messages show }
  MESSAGE_LEFT = 1;
  MESSAGE_TOP = 17;
  MESSAGE_RIGHT = 38;
  MESSAGE_BOTTOM = 22;

implementation

end.
