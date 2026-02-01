# Shortcut

Shorthand-style commands for Ashita v4. Type less, play more.

## ⚠️ Not the Shorthand You Know

This is **not** a full Shorthand replacement. Due to Lua addon limitations, partial name targeting (`//cure sam`) is unreliable.

**What works reliably:** Target tokens
**What's hit-or-miss:** Partial name search

## Quick Start

Use in conjunction with Shorthand anyway. 

```
//[action] <target>
```

| You type | What happens |
|----------|--------------|
| `//cure` | Cures `<t>` (current target) |
| `//cure <me>` | Cures yourself |
| `//cure <stpc>` | Opens player picker, then cures |
| `//dia <stnpc>` | Opens mob picker, then casts Dia |
| `//cure <bt>` | Cures battle target (whoever has hate) |
| `//fight` | Pet attacks `<t>` |
| `//ra` | Ranged attack `<t>` |

## Target Tokens (Reliable ✅)

| Token | Target |
|-------|--------|
| `<t>` | Current target |
| `<bt>` | Battle target (mob your party is fighting) |
| `<me>` | Yourself |
| `<st>` | Subtarget cursor (any) |
| `<stpc>` | Subtarget cursor (players only) |
| `<stnpc>` | Subtarget cursor (NPCs/mobs only) |
| `<pet>` | Your pet |
| `<p0>`-`<p5>` | Party members |

These always work because they're native FFXI tokens.

**Best combos:**
- `//cure <stpc>` - Cure, then pick any player
- `//dia <stnpc>` - Dia, then pick any mob
- `//cure <bt>` - Cure whoever has hate

## Partial Names (Unreliable ⚠️)

`//cure sam` attempts to:
1. `/target "Samurai"`
2. Wait 0.5s
3. `/ma "Cure" <t>`

This can fail if:
- `/target` doesn't find the name
- Target doesn't register in time
- Multiple entities match

**Use at your own risk.** For reliability, stick to tokens.

## Installation

1. Place `shortcut.lua` in `Ashita/addons/shortcut/`
2. Load: `/addon load shortcut`
3. Help: `/sc`

## Command Types

Auto-detected:

| Type | Example | Output |
|------|---------|--------|
| Spell | `//cure4 <me>` | `/ma "Cure IV" <me>` |
| Ability | `//provoke` | `/ja "Provoke" <t>` |
| Pet | `//fight` | `/pet "Fight" <t>` |
| Weapon Skill | `//raging axe` | `/ws "Raging Axe" <t>` |
| Ranged | `//ra` | `/ra <t>` |
| Item | `//potion <me>` | `/item "Potion" <me>` |

## Spell Formats

Both number and roman numeral formats work:

| You type | Becomes |
|----------|---------|
| `//cure2` | `Cure II` |
| `//cure3` | `Cure III` |
| `//cureii` | `Cure II` |
| `//cureiii` | `Cure III` |
| `//fireiv` | `Fire IV` |
| `//protectv` | `Protect V` |
| `//stonega` | `Stonega` |

## Safety

**Undetectable.** Only sends vanilla commands:
- `/target "Name"`
- `/ma "Spell" <t>`
- `/ja "Ability" <t>`
- etc.

No packets modified. No memory written. Just faster typing.

## Why Not Full Shorthand?

Shorthand was a DLL plugin with deeper access. Lua addons can only:
- Read memory (not write)
- Queue commands (not inject packets)
- Use timers (not instant targeting)

The 0.5s delay between `/target` and action is the limitation.

## License

Free to use and modify.
