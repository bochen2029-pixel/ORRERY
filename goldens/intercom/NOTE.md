# goldens/intercom — NOTE

**Golden:** `fb722929cde142b8ebd5f9f2baf1203bce50fb8df92068eb44f91cf942411c84`
(`declared.hash`). Frozen 2026-07-14, ORRERY Intercom v1.0.0.

**What it freezes.** A scripted, deterministic **posit-golden-match converge scenario** run entirely
through the ASIC loop: `converge-open` (falsifier = `posit` in `golden` mode, expect-hash =
posit's frozen `7a22dd22…`, target 1.0, k=2, arms `trace,decoy`) followed by a fixed 4-proposal
sequence —

1. `{"case":"nonsense…"}` → posit exits 2 → **INVALID** (excluded; `invalid=1`)
2. `{"golden":true}` → declared hash == posit golden → score 1.0 → **CHAMPION**
3. `{"golden":true}` → 1.0, no improvement (`no_improve=1`)
4. `{"golden":true}` → 1.0, `no_improve=2 == k` → **CONVERGED**

The declared object is the ts-free / id-free outcome (scenario, champion params + declared blake2b +
score + verdict, converged, spent, invalid, no_improve, and the ordered candidate records). blake2b of
its canonical serialization = the golden.

**Re-baseline protocol.** This golden **re-baselines with `posit`** (like `mcp`/`orrery`): the champion's
`declared_blake2b` IS posit's frozen declared hash. If `posit`'s golden legitimately changes (a contract
bump + re-freeze), this scenario's champion hash changes and this golden MUST be re-frozen in the same
commit. A mismatch that is NOT explained by a posit re-baseline is a real regression in the falsifier /
converge machinery — investigate, do not re-freeze.

**Reproduce:** `python C:\ORRERY\Intercom\intercom.py --golden` (deterministic, instant, no GPU — posit
is a Python tool). ≥3× byte-identical confirmed at freeze.

*Structure, never acquaintance. The judge is a golden; the proposer never scores itself.*
