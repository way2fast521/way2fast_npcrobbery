Config = {}

Config.HandsUpDuration  = 15000   -- How long the NPC keeps hands up before being auto-released (ms)
Config.RobberyCooldown  = 300000  -- Per-NPC cooldown between robberies (ms)
Config.AimDistance      = 8.0     -- Max distance to trigger hands-up (metres)
Config.RequireWeapon    = true    -- Player must be armed to rob
Config.RobbingDuration  = 5000   -- Search progress bar duration (ms)
Config.NotifyPosition   = 'top-right'


-- ─────────────────────────────────────────────
Config.Dispatch = {
    type        = 'tk_dispatch', -- or 'ps_dispatch', 'cd_dispatch', 'custom', false
    enabled     = true,
    chance      = 35,
    code        = '10-31',
    title       = 'Armed Robbery - Pedestrian',
    priority    = 'Priority 2',
    jobs        = { 'police' },
    blip        = { sprite = 357, color = 1, scale = 1.0 },
    customEvent = 'npc_robbery:dispatch', -- only used when type = 'custom'
}

-- ─────────────────────────────────────────────
-- Loot table
-- ─────────────────────────────────────────────
Config.LootTable = {
    { name = 'money',      label = 'Cash',        min = 10, max = 200, chance = 90 },
    { name = 'phone',      label = 'Phone',        min = 1,  max = 1,  chance = 30 },
    { name = 'wallet',     label = 'Wallet',       min = 1,  max = 1,  chance = 50 },
    { name = 'watch',      label = 'Watch',        min = 1,  max = 1,  chance = 20 },
    { name = 'cigarettes', label = 'Cigarettes',   min = 1,  max = 3,  chance = 40 },
    { name = 'sandwich',   label = 'Sandwich',     min = 1,  max = 2,  chance = 25 },
}

Config.MinItems = 1
Config.MaxItems = 3

-- ─────────────────────────────────────────────
-- Animations
-- ─────────────────────────────────────────────
Config.Animations = {
    -- NPC hands-up
    handsUp = {
        dict = 'random@mugging3',
        anim = 'handsup_standing_base',
        flag = 49,
    },
    -- Player frisk (alternates between both phases for the full duration of the progress bar)
    frisking = {
        phase1 = { dict = 'missbigscore2aig_7@driver', anim = 'boot_r_loop', flag = 49 },
        phase2 = { dict = 'missbigscore2aig_7@driver', anim = 'boot_l_loop', flag = 49 },
    },
}
