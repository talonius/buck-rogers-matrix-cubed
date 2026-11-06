{ The shop: its main menu, buying from the shop's item list, the ammunition counter that fills clips and reloads missile
  weapons, and the exit warning about credits left in the pool. Selling, viewing and the pool itself are ViewChar's and
  Money's routines. The shop's item list is GDVars' availableItems, its price multiplier a zone 1 cell, and the pool
  GDVars' poolCredits. }
{$O+,F+,V-}
unit Shop;

interface

uses Types, C_Menu, GDConsts, GDVars, CharHlp, ViewChar, TextRend, Border, MenuCore,
  Money, Crt, C_Equip, C_WClass, C_Ifc, C_Item, C_Msg, C_Keys;

{ Runs the shop until the party leaves it, with interfaceState IN_SHOP meanwhile. It empties the pool on entry, and
  credits still pooled when the party declines to go back for them at the exit are lost. }
procedure ShopMainMenu;

{ Gives currentCharacter a copy of item, joined with a like item unless it is not joinable, and takes it back when that
  leaves more than 16 items.
  @param(item The item copied.)
  @param(failed True when the copy was taken back.) }
procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);

{ Puts the two free ammunition items (freeAmmoTemplates, freeAmmoQuantities) at the head of currentCharacter's item
  list, readied. }
procedure BuildAmmoItems;

implementation

