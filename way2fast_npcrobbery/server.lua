local robbedCache = {} -- [npcNetId] = os.time()

-- ─────────────────────────────────────────────
-- Generate random loot from the config table
-- ─────────────────────────────────────────────

local function generateLoot()
    local pool = {}

    for _, entry in ipairs(Config.LootTable) do
        if math.random(100) <= entry.chance then
            pool[#pool + 1] = entry
        end
    end

    if #pool == 0 then return {} end

    local count  = math.min(#pool, math.random(Config.MinItems, Config.MaxItems))
    local result = {}

    for i = 1, count do
        local idx   = math.random(1, #pool)
        local entry = table.remove(pool, idx)
        result[#result + 1] = {
            name   = entry.name,
            label  = entry.label,
            amount = math.random(entry.min, entry.max),
        }
    end

    return result
end

-- ─────────────────────────────────────────────
-- Event: rob NPC
-- ─────────────────────────────────────────────

RegisterNetEvent('npc_robbery:loot', function(npcNetId)
    local src = source

    -- Server-side cooldown (double-checks the client)
    if robbedCache[npcNetId] then
        local elapsed = os.time() - robbedCache[npcNetId]
        if elapsed < (Config.RobberyCooldown / 1000) then
            TriggerClientEvent('ox_lib:notify', src, {
                title       = 'Robbery',
                description = 'This person has already been robbed recently.',
                type        = 'error',
            })
            return
        end
    end

    robbedCache[npcNetId] = os.time()

    local loot = generateLoot()

    if #loot == 0 then
        TriggerClientEvent('npc_robbery:showLoot', src, {})
        return
    end

    -- Give items via ox_inventory
    for _, item in ipairs(loot) do
        exports.ox_inventory:AddItem(src, item.name, item.amount)
    end

    -- Send loot list back to client for the notification
    TriggerClientEvent('npc_robbery:showLoot', src, loot)

    print(string.format('[npc_robbery] %s (id: %s) robbed NPC (netId: %s)', GetPlayerName(src), src, npcNetId))
end)
