

local BJ = {}
BJ.money = 100
BJ.bet = 0
BJ.deck = {}
BJ.player = {}
BJ.dealer = {}
BJ.inRound = false
BJ.borrowCount = 0

-- SavedVariables initialization (runs on ADDON_LOADED)
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- placeholder for UI update function (set after UI is created)
local updateUI = function() end

frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Blackjack" then
        BlackjackDB = BlackjackDB or { money = 100, borrowCount = 0 }
        BJ.money = BlackjackDB.money or 100
        BJ.borrowCount = BlackjackDB.borrowCount or 0

        -- Create simple movable window for the game
        local ui = CreateFrame("Frame", "BlackjackFrame", UIParent, "BasicFrameTemplateWithInset")
        ui:SetSize(260, 120)
        ui:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        ui:SetMovable(true)
        ui:EnableMouse(true)
        ui:RegisterForDrag("LeftButton")
        ui:SetScript("OnDragStart", ui.StartMoving)
        ui:SetScript("OnDragStop", ui.StopMovingOrSizing)

        ui.title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ui.title:SetPoint("TOP", ui, "TOP", 0, -6)
        ui.title:SetText("Blackjack")

        ui.status = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ui.status:SetPoint("TOPLEFT", ui, "TOPLEFT", 10, -30)
        ui.status:SetJustifyH("LEFT")
        ui.status:SetText("Money: $" .. BJ.money)

        -- Hit button
        local hitBtn = CreateFrame("Button", "BlackjackHitButton", ui, "UIPanelButtonTemplate")
        hitBtn:SetSize(100, 24)
        hitBtn:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 12, 10)
        hitBtn:SetText("Hit")
        hitBtn:SetScript("OnClick", function()
            -- call existing command handler
            if BJ.inRound then
                cmd_hit()
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[Blackjack]|r No active round. Use /bj start <bet>")
            end
        end)

        -- Stand button
        local standBtn = CreateFrame("Button", "BlackjackStandButton", ui, "UIPanelButtonTemplate")
        standBtn:SetSize(100, 24)
        standBtn:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -12, 10)
        standBtn:SetText("Stand")
        standBtn:SetScript("OnClick", function()
            if BJ.inRound then
                cmd_stand()
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[Blackjack]|r No active round. Use /bj start <bet>")
            end
        end)

        -- Make buttons accessible from outer scope through closure capture
        ui.hitBtn = hitBtn
        ui.standBtn = standBtn

        -- Update function to refresh UI text and button visibility
        updateUI = function()
            ui.status:SetText("Money: $" .. BJ.money .. "  Borrowed: " .. (BJ.borrowCount or 0))
            if BJ.inRound then
                ui.hitBtn:Show()
                ui.standBtn:Show()
                ui:Show()
            else
                -- hide buttons when not in a round, keep window visible so player can see money
                ui.hitBtn:Hide()
                ui.standBtn:Hide()
                ui:Show()
            end
        end

        -- initial UI update
        updateUI()
    end
end)

math.randomseed(time())

local function saveState()
    BlackjackDB = BlackjackDB or {}
    BlackjackDB.money = BJ.money
    BlackjackDB.borrowCount = BJ.borrowCount
end

local function printmsg(...)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[Blackjack]|r " .. table.concat({...}, " "))
end

local suits = {"H","D","C","S"}
local ranks = {"2","3","4","5","6","7","8","9","10","J","Q","K","A"}

local function createDeck()
    local d = {}
    for _,s in ipairs(suits) do
        for _,r in ipairs(ranks) do
            table.insert(d, {rank = r, suit = s})
        end
    end
    -- Fisher-Yates shuffle
    for i = #d, 2, -1 do
        local j = math.random(i)
        d[i], d[j] = d[j], d[i]
    end
    return d
end

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

local function cardToString(c)
    return c.rank .. c.suit
end

local function showHands(hideDealerFirst)
    local pstr = {}
    for _,c in ipairs(BJ.player) do table.insert(pstr, cardToString(c)) end
    printmsg("Player ("..handValue(BJ.player).."): " .. table.concat(pstr, " "))

    local dstr = {}
    for i,c in ipairs(BJ.dealer) do
        if i == 1 and hideDealerFirst then
            table.insert(dstr, "??")
        else
            table.insert(dstr, cardToString(c))
        end
    end
    local dealerVal = hideDealerFirst and "??" or tostring(handValue(BJ.dealer))
    printmsg("Dealer ("..dealerVal.."): " .. table.concat(dstr, " "))
end

