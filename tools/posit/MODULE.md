# MODULE — `posit`

*The third ORRERY tool, and the first **Python** tool (D-005 — Python-is-right). Copies `someone`'s envelope/determinism/golden/two-pass shape. Read `contracts/posit.contract.md` (v1.0.0) first — the contract is authoritative.*

**Status: DONE v1.0.0** — built, golden frozen (`7a22dd22`, 3× byte-identical), selftest green (12 checks), schema-valid.

## Purpose
The **parsimony auditor**. Given a set of explanatory TARGETS and two accounts — a PATCHWORK (a brute posit per phenomenon) and a UNIFIED account (few shared mechanisms + derivations) — count the independent assumptions each spends and decide whether the unification is *real physics-layer parsimony* or *relabeling*. Operationalizes Q3 and answers chat002 ("unification counts only if the number of independent brute posits goes DOWN"). Items are priced posit/bridge = 1.0, import = 0.2, derived = 0.0, and tagged physics/overlay.

## SCOPE GUARD (sacred — the §III firewall)
**This measures the parsimony structure of two accounts (bookkeeping); it makes no claim either account is true, and nothing about qualia — the overlay layer is reported separately and never counted as a win, §III-sealed.** Emitted verbatim in the JSON `notes`.

## Contract
`contracts/posit.contract.md` v1.0.0 (+ `contracts/posit.schema.json`).

## Provenance & language
Ports `C:\Fable_LLC\QUALIA_LAB\gym\posit_counter.py` (the `Item`/`Account`/`audit` model); the worked multi-cluster audits live in `gym/receipts/posit_audits.py`. **Python is right (D-005):** this is exact symbolic accounting — no compute, no scale, no GPU, and *no RNG*. It is the canonical Python-is-right tool; every other ORRERY tool is CUDA.

## Internal design
- **Model:** an account is a list of items `{id, kind∈{posit,bridge,import,derived}, layer∈{physics,overlay}, covers[], via[]}`. `budget(layer)` = Σ of kind-weights over items **deduped by id** (in input order); `covered` = ∪ covers; `floating` = `derived` items whose `via` traces to no posit/bridge/import root in the same account (the confabulation flag).
- **The audit:** `delta_physics = patchwork.physics − unified.physics` (the citable parsimony number), `delta_overlay`, `delta_total`, `same_reach` (both cover all targets). `parsimony="win"` iff `same_reach ∧ delta_physics > tie_band ∧ no unified floating`.
- **Input:** a case JSON via `--case PATH` or `--stdin` (targets + patchwork + unified accounts). Malformed input (unknown kind/layer, missing field, non-JSON) → exit 2.
- **The confabulation guard, numeric:** bridge cost == posit cost (both 1.0), so relabeling a posit as a bridge (or "qualia explains it") never lowers the budget — only genuine DERIVATION (cost 0.0, backed via a real root) does.

## Determinism approach
Trivial and total: exact symbolic accounting, **no RNG, no wall-clock, no floating-point reduction nondeterminism** (fixed-order sums of {1.0, 0.2, 0.0}). The `--seed` flag is accepted for envelope uniformity but is **inert**. blake2b via Python `hashlib`; canonical serialization (fixed key order, `%.6f` floats) built by hand for byte-stable hashing. Hash domain = {seed, params, result, gates, verdict} (D-013).

## Selftest (green — 12 checks)
blake2b KAT; the seed cluster (physics 4.0→3.2, Δ=+0.8, overlay +1.0, total −0.2, same_reach, no floating, win, exit 0); the confabulation guard (bridge==posit cost); floating detection → G-FLOATING → exit 1; equal-budget → reject → G-NO-PARSIMONY → exit 1; the reach guard (cheaper-but-less-reach is not a win); determinism (×2 identical).

## Golden
The embedded **seed cluster** {arrow_of_time, measurement_classicality, low_entropy_start} — the corpus-grade banked win (D-POSIT): `delta_physics = +0.8` at equal reach, no floating, parsimony "win". Frozen `7a22dd22` in `goldens/posit/`; `result.lock` in `runs/posit_golden.result.lock`.

## Build
Python (no compile). The harness runs a syntax-check as the "build" step; the command is in a fenced block so `harness/verify.py`'s `extract_build_cmd` discovers it (an inline span → NO-BUILD-CMD, the defect the ratchet cold two-pass caught):
```
python -m py_compile posit.py
```
Then: `python posit.py --selftest` · `python posit.py --golden` · `python posit.py --case CASE.json --json`. (Windows console is cp1252 — the tool forces UTF-8 stdout.)

## Known issues / caveats
- Multi-cluster **aggregation** (D-POSIT-AGG — the de-duplicated *global* budget that enforces `record_primitive≡recoverability_primitive` etc. as identities) is NOT in v1.0.0; each invocation audits ONE case. A planned MINOR extension.
- Counts (posits/bridges/imports/derived) are of unique items by id (matching the deduped budget), so a repeated id is one posit, not two.
- The tool audits whatever case it is given; the *honesty of the audit* (generous patchwork, full-price bridges — posit_audits R1–R4) is the caller's responsibility. The tool enforces the numeric guards (bridge cost, floating flag, same-reach); it cannot witness whether the patchwork was under-counted.

*Sims/audits prove structure, never acquaintance. Build one tool right; freeze its golden; let the science call it.*
