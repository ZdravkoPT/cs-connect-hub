# CS 1.6 Matchmaking Platform — Merged Final Specification (v2)

This locks the original 43-section specification and folds in both research batches. Nothing below replaces your architecture; every item is attached to an existing module and to a phase, so the build order stays intact.

## What changes vs v1

- Rating gets four concrete anti-abuse rules it was missing (derank floor, loss shield, participation scaling, disconnect data preservation).
- Match running switches to a proven no-admin lifecycle (ready flow, warmup, LO3, surrender, timeout, backfill).
- Low-population fallbacks become a real subsystem instead of a note.
- Trust score gets defined input signals instead of "behaviour".
- Anti-cheat gains reviewer tooling and file-hash verification, not just detectors.
- Progression gains a season/battle-pass structure with one bridged currency.
- A public API, Discord bridge and clip pipeline become first-class, phase 10.

## Section additions, by module

### server_core / match_state
- Full no-admin match lifecycle: `.ready` flow, warmup DM, live-on-three restart, surrender vote, technical timeout, vote-kick, mid-match reconnect with backfill slot, auto temp-ban on ranked ragequit, configurable overtime presets.
- Per-match isolated server instance where infrastructure allows, with spectator relay for casting.
- Feature-flag gate on every item added here.

### lobby / queue / matchmaking
- Seeker rotation queue: turn order, not random pick.
- Seeker count as a formula of population, not a fixed split.
- Spectator-only lobby server with `!queue`, `!status`, `!lastmatch`; players redirect to the match server on lock.
- 7-day mutual avoid list.
- Priority tickets earned in low-population modes, spendable to skip ranked queue.
- Captain alternating map bans onto a freshly wiped server.
- Fallback ladder when the pool is short: 1-seeker HNS, Maniac one-vs-all, 1v1 DM, Bricks, LJ duel.

### mode_hns
- Ownage streak counter for repeat-surviving hiders (HUD stat + clip marker).
- Frag economy: tags and survival earn frags, spent in a tiny buymenu. Unranked only.
- Two scrim formats as separate ladders: win-streak and point-based.
- Halfway vote between classic and DM-style HNS. Unranked only.
- Distance-only reveal ping on an interval, tuned per rank tier, against infinite camping.
- Per-side footstep audibility and flash immunity as ranked/unranked presets.
- Hide-spot heatmap collected from match data, exported for balance and caster overlays.
- Ranked physics stay untouched by all of the above.

### mode_kz / jumpstats / record_system
- Frames-on-ground and prestrafe-type readout before takeoff.
- Per-strafe overlap and desync stats on top of gain/loss/sync.
- Practice toolkit: `/cp`, `/tp`, `/pause`, with ground-only checkpoint enforcement.
- `/goto` teleport to another player's position.
- Persistent current-map WR HUD.
- Split ladders: Pro vs Nub route, and checkpoint-allowed vs strict single run.
- Cross-network record comparison per map.
- `/measure` distance tool.
- Runtime jump-pad and block placement tools for event courses; event-only, never on ranked maps.
- Unified Movement Rating blending KZ, bhop and parkour percentiles.

### rating_system
- MMR delta from aggregated score-per-minute comparison between opponents, feeding the Glicko-2 update as the performance component.
- Participation-time scaling on every rating change.
- Anti-derank floor at half of season-peak rating.
- Reduced loss at low ranks.
- Disconnect data preservation until reconnect or map change.
- Previous seasons archived and viewable, never deleted.

### trust / restricted queue / calibration
- Defined trust inputs: playtime, account age, profile completeness, report history, admin actions, disconnect history, demo-review outcomes, weighted per mode.
- Admin `/checktrust` lookup.
- New-account throttling on chat, sprays and ranked eligibility until minimum playtime.
- Peer vouching: high-reputation players can lift a new account's restriction early.
- Short recalibration series after long inactivity instead of instant ladder re-entry.
- Fake-client and bot-flood detection on queue servers.
- Name-spam and admin-impersonation tagging before ranked entry.

