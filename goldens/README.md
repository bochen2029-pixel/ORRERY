# goldens/ — the Proof (load-bearing)

A golden is a frozen `(params → declared-output-hash)` record. It asserts **stability**, not correctness: it lets a future agent rewrite a tool's kernels for a 2028 GPU and instantly see whether behavior changed. This is what makes the instrument compound instead of rot.

## Per tool: `goldens/<tool>/`
- `golden.json` — the exact golden invocation (params + seed), the canonical-serialized declared output, and its `blake2b` hash.
- `stdout.txt` — the captured `--json` stdout at freeze time (for human diff).
- `NOTE.md` — one line: what config, why this config (fast enough for CI), when frozen, tool version.

## Freezing a golden
1. Build the tool; run its golden params with `--json`.
2. Canonically serialize the **declared** fields only (`tool, version, seed, params, result, verdict, gates` — exclude `notes`, timings).
3. Hash (blake2b). Write `golden.json` + `stdout.txt` + `NOTE.md`. Commit.

## Reproducing / superseding
- `--golden` reruns the params and compares the hash. Match → exit 0. Mismatch → exit 1.
- A PATCH/impl change that changes the hash is a **regression** unless deliberately superseded.
- To **supersede** (a genuine improvement, or a MINOR/MAJOR contract change): regenerate under **two-pass review**, bump semver, note the reason in the tool's contract change log and the golden `NOTE.md`. Never silently overwrite.

## Determinism precondition
Goldens only work if the tool is deterministic (same params+seed ⇒ identical declared output). If a golden won't reproduce run-to-run, the tool has a determinism bug (usually atomic reductions or unseeded RNG) — fix the tool, not the golden.
