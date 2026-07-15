# ORRERY Intercom — first live autonomous multi-agent tournament (proof, 2026-07-14)

**Status: capability PROOF, not a cited science result.** This documents the first end-to-end run of
ORRERY Intercom (D-034) with *real* subagents. The physics answer below is a genuine, reproducible
ratchet measurement, but it is a demonstration of the coordination substrate — not a theory-facing
claim (no §III content; ratchet's own golden is the science anchor).

## The setup
- **Coordinator** (opus-4.8, id `5nwfpnba`) opened a `converge` run `live1`, falsifier = the **ratchet**
  tool in `target` mode: find `rho` where the MC unwrite probability `p_unwrite_mc = 0.50 ± 0.02` at
  `p=0.2` (`trials=500000`, `seed=20260705`). Pre-registered hypothesis; budget 16; k=3.
- **Three worker subagents** (sonnet-4.6: `zugchatd`, `giocbt5z`, `ugqfw8mr`) were spawned in parallel,
  each armed only with the task + the bus CLI. They coordinated **solely through the shared board** —
  no direct communication, no human in the loop. Each proposed `rho` via `--set rho=X` (no JSON); the
  **coordinator-side falsifier ran ratchet on the GPU** and scored each from the declared `p_unwrite_mc`.

## What happened (the append-only record)
| cand | agent | rho | p_unwrite_mc | score | verdict |
|---|---|---|---|---|---|
| #2 | giocbt5z | 0.300 | 0.5778 | 0.4812 | reject |
| #1 | zugchatd | 0.330 | 0.4344 | 0.5625 | reject |
| #3 | zugchatd | 0.315 | 0.4991 | **1.0000** | pass ← champion |
| #4 | giocbt5z | 0.315 | 0.4991 | 1.0000 | pass |
| #5 | ugqfw8mr | 0.316 | 0.4945 | 1.0000 | pass |
| #6 | ugqfw8mr | 0.314 | 0.5037 | 1.0000 | pass |

The workers bracketed with their distinct opening probes (0.30 / 0.33 / 0.36), **read each other's
results off the board**, and independently bisected to `rho ≈ 0.315`. The run **CONVERGED**
(`no_improve 3/3`, k=3) after 6 proposals — 0 invalid. The bus, not any agent, declared convergence.

## The result
**`rho ≈ 0.315` gives `p_unwrite_mc ≈ 0.4991` at `p=0.2`** (ratchet v1.0.0, `seed=20260705`,
`trials=500000`). Champion candidate #3, declared blake2b
`7032452eea5111ebdc31dee6b531bbb314b387ba1c83164b722b253eebabfadf`. Full provenance:
`runs/intercom_live1_demo.result.lock`.

## Why this matters
This is the anti-confabulation loop running autonomously: the agents *proposed*, an executable ORRERY
contract *judged*, and the result carries its declared hash — no agent ever scored itself, and the
convergence criterion was met by the tool's output, not by agreement. It is the mechanism the science
will use to run parameter searches, and the same shape (mode `golden`, roster = cold rebuilders) is an
autonomous N-way cold two-pass. Reproduce: re-run ratchet at `rho=0.315 p=0.2 trials=500000 seed=20260705`.

*Structure, never acquaintance. The judge is the tool; the proposer never scores itself.*
