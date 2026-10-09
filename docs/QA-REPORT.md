# v0.2.0 expansion verification — 9 October 2026

The current build replaces the six-room layout and late ending selector. It contains fourteen furnished rooms across two floors, a courtyard loop, main/service stairs, a kitchen side exit and a crouch-height crawlspace with two hatches. Keeper and release commit early and use different evidence, puzzles, encounter sequences and finales. Ending cinematics last approximately 35/40 seconds and support pause, a two-second skip hold, and gallery replay.

Engine verification: **52/52 tests pass**, with zero errors/failures/orphans (`report_26`). This includes both route gates, binding-order recovery, partial candle checkpoints, save-v1 migration, actual JSON save roundtrips, malformed nested-save rejection, 3D paths to every room, real crouch collision/headroom, scare cooldown/one-shot persistence, replay non-mutation and independent cinematic staging, localization, geometry clipping, mipmaps, shadow settings and headless audio cleanup. The latest release build repeats these checks before export.

Browser expansion checks use `tests/expansion-web.mjs`, silent headless Chromium/Firefox, isolated storage and a pointer-lock prohibition. They exercise real keyboard movement on the patio and both ramps, a creature climbing between floors, raycast interactions, held route commitment, eight-second candle trials, crawlspace traversal, bindings, route finales, cutscene pause/skip/replay, fullscreen safety and a fourteen-room low/high rendering sweep. They teleport between distant interaction locations and submit clock choices directly; they do not measure natural playthrough time or difficulty.

**All 15 expansion groups pass in both browsers**, with no reported script/browser errors. Both routes finish without microphone access. A pending keeper cinematic survives a real browser reload; ending replay leaves the checkpoint unchanged. Five Chromium microphone/capture/touch/portrait resilience groups also pass. Separate save/reload, final-photo/sewing render/skip, release-boot/fullscreen/no-debug-bridge, and native headless startup checks pass. Native startup reaches `BULONG_READY`, exits with code 0 and has an empty stderr log. Test-only headless audio no longer allocates unused looping playback voices.

The low/high room sweep reports 52–227 draws and 6,082–14,840 rendered triangles in Chromium; Firefox reports 52–178 and 6,082–9,336. These stay inside the 300-draw / 50,000-triangle guards. FPS snapshots include shader warm-up and competing background test/build work; they are diagnostics, not a controlled sustained-frame-rate benchmark or mobile hardware evidence.

Fixes found during implementation: a blocked guest-bedroom doorway; the kitchen wall cutting across the service ramp; oversized baul/altar hotspots hiding smaller objects; touch USE firing twice; room culling resurrecting unlit candles/fire; and architectural walls disappearing when an adjacent room was culled. Boundary walls now always render, while furnishings/lights retain conservative visibility culling.

The deterministic baked shell has zero competing coplanar faces. The compressed archives are approximately **11.96 MiB web** and **38.55 MiB Windows**, below the 15 MiB web target. Previous v0.1 archives remain intact. Baking is performed before exports, not during browser startup. Editor source changes invalidate stale baked geometry automatically.

Current browser results, room snapshots and screenshots: `build/qa/*-expansion-report.json` and `build/qa/*-v02-*.png`. Release startup evidence uses `build/qa/v02-release-report.json`; engine reports use `build/unit-results/report_*/results.xml`. Test-only audio muting does not remove playable-build sound, and no test should capture the laptop cursor. Owned browsers/servers are closed after validation.

Remaining gates: independent first-time pacing/scare/localization reviews, audible sound balance with headphones, physical Android/iOS performance and touch/microphone hardware, actual itch.io iframe behavior, and a full native Windows playthrough. No publishing or monetization changes were made. This is a playtest MVP, not a guarantee that every device runs it.

## Historical v0.1.0 verification — 22 September 2026

The results below describe the earlier layout and are retained as history, not fresh v0.2 benchmark claims.

Status: playable MVP / initial playtest candidate. Not published or certified for every device.

## Follow-up fixes: patio and fullscreen

The first player feedback exposed two gaps in the initial checks. The old entrance test teleported past the patio, and fullscreen had not been exercised. Those checks are now expanded.

