-- Blackjack.lua (enhanced windowed UI)

local BJ = {}
BJ.money = 100
BJ.borrowCount = 0
BJ.bet = 0
BJ.deck = {}
BJ.player = {}
BJ.dealer = {}
BJ.inRound = false
BJ.revealed = false -- whether dealer’s hand is revealed

-- UI handles (filled in after ADDON_LOADED)
local ui, title, moneyText, borrowText, betBox, startBtn, hitBtn, standBtn, borrowBtn, closeBtn
local playerLabel, playerCardsText, dealerLabel, dealerCardsText, statusText

-- === Persistence ===
local function saveState()
  BlackjackDB = BlackjackDB or {}
  BlackjackDB.money = BJ.money
  BlackjackDB.borrowCount = BJ.borrowCount
  -- Optional: save window position (uncomment below + see OnShow/OnHide comment)
  -- local point, relTo, relPoint, xOfs, yOfs = ui:GetPoint(1)
  -- BlackjackDB.uiPoint = {point, relPoint, xOfs, yOfs}
end
-- === Cards/Scoring ===
local function cardValue(card)
  if card.rank == "J" or card.rank == "Q" or card.rank == "K" then return 10 end
  if card.rank == "A" then return 11 end
  return tonumber(card.rank) or 0
end
local function handValue(hand)
  local value, aces = 0, 0
  for _,c in ipairs(hand) do
    value = value + cardValue(c)
    if c.rank == "A" then aces = aces + 1 end
  end
  while value > 21 and aces > 0 do
    value = value - 10
    aces = aces - 1
  end
  return value
end

-- Colored suit Letter + rank
local function suitSymbol(s)
  if s == 'H' then return '|cffff4040H|r' end  -- Hearts: red H
  if s == 'D' then return '|cffff4040D|r' end  -- Diamonds: red D
  if s == 'C' then return '|cffffffffC|r' end  -- Clubs: white C
  if s == 'S' then return '|cff80b0ffS|r' end  -- Spades: blue S
  return s or ''
end
local function cardToString(c)
  return tostring(c.rank) .. suitSymbol(c.suit)
end


local function cardToString(c)
  return tostring(c.rank) .. suitSymbol(c.suit)
end


local function createDeck()
  local suits = {"H","D","C","S"}
  local ranks = {"2","3","4","5","6","7","8","9","10","J","Q","K","A"}
  local d = {}
  for _,s in ipairs(suits) do
    for _,r in ipairs(ranks) do
      table.insert(d, {rank = r, suit = s})
    end
  end
  for i = #d, 2, -1 do
    local j = math.random(i)
    d[i], d[j] = d[j], d[i]
  end
  return d
end

-- === UI: helpers ===
local function handsToText(hideDealerFirst)
  local p = {}
  for _,c in ipairs(BJ.player) do table.insert(p, cardToString(c)) end
  local d = {}
  for i,c in ipairs(BJ.dealer) do
    if i == 1 and hideDealerFirst then table.insert(d, "??") else table.insert(d, cardToString(c)) end
  end
  local pVal = handValue(BJ.player)
  local dVal = hideDealerFirst and "??" or tostring(handValue(BJ.dealer))
  return p, pVal, d, dVal
end

local function setStatus(msg)
  if statusText then statusText:SetText(msg or "") end
end

local function updateButtons()
  if not ui then return end
  local inRound = BJ.inRound
  startBtn:SetEnabled(not inRound and BJ.money > 0)
  hitBtn:SetEnabled(inRound)
  standBtn:SetEnabled(inRound)
  borrowBtn:SetEnabled(BJ.money <= 0 and not inRound)
end

local function updateMoneyBorrow()
  if moneyText then moneyText:SetText("Money: $" .. BJ.money) end
  if borrowText then borrowText:SetText("Borrowed: " .. BJ.borrowCount) end
end

local function updateHandsUI()
  if not ui then return end
  local hideDealer = BJ.inRound and not BJ.revealed
  local p, pVal, d, dVal = handsToText(hideDealer)
  playerCardsText:SetText(table.concat(p, " "))
  playerLabel:SetText(("Player (%s)"):format(pVal))
  dealerCardsText:SetText(table.concat(d, " "))
  dealerLabel:SetText(("Dealer (%s)"):format(dVal))
end

local function fullUIUpdate(statusMsg)
  updateMoneyBorrow()
  updateHandsUI()
  updateButtons()
  if statusMsg then setStatus(statusMsg) end
end

