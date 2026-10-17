# TargetFrameBuff
TargetFrameBuff allows you to view up to 32 buffs & 16 debuffs on a target in the default UI.

**Layout:**
- **Buffs**: 32 buffs displayed above the target frame, stacked upward in rows of 5, 11, 11 and 5
- **Debuffs**: 16 debuffs displayed below the target frame in 4-4-8 layout (no gap)

**Remaining time (optional):**
With [ClassicAPI](https://github.com/brues-code/ClassicAPI) installed, each buff and debuff shows how long it has left, turning red in the last 5 seconds. Without ClassicAPI the addon works the same, just without timers.

- Auras that were already up before you logged in, or before you first saw them land, show no timer.
- On WoW 1.18.1 clients, debuffs the server puts into buff slots (once a target has 16 debuffs) are shown after the target's buffs, with correct tooltips.

Supports 1.12.1, but will most likely work on any vanilla patch.

Based on: https://wow.curseforge.com/projects/project-949

### Setup
Rename TargetFrameBuff-master to TargetFrameBuff and drag it into your addon folder.
Start up WoW and target a player with more than 5 buffs.
