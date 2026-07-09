# golden — `orreryd` v0.1.0

## What is frozen
The declared output of the canned 3-job drain:
```
orreryd.exe --golden
```
A fresh temp spool gets `j1` = posit `--golden`, `j2` = unknown tool, `j3` = posit `--golden`; the REAL daemon loop drains it (one tenant, lexicographic FIFO). Declared: 3/3 completed, order ok, classes `[pass,error,pass]` (the queue survives an error job), `j1`/`j3` declared hashes == posit's frozen golden (the I-12 chain), `.DONE` written.

Files: `declared.hash` (blake2b-256 of the canonical declared object = `86f133bb…`), `stdout.txt` (full JSON envelope).

## Hash domain (D-013, same as every tool)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — fixed key order, gate values `%.6f`. `tool`/`version`/`notes` excluded. Reproduced **3× byte-identical** at freeze (2026-07-09). Timestamps/durations/spool paths are non-declared; status files are operational UI.

## What it proves
1. **Serialization** — jobs run one at a time in lexicographic FIFO through the real loop (the GPU-tenancy guarantee, at the behavioral level the golden can see).
2. **Error containment** — a bad job becomes an `error` record and the queue continues (never stalls, never crashes).
3. **The I-12 chain through the daemon** — the drained posit records hash to `7a22dd22…` == `goldens/posit/declared.hash`.
4. **Campaign semantics** — `.DONE` written exactly when the drain empties.

## DELIBERATE COUPLING (same protocol as mcp)
This golden embeds posit's frozen declared hash (see `contracts/orreryd.contract.md` "Golden coupling" and `goldens/mcp/NOTE.md`). **If posit's golden is ever legitimately superseded under review, orreryd's golden re-baselines in the same operator-signed commit** (record old/new hashes for both here). Catalogue growth cannot break this golden (fixed canned jobs, not a live registry check).

## Environment
Recorded in `runs/orreryd_golden.result.lock`. Live-smoke evidence at freeze: a real spool drained a ratchet GPU job (200k trajectories, `p_unwrite_mc=0.12623`) + a posit job with hash-chained records; a 2-second budget killed an oversized GPU job (`exit_class:"timeout"`, code 258) with a clean drain exit.
