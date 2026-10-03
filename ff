-- ============================================================
--  Inventory Manager Controller
--  CC:Tweaked + Advanced Peripherals
--  Chest is placed ABOVE the computer
-- ============================================================

-- ------------------------------------------------------------
-- 1. Peripheral detection
-- ------------------------------------------------------------
local manager = peripheral.find("inventory_manager")
if not manager then
    error("Inventory Manager not found. Make sure the block is connected to the computer.")
end

local function findStorage()
    for _, name in ipairs(peripheral.getNames()) do
        local t = peripheral.getType(name)
        if t == "minecraft:chest"
        or t == "minecraft:barrel"
        or t == "minecraft:trapped_chest"
        or t == "minecraft:shulker_box"
        or t == "ironchest:iron_chest"
        or t == "ironchest:gold_chest"
        or t == "ironchest:diamond_chest"
        or t == "ironchest:crystal_chest"
        or t == "ironchest:obsidian_chest" then
            return name
        end
    end
    return nil
end

local chest = findStorage()
if not chest then
    error("No storage block found nearby. Place a chest next to the computer.")
end

-- ------------------------------------------------------------
-- 2. Owner check (memory card)
-- ------------------------------------------------------------
local ownerUuid, ownerName = manager.getOwner()
if not ownerUuid then
    error("Memory card not inserted or owner is offline.\n" ..
          "Insert a player-bound memory card into the Inventory Manager.\n" ..
          "To bind a card: hold it in your hand and right-click yourself.")
end

print("==================================================")
print("  Inventory Manager Controller")
print(("  Player: %s (%s)"):format(tostring(ownerName), tostring(ownerUuid)))
print(("  Storage: %s"):format(chest))

-- Safe call for size()
local okSize, invSize = pcall(function() return manager.size() end)
if okSize and invSize then
    print(("  Inventory size: %d slots"):format(invSize))
else
    print("  Inventory size: N/A")
end

-- Safe call for getEmptySlots()
local okEmpty, emptySlots = pcall(function() return manager.getEmptySlots() end)
if okEmpty and emptySlots then
    print(("  Empty slots: %d"):format(emptySlots))
else
    print("  Empty slots: N/A")
end

print("==================================================")
print()

-- ------------------------------------------------------------
-- 3. Helper functions
-- ------------------------------------------------------------

--- Print the contents of the player's inventory
local function listInventory()
    local ok, items = pcall(function() return manager.list() end)
    if not ok or not items or not next(items) then
        print("Inventory is empty (or 'list' is not supported).")
        return
    end

    print("--- Inventory contents ---")
    for slot, item in pairs(items) do
        -- item may be a table with name/count, or a simple value
        if type(item) == "table" then
            print(("  Slot %3d: %-40s x%d  (%s)"):format(
                slot,
                tostring(item.name),
                tonumber(item.count) or 0,
                tostring(item.displayName or item.name)
            ))
        else
            print(("  Slot %3d: %s"):format(slot, tostring(item)))
        end
    end
    print("--------------------------")
end

--- Export items from the player's inventory into the chest
-- @param filter  table filter (nil = all items)
local function exportToChest(filter)
    local ok, moved = pcall(function()
        return manager.exportItem(chest, filter or {})
    end)
    if not ok then
        print("[FAIL] exportItem error: " .. tostring(moved))
        return 0
    end
    moved = tonumber(moved) or 0
    if moved > 0 then
        print(("[OK] Exported %d items to %s"):format(moved, chest))
    else
        print("[FAIL] Nothing was exported (no matching items or chest is full).")
    end
    return moved
end

--- Import items from the chest into the player's inventory
-- @param filter  table filter (nil = all items)
local function importFromChest(filter)
    local ok, moved = pcall(function()
        return manager.importItem(chest, filter or {})
    end)
    if not ok then
        print("[FAIL] importItem error: " .. tostring(moved))
        return 0
    end
    moved = tonumber(moved) or 0
    if moved > 0 then
        print(("[OK] Imported %d items from %s"):format(moved, chest))
    else
        print("[FAIL] Nothing was imported (no matching items or inventory is full).")
    end
    return moved
end

--- Export everything from the inventory to the chest
local function exportAll()
    return exportToChest(nil)
end

--- Import everything from the chest into the inventory
local function importAll()
    return importFromChest(nil)
end

-- ------------------------------------------------------------
-- 4. Menu
-- ------------------------------------------------------------
local function showMenu()
    print()
    print("========== MENU ==========")
    print(" 1. Show inventory contents")
    print(" 2. Export ALL to chest")
    print(" 3. Import ALL from chest")
    print(" 4. Export by filter")
    print(" 5. Import by filter")
    print(" 6. Exit")
    print("==========================")
    write("Choose an option: ")
end

--- Ask the user for a filter
local function askFilter()
    write("Enter item name (e.g. minecraft:cobblestone): ")
    local name = read()
    if not name or name == "" then return nil end

    write("Amount (Enter = all): ")
    local cntStr = read()
    local filter = { name = name }
    if cntStr and cntStr ~= "" then
        local cnt = tonumber(cntStr)
        if cnt then filter.count = cnt end
    end
    return filter
end

-- ------------------------------------------------------------
-- 5. Main loop
-- ------------------------------------------------------------
while true do
    showMenu()
    local choice = read()

    if choice == "1" then
        listInventory()

    elseif choice == "2" then
        exportAll()

    elseif choice == "3" then
        importAll()

    elseif choice == "4" then
        local f = askFilter()
        if f then exportToChest(f) end

    elseif choice == "5" then
        local f = askFilter()
        if f then importFromChest(f) end

    elseif choice == "6" then
        print("Exiting.")
        break

    else
        print("Invalid choice. Try again.")
    end

    sleep(0.5)
end
