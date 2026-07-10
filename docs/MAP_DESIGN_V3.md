# Overlap — The Archipelago (map v3)

Status: APPROVED 2026-07-10 ("let's plan and implement"); V3-1 built
the same day. Supersedes the "one growing island" premise of
MAP_DESIGN_V2 §0; V2's hub geometry, junction-spacing rules and
economy normalization still govern everything that survives. Read V2
first. BUILT: V3-1 (Home simplified — chord/cliffs/harbor removed,
dunes re-grammared as the T1 fork). NEXT: V3-2 the strait + Port.

## 0. Why v3 (human feedback, 2026-07-10)

Playtest verdict on the v2 island as it grew:

- **T-junctions kill momentum.** The chord reads as "turn backwards to
  enter"; the dune loop rejoins at ~135°. Racing variants must fork
  and merge tangentially — a decision you take at speed, not a stop.
- **Route identity is illegible.** With six appendages braided onto
  one ring, the player cannot tell what combination "counts" as a
  track: desert+forest? everything? the loop with or without the
  jump? Authored edge-sequences are invisible grammar; the player
  needs the geography itself to answer the question.
- **Verdict: "I like the idea but not the execution. Maybe there
  should be a completely another base loop that we reach when we
  unlock a jump. Keep this first clover simple; the next one can be
  more difficult."**

## 1. The model

The world is an **archipelago**. Each island is a small, self-
contained clover: ONE base loop + at most TWO purchasable variants +
at most ONE secret. An island's whole route menu fits in your head —
that is the legibility budget, and it is a hard cap.

Islands, not gates, are the big-ticket progression. The Jump Kit (and
later linkers) are **bridges between islands** — travel, never part
of a lap. Crossing the strait is the "map explodes" moment: a whole
new landmass with its own start line, its own rivals, its own fleets
in its own livery filling its own roads.

**Bridge gating (human, 2026-07-10):** the bridge to the next island
goes on sale only when the current island is COMPLETE — all its
routes unlocked — and you have the cash. Completion, not just money,
is the ticket; finishing an island's route menu is what points you at
the horizon. Bridge *flavor* varies per crossing (jump kit, ferry,
teleport, …) — the grammar rule is only that it's travel, never a lap
ingredient.

**Junction grammar (hard rules, added to the authoring canon):**

1. Variant ENTRY is a fork: the new road continues your heading
   (straight-on = adventure, turning = staying home), never > 45°.
2. Variant EXIT merges tangentially (≤ 30°) into a straight — never
   into a corner, never against travel direction.
3. One decision per corner; junction mouths ≥ 1600 px apart (V2 §4).
4. New routes beyond the per-island cap come from braiding existing
   asphalt (line combos), never from new appendages.
5. **Variants exclude by position** (human, 2026-07-10): every
   variant's fork sits on a track section another variant bypasses,
   so no two variants fit in one lap. N loops = exactly N+1 possible
   laps, never a combinatorial menu — and no drivable lap can match
   zero authored routes (an unauthored combo silently voids, the
   worst feedback in the game). On Home: the dune bypasses the riser;
   the forest forks off the riser, so dune+forest cannot happen.

## 2. The islands

### Island 1 — HOME (keep, simplify)
- Base loop: the approved 15 s GP hub, untouched.
- Variant 1: THE DUNES, re-grammared: fork at T1 ("don't brake —
  continue straight into the sand"), bowl loop, tangential rejoin
  onto the riser heading north. A section-swap of the west corner.
- Secret: FOREST RUN as-is (golden gap; off-road entry is exempt
  from fork grammar by nature).
- REMOVED: the chord (both routes: cut, sandcut), the cliff annex,
  the harbor annex — they leave Island 1 entirely. The chord's
  "cheap first gate" role passes to the Dune Gate; the onboarding
  rival ladder is untouched.
- Route menu: Grand Ring, Dune Bend, Forest Run. Three. Readable.

### Island 2 — THE PORT (rebuild from harbor parts; "more difficult")
- Reached by the Jump Kit: a shore ramp on Home's east coast jumps
  the strait to the Port's west shore; a mirrored ramp jumps back.
  Travel, not lap — no route crosses the water.
- Base loop: rebuilt from the container maze + dock straight as a
  closed stop-go circuit with its own start line and garage pad
  (annex of the one GARAGE — same shop, second location).
- Variant 1: THE PIER with the canal jump — the one lap that uses a
  jump INSIDE a route, introduced only after jumps are familiar as
  travel. Canal Runner's premium survives here.
- Variant 2 (later): crane yard / oil-slick alley (V2 hazard note).
- Rivals: its own resident pair at Port arrival spec.

### Island 3 — THE CRAG (later; hardest)
- The proven cliff ladder + lighthouse + esses as the SPINE of its
  base loop (not an annex — the whole island is the technical lap).
  Washout gap as its jump-variant. Reached by a second bridge
  (coast linker boat/ferry or a longer jump — open).

## 3. Consequences to design around

- **RouteTracker generalizes to one start line per island.** A lap
  closes at the line it opened at; edge sequences stay island-local.
  The active island is simply the last start line crossed. (Analytic
  crossing code is untouched; TrackNetworkDef gains islands or one
  network per island — implementation's choice, data stays authored.)
- **Fleets/income unchanged**: per-route fleets already generalize;
  each island fills with its own colored traffic (pillar 2, now with
  geography). Offline math untouched.
- **Save**: v3 keeps profiles (money/upgrades/rivals/kit) and wipes
  PBs of removed/reshaped routes only (ring + forest survive
  verbatim; dune reshaped → wiped).
- **Minimap** becomes per-island (current island large, others as
  distant silhouettes — the horizon is the ad for the next island).
- **Pacing**: Island 1 economy already tuned; Jump Kit price becomes
  the Island-2 ticket (replaces harbor_gate's slot at ~$2200);
  in-island gates stay cheap and few. Per the §1 bridge-gating rule,
  ShopPacing offers the ticket only once every Home route is unlocked
  (dune gate owned + forest discovered), not on cash alone.

## 4. Build order (each slice playable, probe-verified)

1. **V3-1 Simplify Home**: remove chord/cliffs/harbor from the map +
   network, re-grammar the dune fork/rejoin, retune probe + rivals
   (jade retires; sienna re-records on the new dune line). Game
   shrinks but every junction obeys the grammar.
2. **V3-2 The strait + Port base loop**: shore ramps both ways,
   island-local start lines in RouteTracker, Port ring from maze
   parts, Port residents, garage pad #2.
3. **V3-3 Port pier variant** (canal jump inside a lap), then crane
   yard.
4. **V3-4 The Crag** (cliff spine island, washout variant, bridge 2).

## 5. Open questions (human)

- Port base-loop rhythm: pure stop-go (maze) or maze + dock straight
  as the lap? (Doc assumes maze+dock: burst-and-brake with one long
  breath.)
- ~~Does the ferry/coast linker idea survive for Island 3, or is a
  long jump the only bridge grammar?~~ ANSWERED 2026-07-10: bridge
  flavor is free per crossing (jump/ferry/teleport all fine); the
  only rule is travel-not-lap. Pick per island for theme. A teleport
  bridge could foreshadow the non-Euclidean biome idea (IDEAS.md).
- Island 1 keeps 2 gates (dune + ???) or just the Dune Gate before
  the Jump Kit ticket? (Doc assumes just dune — Home stays gentle.)
