-- ============================================================
--   Inventory Manager Controller (Categorized Export Support)
--   CC:Tweaked + Advanced Peripherals
-- ============================================================

-- 1. Peripherals Detection (Universal Scanner)
local manager = peripheral.find("inventory_manager") or peripheral.find("inventoryManager")
if not manager then
    error("Inventory Manager not found! Check connection or modem.")
end

local monitor = peripheral.find("monitor")
if monitor then
    pcall(function()
        monitor.setTextScale(0.5)
        monitor.clear()
    end)
end

local function monHas(name)
    return monitor and type(monitor[name]) == "function"
end

local function monColor(c)
    if monHas("setTextColour") and colors and c then
        pcall(function() monitor.setTextColour(c) end)
    end
end

-- Storage detection
local STORAGE_TYPES = {
    ["minecraft:chest"] = true,
    ["minecraft:barrel"] = true,
    ["minecraft:trapped_chest"] = true,
    ["minecraft:shulker_box"] = true,
    ["ironchest:iron_chest"] = true,
    ["ironchest:gold_chest"] = true,
    ["ironchest:diamond_chest"] = true,
    ["ironchest:crystal_chest"] = true,
    ["ironchest:obsidian_chest"] = true,
}

local chest = nil
for _, name in ipairs(peripheral.getNames()) do
    local pType = peripheral.getType(name)
    if STORAGE_TYPES[pType] or (pType and string.find(pType, "chest")) then
        chest = name
        break
    end
end

if not chest then
    chest = "top" -- Default direction if placed directly on top of Inventory Manager
end

-- Owner / Memory card check
local ownerName = manager.getOwner and manager.getOwner()
if not ownerName or ownerName == "" then
    error("Memory card not inserted, invalid, or player is offline!\n" ..
          "Insert a bound Memory Card into the Inventory Manager.")
end

-- 2. Safe helpers
local function toNum(v)
    return tonumber(v) or 0
end

local function shortStr(s, maxLen)
    s = tostring(s or "?")
    maxLen = maxLen or 22
    if #s > maxLen then
        s = s:sub(1, maxLen - 3) .. "..."
    end
    return s
end

-- Check if slot belongs to the target export area
local function isSlotInScope(slotNum, scope)
    if scope == "ALL" then
        return true
    elseif scope == "HOTBAR" then
        return slotNum >= 0 and slotNum <= 8
    elseif scope == "MAIN" then
        return slotNum >= 9 and slotNum <= 35
    elseif scope == "ARMOR" then
        -- Armor slots in Minecraft / AP are typically 100-103 or 36-39 depending on AP version
        return (slotNum >= 100 and slotNum <= 103) or (slotNum >= 36 and slotNum <= 39 and not isSlotInScope(slotNum, "MAIN"))
    elseif scope == "OFFHAND" then
        -- Offhand is usually slot 36 or 104
        return slotNum == 36 or slotNum == 104
    end
    return true
end

-- 3. Monitor rendering
local function updateMonitor()
    if not monitor then return end

    local ok, err = pcall(function()
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monColor(colors and colors.yellow)
        monitor.write("=== Inventory: " .. shortStr(ownerName, 12) .. " ===")
        monColor(colors and colors.white)

        local okList, items = pcall(function() return manager.getItems() end)
        if not okList or type(items) ~= "table" or not next(items) then
            monitor.setCursorPos(1, 3)
            monitor.write("(empty or items unavailable)")
            return
        end

        local line = 3
        for slot, item in pairs(items) do
            if line > 20 then
                monitor.setCursorPos(1, line)
                monitor.write("... truncated")
                break
            end

            if type(item) == "table" then
                local slotNum = toNum(item.slot or item.slotNumber or slot)
                local name = shortStr(item.name or "?", 20)
                local count = toNum(item.count)
                local dname = shortStr(item.displayName or item.name or "?", 20)

                monitor.setCursorPos(1, line)
                monitor.write(string.format("%3d %-20s x%-4d", slotNum, name, count))
                line = line + 1

                if dname ~= "" and dname ~= name then
                    monitor.setCursorPos(1, line)
                    monColor(colors and (colors.lightGrey or colors.gray or colors.white))
                    monitor.write("    " .. dname)
                    monColor(colors and colors.white)
                    line = line + 1
                end
            end
        end
    end)

    if not ok then
        print("[WARN] Monitor update failed: " .. tostring(err))
    end
end

-- 4. Terminal + transfer functions
local function listInventory()
    local ok, items = pcall(function() return manager.getItems() end)
    if not ok or type(items) ~= "table" or not next(items) then
        print("Inventory is empty (or getItems unavailable).")
        return
    end

    print("--- Inventory contents ---")
    for slot, item in pairs(items) do
        if type(item) == "table" then
            print(string.format("  Slot %3d: %-35s x%-4d  (%s)",
                toNum(item.slot or item.slotNumber or slot),
                tostring(item.name or "?"),
                toNum(item.count),
                tostring(item.displayName or item.name or "?")
            ))
        end
    end
    print("--------------------------")
