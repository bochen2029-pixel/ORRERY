#!/usr/bin/env python3
"""
analyze_round01.py — turn the S5 per-level CSVs into a rigorous two-sided per-level verdict.

`someone`'s JSON p_value is one-sided (tests normal-wins-more-than-half). To license a
per-level winner in EITHER direction we need both tails. This reads the final-generation
per-replica (normal_fit, zombie_fit) from each runs/round01/round01_L?.csv, computes the
per-replica delta, and runs an exact two-sided sign test.

Deterministic, stdlib only. Prints a table + the licensed verdict per level (D-DAK-RNG bar:
a winner is corpus-grade only when its one-sided sign-test p < 0.05; else TIE).
"""
import csv, os, math, sys
TIE_BAND = 0.02
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "round01")

def binom_cdf_ge(k, n):   # P(X >= k), X ~ Binomial(n, 0.5)
    if k <= 0: return 1.0
    if k > n: return 0.0
    s = 0.0
    for i in range(k, n+1):
        # exact C(n,i) * 0.5^n
        c = 1.0
        kk = min(i, n-i)
        for j in range(kk): c = c*(n-j)/(j+1)
        s += c
    return s * (0.5**n)

def per_replica_final_deltas(path):
    rows = list(csv.DictReader(open(path, newline="")))
    if not rows: return {}
    # last gen per replica
    last = {}
    for r in rows:
        rep = int(r["replica"]); gen = int(r["gen"])
        if rep not in last or gen > last[rep][0]:
            last[rep] = (gen, float(r["normal_fit"]) - float(r["zombie_fit"]))
    return {rep: d for rep,(g,d) in last.items()}

def verdict(level):
    path = os.path.join(OUT, f"round01_{level}.csv")
    if not os.path.isfile(path): return None
    deltas = per_replica_final_deltas(path)
    n = len(deltas)
    wins   = sum(1 for d in deltas.values() if d >  TIE_BAND)   # normal beats zombie
    losses = sum(1 for d in deltas.values() if d < -TIE_BAND)   # zombie beats normal
    ties   = n - wins - losses
    neff = wins + losses
    p_normal = binom_cdf_ge(wins, neff) if neff else 1.0        # H1: normal wins > half
    p_zombie = binom_cdf_ge(losses, neff) if neff else 1.0      # H1: zombie wins > half
    mean_delta = sum(deltas.values())/n if n else 0.0
    if p_normal < 0.05:   lic = "NORMAL (licensed)"
    elif p_zombie < 0.05: lic = "ZOMBIE (licensed)"
    else:                 lic = "TIE (no significant winner)"
    return dict(level=level, n=n, wins=wins, losses=losses, ties=ties,
                mean_delta=mean_delta, p_normal=p_normal, p_zombie=p_zombie, licensed=lic)

def main():
    print(f"{'lvl':3} {'n':>3} {'win(N)':>6} {'loss(Z)':>7} {'tie':>3} "
          f"{'meanD':>8} {'p_norm':>7} {'p_zomb':>7}  verdict")
    rows = []
    for L in ["L0","L1","L2","L3"]:
        v = verdict(L)
        if not v:
            print(f"{L}: (no csv)"); continue
        rows.append(v)
        print(f"{v['level']:3} {v['n']:>3} {v['wins']:>6} {v['losses']:>7} {v['ties']:>3} "
              f"{v['mean_delta']:>8.4f} {v['p_normal']:>7.4f} {v['p_zombie']:>7.4f}  {v['licensed']}")
    # monotonicity check on mean_delta (strong form = normal advantage grows with complexity)
    if len(rows) == 4:
        md = [r["mean_delta"] for r in rows]
        mono = all(md[i] <= md[i+1] for i in range(3))
        print(f"\nmean_delta by level (L0->L3): {[round(x,4) for x in md]}")
        print(f"strong monotone-increasing form supported: {mono}")
        seq = "".join("N" if r["licensed"].startswith("NORMAL") else
                      "Z" if r["licensed"].startswith("ZOMBIE") else "T" for r in rows)
        print(f"licensed winner sequence [L0,L1,L2,L3]: [{','.join(seq)}]")
    return 0

if __name__ == "__main__":
    sys.exit(main())
