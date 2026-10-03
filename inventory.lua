-- ============================================================
--   SPACED & ACCENTED 4-PLAYER INVENTORY CONTROLLER
--   CC:Tweaked + Advanced Peripherals (No Emojis, Green Accent)
-- ============================================================

local monitor = peripheral.find("monitor")
if not monitor then
    error("Touchscreen Monitor not found! Attach a monitor to the computer.")
end

monitor.setTextScale(0.5)
local mWidth, mHeight = monitor.getSize()

-- Color Palette with Green Accent
local cBg          = colors.black
local cHeaderBg    = colors.green
local cHeaderFg    = colors.black
local cCardBg      = colors.gray
local cTextPrimary = colors.white
local cTextSec     = colors.lightGray
local cActive      = colors.lime      -- Main Active Accent
local cInactive    = colors.gray
local cWarn        = colors.orange
local cFail        = colors.red
local cSuccess     = colors.lime

-- Transfer Mode Player Colors
local cSrcColor    = colors.red       -- Sender (Red)
local cDstColor    = colors.lime      -- Receiver (Green)

-- State Variables
local managers = {}
local connectedStorages = {}
local selectedSourceIdx = 1
local selectedTargetIdx = 2

local currentTab = "EXPORT" -- "EXPORT", "IMPORT", "TRANSFER"
local currentScope = "ALL"  -- "ALL", "HOTBAR", "MAIN", "ARMOR", "OFFHAND"
local selectedAmountMode = "ALL" -- "1", "STACK", "ALL"
local currentPage = 1
local cachedItemList = {}
local buttons = {}

-- Dynamic Spaced Grid Layout
local cardHeight = 2
local startY_Items = 13
local endY_Items = mHeight - 2
local rowsAvailable = math.floor((endY_Items - startY_Items + 1) / cardHeight)
local itemsPerPage = math.max(2, rowsAvailable * 2)

local SCAN_DIRECTIONS = { "up", "down", "north", "south", "east", "west", "top", "bottom" }

local function detectChestDirection(mgrObj)
    for _, dir in ipairs(SCAN_DIRECTIONS) do
        local ok, size = pcall(function() return mgrObj.getContainerSize(dir) end)
        if ok and type(size) == "number" and size > 0 then return dir end
    end
    return "up"
end

-- 1. Hardware Scanner
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
                table.insert(managers, {
                    id = name,
                    obj = obj,
                    owner = owner,
                    chestDir = detectChestDirection(obj)
                })
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

scanPeripherals()

local function toNum(v) return tonumber(v) or 0 end

local function isSlotInScope(slotNum, scope, isArmorSlot)
    if scope == "ALL" then return true end
    if isArmorSlot and scope == "ARMOR" then return true end
    if scope == "HOTBAR" then return slotNum >= 0 and slotNum <= 8 end
    if scope == "MAIN" then return slotNum >= 9 and slotNum <= 35 end
    if scope == "ARMOR" then return (slotNum >= 36 and slotNum <= 39) or (slotNum >= 100 and slotNum <= 103) end
    if scope == "OFFHAND" then return slotNum == 40 or slotNum == 104 or slotNum == 150 end
    return false
end

local function getItemSlotLabel(slotNum, isArmor)
    if isArmor or (slotNum >= 36 and slotNum <= 39) or (slotNum >= 100 and slotNum <= 103) then
        return "[ARMOR]"
    elseif slotNum == 40 or slotNum == 104 then
        return "[OFFH]"
    elseif slotNum >= 0 and slotNum <= 8 then
        return "[HOTB]"
    else
        return "[MAIN]"
    end
end

-- 2. Core Transfer
local function exportPlayerToChest(mgr, slotNum, count, itemName)
    local dir = mgr.chestDir or "up"

    local ok, res = pcall(function()
        return mgr.obj.removeItemFromPlayer(dir, { fromSlot = slotNum, count = count })
    end)
    if ok and type(res) == "number" and res > 0 then return res end

    if itemName and itemName ~= "" then
        ok, res = pcall(function()
            return mgr.obj.removeItemFromPlayer(dir, { name = itemName, count = count })
        end)
        if ok and type(res) == "number" and res > 0 then return res end
    end

    ok, res = pcall(function()
        return mgr.obj.removeItemFromPlayer(dir, count, slotNum)
    end)
    if ok and type(res) == "number" and res > 0 then return res end

    return 0
