# Changelog

## 2026-10-21 overnight pass

Ported the browser version's improvements, fixed the Godot bugs from the arena review
(`claude-game-arena/review/marti.md`, section 4) and closed the design-language gaps.

### Fixed

- **Steering was mirrored (G1, P0).** The chase camera looks along +z, so its right is world -x. Keys, stick
  and mouse now steer towards the screen side you press. Touch steers by relative drag from where the finger
  went down and never on finger down, so a tap only dives (H2). New tests check the camera's right axis
  against the steering delta and the projected target; Movie Maker runs with `--hold=steer_right` and
  `--hold=steer_left` show the gull going to that side of the screen.
- **Hit spam while blinking (G2).** A hit during invulnerability is ignored: no burst, no sound every frame.
- **Collision (G4, H3).** Boat collision boxes now live in `data/boats/*.tres`: ferry cabin (y 2.6-4.5, the deck
  simit at y 5.3 stays reachable), tanker bridge block and funnel, fishing cabin and mast, the sail panel.
- **Water and land wobble (G5).** The plane z is snapped to one grid row.
- **Music gap (G6).** The loop is exactly four bars; the tail past the seam is folded onto the start.
- **Touch dived on every drag (G7).** The mouse button is no longer part of the dive action; mouse events that
  Godot emulates from touch are ignored.
- **Simit and tailwind rings lay flat (G3).** The simit model stands upright and spins about y; the tailwind
  ring is built upright.
- Hint labels follow the language (G8); the house material no longer toggles `emission_enabled` (G9); windows
  glow instead of whole houses (G10); fireworks are no longer fogged and are large enough to see (G11); the ferry
  horn plays once when a ferry is within 90 units (G12); fish pitch along their leap (G16); daily missions are
  cached per date (G17); slider changes are saved at once (G21); one dive splash instead of two (G22); the
  duplicate shadow loop is gone (G23); the gull is drawn at scale 1.1 with the same hitbox (G24); defaults are
  master 0.8 and the OS language (G25); icon buttons are focusable and 44 px on touch (G26); unused text keys were
  removed and `fly` / `reason_*` are used (G27); a run paused at once shows the gull and camera in place.
- Particle bursts: the fireworks (one-shot `CPUParticles3D` nodes far ahead) never showed up in Movie Maker
  frames, even at ten times the rate. Every burst (and the fireworks) now comes from a pooled MultiMesh
  (`scripts/sparks.gd`, one draw call each, no node per burst); fireworks and pickup sparkles are visible now.
- The feather trail is shorter-lived, so its puffs no longer reach the chase camera as big blobs.

### Added

- Generated models from the browser version (Higgsfield Tripo): simit, golden simit (x1.3, gold tint),
  fish, shield feather, ferry, fishing boat, sailboat, mosque (replaces dome + minarets), yalı, Galata tower,
  Maiden's tower. Textures re-encoded to PNG for Godot's importer. `--no-assets` keeps the procedural models,
  which stay as the fallback (procedural mosque, yalı, tower and Maiden's tower were added for that).
- The new procedural gull (two-layer tapered wings, mantle, fan tail, wing pitch -0.6, body pitch -0.15,
  dihedral 0.12, flap amplitude 0.55) and the same bird for the rival flock, whose wings flap in a vertex shader
  and whose V now points where it flies. Passed pickups (3 units) and flock birds and kites (4 units) are hidden.
- Crest logo on the title card, in the HUD (28 px) and as the project and web icon.
- Pause menu: Resume, Restart, Settings, Main menu over a dimmed, blurred backdrop. HUD gear button. `F`
  toggles fullscreen. Footer credit "Claude Game Arena · built by Claude Haiku 5.5 · assets remastered".
  Focus rings on every button. The HUD icon row wraps under the stats on narrow phones.
- Game-over jingle (523/392/262 Hz, music ducked to 25 % for 1.6 s) and the reason on the game-over card.
  Sound is suspended while paused; losing the window focus pauses the run. "Have a good flight!" toast at the
  start. Feather icons for lives. Pyramid roofs, larger clouds.
- The title demo's clock stays at or below 60 s (a golden afternoon).
- Tests: 43 → 77 (steering direction, collision boxes, flock V, landmark facing, fish pitch, models, music
  loop, ignored hits, hidden pickups, burst pool, title clock, mission cache).

### Kept

- The Godot sky shader, settings, tests and bot. The light colours already blend between the day keys, and the
  sun light already comes from the visible sun's side; both were checked, not changed.
