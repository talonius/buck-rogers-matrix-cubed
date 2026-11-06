{ Menu choices: the yes/no prompt's default, the choices a menu starts on, no skill line clicked, and the fields of
  CharGen's character modify menu. }
unit C_Menu;

interface

const
  { YesNoMenu's defaultChoice: Yes selected first }
  DEFAULT_YES = 1;
  { No selected first }
  DEFAULT_NO = 2;
  { menuChecksum that keeps horizChoice across a changed menu }
  KEEP_MENU_CHOICE = 255;
  { a horizChoice that starts ViewChar's UseItemMenu on the option after Join: Sell in a shop, which sets it }
  SELL_CHOICE = 255;
  { clickedSkillLine when no click on the skill screen is pending: MenuCore's MenuHorizontal sets it before it tests a
    click, and Skills' EditSkills once it has taken the line }
  NO_SKILL_LINE = -1;
  { the character modify menu's fields after the abilities 0..6, which a click on them selects (MenuCore): the name, and
    the last, hpMax }
  MODIFY_NAME_FIELD = 7;
  MODIFY_HIT_POINTS_FIELD = 8;

implementation

end.