- Reproduced the original collision failure from the real spawn: forward movement stopped at z=12.197, against the 10 cm patio lip. Yard, patio collision and the interior now share a flush floor.
- Fullscreen entry/exit and pointer-lock loss now pause safely and expose the cursor. Clicking **Return to the house** restores capture using a fresh browser gesture. The shell button hides during mouse capture; left-click can also retry capture during controlled gameplay.
- `npm run test:entry` checks actual spawn-to-patio-to-door movement and the return trip without teleporting, then fullscreen entry, mouse-look rotation and walking after resume, pointer-lock recovery, fullscreen exit and the real shell button. All four groups pass in both Chromium and Firefox. JSON reports and screenshots are in `build/qa/*-entry-fullscreen*` and `build/qa/*-fullscreen-*.png`.
- The ordinary progression test now walks across the patio from spawn. The release smoke test also checks fullscreen and resume with the debug bridge absent.

Browser implementation references: [pointer-lock activation requirements](https://developer.mozilla.org/en-US/docs/Web/API/Element/requestPointerLock) and [fullscreen change events](https://developer.mozilla.org/en-US/docs/Web/API/Element/requestFullscreen). Tests use the real browser APIs, not a mocked fullscreen flag; physical-device/host-iframe validation remains pending.

### Follow-up floor rendering correction

Player feedback revealed that raising the yard had left a coplanar concrete surface underneath the indoor wood, producing visible z-fighting. The outdoor slab is now split into a front section and two side sections, excluding the house footprint. The redundant patio finish was removed. Surfaces meet at the same height without sharing area.

Two geometry regression tests cover non-overlap and continuous level entry coverage. The overlap test failed against the broken geometry before the correction; all 21 tests pass afterward. `npm run test:floor` walks from the real spawn through the front door and captures indoor, threshold and patio views. This visual test uses touch mode and explicitly forbids pointer-lock requests so it cannot capture the laptop cursor.

## Global surface-stability update

The follow-up audit addressed more than the floor: static wall/beam/trim intersections now pass through a deterministic surface builder. Higher material layers own coplanar overlap; lower-priority geometry is clipped out, buried faces are removed, and the surviving mesh is still batched by material. The current house contains 299 authored boxes, resolves 108 shared-face priority cases, and has **zero remaining competing coplanar static faces**. Cutting faces into non-overlapping fragments increases the polygon count slightly; it does not add per-frame geometry processing.

Window frame intersections were made edge-to-edge, rotating latches and clock hands received clear separation, and thin floor/paper overlays were lifted clear of their backing. Real mipmaps are now generated for the repeating world textures and portrait; previously the material requested them but the texture import did not generate them. Camera depth range and world-space texture scale were tightened as well.

See `SURFACE-POLICY.md` for the shared layer policy, its scope and references. Moving and imported meshes still require proper authoring; the structural proof does not claim to eliminate every possible aliasing artifact on every GPU.

The geometry/material suite now has **32 passing tests**. Visual sweep reports live in `build/qa/surfaces/`: 13 locations at low/high quality, with additional shifted-angle views. Its draw-call guard includes the touch HUD, so it permits 300 total calls instead of comparing directly with the earlier non-touch 250-call budget. Sample FPS collected while multiple test processes run is diagnostic, not a sustained device benchmark. The tests forbid pointer capture.

Review of those screenshots also revealed horizontal self-shadow bands in the high-quality flashlight beam. Bias comparison captures confirmed that raising shadow bias from 0.1 to 0.5 removes those bands. The final build uses 0.5 with normal bias 2.0; rain no longer casts moving shadow stripes. Focused high-quality rechecks use `*-focused-report.json`. This is a separate lighting fix from the geometry priority system.

## Implemented scope

One complete, compact 3D house story: six instructions, noise-driven pursuit, hiding/crouching, a reusable phone lure, checkpoint recovery, three memories, a quiet final ritual and two endings. English/Filipino text, captions, touch controls, graphics/accessibility settings and optional local-only microphone loudness are included. Browser and portable Windows exports are packaged with third-party credits and licenses.

## Automated and visual verification

- **32/32 GdUnit4 gameplay/integration and surface tests passed.** Includes progression gates, inventory, clock solution, checkpoints, localization, corrupt saves, hearing, path connectivity, salt protection, quiet/proximity ritual requirements, restart/capture accounting, floor non-overlap, level entry coverage, deterministic surface ownership, actual mipmap data and safe flashlight/rain shadow settings. These are headless logic tests, not native UI tests.
- **Chromium 145 and Firefox 146:** nine end-to-end check groups passed in each browser, covering actual title/onboarding buttons, real keyboard movement, raycast interactions, all instructions and memories, save/reload, both endings without a microphone, and the low-quality Filipino touch layout. No runtime script/browser errors were reported.
- **Five Chromium resilience checks passed:** denied microphone fallback, synthetic microphone calibration/disconnect cleanup, capture recovery, actual emulated touch-joystick movement and a readable portrait rotation prompt.
- **Release web smoke check:** starts from the real title buttons, closes the opening note, captures/releases the mouse correctly, accepts movement, pauses, and makes no third-party runtime requests. The debug automation bridge is absent even with `?qa=1`.
- **Windows:** native GPU render inspected; the packaged portable release also starts headlessly and exits successfully without script errors. This is not a complete native Windows playthrough.
- Screenshots reviewed for title, onboarding, notes, rooms, endings, touch layout and portrait guidance. A browser pointer-lock race on the opening note was discovered during final visual review, fixed, and covered by a release regression assertion.

End-to-end automation uses a separate debug export. It uses real input for movement/interactions but also teleports between test locations, submits some puzzle choices directly, and shortens the ritual timer. It does **not** establish natural pacing, difficulty, scare effectiveness or a first-time player's ability to find everything. Synthetic microphone tests do not exercise physical microphone hardware.

## Performance evidence

Desktop Chromium snapshots at 1280 × 720, sampled in sala, kitchen, altar and exterior:

The table below records the original MVP baseline, before surface clipping and the touch-HUD inspection runs. For current raw snapshots use `build/qa/performance.json` and `build/qa/surfaces/*-report.json`; do not treat the baseline as a fresh benchmark of the updated build.

| Setting | FPS in samples | Draw calls | Rendered triangles | Engine-reported VRAM |
| --- | --- | --- | --- | --- |
| Low | 60 | 27–192 | 4,184–11,680 | 31.5 MiB |
| Medium | 60 | 27–192 | 4,184–13,000 | 33.5 MiB |
| High | 60 | 27–242 | 4,184–19,900 | 29.0 MiB |

These are short snapshots, not sustained frame-time percentiles or total browser memory measurements. The engine memory counter can vary as resources are allocated/released; the lower high-setting sample is not evidence that high quality needs less memory. Browser tests used hardware-accelerated desktop rendering. Firefox startup/touch samples were 58–59 FPS.

A native medium-quality sala sample on Intel Arc 130T reported 60 FPS, 125 draw calls, 8,594 triangles and approximately 29.3 MiB engine-reported VRAM. The game caps at 60 FPS. None of these results proves performance on low-end Android hardware.

Optimizations include material-batched static geometry, small textures, one optional shadow-casting flashlight only on high, reduced render scale on low/medium, a compact A* navigation grid, pooled audio capped at 15 voices, and a single-threaded web export.

The compressed web archive after the surface update is approximately **11.8 MiB**, and Windows approximately **38.4 MiB**. Installed/uncompressed sizes and browser memory use are larger.

## Evidence and reproduction

See the root README for build/test commands. Generated evidence is under ignored `build/`:

- `unit-results/report_*/results.xml`: logic test results.
- `qa/chromium-report.json`, `qa/firefox-report.json`: browser progression reports.
- `qa/resilience-report.json`, `qa/release-report.json`: browser fallback/release checks.
- `qa/performance.json`: scene-level performance snapshots.
- `qa/windows-release.log`: portable Windows startup log.
- `qa/*.png`: screenshots; files with `failure` in their name are retained diagnostics from earlier test iterations, not current pass evidence.

## Remaining public-release gates

1. Independent first-time playtests: navigation, clues, threat fairness, cultural tone, both endings and measured duration. The 20–30 minute design target is unverified.
2. Physical Android tests on low/mid-range hardware: landscape touch controls, performance over a full session, audio, save persistence, thermal behavior and permission denial. There is no native Android APK in this MVP.
3. Test the actual itch.io iframe/fullscreen embed, including touch and browser permission restrictions. The game remains playable without microphone permission.
4. A full native Windows playthrough and physical microphone calibration/disconnect test. The executable is unsigned.
5. Owner review of the page, screenshots, pricing/donations and payout setup before publication. No itch.io page, monetization or payment account has been changed.

Use `PLAYTEST.md` for the next feedback round and `ITCH-PAGE.md` for the upload draft. All-device compatibility, commercial success and a particular playtime are not promised.