### anti_cheat / demo_system
- Reviewer demo tool: ESP and sound-ESP toggles, ping graph, sensitivity and interp readout, crosshair-path graph for snap-aim.
- Timestamped demo bookmarks and comments in a shared database, multi-reviewer.
- Spin-hack rotation anomaly detector.
- Client file-hash verification before ranked match start.
- Admin shadow-watch: semi-transparent walls and suspect beacon while dead, no visible spectate.
- Retroactive ban of an already-disconnected offender.
- Movement-consistency anomaly flag using your own strafe telemetry as the human baseline.
- Volunteer reviewer bounty queue with voting and audit trail.
- Auto-demo on every PB, WR and ranked match; auto-clip on WR, ace and clutch.

### Progression, coins, clans
- Season structure: ~40 tiers, 25+ mission types, rotating daily and weekly missions, cumulative rewards.
- Cosmetics persist across seasons; tier progress resets; deliberate frozen gap week between seasons.
- One currency bridged across ranked rewards, shop and a coin sink; admin grant menu.
- VIP perks unlockable by grinding, not only by paying.
- Reduced-but-nonzero warmup and bot XP.
- Clan-vs-clan seasonal ladder derived from individual results.
- Mentorship bonus for veteran-plus-newcomer duo queue.
- Meta-achievements spanning several modes.

### hud_system / chat_system / voice_system
- MOTD used as a mini app surface: season progress, missions, countdown; works on vanilla clients.
- Chat framework with placeholder tokens for rank, season and coin prefixes.
- Spectator-count HUD element; instant even-teams captain command.
- Regional radio and voice packs per player locale.
- Personal visibility toggles: hide player models, hide water, fog/fade aids.
- Dead-player messages visually distinct everywhere, including the Discord relay.
- NextClient-enhanced HUD with vanilla fallback.

### API / web / Discord
- JWT-secured REST API: top, profile, match history, records, clan and season endpoints.
- Two-way Discord bridge that sleeps on an empty server and wakes on first join; event feed with country flags.
- Discord `/make-teams` from a voice channel and `/go` timed map vote.
- Live latest-records ticker on the site homepage.
- OBS browser-source widgets: live rank, current-map WR, kill feed.
- Public cosmetic showcase profile page.

### Ops
- Official sub-plugin extension API so add-ons never touch core code.
- Missions and reward tables fully config-driven; no recompiling.
- Automatic season scheduling by calendar.
- Multi-language from day one (BG, EN first; RU, TR, RO next).
- Match server capacity scaling with queue load.

## Phase mapping

- PHASE 2: extension API, feature flags, config-driven tables, i18n scaffolding, chat framework.
- PHASE 3: spectator lobby, queue commands, avoid list, new-account throttling.
- PHASE 4: match lifecycle (ready, warmup, LO3, surrender, timeout, backfill), 1v1 DM.
- PHASE 5: all KZ/JumpStats items, practice toolkit, split ladders, PB/WR demos, Movement Rating.
- PHASE 6: HNS additions, fallback ladder, seeker rotation, reveal ping, heatmap collection.
- PHASE 7: rating rules, map bans, per-match server, auto-clips.
- PHASE 8: season structure, currency bridge, clan ladder, mentorship, meta-achievements.
- PHASE 9: trust inputs, vouching, recalibration, all anti-cheat and reviewer tooling.
- PHASE 10: REST API, Discord bridge, OBS widgets, showcase pages, server scaling.

## Unchanged rule

Per module: write, compile, install, start, test, verify, then next. Nothing counts as done because it is written.

## First action after approval

No code from this list yet. Verify AMX Mod X first: start the server, run `meta list`, `amxx version`, `amxx plugins`, then build `server_test.sma` as the first real plugin.
