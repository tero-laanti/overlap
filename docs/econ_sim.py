#!/usr/bin/env python3
"""Overlap2 economy pacing simulator.

Models a 60-minute session: a player whose driving skill improves with laps,
ghosts that pay per completed loop, greedy best-ROI purchasing, and upgrade
effects that only land after the next PB re-record. Scores each config
against "fun pacing" targets derived from idle-game research.
"""
import math
from dataclasses import dataclass, field

TRACK_MIN_LAP = 3.8          # physical floor for this track
BASE_LAP_CAR = 7.0           # stock car, perfect line
SESSION = 3600               # seconds simulated
ACTIVE_WINDOW = 3600         # player drives the whole session (prototype phase)


@dataclass
class Config:
    name: str
    payout: float = 10.0
    ghost_base: float = 10.0
    ghost_growth: float = 1.08
    up_speed_base: float = 50.0
    up_accel_base: float = 40.0
    up_grip_base: float = 40.0
    up_growth: float = 1.15
    active_lap_mult: float = 0.0     # player's own lap pays payout * this
    milestones: tuple = ()           # ghost counts that multiply income
    milestone_x: float = 2.0
    max_level: int = 8
    start_money: float = 0.0


@dataclass
class State:
    money: float = 0.0
    ghosts: int = 1                  # first ghost is free on first PB
    lv_speed: int = 0
    lv_accel: int = 0
    lv_grip: int = 0
    skill: float = 1.22              # lap = car_optimal * skill
    laps_driven: int = 0
    pb: float = 0.0                  # current recorded ghost lap
    pending_car_gain: bool = False   # upgrade bought, not yet re-recorded
    log: list = field(default_factory=list)


def car_optimal(s: State) -> float:
    speed_mult = 1.05 ** s.lv_speed
    lap = BASE_LAP_CAR / (speed_mult ** 0.9)
    lap *= 0.99 ** s.lv_accel
    lap *= 0.985 ** s.lv_grip
    return max(lap, TRACK_MIN_LAP)


def milestone_mult(cfg: Config, ghosts: int) -> float:
    m = 1.0
    for g in cfg.milestones:
        if ghosts >= g:
            m *= cfg.milestone_x
    return m


def income_rate(cfg: Config, s: State) -> float:
    if s.pb <= 0:
        return 0.0
    return s.ghosts * cfg.payout * milestone_mult(cfg, s.ghosts) / s.pb


def try_purchases(cfg: Config, s: State, t: float):
    """Greedy: buy whichever affordable option has the best d(income)/cost."""
    while True:
        options = []
        g_cost = cfg.ghost_base * cfg.ghost_growth ** (s.ghosts - 1)
        base = income_rate(cfg, s)
        # ghost: income with one more ghost (may cross milestone)
        if s.pb > 0:
            gain = (s.ghosts + 1) * cfg.payout * milestone_mult(cfg, s.ghosts + 1) / s.pb - base
            options.append(("ghost", g_cost, gain))
        # upgrades: estimate post-re-record income gain
        for kind, base_cost, lv in (("speed", cfg.up_speed_base, s.lv_speed),
                                    ("accel", cfg.up_accel_base, s.lv_accel),
                                    ("grip", cfg.up_grip_base, s.lv_grip)):
            if lv >= cfg.max_level:
                continue
            cost = base_cost * cfg.up_growth ** lv
            s2 = State(**{**s.__dict__, "log": []})
            setattr(s2, f"lv_{kind}", lv + 1)
            new_pb = car_optimal(s2) * max(s.skill, 1.0)
            if s.pb > 0 and new_pb < s.pb:
                gain = s.ghosts * cfg.payout * milestone_mult(cfg, s.ghosts) * (1 / new_pb - 1 / s.pb)
            else:
                gain = 0.0001
            options.append((kind, cost, gain))
        affordable = [(k, c, g) for k, c, g in options if c <= s.money and g > 0]
        if not affordable:
            return
        k, c, g = max(affordable, key=lambda o: o[2] / o[1])
        s.money -= c
        if k == "ghost":
            s.ghosts += 1
        else:
            setattr(s, f"lv_{k}", getattr(s, f"lv_{k}") + 1)
            s.pending_car_gain = True
        s.log.append((t, k, c))