local function endRound(result)
    if result == "player_bust" then
        BJ.money = BJ.money - BJ.bet
        printmsg("Bust! You lost $"..BJ.bet..". Money: $"..BJ.money)
    elseif result == "dealer_bust" or result == "player_win" then
        BJ.money = BJ.money + BJ.bet
        printmsg("You won $"..BJ.bet.."! Money: $"..BJ.money)
    elseif result == "blackjack" then
        local payout = math.floor(BJ.bet * 1.5 + 0.5)
        BJ.money = BJ.money + payout
        printmsg("Blackjack! You won $"..payout.." (3:2). Money: $"..BJ.money)
    elseif result == "dealer_win" then
        BJ.money = BJ.money - BJ.bet
        printmsg("You lost $"..BJ.bet..". Money: $"..BJ.money)
    elseif result == "push" then
        printmsg("Push. Bet returned. Money: $"..BJ.money)
    end

    -- Save money and borrow count
    saveState()

    BJ.inRound = false
    BJ.bet = 0

    if updateUI then updateUI() end

    if BJ.money <= 0 then
        printmsg("You are out of money. Use /bj borrow to borrow $100 (counts saved).")
    end
end

local function dealerPlay()
    showHands(false)
    while handValue(BJ.dealer) < 17 do
        table.insert(BJ.dealer, table.remove(BJ.deck))
        printmsg("Dealer hits.")
        showHands(false)
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
    end
    if dVal == 21 and pVal ~= 21 then
        showHands(false)
        endRound("dealer_win")
        return true
    end
    return false
end

-- Public command handlers
local function cmd_start(arg)
    local bet = tonumber(arg)
    if not bet or bet < 1 or bet > BJ.money then
        printmsg("Invalid bet. Use /bj start <bet>. You have $"..BJ.money)
        return
    end
    BJ.bet = bet
    BJ.deck = createDeck()
    BJ.player = {}
    BJ.dealer = {}
    -- deal
    table.insert(BJ.player, table.remove(BJ.deck))
    table.insert(BJ.dealer, table.remove(BJ.deck))
    table.insert(BJ.player, table.remove(BJ.deck))
    table.insert(BJ.dealer, table.remove(BJ.deck))
    BJ.inRound = true

    printmsg("Round started. Bet: $"..BJ.bet)
    showHands(true)

    if updateUI then updateUI() end

    if not checkImmediateResults() then
        printmsg("Use /bj hit or /bj stand (or use the buttons).")
    end
end

local function cmd_hit()
    if not BJ.inRound then printmsg("No active round. Start one with /bj start <bet>") return end
    table.insert(BJ.player, table.remove(BJ.deck))
    showHands(true)
    local pVal = handValue(BJ.player)
    if pVal > 21 then
        showHands(false)
        endRound("player_bust")
    elseif pVal == 21 then
        printmsg("21! Standing automatically.")
        dealerPlay()
    end
    if updateUI then updateUI() end
end

local function cmd_stand()
    if not BJ.inRound then printmsg("No active round. Start one with /bj start <bet>") return end
    dealerPlay()
    if updateUI then updateUI() end
end

local function cmd_borrow()
    if BJ.money > 0 then
        printmsg("You still have $"..BJ.money..". Borrow only when you are out of money.")
        return
    end
    BJ.money = BJ.money + 100
    BJ.borrowCount = (BJ.borrowCount or 0) + 1
    saveState()
    if updateUI then updateUI() end
    printmsg("You borrowed $100. Times borrowed: "..BJ.borrowCount..". Money: $"..BJ.money)
end

local function cmd_status()
    printmsg("Money: $"..BJ.money)
    printmsg("Times borrowed: "..(BJ.borrowCount or 0))
    if BJ.inRound then
        showHands(true)
    else
        printmsg("No active round.")
    end
end

local function cmd_help()
    printmsg("Commands:")
    printmsg("/bj help - this")
    printmsg("/bj start <bet> - start a round")
    printmsg("/bj hit - take a card")
    printmsg("/bj stand - end your turn")
    printmsg("/bj status - show money, borrow count and hands")
    printmsg("/bj borrow - borrow $100 if you are out of money (increments saved borrow count)")
end

-- Slash command wiring
SLASH_BLACKJACK1 = "/blackjack"
SLASH_BLACKJACK2 = "/bj"
SlashCmdList["BLACKJACK"] = function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "start" then
        cmd_start(rest)
    elseif cmd == "hit" then
        cmd_hit()
    elseif cmd == "stand" then
        cmd_stand()
    elseif cmd == "status" then
        cmd_status()
    elseif cmd == "borrow" then
        cmd_borrow()
    elseif cmd == "help" or cmd == "" then
        cmd_help()
    else
        printmsg("Unknown command. Use /bj help")
    end
end