end

local function importChestToPlayer(mgr, chestSlotNum, count, itemName)
    local dir = mgr.chestDir or "up"
    
    if itemName and itemName ~= "" then
        local ok, res = pcall(function()
            return mgr.obj.addItemToPlayer(dir, { name = itemName, count = count })
        end)
        if ok and type(res) == "number" and res > 0 then return res end
    end

    if chestSlotNum then
        local ok, res = pcall(function()
            return mgr.obj.addItemToPlayer(dir, { fromSlot = chestSlotNum, count = count })
        end)
        if ok and type(res) == "number" and res > 0 then return res end
    end

    local ok, res = pcall(function() return mgr.obj.addItemToPlayer(dir, count) end)
    if ok and type(res) == "number" and res > 0 then return res end

    return 0
end

-- 3. Items Scanner
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
                    if isSlotInScope(sNum, currentScope, false) then
                        table.insert(cachedItemList, {
                            slot = sNum,
                            name = item.name,
                            displayName = item.displayName or item.name,
                            count = item.count,
                            isArmor = false
                        })
                    end
                end
            end
        end

        local okArmor, armorRes = pcall(function() return mgr.obj.getArmor() end)
        if okArmor and type(armorRes) == "table" then
            for slotKey, item in pairs(armorRes) do
                if type(item) == "table" and item.count and item.count > 0 then
                    local sNum = toNum(item.slot or item.slotNumber or slotKey)
                    if isSlotInScope(sNum, currentScope, true) then
                        table.insert(cachedItemList, {
                            slot = sNum,
                            name = item.name,
                            displayName = item.displayName or item.name,
                            count = item.count,
                            isArmor = true
                        })
                    end
                end
            end
        end

    elseif currentTab == "IMPORT" then
        for _, st in ipairs(connectedStorages) do
            local list = nil
            pcall(function()
                if st.obj.list then list = st.obj.list()
                elseif st.obj.getItems then list = st.obj.getItems() end
            end)

            if type(list) == "table" then
                for slot, item in pairs(list) do
                    if item and item.count and item.count > 0 then
                        local dName = item.displayName or item.name
                        if not dName and st.obj.getItemDetail then
                            pcall(function()
                                local detail = st.obj.getItemDetail(slot)
                                if detail then dName = detail.displayName or detail.name end
                            end)
                        end

                        table.insert(cachedItemList, {
                            slot = slot,
                            name = item.name or "unknown",
                            displayName = dName or item.name or "Unknown Item",
                            count = item.count
                        })
                    end
                end
            end
        end
    end
end

-- 4. Bulk Operations
local function executeBulkOperation()
    local srcMgr = managers[selectedSourceIdx]
    local dstMgr = managers[selectedTargetIdx]
    if not srcMgr then return 0 end

    local totalMoved = 0
    if currentTab == "EXPORT" then
        for _, item in ipairs(cachedItemList) do
            totalMoved = totalMoved + exportPlayerToChest(srcMgr, item.slot, item.count, item.name)
        end
    elseif currentTab == "IMPORT" then
        for _, item in ipairs(cachedItemList) do
            totalMoved = totalMoved + importChestToPlayer(srcMgr, item.slot, item.count, item.name)
        end
    elseif currentTab == "TRANSFER" then
        if srcMgr and dstMgr and selectedSourceIdx ~= selectedTargetIdx then
            for _, item in ipairs(cachedItemList) do
                local pulled = exportPlayerToChest(srcMgr, item.slot, item.count, item.name)
                if pulled > 0 then
                    totalMoved = totalMoved + importChestToPlayer(dstMgr, nil, pulled, item.name)
                end
            end
        end
    end
    return totalMoved
end

-- 5. GUI Rendering Helpers
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

