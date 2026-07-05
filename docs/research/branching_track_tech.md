# Research: branching 2D road networks in Godot 4.6 (2026-07-05)

Agent research report, lightly trimmed. Decisions adopted in
docs/GATE_NETWORK.md §7.

## 1. Road geometry: centerline-first

Author each segment as **Path2D/Curve2D**; generate the drivable polygon:
`Curve2D.tessellate()` (curvature-adaptive point density) →
`Geometry2D.offset_polyline(points, half_width, JOIN_ROUND, END_ROUND)`
inflates the centerline into a closed road polygon with correct rounded
joins — no hand-rolled perpendicular strip math (self-intersects on
sharp corners). Round/square end caps overhang junction mouths so they
seal without gaps. Make the segment a @tool script listening to the
curve's `changed` signal for live editor rebuild.

**Junction merging: two-layer flat-color overdraw, not polygon union.**
Each segment renders a wider border polygon (global z=0) and a surface
polygon (z=1), flat opaque colors. Surfaces overdraw borders at
junctions → curbs break open automatically; identical colors hide seams
(GL Compatibility safe while opaque). `merge_polygons()` only if
translucency/outline shaders are needed later — it's pairwise-only in
GDScript, non-touching inputs yield multiple polys, and closed circuits
produce hole polygons Polygon2D can't render. Lane markings: Line2D with
tiled dashed texture over the same tessellated points.

Alternatives rejected: hand-placed Polygon2D rects (no centerline, dies
on curves), TileMap (fights arbitrary junction angles),
godot-road-generator addon (3D-only), SmartShape2D (terrain-oriented,
not junction-aware). Roll our own ~100-line tool script.

## 2. Junctions & gates

Gate = StaticBody2D + CollisionShape2D barrier + visual + optional
Area2D purchase-prompt sensor. Toggle with
`$CollisionShape2D.set_deferred("disabled", open)` — direct toggling
mid-physics-flush errors (godot#67731). Purchased state lives in the
economy singleton; gates read it in _ready and subscribe to a
purchase signal.

**Tunneling math:** per-tick travel = speed / physics_tps; at 1000 px/s
and 60 Hz ≈ 16.7 px/tick — thinner Area2Ds get skipped. CCD is
RigidBody-only; CharacterBody2D sweeps bodies, not areas. Ghosts have no
physics at all and can never trigger areas.

**Recommendation: analytic segment-crossing tests instead of Area2D
checkpoints** — the racing-game "plane crossing" pattern in 2D:

```gdscript
if Geometry2D.segment_intersects_segment(prev_pos, pos, line.a, line.b):
    var dir := signf((line.b - line.a).cross(pos - prev_pos))  # +fwd/-back
    crossing_event.emit(line.id, dir)
```

Tunnel-proof at any speed, a few dot products per tick, identical code
path for player (physics tick) and ghosts (replay advance — validates
recordings headlessly), deterministic. Keep Area2D only for latency-
tolerant prompts, sized ≥48–64 px thick, full road width. Place one
crossing line at each branch mouth + one mid-edge per segment, derived
from the centerline (`sample_baked` + perpendicular), so checkpoints
never drift from geometry.

## 3. Route identification & lap validation

Directed graph: nodes = junctions (+start/finish), edges = segments, one
crossing line per edge. Traversal accumulates ordered (edge_id,
direction) events; **RouteDef = canonical edge-id sequence**; route key =
joined id string. **Edge lists beat junction bitmasks** — bitmasks break
on 3-way junctions and routes that skip junctions.

Lap state machine: start/finish crossing closes the lap → look up edge
list in the route registry → `lap_completed(route_id, time)` or
`lap_invalid`. Double-back handling: backward crossing of the most
recent edge pops it (U-turn canonicalization); any other backward
crossing dirties the lap. Hysteresis: ignore repeat crossings of the
same line until the car moves N px away. Mid-lap "which route am I on":
walk a **trie of registered edge sequences** with the current prefix —
gives an explicit "route locked in" moment and prunes candidate ghost
fleets; gate ownership prunes further.

## 4. Scene architecture

Author geometry in one network scene (Path2D gizmos are the point of the
editor); keep all data in Resources:

```
TrackNetwork (Node2D, @tool)  — exports network_def: TrackNetworkDef
├── Segments/  RoadSegment.tscn = Path2D + Surface + Border + Walls
├── Junctions/ Junction.tscn (marker + id)
├── Gates/     Gate.tscn (StaticBody2D + barrier + prompt area)
├── StartFinish (Marker2D + crossing line)
└── RouteTracker (pure logic node: crossings in, laps/discoveries out)
```

Resources: TrackNetworkDef {segments, gates, routes, widths} ·
SegmentDef {id, from/to junction, Curve2D} · GateDef {id,
blocks_segment, price} · RouteDef {id, name, edge_sequence, par_time}.
A @tool "Bake" button copies authored curves into the def, derives all
crossing lines, and validates every RouteDef is a connected path — fail
loudly in-editor. RouteTracker consumes only the def (headless
unit-testable). Runtime could rebuild the scene from the def alone
(door open for procedural/DLC tracks).

## Sources

Godot docs: Curve2D, Geometry2D, Beziers tutorial, physics
troubleshooting, Resources · Hedberg Games curve rendering · bugnet.io
tunneling math · godot#67731 (set_deferred disabled) · proposals#13594
(merge_many_polygons) · Godot forums polygon-merge threads ·
GameDev.net racing checkpoint thread · TheDuckCow/godot-road-generator
(3D) · SmartShape2D · Simon Dalvai custom-resource patterns.
