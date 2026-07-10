# Overlap — Roadmap

Vertical slices, in order. Each slice ends with the game playable and its
acceptance line verified by running it (godot-mcp run + screenshot/output).
Tick when done. Notes about deviations go under the slice, not in new files.

## Slice 1 — A car that feels great on one track
- [x] Input map (WASD + arrows + Space drift), Car scene with
      forward/lateral-split controller, drift factor
- [x] One hand-built track scene (simple closed circuit, walls)
- [x] Follow camera
- [x] **Accept:** drive 3 clean laps; steering and drift feel good at speed.
      Feel sign-off is the gate — iterate here before moving on.
      (Ticked 2026-07-07: the notes below record the 2026-07-05 human
      sign-off; the box was simply never checked.)
- Notes: auto-verified 2026-07-05 via DevProbe (scenes/dev/dev_probe.gd —
  scripted drive, telemetry, screenshots to user://dev/; activate by
  creating user://autopilot.flag). Accel 0→920 px/s, cornering, drift and
  wall collisions all behave. Feel tuning: data/cars/starter_car.tres.
  Follow-up playtest chose the drift-heavy candidate over kart/GT; main now
  biases slightly more drifty and adds tire trails while drifting. Rejected
  driving-style branches/worktrees were removed after folding the chosen feel
  into main. Human playtest 2026-07-05: feel signed off as-is. Trails now
  spawn a fresh Line2D pair per drift stint (old ones fade after 4 s — fixes
  stints connecting across the map) and also draw from keyless sideways
  scrub. Road-edge walls and island collision replaced by slowing grass
  (grass_speed_multiplier/grass_deceleration in starter_car.tres); walls
  remain only at the world edge.

## Slice 2 — Laps exist
- [x] Start line + 3 checkpoints on Track; ordered lap validation
- [x] RaceState: lap timer, best lap, HUD showing current/best/last
- [x] **Accept:** crossing the line after all checkpoints logs a lap time;
      cutting the track does not.
- Notes: verified 2026-07-05 — DevProbe waypoint autopilot completed two
  clean laps (7.10s, 7.04s); checkpoints fired in order; first start-line
  crossing started the clock without logging a lap; HUD confirmed via
  screenshot. Track owns validity, RaceState owns time, HUD reads only.

## Slice 3 — Your ghost drives
- [x] LapRecording resource; RaceState records during each lap (30 Hz)
- [x] Ghost scene replaying the best lap on loop, translucent; GhostFleet
      re-arms every ghost on a new PB
- [x] **Accept:** set a lap, ghost appears and retraces it accurately while
      you keep driving.
- Notes: verified 2026-07-05 — 214 samples @ 33.3 ms for a 7.10 s lap;
  ghost traced the recorded line within interpolation error while the car
  drove a different line; three consecutive PBs re-armed the fleet each
  time. Ghost has no physics and no collision (hard rule 5 holds).

## Slice 4 — Ghosts pay
- [x] Bank autoload (currency; each ghost lap pays TrackDef.base_payout,
      so income/s = payout / lap_time)
- [x] HUD money counter + income rate, ticking per ghost lap
- [x] Save/load (currency + best LapRecording via store_var; 5 s autosave
      and save-on-PB and on close)
- [x] **Accept:** ghost earns → money rises each ghost lap → quit and
      relaunch → state intact.
- Notes: verified 2026-07-05 — parked car, ghost paid $10 exactly every
  7.03 s (income 1.42/s = 10/7.03); relaunch restored money + PB, spawned
  the ghost at t=0, and correctly flagged 7.10 as not-a-best against the
  persisted 7.03. Ghost auto-hires on first PB; purchasable slots are
  slice 5.

## Slice 5 — Spend it
- [x] UpgradeDef + UpgradeCatalog resources (top speed / accel / grip,
      data-authored cost growth, multiplicative effects) + Tab-toggled GARAGE shop
- [x] Car computes effective stats (base resource × upgrade multipliers,
      base .tres never mutated); refreshes on purchase and from save
- [x] Ghost slots from data/economy.tres; fleet grows and staggers clones
      evenly around the lap
- [x] **Accept:** full loop closes — earn, buy speed, set faster lap,
      fleet re-arms, income visibly increases.
- Notes: verified 2026-07-05 across two runs — income 1.42/s → 4.61/s
  (3 ghosts × $10 / 6.51 s PB); saved upgrade levels applied to physics on
  relaunch (974 px/s straight from load). Re-verified 2026-07-05 after
  steering-floor, drift tuning, trails, and DevProbe hardening: upgraded
  clean lap improved 6.90 s PB → 6.61 s, fleet income rose to 3.02/s with
  2 ghosts.

## Slice 6 — Idle game shape
- [x] Offline earnings on launch ("While you were away…")
- [x] More ghost slots, cost curves from data/ (already live since slice 5:
      unlimited slots, cost = ghost_base_cost × growth^n from economy.tres;
      slots apply per route fleet since slice 7)
- [x] ~~Second track (TrackDef unlock)~~ SUBSUMED by the gate network
      (slice 7): new asphalt arrives as gated routes on one growing
      network, not separate track scenes.
- **Accept:** relaunching after time away grants income; buying track 2 and
      racing it with its own ghosts works.
- Notes: verified 2026-07-05 via temporary save/load run — 2 ghosts, $10
  payout, 10.0 s PB, and ~1 h elapsed launched from $100 to ~$7300 and
  rewrote the save timestamp. Offline cap lives in data/economy.tres.

## Slice 7 — The gate network (design: docs/GATE_NETWORK.md on design branch)
- [x] Pretzel-lite prototype: island gate ($120 in GARAGE) opens a chord →
      2 authored routes (Grand Ring / Island Cut), analytic line-crossing
      route detection (RouteTracker, no Area2D checkpoints), per-route
      PB/recording/ghost fleet in Bank (save v3 + v2 migration),
      route-discovery toast, par-normalized payouts.
- [x] Route log UI (R key): full cards (name/PB/income) for discovered,
      ??? + authored clue for hinted (gates owned, undriven), X/N counter.
      Gate hardened: 700 px bar + chord_mouth line required in the cut's
      edge sequence, so flanking the gate over grass validates nothing.
- [x] Path2D road pipeline: RoadSegment (@tool) bakes surface + grass
      hitbox from a Curve2D centerline (tessellate + offset_polyline,
      square caps seal junctions). track01 rebuilt from 5 centerlines,
      byte-for-byte drivable-area equivalent — probe lap times identical.
- [x] Clover petal 1: sand-themed curved petal (Dune Gate $250) west of
      the ring; routes Dune Bend + Twin Cut (two-gate combo, hinted until
      driven); mastery medals from PB vs par (data/economy.tres knobs)
      multiply that route's fleet income. Probe-verified; pars set so
      autopilot-clean laps land silver. Human feel pass on the curve
      still pending.
- [x] Mastery is purchasable per route (RouteDef.medal_unlock_cost) and
      the GARAGE evolves (ShopPacing: upgrades reveal by total levels,
      one gate at a time, mastery rows per discovered route). Pars are
      authored from DevCalibrate maxed-car runs (user://calibrate.flag —
      rerun after any handling/catalog change); Top Speed capped at Lv 3
      to keep racing lines beating reflexes. Maxed bot = silver on all
      four routes; gold = beat the bot.
- [x] Island expansion 1 (docs/MAP_DESIGN.md): water boundary replaces
      walls (splash = reset to last asphalt + lap void), bigger land,
      tree obstacles, and the first knowledge route — Forest Run, a
      hidden road unlocked forever by driving between the two golden
      trees (SecretRoad + trigger crossing line; secret routes are
      counter-only in the log until driven). Grass drag now always
      beats engine upgrades (maxed cars could out-accelerate it).
- [x] Petal 2 — THE CLIFFS (docs/MAP_DESIGN.md §3/§8, placed NE/N
      because the Woods took the planned north-center): Cliff Gate
      ($900) forks off the ring's NE corner; narrow slate road
      (half_width 115) climbs a hairpin ladder to the lighthouse
      hairpin, esses descend the north shore, and the descent dives
      through the chord-mouth junction at grade — the X crossover,
      where cliff traffic crosses hub traffic into the chord. First
      real walls (WallSegment) + rubble near-stop shoulders (car layer
      4; decel includes acceleration). Two-layer border/curb rendering
      landed with it (borders z=-1 below all surfaces; backgrounds
      pushed to -4/-3/-2 so drift trails stay above roads). Routes:
      Lighthouse Climb (par 16.0) + High Ring (par 18.2, discovered by
      turning east at the X).
- Notes: verified headless 2026-07-06 — calibration drove all 7 routes
  (maxed bot silver everywhere: climb 16.85 vs par 16.0, high_ring
  19.13 vs 18.2; five old pars still silver, unchanged); full probe
  loop green with new EARN/BUY/DRIVE/WATCH cliff phases (gate bought,
  both routes hinted with clues, Lighthouse Climb discovered on first
  lap, clean 20.30s lap on a low-upgrade car, income 13.11/s, 8
  ghosts, zero errors). Human feel pass on the hairpins pending. The
  descent crosses the hidden forest road once at grade (topologically
  unavoidable — see MAP_DESIGN §9).
- [ ] Petal 3 (harbor per MAP_DESIGN), Jump Kit gateway upgrade
      (+ cliff washout jump spot), coast linker + grand tour,
      gate-exhausted badges
- **Accept (prototype):** buy gate → drive chord → NEW ROUTE toast, own
      PB and fleet, income adds up across routes.
- Notes: prototype verified headless 2026-07-05 — gate bought, Island Cut
  discovered on first lap through it, cut PB 5.12 s, income 3.01 → 5.55/s
  (exactly Σ slots × payout / pb), 4 ghosts in 2 fleets, v2 save migrated
  with offline earnings intact. Human feel pass on the cut still pending.
- Notes (2026-07-07 review fixes, NOT play-verified — no Godot on that
  machine): route certification now requires all RouteDef.required_gates
  owned (closes the cliff-gate grass-flank exploit); start/west/east/
  petal/forest crossing lines overhang the inside curb (apex clips no
  longer void laps); saves write atomically; shop buttons no longer take
  keyboard focus (Space re-purchase). Run the probe loop to re-verify.

## Visual identity pass (2026-07-06, human-directed)
- [x] Flat-vector look leaned into (art-of-rally direction, no tile
      packs — they'd fight the centerline-baked road pipeline): water
      shader (swells, turquoise shelf, foamed wobbling waterline from
      the land-rect SDF), shared mottle shader breaking up grass/sand/
      rock fields, zone underlay polygons (dunes/cliff rock/woods),
      centerline dashes baked per RoadSegment, checkered start +
      gantry (beam over cars) + pit wall + GARAGE building, lighthouse
      beam sweep, layered vector car/ghost/trees (same footprints and
      collision), speed-reactive camera zoom, screenshake on splash/
      wall hits, off-road dust + splash particles.
- Notes: verified 2026-07-06 — boot clean, full probe loop green with
  identical lap times pre/post juice (car handling untouched); every
  pass eyeballed via the new photo-mode tool (user://photo.flag,
  windowed; 12 authored viewpoints to user://dev/). Human feel pass
  on camera zoom/shake amounts pending (knobs exported on
  scenes/car/follow_camera.gd).

## System & audio pass (2026-07-07, human-directed)
- [x] Esc system overlay: non-pausing menu (resume, controls card,
      fullscreen, Master/Music/SFX sliders, reset-save behind a
      click-again confirm, save-and-quit). Settings persist to
      user://settings.cfg — device prefs, never the profile save.
- [x] Audio: Music/SFX buses; tools/gen_sfx.py synthesizes all SFX as
      committed WAVs (engine/drift/offroad loops seam-free from
      integer-Hz partials; splash, purchase, gate, lap, PB, medal,
      discovery one-shots); CarAudio pitches the engine with speed and
      fades screech/rumble; GameAudio plays progression stingers off
      the Events bus (ghost laps deliberately silent). CC0 assets per
      assets/audio/SOURCES.md: chill lofi music loop (autoplays) and a
      recorded engine A/B candidate (use_sampled_engine on CarAudio).
- Notes: verified 2026-07-07 — boot, windowed run, and full probe all
  zero warnings/errors, lap times identical (headless keeps audio
  dormant: the dummy driver never mixes, playing streams would leak).
  PENDING HUMAN EARS: mix levels (exports on car_audio.gd + per-player
  dB), synth vs sampled engine A/B, music taste check.

## Slice 8 — Island v2: the 15-second hub (design: docs/MAP_DESIGN_V2.md)
- [x] V2-1 The hub: GP-style ~15 s circuit (fast+flowing, one braking
      corner) + chord gate, save v4 full wipe, dev tooling retargeted,
      pars/payouts calibrated, economy sim re-checked. track01 deleted.
- Notes: verified 2026-07-07 — human test-drove the prototype and
  approved ("the track is better"); full probe green on v2 (first-time
  lap 15.35 s — on target; upgraded 14.77 s = bronze vs par 12.4; cut
  discovered at 10.82 s; income 5.99/s, 4 ghosts, zero errors, 113 s
  run). Pars from maxed-bot calibration (ring 13.02→12.4, cut
  9.55→9.1); payouts par-normalized at ~1.7/s/slot. Cold-start model:
  first purchase ~15–31 s, inside the 20–40 s target — no economy
  retune. Saves v3 and older wipe on load (approved). Two bake gotchas
  recorded in a3cd464: closed centerlines fill their interior (split
  loops into open segments at zero-curvature points) and Curve2D
  point_count beyond the data invents a phantom origin point.
- [ ] V2-2 Minimap / island map screen (required — circuit no longer
      fits one screen).
- [x] V2-2 minimap — Notes: verified 2026-07-07, photo run; island
      bounds derive from the Grass polygon so annexes auto-appear.
- [x] V2-3 dunes — Notes: verified 2026-07-07 — calibration (dune
      17.58, sandcut 14.06; pars 16.75/13.4), full probe green.
      Also fixed a latent stats leak (profile_reset fact on Events;
      car recomputes on dev wipes).
- [x] V2-4 cliffs + woods — the X returns with room to breathe: v1's
      proven ladder geometry translated NE (+850,-700), descent dives
      through the chord's top mouth (the single at-grade X — the woods
      no longer force a second crossing, v1's documented compromise is
      repaid), golden-gap secret forest arc NW. Pars from calibration:
      climb 21.3, high_ring 25.3, forest 18.6.
- [x] V2-5 harbor — Container Run (par 20.0, 1.25x), stop-go maze in
      navy/rust with container walls (WallSegment ribbons), crane,
      dock straight, Harbor Gate \$2200. Land grows east to 5400.
- Notes: slice 8 verified complete 2026-07-07 — final probe drove the
  entire five-gate loop in one run (island 120 → dune 250 → cliff 900
  → harbor 2200): 12 laps across 5 discovered routes, 10 ghosts,
  income 16.25/s, route log 5/8 with all three hint clues live, zero
  errors, 434 s. All pars from calibration; every annex probe-driven.
  Remaining from the v2 plan: coast linker + grand tour (needs the
  harbor's south edge), Jump Kit, dock-tour variants. Human feel pass
  on the whole island pending.
- **Accept (V2-1):** a first-time lap takes ~15–18 s and feels like a
      race lap (straight → braking spot → sweepers → esses → carousel);
      full probe loop green on the new geometry.

## Slice 9 — Rival onboarding (chosen from IDEAS.md, 2026-07-10)
- [x] The game opens as a race: AMBER, an opaque named rival parked on
      the grid, replays an authored base-car bot lap (data/rivals/
      ring_rival.tres — 16.38 s, bot pace × 1.07 handicap) from every
      lap start. Ghost slots now start at 0: passive income is locked
      until a ring lap beats the rival's time; the win hires ghost #1
      (toast + stinger, shop then starts selling slots). Active-lap
      income still pays from lap one — pillar 4 survives. Existing
      saves are grandfathered (owning any ghost slot implies the win).
      RivalRacer owns the park/race/beaten flow; the rival car is a
      dumb Ghost replay — no AI, no collision (hard rule 5; VISION
      scope fence consciously amended). Rivals are RivalDef resources
      authored by DevRivalRecord (user://rivalrecord.flag — rerun and
      recommit after any change to base-car pace).
- Notes: verified 2026-07-10 — boot clean; full probe green: fresh
  profile slots=0, LAP 1 (15.35) beats AMBER (16.38) → rival_beaten →
  slots=1, then the full five-gate loop matches the pre-rival baseline
  (income 16.25/s, 10 ghosts, 12 laps, 439 s, zero errors). Photo run
  eyeballed: rival + name tag on the grid, HUD objective line ("beat
  the rival to hire your first ghost"), $0 +0.0/s until the win. Human
  feel pass pending: is AMBER's pace right for a first session?
  Generalization parked in IDEAS.md: a resident rival per zone.
- **Accept:** a fresh profile races AMBER from the start line, income
      stays 0 until the win, and beating it hires ghost #1.

## Slice 10 — Onboarding v2: the rival ladder (2026-07-10, human-directed)
- [x] Three rival tiers replace the single rival: AMBER (base-bot ×1.04,
      15.93) → COBALT (+TS1, 15.06) → ONYX (TS2/Accel2/Grip1, 14.28),
      authored per spec by the 3-stage DevRivalRecord. Each win ×2 on
      ACTIVE lap payouts (×2/×4/×8); beating ONYX unlocks personal
      ghosts and idle income. Active lap multiplier dropped 3→1 — the
      ladder is the early income curve (DESIGN_NOTES "Onboarding v2").
- [x] The GARAGE is a place: reveals at $50 driving earnings (toast),
      shop opens only parked at the building (GarageZone + pad), and
      sells only upgrades until ghosts exist (gates/medals/slots wait).
- [x] Progressive map reveal: locked annex roads/fields/dressing hidden
      with their collision (TrackReveal + zone_<gate_id> groups); the
      next gate on sale previews its road faintly and reveals fully on
      purchase; minimap follows (+ only the on-sale gate pin); gate
      bars always visible as locked promises; forest secret untouched.
- [x] Onboarding feedback: race-result toasts with the time delta and
      new multiplier, garage-open and ghosts-unlocked toasts, cold-open
      "AMBER wants a race", controls hint until the garage opens.
- Notes: verified 2026-07-10 — full probe green driving the entire arc:
  AMBER lap 1 → garage $63 lap 2 → upgrades every ~2 laps → COBALT
  lap 6 → ONYX lap 8 (ghost #1, ×8) → slot → all four gates → 18 laps,
  income 17.20/s, 10 ghosts, 405 s, zero errors. Fresh-profile photos:
  hub-only island, minimap hub-only (first build deferred past the
  reveal sync), rival + toast + controls hint on the grid. Existing
  saves grandfather by invariant (slots ≥ 1 ⇒ ladder done + garage).
  Human feel pass PENDING: ladder pacing and the $50/cost curve.
- **Accept:** a fresh profile sees ONLY the hub and one named rival;
      income is laps-only until ONYX falls; the garage is a building
      you drive to; annexes appear as they're earned.

## Slice 11 — Resident rivals (2026-07-10, human-chosen)
- [x] Rivals live in TrackNetworkDef.rivals (authored order = ladder
      order); RivalDef gains required_gate + hires_first_ghost. The
      unified rule (Bank): a rival stands once its gate is owned and
      earlier same-route tiers fell; a route's FLEET only earns while
      no standing rival holds it. The onboarding trio becomes the
      ring's rivals; each annex ships a resident at its arrival spec:
      JADE (cut, ONYX spec ×1.05), SIENNA (dune, TS3/A3/G2 ×1.04),
      SLATE (climb, TS3/A4/G4 ×1.04), RUST (harbor, TS3/A6/G5 ×1.04).
      Buying a gate introduces the resident (toast); beating it rolls
      out that route's fleet. Residents don't grow the ×2 ladder
      multiplier — their prize is the fleet. Rivals host spawns one
      racer per network rival; save v5 (v4 loads: routes already
      earning grandfather their resident as beaten).
- Notes: verified 2026-07-10 — see probe run in the commit; each gate
  phase now buys the zone spec, races the resident, and the fleet
  income appears only after the win. Human feel pass PENDING:
  resident pacing per zone.
- **Accept:** buying a gate parks a named rival on the grid; the new
      route pays active laps only until you beat them; the win spawns
      the fleet.

## Slice 12 — Fleet liveries + the Jump Kit (2026-07-10, human-directed)
- [x] Every route's fleet wears its own livery (RouteDef.ghost_color,
      zone-themed; per-clone variation is now alpha + lightness cycles).
      Fleets held by a standing rival stay OFF the track — the fleet is
      the prize and appears on the win (human chose this over a dimmed
      preview fleet). Other routes' fleets roll and earn throughout.
- [x] Jump Kit (MAP_DESIGN §4 "soft gates"): $1500 garage purchase, on
      sale once the harbor is owned. New pier road forks east off the
      container maze to a ramp over a canal; ramp flight time comes
      from CarStats (0.45 s bare — only a maxed car flat-out barely
      clears, the sequence-break; 0.75 s with the kit). Airborne is a
      physics bypass, not a handling change: no steering/throttle/
      surface effects mid-flight, splash-on-landing handled by the
      normal water flow. Route: Canal Runner (harbor_gate + the kit in
      practice; ability-premium payout), authored par from calibration.
- Notes: verified 2026-07-10 — calibration drove all 9 routes (canal
  21.87 with the kit, zero splashes; par 20.8); full probe green
  (ladder → residents → kit at $1550 → Canal Runner discovered, PB
  22.35, income 22.6/s, 12 ghosts, 20 laps, zero errors); dock photo
  eyeballed. Geometry gotchas this session: container C sat across the
  pier path (moved to the corner pocket) and the canal water initially
  reached west of the pier, splashing maze-corner slides that used to
  recover on grass (pulled back — keep a grass margin around splash
  hazards). Race-result toast bug fixed: rivals only judge laps they
  raced from the start (_racing flag), and a beaten rival can never
  judge from hiding.
- **Accept:** fleets read as colored squads per route; a rival-held
      fleet appears only on the win; the canal splashes a kitless car
      and the kit turns it into a shortcut.

## Slice 13 — Archipelago V3-1: simplify Home (docs/MAP_DESIGN_V3.md)
- [x] Human verdict on the v2 mega-island: T-junction annexes kill
      momentum and route identity is illegible ("which loops count as
      a track?"). New model: an ARCHIPELAGO of small clovers — each
      island one base loop + ≤2 variants + ≤1 secret, bridges (Jump
      Kit) are travel between islands, never lap ingredients. Junction
      grammar is now canon: entries fork straight-on (≤45°), exits
      merge tangentially (≤30°) into straights, one decision per
      corner, new routes beyond the cap braid existing asphalt.
- [x] Home island simplified: chord, cliffs and harbor removed from
      map + network (routes cut/sandcut/climb/high_ring/harbor/canal;
      gates island_chord/cliff_gate/harbor_gate; rivals JADE/SLATE/
      RUST retired — their material returns as Islands 2–3 per the V3
      doc). Dunes re-grammared: straight-on fork at T1, CCW bowl,
      tangential NNE merge into the upper riser; Dune Gate moved to
      the fork mouth. Land shrinks east; Jump Kit off sale until it
      becomes the Island-2 ticket (V3-2). Save v6: drops PBs/discovery
      /medals of removed+reshaped routes (ring/forest survive), rival
      list pruned to known ids.
- Notes: verified 2026-07-10 — rivals re-recorded (ladder unchanged;
  SIENNA 17.03 on the new bowl); calibration ring 13.01 / dune 16.10
  (vs 17.58 on the old T-junction bulb — the fork grammar is
  measurably faster) / forest 19.19 (old par still silver); dune par
  authored 15.3, payout 28.5. Full probe green in 273 s: ladder →
  garage → dune gate + spec → SIENNA raced AND beaten on the very
  first dune lap (no transition lap — fork entry) → fleet income
  steps on the win. Island overview photo: one track, two braided
  loops, zero stubs. GOTCHA (cost one run): crossing lines are
  DIRECTIONAL — forward is (b−a)×travel > 0; author a/b so the racing
  direction crosses forward, else laps silently void as dirty.
- **Accept:** Home's menu is exactly Grand Ring / Dune Bend / Forest
      Run; every junction obeys the fork grammar; onboarding ladder
      and dune resident work end to end on the new geometry.

## Slice 14 — Forest re-grammar: variants exclude by position
- [x] Human feedback after driving V3-1: the forest rejoin hooked
      backwards (~130°) and two free-floating loops made 4 lap combos
      — with dune+forest matching NO authored route (silently voided
      laps, the worst feedback). Fix chosen by the human: the forest
      fork moves onto the riser — the section the dune bypasses — so
      dune+forest is geographically impossible. New grammar rule in
      MAP_DESIGN_V3 §1.5: variants exclude by position; N loops =
      N+1 laps exactly. Forest now forks straight-on where the riser
      bends right, threads the relocated golden gap north, rides the
      old woods arc, and eases onto the top straight tangentially.
- **Accept:** forest entry and exit both flow at speed; dune+forest
      in one lap is impossible; feel signed off (human, 2026-07-10:
      "ok yeah it's better").

## Slice 15 — Remove mastery purchases; medals become free badges
- [x] Human verdict 2026-07-10: "mastery is completely pointless as
      is" — doubly redundant (rivals made the bot visible and beatable;
      a faster PB already pays more via lap frequency) and a purchase
      with no content. Removed: the per-route mastery purchase
      (RouteDef.medal_unlock_cost, Bank.medal_unlocked_routes + its
      save key, try_buy_medal_unlock, ShopPacing.medal_offers, shop
      "Mastery:" rows, HUD hint branch) and the medal income
      multiplier (economy medal_*_multiplier knobs; ghost-lap and
      income/s formulas lose the medal term). Kept: medal tiers as
      FREE recognition — derived from PB vs par as before (economy
      medal_silver/bronze_factor), shown in the route log, with a new
      `Events.medal_earned(route_id, tier)` fired when a new PB
      upgrades the tier (plays the existing medal sting). Save stays
      v6 — the dropped key reads back as nothing.
- **Accept:** no mastery row in the GARAGE; medals appear in the
      route log from the first qualifying PB with no purchase; fleet
      income identical before/after on the same PBs (probe income
      figures drop only by the removed medal factor).

## Slice 16 — V3-2: the strait + Port island (archipelago becomes real)
- [x] Second island east of Home across a 640 px water strait
      (MAP_DESIGN_V3 §2 build spec has every coordinate). Jump Kit is
      the completion-gated ticket: on sale only once Home is complete
      (dune gate + all three Home routes driven; ShopPacing). Two
      one-way ramp crossings (physics layer 5, CanalRamp pattern):
      OUT forks straight-on east at the ring's NE corner (the V2
      cliffs-approach mouth — the old ess harbor mouth violates the
      V3 fork grammar), BACK continues west off the Port's south
      straight into the carousel funnel. Bare car max flight 495 px
      < 640 (can NEVER clear without the kit); kit clears with ~20%
      margin at flat-out commitment.
- [x] Port base loop: the V2 container maze + dock straight rebuilt
      as a closed stop-go circuit (recovered from 5f25833, +2600 x)
      with container WallSegments, crane, navy/rust palette, its own
      start line + checker + garage pad #2 (same shop — GarageZone
      polling is any-zone now). Route "port" (Dock Circuit), par 7.25
      (bot 7.61), payout 17.5 (2.41/s·slot, continuing the per-second
      progression premium). RUST re-authored on the real circuit
      (8.86 s at TS3/A3/G2 ×1.05, required_gate="jump_kit" — Bank's
      rival_requirement_met understands the special id).
- [x] RouteTracker archipelago rules: TrackNetworkDef.start_line_ids
      + RouteDef.start_line; a lap closes only at the line it opened
      at, crossing another island's start line switches islands and
      discards the accumulator (travel is never a lap). Minimap
      bounds/coasts from the island_land group. Splash reset now
      lands on a breadcrumb ~1200 px back along driven asphalt facing
      forward (was: the exact water's edge — a failed jump would
      splash-loop with zero runway).
- [x] Dev tooling: DevDriver loop_from (one-way travel lead-in +
      repeating circuit), probe kit+port phases, calibrate/rivalrecord
      cover the port, OVERLAP_TIMESCALE=<n> env knob (time_scale +
      physics_ticks_per_second scaled together — per-step dt stays
      1/60; all three tools step the driver in _physics_process so
      bot behavior is timescale-invariant). Full probe verified
      identical at 8/16/32×: 56/29/14 s wall vs 475 s at 1×.
- Notes: rival re-record reproduces the ladder byte-for-byte (15.93/
  15.06/14.28) — no handling drift from the breadcrumb change.
  GOTCHA: a recovered .tres may set the same property twice (rust
  kept a stale required_gate="harbor_gate" below the edit point; the
  LAST wins and it cost a probe run). GOTCHA: never run boot checks
  while a flag run is active — two instances share user://.
- **Accept:** probe drives ladder → dune → kit → strait jump → Dock
      Circuit; RUST races and falls; port fleet pays only after;
      feel passes pending (strait jump, stop-go rhythm, ~8 s lap
      length, breadcrumb reset).

## In review (branches, 2026-07-05 autonomous session)
- `design/gate-network` — full gate/route-discovery design + topology
  diagrams + research (docs/GATE_NETWORK.md there). Recommendation:
  Clover topology, Pretzel-lite prototype first. KEEP — later slices
  still reference it.
- `proto/gate-network` — FOLDED into main 2026-07-05 (Pretzel-lite
  prototype, see slice 7). Branch and worktree deleted.
- `polish/quality-pass` — FOLDED into main 2026-07-05 (ghost tint variety,
  garage milestone label, HUD next-purchase hint cherry-picked; superseded
  steering-floor commit dropped). Branch and worktree deleted.

## Later (unordered)
- Prestige/reset layer; more cars (CarStats variants); track hazards that
  make YOUR lap risky but ghosts immune (risk = better recorded lines);
  minimap/map screen; web export (music/audio autoplay needs the
  click-to-start gate there). Audio pass landed 2026-07-07.
- Engine bump to Godot 4.7.x once 4.7.1 lands (brew has 4.7.0 now; shared
  binary also serves fieldbound/overlap — coordinate before upgrading).
- GdUnit4 tests for Bank math once the economy stabilizes (slice 6+), not
  before.