-- === Flow helpers ===
local function endRound(result)
  local msg
  if result == "player_bust" then
    BJ.money = BJ.money - BJ.bet
    msg = ("Bust! You lost $%d."):format(BJ.bet)
  elseif result == "dealer_bust" or result == "player_win" then
    BJ.money = BJ.money + BJ.bet
    msg = ("You won $%d!"):format(BJ.bet)
  elseif result == "blackjack" then
    local payout = math.floor(BJ.bet * 1.5 + 0.5)
    BJ.money = BJ.money + payout
    msg = ("Blackjack! You won $%d (3:2)."):format(payout)
  elseif result == "dealer_win" then
    BJ.money = BJ.money - BJ.bet
    msg = ("You lost $%d."):format(BJ.bet)
  elseif result == "push" then
    msg = "Push. Bet returned."
  end

  saveState()
  BJ.inRound = false
  BJ.bet = 0
  BJ.revealed = true -- show dealer hand

  -- Chat log (keep feedback)
  if msg then print("|cffffff00[Blackjack]|r " .. msg .. " Money: $" .. BJ.money) end

  if BJ.money <= 0 then
    print("|cffffff00[Blackjack]|r You are out of money. Use /bj borrow to borrow $100.")
  end

  fullUIUpdate(msg and (msg .. " Money: $" .. BJ.money) or nil)
end

local function dealerPlay()
  BJ.revealed = true
  updateHandsUI()

  while handValue(BJ.dealer) < 17 do
    table.insert(BJ.dealer, table.remove(BJ.deck))
    setStatus("Dealer hits…")
    updateHandsUI()
  end

  local pScore = handValue(BJ.player)
  local dScore = handValue(BJ.dealer)
  if dScore > 21 then
    endRound("dealer_bust")
  elseif dScore > pScore then
    endRound("dealer_win")
  elseif dScore < pScore then
    endRound("player_win")
  else
    endRound("push")
  end
end

local function checkImmediateResults()
  local pVal = handValue(BJ.player)
  local dVal = handValue(BJ.dealer)
  if pVal == 21 and dVal ~= 21 then
    endRound("blackjack")
    return true
  elseif dVal == 21 and pVal ~= 21 then
    BJ.revealed = true
    updateHandsUI()
    endRound("dealer_win")
    return true
  end
  return false
end

-- === Slash-command handlers ===
local function cmd_start(arg)
  local bet = tonumber(arg)
  if not bet or bet < 1 or bet > BJ.money then
    local m = "|cffffff00[Blackjack]|r Invalid bet. You have $" .. BJ.money
    print(m)
    setStatus("Invalid bet. You have $" .. BJ.money)
    return
  end

  BJ.bet = bet
  BJ.deck = createDeck()
  BJ.player = {}
  BJ.dealer = {}
  table.insert(BJ.player, table.remove(BJ.deck))
  table.insert(BJ.dealer, table.remove(BJ.deck))
  table.insert(BJ.player, table.remove(BJ.deck))
  table.insert(BJ.dealer, table.remove(BJ.deck))
  BJ.inRound = true
  BJ.revealed = false

  print("|cffffff00[Blackjack]|r Round started. Bet: $" .. BJ.bet)
  fullUIUpdate(("Round started. Bet: $%d"):format(BJ.bet))

  if not checkImmediateResults() then
    setStatus("Use Hit or Stand.")
    updateButtons()
  end
end

local function cmd_hit()
  if not BJ.inRound then
    print("|cffffff00[Blackjack]|r No active round.")
    setStatus("No active round.")
    return
  end

  table.insert(BJ.player, table.remove(BJ.deck))
  updateHandsUI()

  local pVal = handValue(BJ.player)
  if pVal > 21 then
    BJ.revealed = true
    updateHandsUI()
    endRound("player_bust")
  elseif pVal == 21 then
    setStatus("21! Standing automatically.")
    dealerPlay()
  else
    setStatus("You drew. Hit or Stand?")
  end
end
local function cmd_stand()
  if not BJ.inRound then
    print("|cffffff00[Blackjack]|r No active round.")
    setStatus("No active round.")
    return
  end
  dealerPlay()
end

local function cmd_borrow()
  if BJ.money > 0 then
    print("|cffffff00[Blackjack]|r You still have $"..BJ.money..". Borrow only when out of money.")
    setStatus("You still have money. Borrow only when at $0.")
    return
  end
  BJ.money = BJ.money + 100
  BJ.borrowCount = BJ.borrowCount + 1
  saveState()
  local msg = "You borrowed $100. Times borrowed: "..BJ.borrowCount..". Money: $"..BJ.money
  print("|cffffff00[Blackjack]|r " .. msg)
  fullUIUpdate(msg)
end

local function cmd_help()
  print("|cffffff00[Blackjack]|r Commands:")
  print("/bj start <bet> - Start a round")
  print("/bj hit - Take a card")
  print("/bj stand - End your turn")
  print("/bj borrow - Borrow $100 if out of money")
  print("/bj help - Show this help")
end

