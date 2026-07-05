# someone — two-pass / conformance verification (S6)

**Tool:** `someone` v1.1.0 · binary blake2b `237d185f…` · **date:** 2026-07-05 · sm_89 / CUDA 13.1

## Verification strength (honest — do not overclaim)
This is a **thorough single-agent verification**: a fresh contract-conformance battery (re-derived from `contracts/someone.contract.md` v1.1.0 + `someone.schema.json`, verifying observed behavior, not code claims) **plus** golden reproduction proven **4× byte-identical**. An **independent cold-context subagent** pass was *attempted* but stalled on an async golden-run handoff and did not report; it is not counted. Per ARCHITECTURE §9 / the RAYFORMER ADR-007 lesson, a same-agent pass cannot truly *forget* the build, so a **genuine fresh-SESSION cold two-pass remains OWED before the science cites this tool for anything load-bearing.** Status: **single-agent-verified · cold-two-pass-pending.**

## Golden reproduction (the definitive determinism check)
`someone --golden` → `GOLDEN OK blake2b=aa5b731d…` matching `goldens/someone/declared.hash`, **byte-identical across 4 runs**:
- 3× background verification (465s, 465s, 464s) on the pre-freeze binary,
- 1× on the committed binary `237d185f` (the S4 stdout capture) → GOLDEN OK.

## Conformance battery (all PASS)
| check | result | evidence |
|---|---|---|
| bad `--pop` (5, <16) → exit 2 | PASS | exit=2 |
| bad `--complexity` (L9) → exit 2 | PASS | exit=2 |
| unknown flag → exit 2 | PASS | exit=2 |
| missing `--seed` on a run → exit 2 | PASS | exit=2 |
| valid run → exit 0 or 1 (never 2) | PASS | exit=0 |
| `tool`="someone", `version`="1.1.0" | PASS | someone/1.1.0 |
| firewall sentence present in `notes` | PASS | "…nothing about whether the agent feels…" |
| default `--k` = N/4 | PASS | k=16 for N=64 |
| default `--ensemble` = 1 | PASS | ensemble=1 |
| `--json` validates against `someone.schema.json` (2 configs, `jsonschema`) | PASS | OK |
| determinism: declared output byte-identical across 2 runs | PASS | identical |

Selftest (`--selftest`, exit 0) independently checks: blake2b KATs, the **confound-fix proof** (gen-0 base layout byte-identical across L0–L3), the gap mechanism (all-normal gap>0.01; all-zombie fires G-NO-GAP), and determinism.

## Verdict
**CONFORMANT to `someone` contract v1.1.0** on all checked dimensions (CLI/ranges/defaults, output schema, exit-code semantics 0/1/2, determinism, golden reproduction, the structure/acquaintance firewall). Cold fresh-session two-pass is the one remaining verification owed for full citation-grade trust.
