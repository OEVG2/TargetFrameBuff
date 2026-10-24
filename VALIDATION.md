# TargetFrameBuff v0.9.1 validation

14 simulated Lua 5.1 regression scenarios passed, plus XML parsing, ZIP integrity,
and patch applicability against the original GitHub baseline.

New checks cover countdown ticks with no aura reads, silent recast detection within
0.5 seconds, target-only UNIT_AURA filtering, target changes, idle countdown behavior,
and restarting countdowns when previously unknown expiration becomes available.

Aura refreshes run through the stock update hook, target aura/target-change events,
and a 0.5-second fallback while the target frame is visible. Countdown ticks use
cached expiration every 0.2 seconds and visit only active timers. Event traffic may
cause additional scans; the polling reduction is five to two scans per second.
No in-game CPU or FPS improvement has been measured. Live event delivery/rendering
still needs an in-game check. Saved settings are preserved; keep ShaguTweaks Debuff
Timer disabled to prevent duplicate countdown text.

Install by replacing your TargetFrameBuff folder with the folder in the v0.9.1 ZIP,
then reload. Verify recasts, target switching, and timers expiring during combat.
Automated validation simulates the game API; verify behavior in your client.
