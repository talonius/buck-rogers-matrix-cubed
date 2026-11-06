{ The keys the menus and the input routines answer: Enter, Escape and Backspace as ASCII, the cursor keys, Alt-X and ]
  as the scan codes read after the #0 of an extended key, and a menu's answer when it is left without a choice. }
unit C_Keys;

interface

const
  { the key ReadGameKey answers for Enter, and for a mouse's or joystick's first button }
  ENTER = #13;
  { the key ReadGameKey answers for Escape, and for a mouse's or joystick's second button }
  ESCAPE = #27;
  { the Backspace key, which CharGen's name entry and the status-line input routines take as a delete }
  BACKSPACE = #8;
  { Alt-X's scan code: Combat's menu and CombatAi's key check take it for the combat debug phrase }
  ALT_X = #45;
  { scan codes of the cursor keys, read with extFlag set: MenuHorizontal and MenuVertical answer the arrows and pages;
    CharGen, Combat, CbtActs, Explore, Skills and ViewChar read the directions }
  UP = #72;
  DOWN = #80;
  LEFT = #75;
  RIGHT = #77;
  PAGE_UP = #73;
  PAGE_DOWN = #81;
  HOME = #71;
  END_KEY = #79;
  { the ] key's scan code, the only #27 a menu answers outside the skill and modify screens, since MenuHorizontal
    answers Escape as NONE. Note: ShipCbt, ViewChar, SaveLoad, Explore and Skills test for it meaning Escape }
  RIGHT_BRACKET = #27;
  { a menu's answer when it is left without a choice: Escape in MenuHorizontal's menuKey, Escape or Exit as
    MenuVertical's result }
  NONE = #0;

implementation

end.