-- Item Card Component
local function drawItemCard(x1, y1, width, item, srcMgr, dstMgr)
    local x2 = x1 + width - 1
    local y2 = y1 + 1

    addBtn(x1, y1, x2, y2, "", cCardBg, cTextPrimary, function()
        local moveCount = item.count
        if selectedAmountMode == "1" then moveCount = 1
        elseif selectedAmountMode == "STACK" then moveCount = math.min(64, item.count) end

        if currentTab == "EXPORT" then
            exportPlayerToChest(srcMgr, item.slot, moveCount, item.name)
        elseif currentTab == "IMPORT" then
            importChestToPlayer(srcMgr, item.slot, moveCount, item.name)
        elseif currentTab == "TRANSFER" and srcMgr and dstMgr then
            local p = exportPlayerToChest(srcMgr, item.slot, moveCount, item.name)
            if p > 0 then importChestToPlayer(dstMgr, nil, p, item.name) end
        end
        refreshItems()
    end)

    monitor.setBackgroundColor(cCardBg)
    monitor.setTextColor(cActive)
    monitor.setCursorPos(x1, y1)
    local slotTag = getItemSlotLabel(item.slot, item.isArmor)
    monitor.write(string.format("%s #%-2d", slotTag, item.slot))

    monitor.setTextColor(cActive)
    local countStr = string.format("x%d", item.count)
    monitor.setCursorPos(x2 - #countStr, y1)
    monitor.write(countStr)

    monitor.setCursorPos(x1, y1 + 1)
    monitor.setTextColor(cTextPrimary)
    local dName = tostring(item.displayName or item.name)
    if #dName > (width - 1) then dName = dName:sub(1, width - 3) .. ".." end
    monitor.write(" " .. dName)
end

-- Main GUI Render
local function drawGUI(statusMessage, statusColor)
    clearButtons()
    monitor.setBackgroundColor(cBg)
    monitor.clear()

    -- 1. Header Line
    monitor.setBackgroundColor(cHeaderBg)
    monitor.setTextColor(cHeaderFg)
    monitor.setCursorPos(1, 1)
    monitor.clearLine()
    monitor.write(" INVENTORY CONTROLLER SYSTEM ")

    local stBadge = string.format("[%d MANAGERS]", #managers)
    monitor.setCursorPos(mWidth - #stBadge, 1)
    monitor.write(stBadge)

    -- 2. Mode Tabs (Row 3 - Spaced from Header)
    local tabs = { "EXPORT", "IMPORT", "TRANSFER" }
    local tabWidth = math.floor((mWidth - 2) / 3)
    for i, t in ipairs(tabs) do
        local x1 = 1 + (i - 1) * (tabWidth + 1)
        local isActive = (currentTab == t)
        local bg = isActive and cActive or cInactive
        local fg = isActive and colors.black or colors.white

        addBtn(x1, 3, x1 + tabWidth - 1, 3, t, bg, fg, function()
            currentTab = t; currentPage = 1; refreshItems()
        end)
    end

    -- 3. Players Selection Bar (Row 5 - Spaced)
    local pCardWidth = math.floor((mWidth - 3) / 4)
    for idx, mgr in ipairs(managers) do
        if idx <= 4 then
            local pName = mgr.owner:sub(1, pCardWidth - 2)
            local btnBg = cInactive
            local btnFg = colors.white
            local prefix = "P" .. idx .. ": "

            if currentTab == "TRANSFER" then
                if idx == selectedSourceIdx then
                    btnBg = cSrcColor -- RED for Sender
                    btnFg = colors.white
                    prefix = "SRC: "
                elseif idx == selectedTargetIdx then
                    btnBg = cDstColor -- GREEN for Receiver
                    btnFg = colors.black
                    prefix = "DST: "
                end
            else
                if idx == selectedSourceIdx then
                    btnBg = cActive
                    btnFg = colors.black
                end
            end

            local x1 = 1 + (idx - 1) * (pCardWidth + 1)
            addBtn(x1, 5, x1 + pCardWidth - 1, 6, prefix .. pName, btnBg, btnFg, function()
                if currentTab == "TRANSFER" then
                    if selectedSourceIdx ~= idx then selectedSourceIdx = idx
                    else selectedTargetIdx = idx end
                else selectedSourceIdx = idx end
                refreshItems()
            end)
        end
    end

    -- 4. Scope Bar (Row 8 - Spaced)
    if currentTab == "EXPORT" or currentTab == "TRANSFER" then
        local scopes = { "ALL", "HOTBAR", "MAIN", "ARMOR", "OFFHAND" }
        local sX = 1
        for _, sc in ipairs(scopes) do
            local isActive = (currentScope == sc)
            local scBg = isActive and cActive or cInactive
            local scFg = isActive and colors.black or colors.white

            addBtn(sX, 8, sX + #sc + 1, 8, sc, scBg, scFg, function()
                currentScope = sc; currentPage = 1; refreshItems()
            end)
            sX = sX + #sc + 2
        end
    end

    -- 5. Amount Selector & Action Button (Row 10 - Spaced)
    local amounts = { { id = "1", label = "x1" }, { id = "STACK", label = "x64" }, { id = "ALL", label = "MAX" } }
    local aX = 1
    for _, am in ipairs(amounts) do
        local isActive = (selectedAmountMode == am.id)
        local aBg = isActive and cActive or cInactive
        local aFg = isActive and colors.black or colors.white
        addBtn(aX, 10, aX + #am.label + 1, 10, am.label, aBg, aFg, function()
            selectedAmountMode = am.id
        end)
        aX = aX + #am.label + 2
    end

    local scopeText = (currentTab == "IMPORT") and "ALL" or currentScope
    local bulkLabel = "EXECUTE " .. currentTab
    addBtn(mWidth - #bulkLabel - 1, 10, mWidth - 1, 10, bulkLabel, cActive, colors.black, function()
        local count = executeBulkOperation()
        refreshItems()
        drawGUI(string.format("Moved %d items (%s)", count, scopeText), cSuccess)
    end)

    -- 6. Status Notification Line (Row 11)
    monitor.setCursorPos(1, 11)
    if statusMessage then
        monitor.setTextColor(statusColor or cActive)
        monitor.write("> " .. statusMessage:sub(1, mWidth - 2))
    else
        monitor.setTextColor(cTextSec)
        monitor.write("> Ready.")
    end

    if #managers == 0 then
        monitor.setCursorPos(1, 13)
        monitor.setTextColor(cFail)
        monitor.write("NO INVENTORY MANAGERS DETECTED")
        return
    end

    -- 7. Item Grid (Row 13 onwards - NO GREEN SEPARATOR LINE)
    local totalPages = math.max(1, math.ceil(#cachedItemList / itemsPerPage))
    if currentPage > totalPages then currentPage = totalPages end

    local startIndex = (currentPage - 1) * itemsPerPage + 1
    local endIndex = math.min(#cachedItemList, startIndex + itemsPerPage - 1)
    local cardWidth = math.floor((mWidth - 2) / 2)

    if #cachedItemList == 0 then
        monitor.setCursorPos(1, 13)
        monitor.setTextColor(cWarn)
        monitor.write("No items found in scope: " .. currentScope)
    else
        local itemIdx = startIndex
        local srcMgr = managers[selectedSourceIdx]
        local dstMgr = managers[selectedTargetIdx]

        for row = 0, rowsAvailable - 1 do
            local curY = startY_Items + (row * cardHeight)
            if curY > endY_Items or itemIdx > endIndex then break end

            local item1 = cachedItemList[itemIdx]
            if item1 then
                drawItemCard(1, curY, cardWidth, item1, srcMgr, dstMgr)
                itemIdx = itemIdx + 1
            end

            if itemIdx <= endIndex then
                local item2 = cachedItemList[itemIdx]
                if item2 then
                    drawItemCard(cardWidth + 2, curY, cardWidth, item2, srcMgr, dstMgr)
                    itemIdx = itemIdx + 1
                end
            end
        end
    end

    -- 8. Footer Navigation
    addBtn(1, mHeight, 8, mHeight, "< PREV", cActive, colors.black, function()
        if currentPage > 1 then currentPage = currentPage - 1; drawGUI() end
    end)

    monitor.setCursorPos(10, mHeight)
    monitor.setTextColor(cActive)
    monitor.write(string.format("PAGE %d / %d (%d TOTAL)", currentPage, totalPages, #cachedItemList))

    addBtn(mWidth - 16, mHeight, mWidth - 9, mHeight, "NEXT >", cActive, colors.black, function()
        if currentPage < totalPages then currentPage = currentPage + 1; drawGUI() end
    end)

    addBtn(mWidth - 7, mHeight, mWidth, mHeight, "REFRESH", cWarn, colors.black, function()
        scanPeripherals(); refreshItems(); drawGUI("Refreshed.", cActive)
    end)
end

-- 6. Main Loop
refreshItems()
drawGUI("System initialized.", cSuccess)

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    for _, btn in ipairs(buttons) do
        if x >= btn.x1 and x <= btn.x2 and y >= btn.y1 and y <= btn.y2 then
            btn.cb()
            drawGUI()
            break
        end
    end
end
