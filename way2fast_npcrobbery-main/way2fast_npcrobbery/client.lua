local robbedNPCs  = {}
local handsUpNPCs = {}
local targetZones = {}

-- ─────────────────────────────────────────────
-- Preload animation dicts on resource start
-- Eliminates the delay the first time they play
-- ─────────────────────────────────────────────
CreateThread(function()
    local dicts = {
        'random@mugging3',
        'missbigscore2aig_7@driver',
    }
    for _, dict in ipairs(dicts) do
        if not HasAnimDictLoaded(dict) then
            RequestAnimDict(dict)
            while not HasAnimDictLoaded(dict) do Wait(10) end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function notify(msg, ntype)
    lib.notify({
        title       = 'Robbery',
        description = msg,
        type        = ntype or 'inform',
        position    = Config.NotifyPosition,
    })
end

local function isArmed()
    return GetSelectedPedWeapon(PlayerPedId()) ~= GetHashKey('WEAPON_UNARMED')
end

local function getAimedNPC()
    local ped = PlayerPedId()
    local _, target = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if not target or target == 0 or not DoesEntityExist(target) then return nil end
    if not IsEntityAPed(target) or IsPedAPlayer(target) then return nil end
    if #(GetEntityCoords(ped) - GetEntityCoords(target)) > Config.AimDistance then return nil end
    return target
end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        t = t + 10
        if t > 5000 then return false end
    end
    return true
end

-- ─────────────────────────────────────────────
-- Dispatch
-- Supports tk_dispatch, ps_dispatch, cd_dispatch,
-- custom event, or disabled via Config.Dispatch.type
-- ─────────────────────────────────────────────

local function triggerDispatch()
    local d = Config.Dispatch
    if not d.enabled then return end
    if math.random(100) > d.chance then return end

    local coords = GetEntityCoords(PlayerPedId())

    if d.type == 'tk_dispatch' then
        exports.tk_dispatch:addCall({
            title        = d.title,
            code         = d.code,
            priority     = d.priority,
            coords       = coords,
            showLocation = true,
            showGender   = true,
            playSound    = true,
            blip         = d.blip,
            jobs         = d.jobs,
        })

    elseif d.type == 'ps_dispatch' then
        exports['ps-dispatch']:addCall({
            title  = d.title,
            code   = d.code,
            coords = coords,
            jobs   = d.jobs,
            blip   = d.blip,
        })

    elseif d.type == 'cd_dispatch' then
        exports.cd_dispatch:addCall({
            job_table = d.jobs,
            coords    = coords,
            title     = d.title,
            code      = d.code,
            blip      = d.blip,
        })

    elseif d.type == 'custom' then
        -- Hook into this event to connect your own dispatch resource
        TriggerEvent(d.customEvent, {
            title    = d.title,
            code     = d.code,
            priority = d.priority,
            coords   = coords,
            jobs     = d.jobs,
            blip     = d.blip,
        })
    end
end

-- ─────────────────────────────────────────────
-- NPC lock / unlock
-- ─────────────────────────────────────────────

local function lockNPC(npc)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedFleeAttributes(npc, 0, true)
    SetPedCombatAttributes(npc, 17, true)
    SetPedCanRagdoll(npc, false)
    SetEntityVelocity(npc, 0.0, 0.0, 0.0)
end

local function unlockNPC(npc)
    FreezeEntityPosition(npc, false)
    SetEntityInvincible(npc, false)
    SetBlockingOfNonTemporaryEvents(npc, false)
    SetPedCanRagdoll(npc, true)
end

-- ─────────────────────────────────────────────
-- ox_target helpers
-- ─────────────────────────────────────────────

local function removeTarget(npc)
    if not targetZones[npc] then return end
    exports.ox_target:removeLocalEntity(npc, { 'rob_npc_' .. tostring(npc) })
    targetZones[npc] = nil
end

-- ─────────────────────────────────────────────
-- Frisk animation loop
-- Alternates phases until doneRef.done is true
-- ─────────────────────────────────────────────

local function playFriskAnims(playerPed, doneRef)
    local phases = {
        Config.Animations.frisking.phase1,
        Config.Animations.frisking.phase2,
    }
    local i = 1
    while not doneRef.done do
        local p = phases[i]
        if loadDict(p.dict) then
            TaskPlayAnim(playerPed, p.dict, p.anim, 8.0, -8.0, 1500, p.flag, 0, false, false, false)
        end
        Wait(1400)
        i = (i % #phases) + 1
    end
    ClearPedTasks(playerPed)
end

-- ─────────────────────────────────────────────
-- Add ox_target zone to NPC
-- ─────────────────────────────────────────────

local function addTarget(npc)
    if targetZones[npc] then return end

    exports.ox_target:addLocalEntity(npc, {
        {
            name     = 'rob_npc_' .. tostring(npc),
            icon     = 'fas fa-hand-holding-usd',
            label    = 'Search person',
            distance = 2.5,
            onSelect = function()
                local netId = NetworkGetNetworkIdFromEntity(npc)

                -- Client-side cooldown check
                if robbedNPCs[netId] then
                    local elapsed = GetGameTimer() - robbedNPCs[netId]
                    if elapsed < Config.RobberyCooldown then
                        local secs    = math.ceil((Config.RobberyCooldown - elapsed) / 1000)
                        local mins    = math.floor(secs / 60)
                        local remSecs = secs % 60
                        notify(string.format('Already robbed. Wait %dm %ds.', mins, remSecs), 'error')
                        return
                    end
                end

                if not handsUpNPCs[npc] then
                    notify('Aim your weapon at them first!', 'error')
                    return
                end

                local playerPed = PlayerPedId()

                -- Lock NPC completely and keep hands-up animation running
                lockNPC(npc)
                ClearPedTasks(npc)
                if loadDict(Config.Animations.handsUp.dict) then
                    TaskPlayAnim(npc, Config.Animations.handsUp.dict, Config.Animations.handsUp.anim,
                        8.0, -8.0, -1, Config.Animations.handsUp.flag, 0, false, false, false)
                end

                -- Face player toward NPC
                local npcCoords    = GetEntityCoords(npc)
                local playerCoords = GetEntityCoords(playerPed)
                SetEntityHeading(playerPed, GetHeadingFromVector_2d(
                    npcCoords.x - playerCoords.x,
                    npcCoords.y - playerCoords.y
                ))

                -- Start frisk animations immediately in a side thread
                local animDone = { done = false }
                CreateThread(function()
                    playFriskAnims(playerPed, animDone)
                end)

                -- Progress bar runs in parallel
                local success = lib.progressBar({
                    duration     = Config.RobbingDuration,
                    label        = 'Searching...',
                    useWhileDead = false,
                    canCancel    = false,
                    disable      = { car = true, move = true, sprint = true, combat = true },
                })

                -- Stop animation loop and release NPC
                animDone.done = true
                unlockNPC(npc)

                if success then
                    robbedNPCs[netId] = GetGameTimer()
                    TriggerServerEvent('npc_robbery:loot', netId)
                    handsUpNPCs[npc] = nil
                    removeTarget(npc)

                    -- NPC flees after being robbed
                    if DoesEntityExist(npc) then
                        ClearPedTasks(npc)
                        SetPedFleeAttributes(npc, 0, false)
                        SetPedCanRagdoll(npc, true)
                        TaskSmartFleePed(npc, playerPed, 100.0, -1, false, false)
                    end
                end
            end,
        },
    })

    targetZones[npc] = true
end

-- ─────────────────────────────────────────────
-- Trigger hands-up on NPC
-- ─────────────────────────────────────────────

local function makeHandsUp(npc)
    if handsUpNPCs[npc] then return end
    handsUpNPCs[npc] = true

    ClearPedTasks(npc)
    lockNPC(npc)

    if loadDict(Config.Animations.handsUp.dict) then
        TaskPlayAnim(npc, Config.Animations.handsUp.dict, Config.Animations.handsUp.anim,
            8.0, -8.0, -1, Config.Animations.handsUp.flag, 0, false, false, false)
    end

    addTarget(npc)
    notify('Keep them at gunpoint! Use 👁️ to search them.', 'success')
    triggerDispatch()

    -- Auto-release after HandsUpDuration
    SetTimeout(Config.HandsUpDuration, function()
        if handsUpNPCs[npc] then
            handsUpNPCs[npc] = nil
            removeTarget(npc)
            if DoesEntityExist(npc) then
                unlockNPC(npc)
                ClearPedTasks(npc)
            end
        end
    end)
end

-- ─────────────────────────────────────────────
-- Main loop – detect aiming, keep NPCs locked
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(100)

        if Config.RequireWeapon and not isArmed() then
            -- Player holstered – release all hands-up NPCs immediately
            for npc, _ in pairs(handsUpNPCs) do
                handsUpNPCs[npc] = nil
                removeTarget(npc)
                if DoesEntityExist(npc) then
                    unlockNPC(npc)
                    ClearPedTasks(npc)
                end
            end
            goto continue
        end

        local aimedNPC = getAimedNPC()
        if aimedNPC then makeHandsUp(aimedNPC) end

        -- Every 100ms: keep all active hands-up NPCs fully locked
        -- and re-apply the animation if the game cleared it
        for npc, _ in pairs(handsUpNPCs) do
            if DoesEntityExist(npc) then
                lockNPC(npc)
                if not IsEntityPlayingAnim(npc, Config.Animations.handsUp.dict, Config.Animations.handsUp.anim, 3) then
                    if loadDict(Config.Animations.handsUp.dict) then
                        TaskPlayAnim(npc, Config.Animations.handsUp.dict, Config.Animations.handsUp.anim,
                            8.0, -8.0, -1, Config.Animations.handsUp.flag, 0, false, false, false)
                    end
                end
            else
                handsUpNPCs[npc] = nil
                removeTarget(npc)
            end
        end

        ::continue::
    end
end)

-- ─────────────────────────────────────────────
-- Receive loot result from server
-- ─────────────────────────────────────────────

RegisterNetEvent('npc_robbery:showLoot', function(lootList)
    if not lootList or #lootList == 0 then
        notify('The person had nothing on them.', 'error')
        return
    end
    local lines = ''
    for _, item in ipairs(lootList) do
        lines = lines .. string.format('\n• %s x%d', item.label, item.amount)
    end
    lib.notify({
        title       = 'You robbed:',
        description = lines,
        type        = 'success',
        position    = Config.NotifyPosition,
        duration    = 6000,
    })
end)