-- === Slash registration ===
SLASH_BLACKJACK1 = "/bj"
SlashCmdList["BLACKJACK"] = function(msg)
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "start" then cmd_start(rest)
  elseif cmd == "hit" then cmd_hit()
  elseif cmd == "stand" then cmd_stand()
  elseif cmd == "borrow" then cmd_borrow()
  else cmd_help() end
end
-- === UI construction ===
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
  if name ~= "Blackjack" then return end

  -- Load saved variables
  BlackjackDB = BlackjackDB or { money = 100, borrowCount = 0 }
  BJ.money = BlackjackDB.money or 100
  BJ.borrowCount = BlackjackDB.borrowCount or 0

  -- Frame
  ui = CreateFrame("Frame", "BlackjackFrame", UIParent, "BackdropTemplate")
  ui:SetSize(360, 280)
  ui:SetPoint("CENTER")
  ui:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = nil, tile = true, tileSize = 16 })
  ui:SetBackdropColor(0, 0, 0, 0.85)
  ui:Hide()

  ui:EnableMouse(true)
  ui:SetMovable(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", function()
    ui:StopMovingOrSizing()
    -- Optional: persist position (uncomment with saving above)
    -- local point, relTo, relPoint, xOfs, yOfs = ui:GetPoint(1)
    -- BlackjackDB.uiPoint = {point, relPoint, xOfs, yOfs}
  end)

  -- Close button
  closeBtn = CreateFrame("Button", nil, ui, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", 0, 0)

  -- Title
  title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Blackjack")

  -- Money/Borrow
  moneyText = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  moneyText:SetPoint("TOPLEFT", 12, -36)

  borrowText = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  borrowText:SetPoint("TOPLEFT", 12, -56)

  -- Bet controls
  local betLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  betLabel:SetPoint("TOPLEFT", 12, -82)
  betLabel:SetText("Bet:")

  betBox = CreateFrame("EditBox", nil, ui, "InputBoxTemplate")
  betBox:SetSize(70, 22)
  betBox:SetPoint("LEFT", betLabel, "RIGHT", 6, 0)
  betBox:SetAutoFocus(false)
  betBox:SetNumeric(true)
  betBox:SetNumber(10)
  betBox:SetScript("OnEnterPressed", function() cmd_start(betBox:GetText()); betBox:ClearFocus() end)

  startBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
  startBtn:SetSize(70, 22)
  startBtn:SetPoint("LEFT", betBox, "RIGHT", 8, 0)
  startBtn:SetText("Start")
  startBtn:SetScript("OnClick", function() cmd_start(betBox:GetText()) end)

  borrowBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
  borrowBtn:SetSize(90, 22)
  borrowBtn:SetPoint("LEFT", startBtn, "RIGHT", 8, 0)
  borrowBtn:SetText("Borrow $100")
  borrowBtn:SetScript("OnClick", function() cmd_borrow() end)

  -- Player / Dealer areas
  playerLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  playerLabel:SetPoint("TOPLEFT", 12, -116)
  playerLabel:SetText("Player")

  playerCardsText = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  playerCardsText:SetPoint("TOPLEFT", 12, -136)
  playerCardsText:SetJustifyH("LEFT")

  dealerLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  dealerLabel:SetPoint("TOPLEFT", 12, -164)
  dealerLabel:SetText("Dealer")

  dealerCardsText = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  dealerCardsText:SetPoint("TOPLEFT", 12, -184)
  dealerCardsText:SetJustifyH("LEFT")

  -- Status line
  statusText = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  statusText:SetPoint("BOTTOMLEFT", 12, 70)
  statusText:SetPoint("RIGHT", -12, 70)
  statusText:SetJustifyH("LEFT")

-- Action buttons
hitBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
hitBtn:SetSize(70, 22)
hitBtn:SetText("Hit")
hitBtn:ClearAllPoints()
hitBtn:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 12, 8)
hitBtn:SetScript("OnClick", function() cmd_hit() end)

standBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
standBtn:SetSize(70, 22)
standBtn:SetText("Stand")
standBtn:ClearAllPoints()
-- Same baseline, explicit X (12 left padding + 70 width + 8 gap = 90)
standBtn:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 12 + 70 + 8, 8)
standBtn:SetScript("OnClick", function() cmd_stand() end)


  -- Initialize UI
  fullUIUpdate("Welcome! Set a bet and press Start.")

  -- Slash to show/hide (toggle)
  SLASH_BLACKJACKUI1 = "/bjui"
  SlashCmdList["BLACKJACKUI"] = function()
    if ui:IsShown() then ui:Hide() else
      -- Optional: restore saved position
      -- if BlackjackDB.uiPoint then ui:ClearAllPoints(); ui:SetPoint(BlackjackDB.uiPoint[1], UIParent, BlackjackDB.uiPoint[2], BlackjackDB.uiPoint[3], BlackjackDB.uiPoint[4]) end
      ui:Show()
      fullUIUpdate()
    end
  end
end)