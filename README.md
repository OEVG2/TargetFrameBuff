# TargetFrameBuff v0.9.1

Shows up to 32 upper-row icons and 16 lower-row debuffs on the default target frame.
The existing 5-11-11-5 buff layout and 4-4-8 debuff layout are preserved.
With ClassicAPI, harmful auras beyond the first 16 use available upper-row icons.

## Installation

Back up your existing TargetFrameBuff folder, then replace it with the TargetFrameBuff
folder from the ZIP under Interface/AddOns. Restart the client or reload the UI.
ClassicAPI is optional; version 1.17.3 was reviewed for this update.
For working reverse sweeps and edges, use ClassicAPI 1.17.1 or newer.

## Changes in v0.9.1

- Refresh auras on target changes and target aura events, with a 0.5-second fallback.
- Update only active countdowns every 0.2 seconds using cached expiration; stop
  countdown work when none remain. Silent timing changes can take up to 0.5 seconds to appear.
- Use GetAuraSlots with reusable buffers and UnitAuraBySlot where available; retain
  the positional UnitAura fallback for older ClassicAPI. Slot IDs never survive a scan.
- Display stack counts for upper-row buffs and overflow debuffs, with debuff-type borders.
- Gold borders identify enemy buffs ClassicAPI says you or your pet can remove.
- Optional reverse cooldown sweeps; countdown and stack text draw above the sweep.
- Saved settings, a ClassicAPI AddOn Options panel, and vanilla-compatible slash commands.
- Guard against an aura disappearing immediately before its tooltip opens.

## Settings

Run /tfb to open AddOn Options when available, or show command help otherwise.

| Command | Action |
| --- | --- |
| /tfb timers on or off | Toggle countdown text (default on) |
| /tfb highlight on or off | Toggle removable-buff borders (default on) |
| /tfb sweeps on or off | Toggle cooldown sweeps (default off) |
| /tfb size 6-20 | Set countdown font size (default 9) |
| /tfb warning 0-30 | Seconds remaining at which text turns red (default 5) |
| /tfb reset | Restore defaults |

Without ClassicAPI the original native aura display remains available without timers,
highlighting or sweeps. Settings are retained for use when ClassicAPI is installed.

Disable ShaguTweaks Unit Frames > Debuff Timer when using these countdowns,
to prevent overlapping timer text.

## Timing limitations

ClassicAPI timings are best-effort. Unobserved applications and certain max-stack
refreshes can have unknown expiration. Unknown or expired timers hide their text
and sweep; the icon stays visible while the aura remains listed by the API.
ClassicAPI controls aura ordering and puts your own auras first.

## Validation

14 automated scenarios passed using Lua 5.1 with a simulated WoW API; XML parses.
This is not a live WoW 1.12/1.18.1 test or an exact Lua 5.0 runtime test.
See VALIDATION.md for remaining in-game checks.

Based on https://wow.curseforge.com/projects/project-949
Original author: lua@lumpn.de (modified).

