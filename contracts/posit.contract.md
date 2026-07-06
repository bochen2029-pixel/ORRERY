# posit — Contract  v1.0.0

## Purpose
The **parsimony auditor**. Given an explanatory problem (a set of TARGETS) and two accounts of it — a **PATCHWORK** (a separate brute assumption per phenomenon) and a **UNIFIED** account (few shared mechanisms + derivations) — count the independent assumptions each spends and decide whether the unification is *real parsimony* or *relabeling*. Operationalizes the science's sample-quality criterion **Q3** and answers chat002's objection ("unification counts only if the number of independent brute posits goes DOWN"). Ports `C:\Fable_LLC\QUALIA_LAB\gym\posit_counter.py`.

Each account is a list of **items**, each with a `kind` priced by its epistemic cost and a `layer`:
| kind | cost | meaning |
|---|---|---|
| posit | 1.0 | an independent brute assumption the account itself makes |
| bridge | 1.0 | a committed step with no derivation yet (a claim you can't back) |
| import | 0.2 | an established external result adopted as-is (the field's, not yours) |
| derived | 0.0 | a target reached FROM the above via a genuine root — no new assumption |
| layer | | `physics` (the falsifiable layer) or `overlay` (qualia interpretation — §III-sealed, zero-lifting by design) |

**The confabulation guard, made numeric:** a bridge costs exactly as much as a posit, so relabeling a posit as a bridge (or "qualia explains it") never lowers the budget — only genuine DERIVATION does. A `derived` item whose `via` traces to no posit/bridge/import root in its own account is **floating** (a confabulation flag).

**Scope:** measures the *parsimony structure* of two accounts (bookkeeping); it makes no claim that either account is true, and nothing about qualia — the overlay layer is reported separately and never counted as a win. §III-sealed.

**Language:** Python (D-005 — exact symbolic accounting; no compute/scale/GPU). Deterministic by exact computation; there is **no RNG** (the `--seed` flag is accepted for envelope uniformity but is inert).

## Input (the audit case)
A JSON **case** supplied via `--case PATH` or `--stdin`:
```json
{ "name": "seed_cluster",
  "targets": ["arrow_of_time", "measurement_classicality", "low_entropy_start"],
  "patchwork": { "name": "PATCHWORK (orthodox)", "items": [
    {"id":"past_hypothesis","kind":"posit","layer":"physics","covers":["arrow_of_time","low_entropy_start"]}, ... ] },
  "unified":   { "name": "UNIFIED (recoverability)", "items": [
    {"id":"record_primitive","kind":"posit","layer":"physics","covers":[]},
    {"id":"arrow_derived","kind":"derived","layer":"physics","covers":["arrow_of_time"],"via":["record_primitive"]}, ... ] } }
```
Each item: `id` (str), `kind` (posit|bridge|import|derived), `layer` (physics|overlay), `covers` (target ids explained), `via` (for derived: item ids it follows from; optional otherwise). A budget dedups by `id`. Malformed input (unknown kind/layer, missing field, non-JSON) → exit 2.

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --case PATH | path | | (one of case/stdin required) | audit case JSON file |
| --stdin | flag | | off | read the audit case JSON from stdin instead |
| --tie-band | float | 0.0–10.0 | 0.0 | physics-layer Δ at/below which a "win" is not licensed (a nonzero band demands margin) |
| --seed | int | ≥0 | 0 | accepted for envelope uniformity; **inert** (posit has no RNG) |
| --json | flag | | off | emit JSON envelope on stdout |
| --csv PATH | path | | off | per-item ledger (account,id,kind,layer,weight,covers,via,floating) to PATH |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | run the embedded golden case (the seed cluster); hash; exit 0/1 |

## Output (result fields; nested)
| field | type | meaning |
|---|---|---|
| targets_n | int | number of targets |
| patchwork | object | `{total, physics, overlay}` (float budgets); `{posits, bridges, imports, derived}` (int counts); `{covered}` (int targets covered), `missing` (str[]), `floating` (str[] unbacked-derived ids) |
| unified | object | same shape as patchwork |
| delta_physics | float | `patchwork.physics − unified.physics` (the discriminating quantity; > tie_band ⇒ real physics-layer parsimony) |
| delta_overlay | float | `unified.overlay − patchwork.overlay` (bridges the overlay adds; buys no parsimony, by design) |
| delta_total | float | `patchwork.total − unified.total` |
| same_reach | bool | both accounts cover all targets |
| parsimony | enum | "win" (same_reach ∧ delta_physics>tie_band ∧ no unified floating) \| "reject" |

**Guard (honest-audit discipline, from D-POSIT / posit_audits R1–R4):** the physics-layer Δ is the only citable parsimony number; the overlay Δ is reported but never counted as a win. A win requires **same reach** (no cheating by covering fewer targets) and **no floating** derivations (no deriving-from-nothing). Report `delta_physics` + `same_reach` + `floating`, never a bare "unified is simpler" without them.

## CSV schema (--csv)
`account,id,kind,layer,weight,covers,via,floating` — one row per item (dedup by id within account), `covers`/`via` semicolon-joined, `floating` 0/1.

## Gates (declared negative-result conditions → exit 1)
| id | fires when | field |
|---|---|---|
| G-NO-PARSIMONY | NOT (same_reach ∧ delta_physics > tie_band) — the "unification" is relabeling, not physics-layer reduction | delta_physics |
| G-FLOATING | the unified account has ≥1 floating (unbacked `derived`) item — a confabulation flag | unified.floating |

Exit `0` when parsimony wins (real physics-layer reduction at equal reach, no floating); exit `1` when a gate fires (a genuine result — "no parsimony win / confabulation caught", exactly chat002's REJECT); exit `2` on bad input.

## Determinism
Exact symbolic accounting — budgets are fixed-weight sums over items deduped by id in input order; **no RNG, no wall-clock, no floating-point nondeterminism** (float sums of {1.0,0.2,0.0} are order-fixed). Byte-identical declared output. Golden hash domain = canonical JSON of {seed, params, result, gates, verdict}, floats `%.6f`, fixed key order (D-013). `params` echoes {case_name, targets_n, patchwork_items, unified_items, case_blake2b} (the input is pinned by its own blake2b, not re-echoed whole).

## Golden
The embedded **seed cluster** {arrow_of_time, measurement_classicality, low_entropy_start} from `posit_counter.py` (the corpus-grade banked win, D-POSIT): patchwork physics 4.0, unified physics 3.2 ⇒ **delta_physics = +0.8** at equal reach, no floating ⇒ parsimony "win", exit 0. (overlay +1.0, total −0.2 — the overlay bridge buys nothing, as designed.)
params: `posit.exe --golden --json`  ·  recorded: `goldens/posit/` (declared hash + stdout + NOTE).

## Change log
- v1.0.0 — initial contract. Ports posit_counter.py to the headless envelope; reads an audit case (JSON via --case/--stdin), reports per-account budgets + the physics/overlay/total deltas + same_reach + floating flags, gates on no-parsimony and confabulation. The seed-cluster +0.8 physics win is the golden; multi-cluster aggregation (D-POSIT-AGG, the de-duplicated global budget) is a planned MINOR extension.