def simulate(cfg: Config) -> dict:
    s = State(money=cfg.start_money)
    t = 0.0
    income_samples = {}
    lap_elapsed = 0.0
    ghost_acc = 0.0
    while t < SESSION:
        dt = 0.5
        t += dt
        active = t < ACTIVE_WINDOW
        # player driving: finishes laps, improves skill, sets PBs
        if active:
            lap_elapsed += dt
            current_lap_time = car_optimal(s) * s.skill
            if lap_elapsed >= current_lap_time:
                lap_elapsed = 0.0
                s.laps_driven += 1
                s.skill = 1.0 + (s.skill - 1.0) * 0.90   # approach clean line
                s.money += cfg.payout * cfg.active_lap_mult * milestone_mult(cfg, s.ghosts)
                if s.pb == 0 or current_lap_time < s.pb:
                    s.pb = current_lap_time
                    s.pending_car_gain = False
        # ghost income (continuous approximation of per-lap payouts)
        rate = income_rate(cfg, s)
        ghost_acc += rate * dt
        if ghost_acc >= 1:
            s.money += ghost_acc
            ghost_acc = 0.0
        try_purchases(cfg, s, t)
        if int(t) % 60 == 0:
            income_samples[int(t) // 60] = rate + (
                cfg.payout * cfg.active_lap_mult * milestone_mult(cfg, s.ghosts) /
                max(s.pb, 1) if active and s.pb else 0)
    # metrics
    buys = s.log
    first_buy = buys[0][0] if buys else None
    buys_10min = len([b for b in buys if b[0] <= 600])
    inc1 = income_samples.get(1, 0.0001) or 0.0001
    inc30 = income_samples.get(30, 0)
    inc60 = income_samples.get(59, 0)
    growth_late = (inc60 / inc30) if inc30 else 0
    gaps = [b2[0] - b1[0] for b1, b2 in zip(buys, buys[1:])]
    max_gap_20 = max([g for b, g in zip(buys, gaps) if b[0] < 1200], default=0)
    early_gaps = sorted(g for b, g in zip(buys, gaps) if b[0] < 600)
    med_gap_early = early_gaps[len(early_gaps) // 2] if early_gaps else 0
    late_buys = [b for b in buys if b[0] >= 1800]
    kinds_10min = len({b[1] for b in buys if b[0] <= 600})
    return {
        "cfg": cfg.name,
        "first_buy_s": first_buy,
        "buys_10min": buys_10min,
        "buys_total": len(buys),
        "ghosts": s.ghosts,
        "levels": (s.lv_speed, s.lv_accel, s.lv_grip),
        "pb": round(s.pb, 2),
        "inc_1m": round(inc1, 2),
        "inc_30m": round(inc30, 1),
        "inc_60m": round(inc60, 1),
        "x_by_30m": round(inc30 / inc1, 1),
        "late_growth_x": round(growth_late, 2),
        "max_gap_early_s": round(max_gap_20),
        "med_gap_early_s": round(med_gap_early),
        "buys_last_30m": len(late_buys),
        "kinds_10min": kinds_10min,
        "money_end": round(s.money),
        "buys": buys,
    }


CONFIGS = [
    Config("L: steep", active_lap_mult=3.0, milestones=(10, 25, 50),
           ghost_base=25, ghost_growth=1.25,
           up_speed_base=75, up_accel_base=50, up_grip_base=50, up_growth=1.5,
           max_level=8),
    Config("M: L milestone x1.5", active_lap_mult=3.0, milestones=(10, 25, 50),
           milestone_x=1.5, ghost_base=25, ghost_growth=1.25,
           up_speed_base=75, up_accel_base=50, up_grip_base=50, up_growth=1.5,
           max_level=8),
    Config("N: steeper ghosts", active_lap_mult=3.0, milestones=(10, 25, 50),
           milestone_x=1.5, ghost_base=25, ghost_growth=1.35,
           up_speed_base=75, up_accel_base=50, up_grip_base=50, up_growth=1.5,
           max_level=8),
    Config("O: N upgrades 1.6", active_lap_mult=3.0, milestones=(10, 25, 50),
           milestone_x=1.5, ghost_base=25, ghost_growth=1.35,
           up_speed_base=75, up_accel_base=50, up_grip_base=50, up_growth=1.6,
           max_level=8),
    Config("P: O active x5", active_lap_mult=5.0, milestones=(10, 25, 50),
           milestone_x=1.5, ghost_base=25, ghost_growth=1.35,
           up_speed_base=75, up_accel_base=50, up_grip_base=50, up_growth=1.6,
           max_level=8),
    Config("FINAL: ghosts 1.30, ms x2", active_lap_mult=3.0,
           milestones=(10, 25, 50), milestone_x=2.0,
           ghost_base=25, ghost_growth=1.30,
           up_speed_base=75, up_accel_base=50, up_grip_base=50, up_growth=1.5,
           max_level=8),
]

if __name__ == "__main__":
    for cfg in CONFIGS:
        r = simulate(cfg)
        print(f"\n=== {r['cfg']} ===")
        print(f"  first buy: {r['first_buy_s']}s | buys in 10min: {r['buys_10min']}"
              f" (kinds={r['kinds_10min']}) | total: {r['buys_total']}"
              f" | last-30min buys: {r['buys_last_30m']}")
        print(f"  gaps early: median {r['med_gap_early_s']}s, max {r['max_gap_early_s']}s")
        print(f"  end: ghosts={r['ghosts']} levels(spd,acc,grp)={r['levels']}"
              f" pb={r['pb']}s money=${r['money_end']}")
        print(f"  income: 1m={r['inc_1m']}/s 30m={r['inc_30m']}/s 60m={r['inc_60m']}/s"
              f" | x{r['x_by_30m']} by 30m | late growth x{r['late_growth_x']}")
        timeline = [f"{int(b[0])}s:{b[1][0]}" for b in r["buys"][:14]]
        print(f"  first buys: {' '.join(timeline)}")
