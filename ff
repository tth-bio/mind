print("==================================================")
print("  Inventory Manager Controller")
print(("  Player: %s (%s)"):format(ownerName, ownerUuid))
print(("  Storage: %s"):format(chest))

-- Безопасный вывод размера инвентаря
local okSize, invSize = pcall(function() return manager.size() end)
if okSize and invSize then
    print(("  Inventory size: %d slots"):format(invSize))
else
    print("  Inventory size: N/A (method 'size' not available)")
end

-- Безопасный вывод свободных слотов
local okEmpty, emptySlots = pcall(function() return manager.getEmptySlots() end)
if okEmpty and emptySlots then
    print(("  Empty slots: %d"):format(emptySlots))
else
    print("  Empty slots: N/A (method 'getEmptySlots' not available)")
end

print("==================================================")
print()
