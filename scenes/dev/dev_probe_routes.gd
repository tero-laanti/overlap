class_name DevProbeRoutes
extends RefCounted
## DevProbe's authored waypoint routes, split out to keep the probe
## scenario under the line ceiling. Pure data — the probe hands these to
## DevDriver as it advances through its phases. Island v2 hub
## (docs/MAP_DESIGN_V2.md §2); annex routes return with their
## re-adaptation slices.

## Hairpin apex / tree gap capture: the default reach corner-cuts both.
const CLIFF_REACH := 120.0

const RING: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(0, -1380), Vector2(1000, -1450),
	Vector2(1900, -1250), Vector2(2300, -800), Vector2(1950, -250),
	Vector2(2350, 300), Vector2(2650, 750), Vector2(2350, 1150),
	Vector2(1400, 1200),
]
const CUT: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(-200, -1390), Vector2(450, -1360),
	Vector2(500, -900), Vector2(500, 0), Vector2(500, 1000),
	Vector2(0, 1200),
]
## Off the riser into the sand bowl, around, and back onto the hub.
const DUNE: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2540, 420), Vector2(-3350, 640), Vector2(-4250, 330),
	Vector2(-4820, -350), Vector2(-4250, -1060), Vector2(-3300, -1210),
	Vector2(-2660, -640), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(0, -1380), Vector2(1000, -1450),
	Vector2(1900, -1250), Vector2(2300, -800), Vector2(1950, -250),
	Vector2(2350, 300), Vector2(2650, 750), Vector2(2350, 1150),
	Vector2(1400, 1200),
]
## Sand bowl, then the chord — the two-gate combo discovery.
const SANDCUT: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2540, 420), Vector2(-3350, 640), Vector2(-4250, 330),
	Vector2(-4820, -350), Vector2(-4250, -1060), Vector2(-3300, -1210),
	Vector2(-2660, -640), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(-200, -1390), Vector2(450, -1360),
	Vector2(500, -900), Vector2(500, 0), Vector2(500, 1000),
	Vector2(0, 1200),
]
## NE fork, hairpin ladder, lighthouse, north-shore esses, descent
## through the X into the chord.
const CLIMB: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(0, -1380), Vector2(1000, -1450),
	Vector2(1900, -1250), Vector2(2250, -1490), Vector2(2390, -1820),
	Vector2(3100, -1820), Vector2(3250, -1880), Vector2(3270, -1990),
	Vector2(3250, -2100), Vector2(3100, -2160),
	Vector2(2500, -2160), Vector2(2350, -2220), Vector2(2330, -2330),
	Vector2(2350, -2440), Vector2(2500, -2500),
	Vector2(3100, -2500), Vector2(3290, -2580), Vector2(3320, -2710),
	Vector2(3290, -2840), Vector2(3100, -2920),
	Vector2(2570, -2980), Vector2(2130, -2860), Vector2(1710, -3000),
	Vector2(1370, -2850),
	Vector2(1110, -2450), Vector2(700, -2100), Vector2(520, -1750),
	Vector2(500, -1300), Vector2(500, -900), Vector2(500, 0),
	Vector2(500, 1000), Vector2(0, 1200),
]
## Same climb, but turning east at the X onto the top straight.
const HIGH_RING: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(0, -1380), Vector2(1000, -1450),
	Vector2(1900, -1250), Vector2(2250, -1490), Vector2(2390, -1820),
	Vector2(3100, -1820), Vector2(3250, -1880), Vector2(3270, -1990),
	Vector2(3250, -2100), Vector2(3100, -2160),
	Vector2(2500, -2160), Vector2(2350, -2220), Vector2(2330, -2330),
	Vector2(2350, -2440), Vector2(2500, -2500),
	Vector2(3100, -2500), Vector2(3290, -2580), Vector2(3320, -2710),
	Vector2(3290, -2840), Vector2(3100, -2920),
	Vector2(2570, -2980), Vector2(2130, -2860), Vector2(1710, -3000),
	Vector2(1370, -2850),
	Vector2(1110, -2450), Vector2(700, -2100), Vector2(520, -1750),
	Vector2(500, -1520), Vector2(900, -1430), Vector2(1900, -1250),
	Vector2(2300, -800), Vector2(1950, -250), Vector2(2350, 300),
	Vector2(2650, 750), Vector2(2350, 1150), Vector2(1400, 1200),
]
## Through the golden tree gap into the woods arc — the first crossing
## proves the secret trigger fires from real driving.
const FOREST: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1900, -1450), Vector2(-1990, -1620), Vector2(-2060, -1810),
	Vector2(-2250, -2100),
	Vector2(-2350, -2850), Vector2(-1650, -3300), Vector2(-800, -3150),
	Vector2(-550, -2400), Vector2(-1100, -1450),
	Vector2(0, -1380), Vector2(1000, -1450), Vector2(1900, -1250),
	Vector2(2300, -800), Vector2(1950, -250), Vector2(2350, 300),
	Vector2(2650, 750), Vector2(2350, 1150), Vector2(1400, 1200),
]
## Off the esses into the container maze, the dock straight, and back
## via the carousel.
const HARBOR: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(0, -1380), Vector2(1000, -1450),
	Vector2(1900, -1250), Vector2(2300, -800), Vector2(2100, -400),
	Vector2(2750, -200), Vector2(3350, -350), Vector2(3350, -800),
	Vector2(4050, -800), Vector2(4050, -150), Vector2(4650, -150),
	Vector2(4650, 650), Vector2(3700, 800), Vector2(2660, 740),
	Vector2(2350, 1150), Vector2(1400, 1200),
]
## Down the pier and over the canal ramp — flat out into the jump; the
## post-canal waypoint keeps the driver committed through the flight.
## GOTCHA: the canal water must never reach west of the pier — a slide
## off the NE maze corner has to land on recoverable grass, not splash
## (that trap cost two calibration runs).
const CANAL: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(0, -1380), Vector2(1000, -1450),
	Vector2(1900, -1250), Vector2(2300, -800), Vector2(2100, -400),
	Vector2(2750, -200), Vector2(3350, -350), Vector2(3350, -800),
	Vector2(4300, -800), Vector2(5140, -800), Vector2(5150, -450),
	Vector2(5150, 420), Vector2(5100, 620), Vector2(4200, 760),
	Vector2(3700, 800), Vector2(2660, 740),
	Vector2(2350, 1150), Vector2(1400, 1200),
]
