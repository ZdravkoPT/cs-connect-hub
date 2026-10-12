# CS 1.6 Matchmaking Platform — Roadmap

## Repository
- [x] Repository connected: github.com/ZdravkoPT/CS1.6 (private, Pawn, via GitHub connector)
  - Contains full HLDS server tree under server/ (cstrike, addons/amxmodx default install)
  - plugins.ini = stock AMXX defaults + whistle.amxx; no custom plugins yet
  - CS16-Server.rar at root is a 134-byte Git LFS pointer, not the real archive
- [ ] Waiting for the user's instructions on what to do with the repository

## Research / ideas
- [x] Batch 3 — paid plugin shops and what buyers get (result read)
- [x] Batch 4 — AMX Mod X plugin threads, deep pages (result read)
- [x] Batch 5 — event, tournament and video formats (result read)
- [x] Batch 6 — regional communities RU/TR/GR/RO/PL/BR/ZH (result read)
- [x] Batch 7 — player wishlists and churn reasons (result read)
- [ ] Merge all new ideas into specification v3
- [ ] Verify no duplicate of an already-specified feature

## Spec additions found so far (to fold into v3)
- [ ] End-of-round celebration: dance/animation + music (unranked only)
- [ ] Anti-frag / anti-block / forced auto-team-balance enforcement
- [ ] Boosting detection with escalating punishment
- [ ] Freeze grenade (smoke converted to area freeze) for HNS fallback modes
- [ ] Grenade trail visuals for caster readability
- [ ] Per-map lighting (hns_lights) and skyname presets
- [ ] Screen fade color for seekers during hiding time
- [ ] Point system variants: headshot points, suicide/TK point penalty
- [ ] Built-in server rules + admin contact panel

## Build (blocked on user's machine)
- [ ] Start server, run `meta list`, `amxx version`, `amxx plugins` and paste output
- [ ] `server_test.sma` — WRITTEN and pushed to repo (server/cstrike/addons/amxmodx/scripting/). Next: user compiles, installs, loads, confirms in game
- [x] v0.1 pushed (abd7785): core, lobby, match, 1v1, HNS, rating, cfg, BG/EN lang — compiles 0 errors
- [ ] User installs v0.1 and reports errors
- [ ] Next: KZ/JumpStats, captain/draft/map vote, MySQL, trust/anti-cheat
