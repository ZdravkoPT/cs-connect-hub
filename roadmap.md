# CS 1.6 Matchmaking Platform — Roadmap

## Repository
- [x] Repository connected: github.com/ZdravkoPT/CS1.6 (private, Pawn, via GitHub connector)
- [x] v0.1 pushed (abd7785): core, lobby, match, 1v1, HNS, rating, cfg, BG/EN lang
- [x] v0.2 pushed: cs16_trust, cs16_kz, cs16_jumpstats, cs16_mapvote (.sma), cs16_maps.ini, plugins-cs16.ini (trust loads before lobby)
- [ ] User compiles the 4 new .sma with compile.exe (sandbox cannot run the 32-bit compiler), installs .amxx, starts server, reports errors

## Research / ideas
- [x] Batches 3-7 research done (shops, AMXX threads, events/video, regional communities, wishlists)
- [ ] Merge all new ideas into specification v3 (user not confirmed yet)
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
- [ ] User installs full plugin set and reports errors
- [ ] Next: captain draft + knife duel, MySQL (nvault is stopgap), website/Discord/NextClient
