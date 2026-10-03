-- ============================================================
--  Inventory Manager Controller
--  CC:Tweaked + Advanced Peripherals
--  Сундук стоит НАД компьютером
-- ============================================================

-- ------------------------------------------------------------
-- 1. Поиск периферии
-- ------------------------------------------------------------
local manager = peripheral.find("inventory_manager")
if not manager then
    error("Inventory Manager не найден. Убедитесь, что блок подключён к компьютеру.")
end

-- Автопоиск ближайшего сундука / бочки / шалкера
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
    error("Сундук рядом не найден. Поставьте сундук рядом с компьютером.")
end

-- ------------------------------------------------------------
-- 2. Проверка владельца (карта памяти)
-- ------------------------------------------------------------
local ownerUuid, ownerName = manager.getOwner()
if not ownerUuid then
    error("Карта памяти не вставлена или владелец не в сети.\n" ..
          "Вставьте привязанную карту в Inventory Manager.")
end

print("==================================================")
print(("  Управление инвентарём игрока"):format())
print(("  Игрок: %s (%s)"):format(ownerName, ownerUuid))
print(("  Сундук: %s"):format(chest))
print(("  Размер инвентаря: %d слотов"):format(manager.size()))
print(("  Свободных слотов: %d"):format(manager.getEmptySlots()))
print("==================================================")
print()

-- ------------------------------------------------------------
-- 3. Функции
-- ------------------------------------------------------------

--- Вывод содержимого инвентаря игрока
local function listInventory()
    local items = manager.list()
    if not items or not next(items) then
        print("Инвентарь пуст.")
        return
    end

    print("--- Содержимое инвентаря ---")
    for slot, item in pairs(items) do
        print(("  Слот %3d: %-40s x%d  (%s)"):format(
            slot,
            item.name,
            item.count,
            item.displayName or item.name
        ))
    end
    print("----------------------------")
end

--- Выгрузить предметы из инвентаря игрока в сундук
-- @param filter  таблица-фильтр (nil = все предметы)
local function exportToChest(filter)
    local moved = manager.exportItem(chest, filter or {})
    if moved > 0 then
        print(("✔ Выгружено %d предметов в %s"):format(moved, chest))
    else
        print("✖ Ничего не выгружено (нет подходящих предметов или сундук полон).")
    end
    return moved
end

--- Загрузить предметы из сундука в инвентарь игрока
-- @param filter  таблица-фильтр (nil = все предметы)
local function importFromChest(filter)
    local moved = manager.importItem(chest, filter or {})
    if moved > 0 then
        print(("✔ Загружено %d предметов из %s"):format(moved, chest))
    else
        print("✖ Ничего не загружено (нет подходящих предметов или инвентарь полон).")
    end
    return moved
end

--- Выгрузить всё содержимое инвентаря в сундук
local function exportAll()
    return exportToChest(nil)
end

--- Забрать всё содержимое сундука в инвентарь
local function importAll()
    return importFromChest(nil)
end

-- ------------------------------------------------------------
-- 4. Меню
-- ------------------------------------------------------------
local function showMenu()
    print()
    print("========== МЕНЮ ==========")
    print(" 1. Показать содержимое инвентаря")
    print(" 2. Выгрузить ВСЁ в сундук")
    print(" 3. Загрузить ВСЁ из сундука")
    print(" 4. Выгрузить по фильтру")
    print(" 5. Загрузить по фильтру")
    print(" 6. Выход")
    print("==========================")
    write("Выберите действие: ")
end

--- Запрос фильтра у пользователя
local function askFilter()
    write("Введите имя предмета (например, minecraft:cobblestone): ")
    local name = read()
    if not name or name == "" then return nil end

    write("Количество (Enter = все): ")
    local cntStr = read()
    local filter = { name = name }
    if cntStr and cntStr ~= "" then
        local cnt = tonumber(cntStr)
        if cnt then filter.count = cnt end
    end
    return filter
end

-- ------------------------------------------------------------
-- 5. Основной цикл
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
        print("Выход.")
        break

    else
        print("Неверный выбор. Попробуйте снова.")
    end

    -- Небольшая пауза, чтобы экран не «мигал» при быстрых нажатиях
    sleep(0.5)
end