const
  { a buy-menu line: the item's name, its price right-aligned }
  MENU_LINE_WIDTH = 38;
  { rounds a ROUND_AT_A_TIME_CLASSES weapon holds; it is sold a round at a time }
  AREA_AMMO_CAPACITY = 10;
  { the area weapons but the grenades }
  ROUND_AT_A_TIME_CLASSES = [C_WClass.ROCKET_LAUNCHER, C_WClass.PLASMA];
  { rounds any other missile weapon holds }
  AMMO_CAPACITY = 250;
  { rounds in one of its clips }
  CLIP_ROUNDS = 10;
  BUYS_TEXT = ' buys ';
  BUYS_A_TEXT = ' buys a ';
  NOT_ENOUGH_TEXT = 'Not enough Money.';

{ Shows the current character's funds and the pooled funds on rows 20 and 21. }
procedure DisplayShopMoney;
var s: String[10];
begin
  Str(GDVars.currentCharacter^.credits, s);
  TextRend.RightAlignString(s, 10);
  TextRend.DisplayString(1, 20, White, Black, 'Personal funds:' + s);
  Str(GDVars.poolCredits, s);
  TextRend.RightAlignString(s, 10);
  TextRend.DisplayString(1, 21, White, Black, 'Pooled funds:  ' + s)
end;

{ Prices an item for the shop.
  @param(item The item priced.)
  @returns(The item's value, scaled by zone 1's priceMultiplier / 16 when that is set.) }
function ItemPrice(item: Types.PItemRec): LongInt;
begin
  if GDVars.zone1^.priceMultiplier = 0 then
    ItemPrice := item^.template.value
  else
    ItemPrice := LongInt(item^.template.value) * GDVars.zone1^.priceMultiplier div 16
end;

{ Lays each shop item's price into its name's last columns (raising a value of 0 to 1), runs the buy menu, then rebuilds
  the names.
  @param(key The key that ended the menu.)
  @param(itemToBuy The item under the cursor when the menu returns.)
  @param(cursor The menu's cursor item, kept between calls.)
  @param(idx The menu's cursor index, kept between calls.) }
procedure ShopBuyItemSelection(var key: Char; var itemToBuy, cursor: Types.PItemRec; var idx: Integer);
var
  head: Types.PItemRec;
  item: Types.PItemRec;
  priceText: String[16];
  menuLine: String[Shop.MENU_LINE_WIDTH];
  textLength: Byte;
  charIndex: Byte;
  price: LongInt;
begin
  item := GDVars.availableItems;
  while item <> nil do begin
    menuLine := GDConsts.menuBlankLine;
    if item^.template.value = 0 then item^.template.value := 1;
    price := Shop.ItemPrice(item);
    Str(price, priceText);
    textLength := Length(priceText);
    for charIndex := 1 to textLength do
      menuLine[Shop.MENU_LINE_WIDTH - textLength + charIndex] := priceText[charIndex];
    textLength := Length(item^.name);
    for charIndex := 1 to textLength do
      menuLine[charIndex] := item^.name[charIndex];
    item^.name := menuLine;
    item^.name[0] := Chr(Shop.MENU_LINE_WIDTH);
    item := item^.next
  end;
  head := GDVars.availableItems;
  GDVars.horizChoice := 0;
  key := MenuCore.MenuVertical(GDConsts.itemsPrompt, GDConsts.buyMenu, 1, 1, Shop.MENU_LINE_WIDTH, 18,
                               Types.PMenuNode(head), True, GDVars.menuNeedsRedraw, idx, Types.PMenuNode(cursor));
  itemToBuy := cursor;
  item := GDVars.availableItems;
  while item <> nil do begin
    CharHlp.PrintItemString(nil, item, 0, 0, False, False);
    item := item^.next
  end
end;

procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);
var
  newItem: Types.PItemRec;
  tail: Types.PItemRec;
begin
  failed := False;
  GetMem(newItem, SizeOf(Types.TItemRec));
  newItem^ := item^;
  newItem^.next := nil;
  tail := GDVars.currentCharacter^.itemsAddr;
  if tail = nil then
    GDVars.currentCharacter^.itemsAddr := newItem
  else begin
    while tail^.next <> nil do tail := tail^.next;
    tail^.next := newItem
  end;
  if (item^.template.flags and C_Item.NOT_JOINABLE) = 0 then ViewChar.JoinItem(newItem);
  if ViewChar.CountItems(GDVars.currentCharacter) > C_Item.MAX_CARRIED_ITEMS then begin
    CharHlp.PrintBottomLine('OverLoaded');
    failed := True;
    CharHlp.RemoveItem(GDVars.currentCharacter, newItem)
  end;
  CharHlp.RecalcStats(GDVars.currentCharacter)
end;

procedure BuildAmmoItems;
var
  item: Types.PItemRec;
  i: Byte;
begin
  for i := 1 to SizeOf(GDConsts.freeAmmoTemplates) do begin
    GetMem(item, SizeOf(Types.TItemRec));
    GDVars.loopIndex := GDConsts.freeAmmoTemplates[i];
    Move(GDVars.itemTemplates[GDVars.loopIndex], item^.template, SizeOf(Types.TItemTemplate));
    item^.template.quantity := GDConsts.freeAmmoQuantities[i];
    item^.next := GDVars.currentCharacter^.itemsAddr;
    item^.menuLabel := 0;
    GDVars.currentCharacter^.itemsAddr := item;
    item^.template.flags := item^.template.flags or C_Item.READIED
  end
end;

{ Runs the buy menu: gives currentCharacter a copy of the item chosen and charges its price to the character's credits,
  or, when they fall short, takes all of them and the rest from the pool, until the player leaves. }
procedure ShopBuyMenu;
var
  item: Types.PItemRec;
  key: Char;
  done: Boolean;
  price: LongInt;
  failed: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
begin
  item := nil;
  cursor := GDVars.availableItems;
  idx := 0;
  Border.DrawWindowFrame(Byte(True));
  GDVars.menuNeedsRedraw := True;
  repeat
    Shop.DisplayShopMoney;
    Shop.ShopBuyItemSelection(key, item, cursor, idx);
    if (key <> 'B') and (key <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      price := Shop.ItemPrice(item);
      if price <= GDVars.currentCharacter^.credits then begin
        Shop.GiveItemCopyToCreature(item, failed);
        if not failed then begin
          Dec(GDVars.currentCharacter^.credits, price);
          if item^.template.quantity > 0 then
            CharHlp.PrintBottomLine(GDVars.currentCharacter^.name + Shop.BUYS_TEXT + item^.name)
          else
            CharHlp.PrintBottomLine(GDVars.currentCharacter^.name + Shop.BUYS_A_TEXT + item^.name)
        end
      end else if price <= GDVars.poolCredits + GDVars.currentCharacter^.credits then begin
        Shop.GiveItemCopyToCreature(item, failed);
        if not failed then begin
          Dec(price, GDVars.currentCharacter^.credits);
          GDVars.currentCharacter^.credits := 0;
          Dec(GDVars.poolCredits, price);
          if item^.template.quantity > 0 then
            CharHlp.PrintBottomLine(GDVars.currentCharacter^.name + Shop.BUYS_TEXT + item^.name)
          else
            CharHlp.PrintBottomLine(GDVars.currentCharacter^.name + Shop.BUYS_A_TEXT + item^.name)
        end
      end else
        CharHlp.PrintBottomLine(Shop.NOT_ENOUGH_TEXT)
    end
  until done
end;

{ Lists currentCharacter's missile weapons with the price of a clip and of a fill, and sells either; the pool covers
  what the character's credits lack. }
procedure ShopAmmoMenu;
var
  tail: Types.PMenuNode;
  menuItems: Types.PMenuNode;
  weapon: Types.PItemRec;
  weaponIndex: Byte;
  key: Char;
  selectionIndex: Integer;
  done: Boolean;
  weapons: array[0..C_Item.MAX_CARRIED_ITEMS - 1] of Types.PItemRec;
  totalCost: Word;
  { Unused in this version; see the other implementations of this routine. }
  hasBoughtAmmo: Boolean;
  clipCount: Byte;
  amount: Byte;
  baseAmount: Byte;
  info: Types.PItemType;
  priceText: String[40];

  { Sets amount, baseAmount, clipCount and totalCost for weapons[index]: a clip ('C') or a fill ('F') up to capacity. }
  procedure AmmoValues(index: Byte; action: Char);
  begin
    if GDVars.itemTypes[weapons[index]^.template.itemType].weaponClass in Shop.ROUND_AT_A_TIME_CLASSES then begin
      baseAmount := Shop.AREA_AMMO_CAPACITY;
      amount := 1
    end else begin
      amount := Shop.CLIP_ROUNDS;
      baseAmount := Shop.AMMO_CAPACITY
    end;
    if action = 'F' then amount := baseAmount;
    amount := Byte(CharHlp.MinimumWord(amount, baseAmount - weapons[index]^.template.quantity));
    if GDVars.itemTypes[weapons[index]^.template.itemType].weaponClass in Shop.ROUND_AT_A_TIME_CLASSES then
      clipCount := amount
    else
      clipCount := (amount + (Shop.CLIP_ROUNDS - 1)) div Shop.CLIP_ROUNDS;
    totalCost := GDConsts.ammoPrices[weapons[index]^.template.itemType] * clipCount
  end;
begin
  selectionIndex := 0;
  GDVars.menuNeedsRedraw := True;
  done := False;
  repeat
    menuItems := nil;
    weapon := GDVars.currentCharacter^.itemsAddr;
    if weapon = nil then Exit;
    weaponIndex := 0;
    FillChar(weapons, SizeOf(weapons), 0);
    while weapon <> nil do begin
      info := @GDVars.itemTypes[weapon^.template.itemType];
      if (info^.slot = C_Equip.WEAPON) and (info^.weaponClass <> C_WClass.MELEE) and
          (info^.weaponClass <> C_WClass.GRENADE) and
          ((weapon^.template.flags and C_Item.NOT_JOINABLE) <> 0) then begin
        weapons[weaponIndex] := weapon;
        CharHlp.PrintItemString(nil, weapon, 0, 0, False, False);
        AmmoValues(weaponIndex, 'C');
        Str(LongInt(totalCost), priceText);
        TextRend.RightAlignString(priceText, 32 - Length(weapon^.name));
        weapon^.name := weapon^.name + priceText;
        AmmoValues(weaponIndex, 'F');
        Str(LongInt(totalCost), priceText);
        TextRend.RightAlignString(priceText, 6);
        weapon^.name := weapon^.name + priceText;
        if menuItems = nil then begin
          GetMem(menuItems, SizeOf(Types.TMenuNode));
          menuItems^.next := nil;
          menuItems^.menuLabel := 0;
          menuItems^.name := weapon^.name
        end else begin
          tail := menuItems;
          while tail^.next <> nil do tail := tail^.next;
          GetMem(tail^.next, SizeOf(Types.TMenuNode));
          tail := tail^.next;
          tail^.next := nil;
          tail^.menuLabel := 0;
          tail^.name := weapon^.name
        end;
        Inc(weaponIndex)
      end;
      weapon := weapon^.next
    end;
    if menuItems = nil then begin
      CharHlp.PrintBottomLine(GDVars.currentCharacter^.name + ' has no missile weapons');
      Exit
    end;
    Border.DrawWindowFrame(Byte(True));
    tail := menuItems;
    for GDVars.loopIndex := 2 to selectionIndex do tail := tail^.next;
    Shop.DisplayShopMoney;
    TextRend.DisplayString(1, 2, White, Black, 'Weapon');
    TextRend.DisplayString(29, 2, White, Black, 'Clip  Fill');
    GDVars.canClickParty := False;
    key := MenuCore.MenuVertical('', 'Fill Clip', 1, 3, Shop.MENU_LINE_WIDTH, 19, menuItems, True,
                                 GDVars.menuNeedsRedraw, selectionIndex, tail);
    GDVars.canClickParty := True;
    AmmoValues(selectionIndex, key);
    case key of
    { ESCAPE never arrives: MenuVertical answers Escape as NONE }
    C_Keys.NONE, C_Keys.ESCAPE:
      done := True;
    'C', 'F': begin
      if weapons[selectionIndex]^.template.quantity < baseAmount then begin
        if totalCost > GDVars.currentCharacter^.credits then
          if totalCost <= GDVars.currentCharacter^.credits + GDVars.poolCredits then begin
            Dec(GDVars.poolCredits, totalCost - GDVars.currentCharacter^.credits);
            GDVars.currentCharacter^.credits := totalCost
          end;
        if totalCost <= GDVars.currentCharacter^.credits then begin
          hasBoughtAmmo := True;
          Dec(GDVars.currentCharacter^.credits, totalCost);
          if key = 'C' then
            CharHlp.PrintBottomLine(GDVars.currentCharacter^.name + ' purchases a clip')
          else
            CharHlp.PrintBottomLine(GDVars.currentCharacter^.name + '''s weapon is reloaded');
          if weapons[selectionIndex]^.template.quantity < baseAmount then begin
            Inc(weapons[selectionIndex]^.template.quantity, amount);
            if weapons[selectionIndex]^.template.quantity > baseAmount then
              weapons[selectionIndex]^.template.quantity := baseAmount
          end;
          CharHlp.PrintItemString(nil, weapons[selectionIndex], 0, 0, False, False);
          tail^.name := weapons[selectionIndex]^.name
        end else
          CharHlp.PrintBottomLine('Not enough Money')
      end else
        CharHlp.PrintBottomLine('Already full');
      GDVars.menuNeedsRedraw := True
    end
    end;
    while menuItems <> nil do begin
      tail := menuItems^.next;
      FreeMem(menuItems, SizeOf(Types.TMenuNode));
      menuItems := tail
    end
  until done;
  CharHlp.DisplayNoncombatInterface;
  MenuCore.DisplayParty(GDVars.currentCharacter)
end;

procedure ShopMainMenu;
var
  menu: Types.TString40;
  query: String[1];
  done: Boolean;
  key: Char;
  hasMoney: Boolean;
  hasItems: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  hasSold: Byte;
  item: Types.PItemRec;
  { UseItemMenu's combat-turn result; a shop ignores it }
  hasEndedTurn: Boolean;
  oldInterfaceState: Byte;
begin
  oldInterfaceState := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.IN_SHOP;
  GDVars.exploreFrameRedraw := 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.exploreFrameRedraw := 1;
  MenuCore.DisplayParty(GDVars.currentCharacter);
  GDVars.poolCredits := 0;
  query := '';
  GDVars.poolActive := False;
  done := False;
  item := GDVars.availableItems;
  while item <> nil do begin
    CharHlp.PrintItemString(nil, item, 0, 0, False, False);
    item := item^.next
  end;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    menu := 'Buy Sell Ammo View Pool ';
    if hasMoney then menu := menu + 'Take Divvy ';
    menu := menu + 'Exit';
    GDVars.canClickParty := True;
    MenuCore.MenuHorizontal(query, menu, True, False);
    GDVars.canClickParty := False;
    key := GDVars.menuKey;
    case key of
    'A': Shop.ShopAmmoMenu;
    'B': begin
      Shop.ShopBuyMenu;
      CharHlp.DisplayNoncombatInterface;
      MenuCore.DisplayParty(GDVars.currentCharacter)
    end;
    'S': begin
      GDVars.horizChoice := C_Menu.SELL_CHOICE;
      GDVars.menuChecksum := C_Menu.KEEP_MENU_CHOICE;
      ViewChar.UseItemMenu(hasEndedTurn);
      CharHlp.DisplayNoncombatInterface;
      MenuCore.DisplayParty(GDVars.currentCharacter)
    end;
    'V': begin
      ViewChar.ViewCharMenu(GDVars.extFlag);
      CharHlp.DisplayNoncombatInterface;
      MenuCore.DisplayParty(GDVars.currentCharacter)
    end;
    'T': begin
      Money.TakeMoneyMenu;
      TextRend.ClearRect(C_Msg.MESSAGE_LEFT, C_Msg.MESSAGE_TOP, C_Msg.MESSAGE_RIGHT, C_Msg.MESSAGE_BOTTOM)
    end;
    { two roles: the menu's Pool letter, or with extFlag set C_Keys.DOWN ($50, 'P'), which SelectPrevNextChar takes as
      next }
    'P': if not GDVars.extFlag then
      Money.PoolMoney
    else begin
      CharHlp.DisplayRoster(GDVars.currentCharacter, False);
      ViewChar.SelectPrevNextChar(key);
      CharHlp.DisplayRoster(GDVars.currentCharacter, True)
    end;
    'D': Money.ShareMoney;
    'E': begin
      Money.DetermineTreasure(hasMoney, hasItems);
      if hasMoney then begin
        TextRend.DisplayMessageWindow(C_Msg.MESSAGE_LEFT, C_Msg.MESSAGE_TOP, C_Msg.MESSAGE_RIGHT, C_Msg.MESSAGE_BOTTOM,
          LightGreen, Black, True,
          'As you Leave the Shopkeeper says, "Excuse me but you have Left Some Money here."  ');
        TextRend.DisplayMessageWindow(C_Msg.MESSAGE_LEFT, C_Msg.MESSAGE_TOP, C_Msg.MESSAGE_RIGHT, C_Msg.MESSAGE_BOTTOM,
                                      White, Black, False,
                                      'Do you want to go back and get your Money?');
        if MenuCore.YesNoMenu(query, C_Menu.DEFAULT_YES) = 'N' then begin
          done := True;
          TextRend.DisplayMessageWindow(C_Msg.MESSAGE_LEFT, C_Msg.MESSAGE_TOP, C_Msg.MESSAGE_RIGHT,
                                        C_Msg.MESSAGE_BOTTOM, White, Black, True,
                                        'Thanks for the tip.  Have a nice day.');
          TextRend.PauseOnly
        end else
          TextRend.ClearRect(C_Msg.MESSAGE_LEFT, C_Msg.MESSAGE_TOP, C_Msg.MESSAGE_RIGHT, C_Msg.MESSAGE_BOTTOM)
      end else
        done := True
    end;
    C_Keys.UP: begin
      CharHlp.DisplayRoster(GDVars.currentCharacter, False);
      ViewChar.SelectPrevNextChar(key);
      CharHlp.DisplayRoster(GDVars.currentCharacter, True)
    end
    end
  until done;
  GDVars.interfaceState := oldInterfaceState
end;

begin
end.
