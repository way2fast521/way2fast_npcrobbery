# npc_robbery

Rob pedestrian NPCs at gunpoint. Aim at an NPC → they freeze and put their hands up → use Eye Target to search them → realistic pat-down animation plays → receive random loot → NPC flees.

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_target](https://github.com/overextended/ox_target)

## Installation

1. Drop `npc_robbery` into your `resources/` folder.
2. Add `ensure npc_robbery` to `server.cfg`.
3. Make sure item names in `Config.LootTable` match your ox_inventory items.
4. Set `Config.Dispatch.type` to match your dispatch resource (see below).

## Dispatch

Change one line in `config.lua` to match whatever dispatch resource you run:

```lua
Config.Dispatch.type = 'tk_dispatch'  -- or 'ps_dispatch', 'cd_dispatch', 'custom', false
```

| Value | Behaviour |
|---|---|
| `'tk_dispatch'` | Calls `exports.tk_dispatch:addCall(...)` |
| `'ps_dispatch'` | Calls `exports['ps-dispatch']:addCall(...)` |
| `'cd_dispatch'` | Calls `exports.cd_dispatch:addCall(...)` |
| `'custom'` | Fires the event in `Config.Dispatch.customEvent` with all data as a table — hook into it yourself |
| `false` | Dispatch disabled |

## Configuration

All options are in `config.lua`. Cooldowns, distances, loot table, dispatch settings and animations are all tweakable.
