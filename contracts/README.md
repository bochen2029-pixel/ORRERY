# contracts/ — the Laws (sacred)

A contract is the **sacred, semver'd interface** of a tool. It is written and reviewed **before** any tool code. The science depends on this and only this. Break a contract without a MAJOR bump + migration note, and you break every experiment that relied on it.

Each tool has two files here:
- `<tool>.contract.md` — human-readable: CLI flags (types, ranges, defaults), output schema (every declared field, typed, with meaning), exit-code semantics, the determinism clause, the golden params, the change log.
- `<tool>.schema.json` — machine-checkable JSON Schema for the `--json` output. CI validates real output against it.

## The universal envelope (every tool obeys)

```
<tool>.exe [--param VALUE ...] --seed N [--json | --csv PATH] [--selftest] [--golden]
```

- **`--json`** → one JSON object on stdout matching `<tool>.schema.json`.
- **`--csv PATH`** → bulk per-step/per-agent time-series to a file (schema documented in the contract).
- **`--seed N`** → seeds all RNG; required for any stochastic tool.
- **`--selftest`** → run the internal battery, print `PASS`/`FAIL`, exit 0/1. No params needed.
- **`--golden`** → run the frozen golden params, print the canonical output hash, exit 0 if it matches `goldens/<tool>/`, else 1.

### Exit-code semantics (never conflate)
- `0` — pass / expected / golden matched.
- `1` — a **declared gate fired**: a real, meaningful negative result (e.g. "normal did NOT beat zombie", "rate exceeded the ratchet bound"). This is a *result*, not a failure of the tool.
- `2` — **error**: bad input, out-of-range param, crash, CUDA failure. The run is invalid.

### The JSON envelope (declared fields)
```json
{
  "tool": "<name>",
  "version": "<semver>",
  "seed": 7,
  "params": { "...": "the resolved params, echoed" },
  "result": { "...": "the tool's declared measurement fields" },
  "verdict": "pass" ,
  "gates": [ { "id": "G-...", "fired": false, "value": 0.0, "threshold": 0.0 } ],
  "notes": "free text; NON-DECLARED; excluded from the golden hash"
}
```

### The determinism clause (non-negotiable)
Same `params` + same `seed` ⇒ byte-identical **declared** output (`tool, version, seed, params, result, verdict, gates`). Excluded from "declared": `notes`, wall-clock timings, progress logs, and any field the contract explicitly marks `nondeclared`. Seed all RNG (curand per-thread). Document any reduction-order caveat (floating-point non-associativity) and pin the launch config so it does not vary.

### Semver rules
- **PATCH** — internal impl change, identical declared output on the golden. (A CUDA rewrite that reproduces the golden is a PATCH.)
- **MINOR** — new optional flag or new *additive* output field; old callers unaffected; golden extended.
- **MAJOR** — any change to existing flag meaning, output field, or exit-code semantics. Requires a migration note here and golden replacement under review.

## The contract template (copy for a new tool)

```markdown
# <tool> — Contract  vX.Y.Z

## Purpose (1–2 sentences; what it measures)

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --... | ... | ... | ... | ... |
| --seed | int | ≥0 | (required) | RNG seed |
| --json | flag | | off | emit JSON envelope on stdout |
| --csv PATH | path | | off | bulk time-series to PATH (schema below) |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | run golden params; hash; exit 0/1 |

## Output (result fields; each typed, with meaning)
| field | type | meaning |
|---|---|---|
| ... | ... | ... |

## CSV schema (if any)
| column | type | meaning |

## Gates (declared negative-result conditions → exit 1)
| id | fires when | field |

## Determinism
(what is declared; any caveats)

## Golden
params: <exact golden invocation>
recorded: goldens/<tool>/  (hash + captured stdout)

## Change log
- vX.Y.Z — ...
```

`someone.contract.md` is the worked exemplar. Read it before writing a new contract.
