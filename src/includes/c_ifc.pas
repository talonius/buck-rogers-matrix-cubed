{ The interface states, GDVars' interfaceState values. }
unit C_Ifc;

interface

const
  { interfaceState values; 7 is unused }
  { CharGen's main menu, and SaveLoad's LoadGame on its way back to it }
  MAIN_MENU = 0;
  { Shop's ShopMainMenu }
  IN_SHOP = 1;
  { camping: CharHlp's position line adds ' camping' in this state; nothing sets it }
  CAMPING = 2;
  { EclMenu's WriteGbvm when ECL sets areaType C_Area.VENUS_WILDERNESS or C_Area.MARS_WILDERNESS; EclVm's picture mode
    4 }
  WILDERNESS = 3;
  { GameInit; EclVm's picture mode 0; WriteGbvm for any other areaType }
  VIEW_3D = 4;
  { ground combat: Combat's CombatMain }
  IN_COMBAT = 5;
  { PostCbt's PostCombat, from the results to the loot menu }
  POST_COMBAT = 6;
  { the ship screen: ShipCbt's ship combat, and the ship views of Explore's orbit map and PostCbt's loot }
  SHIP = 8;
  { Explore; WriteGbvm when ECL sets areaType C_Area.ORBIT; EclVm's picture mode 2 }
  ORBIT_MAP = 9;
  { EclVm's picture mode 3 }
  PICTURE_VIEW = 10;
  { Skills' EditSkills while it spends points }
  EDITING_SKILLS = 11;

implementation

end.
