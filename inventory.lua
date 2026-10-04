-- ============================================================
--    JARVIS OS v2.3 - PLAYER DETECTOR & DYNAMIC TARGETING
--    CC:Tweaked + Advanced Peripherals
--    Fixed Chat/PM/Toast | Player Detector Scan | Target Toggle
-- ============================================================

local monitor = peripheral.find("monitor")
if not monitor then
    error("Touchscreen Monitor not found! Attach a monitor to the computer.")
end

monitor.setTextScale(0.5)
local mWidth, mHeight = monitor.getSize()

-- Color Palette
local cBg          = colors.black
local cHeaderBg    = colors.green
local cHeaderFg    = colors.black
local cCardBg      = colors.gray
local cTextPrimary = colors.white
local cTextSec     = colors.lightGray
local cActive      = colors.lime
local cInactive    = colors.gray
local cWarn        = colors.orange
local cFail        = colors.red
local cSuccess     = colors.lime

-- Global State
local currentApp = "BOOT" -- "BOOT", "MAIN_MENU", "INVENTORY", "CHAT_HACKER", "RADAR"
local buttons = {}

-- Inventory Manager State
local managers = {}
local connectedStorages = {}
local selectedSourceIdx = 1
local selectedTargetIdx = 2
local playerPage = 1
local currentTab = "EXPORT"
local currentScope = "ALL"
local currentPage = 1
local cachedItemList = {}

-- Chat Hacker State
local targetMode = "ALL" -- "ALL" or "SINGLE"
local selectedTargetPlayer = nil
local chatMessageInput = "BLUE TEAM BEST!!!"
local statusHackerMsg = "System operational."
local chatBoxPeripheral = peripheral.find("chatBox") or peripheral.find("chat_box")
local playerDetectorPeripheral = peripheral.find("playerDetector") or peripheral.find("player_detector")
local allServerPlayers = {}
local playerListScroll = 1

------------------------------------------------------------
-- HELPER FUNCTIONS & UI CREATION
------------------------------------------------------------
local function clearButtons() buttons = {} end