end

local function exportToChest(filter, scope)
    scope = scope or "ALL"
    
    -- Combine regular items and armor
    local items = {}
    local okList, rawItems = pcall(function() return manager.getItems() end)
    if okList and type(rawItems) == "table" then
        for k, v in pairs(rawItems) do table.insert(items, v) end
    end

    -- If export includes armor, check getArmor() separately if available
    if (scope == "ALL" or scope == "ARMOR") and manager.getArmor then
        local okArmor, armorItems = pcall(function() return manager.getArmor() end)
        if okArmor and type(armorItems) == "table" then
            for k, v in pairs(armorItems) do table.insert(items, v) end
        end
    end

    if #items == 0 then
        print("[FAIL] Could not retrieve player inventory.")
        return 0
    end

    local totalMoved = 0

    for _, item in pairs(items) do
        if type(item) == "table" and item.count and item.count > 0 then
            local slotNum = toNum(item.slot or item.slotNumber)
            
            -- Check if slot matches selected area (Hotbar, Main, Armor, Offhand)
            if isSlotInScope(slotNum, scope) then
                local matches = true
                if filter and filter.name and filter.name ~= "" then
                    if item.name ~= filter.name then
                        matches = false
                    end
                end

                if matches then
                    local amountToMove = item.count
                    if filter and filter.count and filter.count > 0 then
                        amountToMove = math.min(amountToMove, filter.count)
                    end

                    local ok, moved = pcall(function()
                        return manager.removeItemFromPlayer(chest, {
                            fromSlot = slotNum,
                            count = amountToMove
                        })
                    end)

                    if ok and toNum(moved) > 0 then
                        totalMoved = totalMoved + toNum(moved)
                    end
                end
            end
        end
    end

    if totalMoved > 0 then
        print(string.format("[OK] Exported %d items [%s] to %s", totalMoved, scope, tostring(chest)))
    else
        print(string.format("[FAIL] Nothing exported for scope [%s].", scope))
    end

    updateMonitor()
    return totalMoved
end

local function importFromChest(filter)
    local ok, moved = pcall(function()
        return manager.addItemToPlayer(chest, filter or {})
    end)
    
    if not ok then
        print("[FAIL] addItemToPlayer error: " .. tostring(moved))
        return 0
    end

    moved = toNum(moved)
    if moved > 0 then
        print(string.format("[OK] Imported %d items from %s", moved, tostring(chest)))
    else
        print("[FAIL] Nothing imported (no matching items or inventory full).")
    end

    updateMonitor()
    return moved
end

-- 5. Scope Selection Menu
local function chooseExportScope()
    print()
    print("--- Select Export Category ---")
    print(" 1. All (Entire Inventory + Armor + Offhand)")
    print(" 2. Hotbar only (Slots 0-8)")
    print(" 3. Main Inventory (Slots 9-35)")
    print(" 4. Armor only (Helmet, Chestplate, etc.)")
    print(" 5. Offhand only (Left Hand)")
    print("------------------------------")
    write("Choice [1-5]: ")
    local input = read()

    if input == "2" then return "HOTBAR"
    elseif input == "3" then return "MAIN"
    elseif input == "4" then return "ARMOR"
    elseif input == "5" then return "OFFHAND"
    else return "ALL" end
end

-- 6. Menu
local function showMenu()
    print()
    print("========== MENU ==========")
    print(" 1. Show inventory (terminal + monitor)")
    print(" 2. Export items (with scope selection)")
    print(" 3. Import ALL from chest")
    print(" 4. Export specific item by filter")
    print(" 5. Import specific item by filter")
    print(" 6. Exit")
    print("==========================")
    write("Choose an option: ")
end

local function askFilter()
    write("Item name (e.g. minecraft:cobblestone) or blank to cancel: ")
    local name = read()
    if not name or name == "" then return nil end

    write("Amount (Enter = default/all): ")
    local cntStr = read()
    local filter = { name = name }
    if cntStr and cntStr ~= "" then
        local cnt = tonumber(cntStr)
        if cnt then filter.count = cnt end
    end
    return filter
end

-- 7. Init
updateMonitor()
print(string.format("Player: %s", tostring(ownerName)))
print(string.format("Chest/Target: %s", tostring(chest)))
print("Monitor: " .. (monitor and "connected" or "not found (optional)"))

-- 8. Main loop
while true do
    showMenu()
    local choice = read()

    if choice == "1" then
        listInventory()
        updateMonitor()
    elseif choice == "2" then
        local scope = chooseExportScope()
        exportToChest({}, scope)
    elseif choice == "3" then
        importFromChest({})
    elseif choice == "4" then
        local f = askFilter()
        if f then
            local scope = chooseExportScope()
            exportToChest(f, scope)
        end
    elseif choice == "5" then
        local f = askFilter()
        if f then importFromChest(f) end
    elseif choice == "6" then
        print("Exiting.")
        break
    else
        print("Invalid choice. Try again.")
    end

    sleep(0.3)
end
