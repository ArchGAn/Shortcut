# Shortcut

Shorthand-style commands for Ashita v4. Type less, play more.

## Quick Start

```
//[action] [partial name]
```

| You type | What happens |
|----------|--------------|
| `//cure` | Cures your current target |
| `//cure sam` | Finds "Samurai" nearby, cures them |
| `//dia gob` | Finds nearest "Goblin", casts Dia |
| `//provoke gob` | Finds nearest "Goblin", uses Provoke |
| `//fight gob` | Finds nearest "Goblin", pet attacks |

**The partial name always wins.** If you have a Goblin targeted but type `//cure sam`, it will cure Samurai, not the Goblin.

## Installation

1. Place `shortcut.lua` in `Ashita/addons/shortcut/`
2. Load: `/addon load shortcut`
3. Help: `/sc`

## Safety

**Undetectable.** The addon only:
- Reads entity names from memory (client-side, invisible to server)
- Sends normal commands: `/target`, `/ma`, `/ja`, `/pet`, `/ws`

The server sees identical traffic to manual typing. No packets modified, no memory written, no automation.

```lua
-- All commands go through Ashita's official API:
AshitaCore:GetChatManager():QueueCommand(1, '/ma "Cure" "Samurai"');
```

## Command Types

Automatically detected:

| Type | Example | Output |
|------|---------|--------|
| Spell | `//cure4 sam` | `/ma "Cure IV" "Samurai"` |
| Ability | `//provoke gob` | `/ja "Provoke" <t>` |
| Pet | `//fight gob` | `/pet "Fight" <t>` |
| Weapon Skill | `//raging axe gob` | `/ws "Raging Axe" <t>` |
| Ranged | `//ra gob` | `/ra <t>` |
| Item | `//potion` | `/item "Potion" <t>` |

## Smart Targeting

- `//cure` → searches **players/party**
- `//dia` → searches **mobs**
- Healing spells auto-target players
- Offensive spells auto-target mobs

## Standard Targets

These pass through directly:
- `//cure <me>` → cures yourself
- `//cure <t>` → cures current target
- `//cure <st>` → opens subtarget

## License

Free to use and modify.