local function addBtn(x1, y1, x2, y2, label, bg, fg, callback)
    table.insert(buttons, { x1 = x1, y1 = y1, x2 = x2, y2 = y2, cb = callback })
    monitor.setBackgroundColor(bg)
    monitor.setTextColor(fg)
    for y = y1, y2 do
        monitor.setCursorPos(x1, y)
        monitor.write(string.rep(" ", x2 - x1 + 1))
    end
    local lx = math.floor(x1 + (x2 - x1 + 1 - #label) / 2)
    local ly = math.floor(y1 + (y2 - y1) / 2)
    monitor.setCursorPos(lx, ly)
    monitor.write(label)
end

local function drawHeader(title)
    monitor.setBackgroundColor(cHeaderBg)
    monitor.setTextColor(cHeaderFg)
    monitor.setCursorPos(1, 1)
    monitor.clearLine()
    monitor.write(" JARVIS OS :: " .. title)
    
    if currentApp ~= "MAIN_MENU" and currentApp ~= "BOOT" then
        addBtn(mWidth - 10, 1, mWidth, 1, "[ MENU ]", colors.lime, colors.black, function()
            currentApp = "MAIN_MENU"
        end)
    end
end

------------------------------------------------------------
-- ADVANCED PLAYER SCANNER (PLAYER DETECTOR + CHATBOX)
------------------------------------------------------------
local function fetchAllPlayers()
    allServerPlayers = {}
    local added = {}

    -- 1. Scan via Player Detector Peripheral (Primary)
    if playerDetectorPeripheral then
        local pList = nil
        if playerDetectorPeripheral.getOnlinePlayers then
            pcall(function() pList = playerDetectorPeripheral.getOnlinePlayers() end)
        elseif playerDetectorPeripheral.getPlayers then
            pcall(function() pList = playerDetectorPeripheral.getPlayers() end)
        end

        if type(pList) == "table" then
            for _, p in ipairs(pList) do
                local name = type(p) == "table" and (p.name or p.username) or tostring(p)
                if name and name ~= "" and not added[name] then
                    table.insert(allServerPlayers, name)
                    added[name] = true
                end
            end
        end
    end

    -- 2. Scan via ChatBox (Fallback / Merge)
    if chatBoxPeripheral and chatBoxPeripheral.getPlayers then
        local ok, pList = pcall(chatBoxPeripheral.getPlayers)
        if ok and type(pList) == "table" then
            for _, p in ipairs(pList) do
                local name = type(p) == "table" and (p.name or p.username) or tostring(p)
                if name and name ~= "" and not added[name] then
                    table.insert(allServerPlayers, name)
                    added[name] = true
                end
            end
        end
    end

    -- 3. Merge Inventory Managers Owners
    for _, mgr in ipairs(managers) do
        if mgr.owner and not added[mgr.owner] then
            table.insert(allServerPlayers, mgr.owner)
            added[mgr.owner] = true
        end
    end

    if #allServerPlayers == 0 then
        table.insert(allServerPlayers, "No Players Found")
    end
end

------------------------------------------------------------
-- 1. MATRIX BOOT ANIMATION
------------------------------------------------------------
local function runBootAnimation()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    local chars = { "0", "1", "X", "Y", "Z", "#", "$", "%", "&", "*", "A", "B", "C" }
    local columns = {}
    for i = 1, mWidth do columns[i] = math.random(-10, 0) end

    for frame = 1, 25 do
        for x = 1, mWidth do
            local y = columns[x]
            if y >= 1 and y <= mHeight then
                monitor.setCursorPos(x, y)
                monitor.setTextColor(colors.lime)
                monitor.write(chars[math.random(1, #chars)])
            end
            if y - 1 >= 1 and y - 1 <= mHeight then
                monitor.setCursorPos(x, y - 1)
                monitor.setTextColor(colors.green)
                monitor.write(chars[math.random(1, #chars)])
            end
            if y - 4 >= 1 and y - 4 <= mHeight then
                monitor.setCursorPos(x, y - 4)
                monitor.write(" ")
            end
            columns[x] = columns[x] + 1
            if columns[x] > mHeight + 5 then columns[x] = math.random(-5, 0) end
        end
        sleep(0.04)
    end

    monitor.clear()
    local banner = {
        "   _  ___  ____ _   _______ ____ ",
        "  / |/ / \\/ / // / / / / _ / __/ ",
        " /    /\\  / _  / /_/ / __/\\ \\  ",
        "/_/_/  /_/_//_/ \\____/_/ /___/ "
    }
    
    local startY = math.floor((mHeight - #banner) / 2)
    for i, line in ipairs(banner) do
        local startX = math.floor((mWidth - #line) / 2)
        monitor.setCursorPos(startX, startY + i - 1)
        monitor.setTextColor(colors.lime)
        monitor.write(line)
    end

    monitor.setCursorPos(math.floor((mWidth - 22) / 2), startY + #banner + 2)
    monitor.setTextColor(colors.white)
    monitor.write("INITIALIZING SYSTEM...")
    sleep(0.8)
    currentApp = "MAIN_MENU"
end

------------------------------------------------------------
-- 2. MAIN MENU
------------------------------------------------------------
local function drawMainMenu()
    clearButtons()
    monitor.setBackgroundColor(cBg)
    monitor.clear()

    local logo = {
        " ____  ____     _   ______   ___  _   _   ___ ",
        "(  _ \\(  _ \\   / ) (   _  ) (  _)( ) ( ) (  _)",
        " )___/ )   /  / /   )   _/  _) \\  \\_/ /  _) \\ ",
        "(__)  (_)\\_) (_/   (___\\_) (____)  (_)  (____)"
    }

    monitor.setTextColor(cActive)
    for i, line in ipairs(logo) do
        monitor.setCursorPos(math.floor((mWidth - #line) / 2), 2 + i)
        monitor.write(line)
    end

    monitor.setCursorPos(math.floor((mWidth - 32) / 2), 10)
    monitor.setTextColor(cTextSec)
    monitor.write("=== INTELLIGENT OPERATING SYSTEM ===")

    local btnW = 32
    local startX = math.floor((mWidth - btnW) / 2)

    addBtn(startX, 12, startX + btnW - 1, 14, "MATRIX INVENTORY", cCardBg, cActive, function()
        currentApp = "INVENTORY"
    end)

    addBtn(startX, 16, startX + btnW - 1, 18, "CHAT HACKER", cCardBg, cWarn, function()
        fetchAllPlayers()
        currentApp = "CHAT_HACKER"
    end)

    addBtn(startX, 20, startX + btnW - 1, 22, "NEO RADAR", cCardBg, cInactive, function()
        currentApp = "RADAR"
    end)

    monitor.setCursorPos(2, mHeight)
    monitor.setTextColor(cInactive)
    monitor.write("SYSTEM STATUS: ONLINE")
end

------------------------------------------------------------
-- 3. APP: MATRIX INVENTORY
------------------------------------------------------------
local SCAN_DIRECTIONS = { "up", "down", "north", "south", "east", "west", "top", "bottom" }

local function detectChestDirection(mgrObj)
    for _, dir in ipairs(SCAN_DIRECTIONS) do
        local ok, size = pcall(function() return mgrObj.getContainerSize(dir) end)
        if ok and type(size) == "number" and size > 0 then return dir end
    end
    return "up"
end

local function scanPeripherals()
    managers = {}
    connectedStorages = {}
    local names = peripheral.getNames()

    for _, name in ipairs(names) do
        local pType = peripheral.getType(name) or ""
        if pType == "inventory_manager" or pType == "inventoryManager" then
            local obj = peripheral.wrap(name)
            local owner = nil
            pcall(function() if obj.getOwner then owner = obj.getOwner() end end)
            if owner and owner ~= "" then
                table.insert(managers, { id = name, obj = obj, owner = owner, chestDir = detectChestDirection(obj) })
            end
        elseif string.find(pType, "chest") or string.find(pType, "barrel") or string.find(pType, "shulker") or string.find(pType, "storage") then
            local obj = peripheral.wrap(name)
            if obj then table.insert(connectedStorages, { id = name, obj = obj }) end
        end
    end

    if #managers > 0 then
        if selectedSourceIdx > #managers then selectedSourceIdx = 1 end
        if selectedTargetIdx > #managers then selectedTargetIdx = math.min(2, #managers) end
    end
end

local function toNum(v) return tonumber(v) or 0 end

local function isSlotInScope(slotNum, scope)
    if scope == "ALL" then return true end
    if scope == "HOTBAR" then return slotNum >= 0 and slotNum <= 8 end
    if scope == "MAIN" then return slotNum >= 9 and slotNum <= 35 end
    if scope == "ARMOR" then return (slotNum >= 36 and slotNum <= 39) or (slotNum >= 100 and slotNum <= 103) end
    if scope == "OFFHAND" then return slotNum == 40 or slotNum == 104 or slotNum == 150 end
    return false
end

local function getItemSlotLabel(slotNum)
    if (slotNum >= 36 and slotNum <= 39) or (slotNum >= 100 and slotNum <= 103) then return "[ARMOR]"
    elseif slotNum == 40 or slotNum == 104 then return "[OFFH]"
    elseif slotNum >= 0 and slotNum <= 8 then return "[HOTB]"
    else return "[MAIN]" end
end

local function exportPlayerToChest(mgr, slotNum, count, itemName)
    local dir = mgr.chestDir or "up"
    local ok, res = pcall(function() return mgr.obj.removeItemFromPlayer(dir, { fromSlot = slotNum, count = count }) end)
    if ok and type(res) == "number" and res > 0 then return res end
    if itemName and itemName ~= "" then
        ok, res = pcall(function() return mgr.obj.removeItemFromPlayer(dir, { name = itemName, count = count }) end)
        if ok and type(res) == "number" and res > 0 then return res end
    end
    return 0
end

local function refreshItems()
    cachedItemList = {}
    if #managers == 0 then return end

    if currentTab == "EXPORT" or currentTab == "TRANSFER" then
        local mgr = managers[selectedSourceIdx]
        if not mgr then return end

        local ok, res = pcall(function() return mgr.obj.getItems() end)
        if ok and type(res) == "table" then
            for slotKey, item in pairs(res) do
                if type(item) == "table" and item.count and item.count > 0 then
                    local sNum = toNum(item.slot or item.slotNumber or slotKey)
                    if isSlotInScope(sNum, currentScope) then
                        table.insert(cachedItemList, {
                            slot = sNum, name = item.name, displayName = item.displayName or item.name, count = item.count
                        })
                    end
                end
            end
        end
    end
end

local function drawInventoryApp(statusMessage, statusColor)
    clearButtons()
    monitor.setBackgroundColor(cBg)
    monitor.clear()
    drawHeader("INVENTORY MATRIX")

    local tabs = { "EXPORT", "IMPORT", "TRANSFER" }
    local tabWidth = math.floor((mWidth - 2) / 3)
    for i, t in ipairs(tabs) do
        local x1 = 1 + (i - 1) * (tabWidth + 1)
        local isActive = (currentTab == t)
        addBtn(x1, 3, x1 + tabWidth - 1, 3, t, isActive and cActive or cInactive, isActive and colors.black or colors.white, function()
            currentTab = t; currentPage = 1; refreshItems()
        end)
    end

    local maxVisiblePlayers = 3
    local totalPlayerPages = math.max(1, math.ceil(#managers / maxVisiblePlayers))
    if playerPage > totalPlayerPages then playerPage = totalPlayerPages end

    local startPIdx = (playerPage - 1) * maxVisiblePlayers + 1

    addBtn(1, 5, 3, 6, "<", playerPage > 1 and cActive or cInactive, colors.black, function()
        if playerPage > 1 then playerPage = playerPage - 1 end
    end)

    local navWidth = 8
    local pCardWidth = math.floor((mWidth - navWidth) / maxVisiblePlayers)

    for slot = 1, maxVisiblePlayers do
        local idx = startPIdx + slot - 1
        local mgr = managers[idx]
        local x1 = 4 + (slot - 1) * pCardWidth

        if mgr then
            local pName = mgr.owner:sub(1, math.max(3, pCardWidth - 6))
            local btnBg, btnFg = cInactive, colors.white
            local prefix = "P" .. idx .. ":"

            if currentTab == "TRANSFER" then
                if idx == selectedSourceIdx then btnBg = colors.red; prefix = "SRC:"
                elseif idx == selectedTargetIdx then btnBg = colors.lime; btnFg = colors.black; prefix = "DST:" end
            else
                if idx == selectedSourceIdx then btnBg = cActive; btnFg = colors.black end
            end

            addBtn(x1, 5, x1 + pCardWidth - 2, 6, prefix .. pName, btnBg, btnFg, function()
                if currentTab == "TRANSFER" then
                    if selectedSourceIdx ~= idx then selectedSourceIdx = idx else selectedTargetIdx = idx end
                else selectedSourceIdx = idx end
                refreshItems()
            end)
        end
    end

    addBtn(mWidth - 2, 5, mWidth, 6, ">", playerPage < totalPlayerPages and cActive or cInactive, colors.black, function()
        if playerPage < totalPlayerPages then playerPage = playerPage + 1 end
    end)

    local scopes = { "ALL", "HOTBAR", "MAIN", "ARMOR", "OFFHAND" }
    local sX = 1
    for _, sc in ipairs(scopes) do
        local isActive = (currentScope == sc)
        addBtn(sX, 8, sX + #sc + 1, 8, sc, isActive and cActive or cInactive, isActive and colors.black or colors.white, function()
            currentScope = sc; currentPage = 1; refreshItems()
        end)
        sX = sX + #sc + 2
    end

    monitor.setCursorPos(1, 10)
    monitor.setTextColor(statusColor or cActive)
    monitor.write("> " .. (statusMessage or "Ready."))

    local cardHeight = 2
    local startY_Items = 12
    local endY_Items = mHeight - 2
    local rowsAvailable = math.floor((endY_Items - startY_Items + 1) / cardHeight)
    local itemsPerPage = math.max(2, rowsAvailable * 2)

    local totalPages = math.max(1, math.ceil(#cachedItemList / itemsPerPage))
    if currentPage > totalPages then currentPage = totalPages end

    local startIndex = (currentPage - 1) * itemsPerPage + 1
    local endIndex = math.min(#cachedItemList, startIndex + itemsPerPage - 1)
    local cardWidth = math.floor((mWidth - 2) / 2)

    local itemIdx = startIndex
    local srcMgr = managers[selectedSourceIdx]

    for row = 0, rowsAvailable - 1 do
        local curY = startY_Items + (row * cardHeight)
        if curY > endY_Items or itemIdx > endIndex then break end

        for col = 0, 1 do
            local item = cachedItemList[itemIdx]
            if item then
                local x1 = 1 + col * (cardWidth + 1)
                addBtn(x1, curY, x1 + cardWidth - 1, curY + 1, "", cCardBg, cTextPrimary, function()
                    if srcMgr then exportPlayerToChest(srcMgr, item.slot, item.count, item.name) end
                    refreshItems()
                end)

                monitor.setBackgroundColor(cCardBg)
                monitor.setTextColor(cActive)
                monitor.setCursorPos(x1, curY)
                monitor.write(getItemSlotLabel(item.slot) .. " #" .. item.slot)

                monitor.setCursorPos(x1 + cardWidth - 6, curY)
                monitor.write("x" .. item.count)

                monitor.setCursorPos(x1, curY + 1)
                monitor.setTextColor(cTextPrimary)
                monitor.write(" " .. item.displayName:sub(1, cardWidth - 2))

                itemIdx = itemIdx + 1
            end
        end
    end

    addBtn(1, mHeight, 8, mHeight, "< PREV", cActive, colors.black, function()
        if currentPage > 1 then currentPage = currentPage - 1 end
    end)

    monitor.setCursorPos(10, mHeight)
    monitor.setTextColor(cActive)
    monitor.write(string.format("PAGE %d / %d", currentPage, totalPages))

    addBtn(mWidth - 16, mHeight, mWidth - 9, mHeight, "NEXT >", cActive, colors.black, function()
        if currentPage < totalPages then currentPage = currentPage + 1 end
    end)

    addBtn(mWidth - 7, mHeight, mWidth, mHeight, "REFRESH", cWarn, colors.black, function()
        scanPeripherals(); refreshItems();
    end)
end

------------------------------------------------------------
-- 4. APP: CHAT HACKER (DYNAMIC MODES & TOAST/PM FIXES)
------------------------------------------------------------
local function drawChatHackerApp()
    clearButtons()
    monitor.setBackgroundColor(cBg)
    monitor.clear()
    drawHeader("CHAT HACKER NETWORK")

    -- TARGET MODE SELECTOR (ALL vs SINGLE PLAYER)
    monitor.setCursorPos(2, 3)
    monitor.setTextColor(cActive)
    monitor.write("TARGET MODE:")

    addBtn(15, 3, 27, 3, "ALL PLAYERS", targetMode == "ALL" and cActive or cInactive, targetMode == "ALL" and colors.black or colors.white, function()
        targetMode = "ALL"
        statusHackerMsg = "Mode: Broadcast to ALL"
    end)

    addBtn(29, 3, 43, 3, "SINGLE PLAYER", targetMode == "SINGLE" and cActive or cInactive, targetMode == "SINGLE" and colors.black or colors.white, function()
        targetMode = "SINGLE"
        statusHackerMsg = "Mode: Single Target"
    end)

    -- LEFT PANEL: PLAYERS LIST (ONLY IN SINGLE MODE)
    local leftPanelWidth = 22
    local rightPanelX = 25

    if targetMode == "SINGLE" then
        monitor.setCursorPos(2, 5)
        monitor.setTextColor(cActive)
        monitor.write("PLAYERS (" .. #allServerPlayers .. "):")

        local visiblePlayersCount = 6
        local startY = 7
        
        for i = 0, visiblePlayersCount - 1 do
            local pIdx = playerListScroll + i
            local pName = allServerPlayers[pIdx]
            local yPos = startY + (i * 2)

            if pName then
                local isSelected = (selectedTargetPlayer == pName)
                local bg = isSelected and cWarn or cCardBg
                local fg = isSelected and colors.black or colors.white

                addBtn(2, yPos, leftPanelWidth, yPos + 1, pName:sub(1, 18), bg, fg, function()
                    selectedTargetPlayer = pName
                    statusHackerMsg = "Target locked: " .. pName
                end)
            end
        end

        addBtn(2, 19, 11, 20, "^ UP", cInactive, colors.white, function()
            if playerListScroll > 1 then playerListScroll = playerListScroll - 1 end
        end)

        addBtn(13, 19, leftPanelWidth, 20, "v DOWN", cInactive, colors.white, function()
            if playerListScroll + visiblePlayersCount - 1 < #allServerPlayers then
                playerListScroll = playerListScroll + 1
            end
        end)
    else
        -- IF MODE IS ALL, DISPLAY A BOLD BANNER ON THE LEFT
        rightPanelX = 2
        monitor.setCursorPos(2, 5)
        monitor.setTextColor(cWarn)
        monitor.write("[ BROADCAST ACTIVE ] Target: ALL SERVER PLAYERS")
    end

    -- RIGHT PANEL / PAYLOAD INPUT
    local actionY = targetMode == "SINGLE" and 5 or 7
    monitor.setCursorPos(rightPanelX, actionY)
    monitor.setTextColor(cActive)
    monitor.write("PAYLOAD TEXT:")

    addBtn(rightPanelX, actionY + 1, mWidth - 2, actionY + 2, chatMessageInput, cCardBg, cSuccess, function()
        term.setCursorPos(1, 1)
        print("\nEnter payload in shell:")
        write("> ")
        local input = read()
        if input and #input > 0 then chatMessageInput = input end
        statusHackerMsg = "Payload updated."
    end)

    -- EXPLOIT ACTIONS
    actionY = actionY + 4
    monitor.setCursorPos(rightPanelX, actionY)
    monitor.setTextColor(cActive)
    monitor.write("EXPLOIT ACTIONS:")

    -- 1. SEND TOAST NOTIFICATION
    addBtn(rightPanelX, actionY + 2, mWidth - 2, actionY + 3, "SEND TOAST NOTIFICATION", cWarn, colors.black, function()
        if not chatBoxPeripheral then statusHackerMsg = "ERR: ChatBox peripheral missing!"; return end
        
        if targetMode == "SINGLE" then
            if not selectedTargetPlayer or selectedTargetPlayer == "No Players Found" then 
                statusHackerMsg = "ERR: Select a valid player!"; return 
            end
            local ok, err = pcall(function()
                if chatBoxPeripheral.sendToastToPlayer then
                    chatBoxPeripheral.sendToastToPlayer("JARVIS OS", chatMessageInput, selectedTargetPlayer)
                elseif chatBoxPeripheral.sendToast then
                    chatBoxPeripheral.sendToast(chatMessageInput, "JARVIS OS", selectedTargetPlayer)
                end
            end)
            statusHackerMsg = ok and ("Toast sent -> " .. selectedTargetPlayer) or ("ERR Toast: " .. tostring(err))
        else
            -- BROADCAST TOAST TO ALL PLAYERS
            local sentCount = 0
            for _, pName in ipairs(allServerPlayers) do
                if pName ~= "No Players Found" then
                    pcall(function()
                        if chatBoxPeripheral.sendToastToPlayer then
                            chatBoxPeripheral.sendToastToPlayer("JARVIS OS", chatMessageInput, pName)
                        elseif chatBoxPeripheral.sendToast then
                            chatBoxPeripheral.sendToast(chatMessageInput, "JARVIS OS", pName)
                        end
                    end)
                    sentCount = sentCount + 1
                end
            end
            statusHackerMsg = "Broadcast Toast sent to " .. sentCount .. " player(s)"
        end
    end)

    -- 2. SEND DIRECT MESSAGE (PM)
    addBtn(rightPanelX, actionY + 5, mWidth - 2, actionY + 6, "SEND DIRECT PM (L5)", cActive, colors.black, function()
        if not chatBoxPeripheral then statusHackerMsg = "ERR: ChatBox peripheral missing!"; return end

        if targetMode == "SINGLE" then
            if not selectedTargetPlayer or selectedTargetPlayer == "No Players Found" then 
                statusHackerMsg = "ERR: Select a target!"; return 
            end
            local ok = pcall(function()
                if chatBoxPeripheral.sendMessageToPlayer then
                    chatBoxPeripheral.sendMessageToPlayer(chatMessageInput, selectedTargetPlayer, "&a[JARVIS]&r")
                end
            end)
            statusHackerMsg = ok and ("PM delivered -> " .. selectedTargetPlayer) or "ERR: PM failed"
        else
            -- PM ALL PLAYERS
            local sentCount = 0
            for _, pName in ipairs(allServerPlayers) do
                if pName ~= "No Players Found" then
                    pcall(function()
                        if chatBoxPeripheral.sendMessageToPlayer then
                            chatBoxPeripheral.sendMessageToPlayer(chatMessageInput, pName, "&a[JARVIS]&r")
                        end
                    end)
                    sentCount = sentCount + 1
                end
            end
            statusHackerMsg = "PM spammed to " .. sentCount .. " player(s)"
        end
    end)

    -- 3. BROADCAST TO PUBLIC CHAT
    addBtn(rightPanelX, actionY + 8, mWidth - 2, actionY + 9, "BROADCAST PUBLIC CHAT", cFail, colors.white, function()
        if not chatBoxPeripheral then statusHackerMsg = "ERR: ChatBox peripheral missing!"; return end
        local ok = pcall(function()
            if chatBoxPeripheral.sendMessage then
                chatBoxPeripheral.sendMessage(chatMessageInput, "&c[JARVIS ALERT]&r")
            end
        end)
        statusHackerMsg = ok and "Public chat broadcast sent!" or "ERR: Public broadcast failed"
    end)

    -- BOTTOM ACTION: REFRESH DETECTOR SCAN
    addBtn(2, mHeight - 3, 22, mHeight - 2, "SCAN PLAYERS", cInactive, colors.white, function()
        fetchAllPlayers()
        statusHackerMsg = "Player Detector Scanned: " .. #allServerPlayers .. " online"
    end)

    -- STATUS BAR
    monitor.setCursorPos(24, mHeight - 2)
    monitor.setTextColor(cWarn)
    monitor.write("> STATUS: " .. statusHackerMsg)
end

------------------------------------------------------------
-- 5. APP: NEO RADAR
------------------------------------------------------------
local function drawRadarApp()
    clearButtons()
    monitor.setBackgroundColor(cBg)
    monitor.clear()
    drawHeader("NEO RADAR SCANNER")

    local cx, cy = math.floor(mWidth / 2), math.floor(mHeight / 2)
    
    monitor.setTextColor(colors.green)
    for r = 2, 8, 2 do
        for a = 0, 360, 30 do
            local rad = math.rad(a)
            local rx = math.floor(cx + math.cos(rad) * r * 2)
            local ry = math.floor(cy + math.sin(rad) * r)
            if rx >= 1 and rx <= mWidth and ry >= 2 and ry <= mHeight - 1 then
                monitor.setCursorPos(rx, ry)
                monitor.write(".")
            end
        end
    end

    monitor.setCursorPos(cx, cy)
    monitor.setTextColor(cActive)
    monitor.write("+")

    monitor.setCursorPos(math.floor((mWidth - 28) / 2), cy + 6)
    monitor.setTextColor(cTextSec)
    monitor.write("RADAR MODULE STANDBY MODE")
end

------------------------------------------------------------
-- MAIN ENGINE LOOP
------------------------------------------------------------
scanPeripherals()
refreshItems()
fetchAllPlayers()
runBootAnimation()

while true do
    if currentApp == "MAIN_MENU" then
        drawMainMenu()
    elseif currentApp == "INVENTORY" then
        drawInventoryApp()
    elseif currentApp == "CHAT_HACKER" then
        drawChatHackerApp()
    elseif currentApp == "RADAR" then
        drawRadarApp()
    end

    local event, side, x, y = os.pullEvent("monitor_touch")
    for _, btn in ipairs(buttons) do
        if x >= btn.x1 and x <= btn.x2 and y >= btn.y1 and y <= btn.y2 then
            btn.cb()
            break
        end
    end
end
