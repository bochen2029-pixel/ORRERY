# orrery v1.1.0 — cold-context two-pass verification (R-5 run-cache delta)

- **Date:** 2026-07-13
- **Verifier:** independent, adversarial, cold-context (no memory of the build)
- **Repo HEAD:** `bfa13ed5dfe7967636dbdc195abb4cff9726bb79`
- **Tree state:** DIRTY — the v1.1.0 delta is uncommitted in the working tree (expected; this is a pre-commit verification). Modified: `.gitignore`, `ARCHITECTURE.md`, `DECISIONS.md`, `RUN_STATE.md`, `TASKLIST.md`, `contracts/orrery.contract.md`, `tools/README.md`, `tools/orrery/MODULE.md`, `tools/orrery/orrery.py`. Untracked: `docs/PROPOSAL_2026-07-11_...md`, `runs/verify_20260713_013504.md`.
- **Scope:** the **v1.1.0 delta ONLY** — the R-5 content-addressed run cache. v1.0.0 was certified by a prior two-pass (`runs/orrery_twopass_verify.md`); not re-litigated except to confirm the golden still reproduces.
- **Environment:** Windows, Python 3.13.2, all runs FOREGROUND + synchronous (no background, no GPU here).

## OVERALL VERDICT: **CONFORMANT to v1.1.0** (with one non-blocking artifact-hygiene finding)

The R-5 cache is correct, transparent, and safe. Every core and adversarial claim about the cache passed, including the load-bearing safety property (a changed binary can never be served a stale result) and cache transparency (MISS / HIT / no-cache all byte-identical). The one finding is a **stale golden artifact** (`goldens/orrery/stdout.txt` + its `NOTE.md` were not re-frozen for the 1.0.0→1.1.0 version bump); it is documentation hygiene, **not** a correctness defect, and it does **not** affect the load-bearing `declared.hash` golden, which reproduces byte-identically.

**checks passed: 8/8** (with a documented WEAKNESS noted under check 2).

---

## Check 1 — BUILD/COMPILE — **PASS**
```
python -m py_compile tools/orrery/orrery.py   -> PY_COMPILE_CLEAN orrery
python -m py_compile tools/mcp/mcp.py         -> PY_COMPILE_CLEAN mcp
Select-String '^VERSION\s*=' tools/orrery/orrery.py -> VERSION = "1.1.0"
```
Both modules compile clean; `VERSION="1.1.0"` confirmed in source (line 26).

## Check 2 — GOLDEN still reproduces (additive-safety) — **PASS** (with WEAKNESS on the stdout.txt artifact)
`python tools/orrery/orrery.py --golden` (WITHOUT --cache), run 3×:
```
run1 stderr: GOLDEN OK blake2b=439771854c718fd460a2282c49f763856564c807455c74bc3b25531e289141c0  exit=0
run2 stderr: GOLDEN OK blake2b=439771854c...289141c0  exit=0
run3 stderr: GOLDEN OK blake2b=439771854c...289141c0  exit=0
```
- Declared hash == `439771854c718fd460a2282c49f763856564c807455c74bc3b25531e289141c0` on all runs, and == `goldens/orrery/declared.hash`. **The load-bearing golden reproduces byte-identically** → the cache is truly additive to the declared output.
- Determinism: run1 stdout SHA256 == run2 stdout SHA256 (`6F728024…`). Identical across runs.

**WEAKNESS (non-blocking):** the live golden stdout does NOT byte-match the committed `goldens/orrery/stdout.txt`. Byte-diff isolates **exactly ONE differing byte** at offset 30: live `"version":"1.1.0"` vs committed `"version":"1.0.0"`.
```
live len=693  gold len=693   TOTAL DIFFERING BYTES: 1
offset 30: ...version":"1.1.0","seed":...   (live '1'  vs  committed '0')
```
The `version` string lives in the envelope wrapper, **outside** the declared object (`extract_declared` slices `seed..verdict`; `tool`/`version`/`notes` are excluded per D-013). So the version bump legitimately changed the full envelope stdout while leaving the declared hash untouched — which is exactly why `declared.hash` still matches. **`goldens/orrery/stdout.txt` and `goldens/orrery/NOTE.md` are stale: frozen under v1.0.0, not re-frozen for v1.1.0** (NOTE.md header reads "v1.0.0" and its re-baseline record says "(none — v1.0.0 freeze.)"). The contract change-log's claim that "the self-check golden `43977185` reproduces byte-identical" refers to the **declared hash**, which is TRUE. Recommendation: re-freeze `stdout.txt` (single byte) and bump `NOTE.md` to v1.1.0 in the same operator-signed commit. This is artifact hygiene, not a cache defect.

## Check 3 — Cache MISS→HIT correctness (THE core claim) — **PASS**
Cleared cache (`cache --clear` → `cleared N cached run(s)`, stats `0 run(s)`), then captured byte-exact stdout (via cmd redirect, no PS re-encoding) for three runs:
```
RUN A  run posit --golden --cache : stderr ... declared_blake2b=7a22dd229a42...a20e44  artifact_blake2b=0f27f736...  [CACHE MISS]
RUN B  run posit --golden --cache : stderr ... declared_blake2b=7a22dd22...a20e44       artifact_blake2b=0f27f736...  [CACHE HIT]
RUN C  run posit --golden         : stderr ... declared_blake2b=7a22dd22...a20e44       artifact_blake2b=0f27f736...  (no tag)

STDOUT SHA256 (byte-exact):
  MISS    32A14C85AE6483BB0A2D32C83C96B6BC8FF849981200D95B7D006B480B378FA0  len=1060
  HIT     32A14C85...378FA0  len=1060
  NOCACHE 32A14C85...378FA0  len=1060
  MISS==HIT : True   MISS==NOCACHE : True   HIT==NOCACHE : True
```
- First run MISS, second run HIT, as claimed. Stderr tags `[CACHE MISS]`/`[CACHE HIT]` correctly.
- **CRITICAL:** MISS stdout, HIT stdout, and NON-cached stdout are **byte-identical** (same SHA256). The `declared_blake2b` receipt is posit's frozen `7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44` on all three. The cache is fully transparent — a HIT returns exactly what a fresh run does.

## Check 4 — Cache-key correctness / invalidation — **PASS**
Key construction read at `orrery.py:_cache_key` (lines 62–65): `blake2b_hex(json.dumps({"tool","params","binary": file_blake2b(artifact)}, sort_keys=True, separators=(",",":")))`. Independently recomputed in a subprocess against the live posit artifact:
```
binary_blake2b    = 0f27f7364fdb74836c52a3d27a35cd379a4e9d695053e6d4fea31acb89fc233a
canon             = {"binary":"0f27f7364fdb...233a","params":{"golden":true},"tool":"posit"}
orrery._cache_key = 7a599707fc61e5571dca1d24f2cd6fe6408ea5f495859ac66d44a5fff162dee5
on-disk filename  = 7a599707fc61e557...162dee5.json   (MATCH)
```
- Key IS content-addressed over `{tool, params, binary-hash}`, and the `binary` field == posit's `file_blake2b`. The stored record's `binary_blake2b` (`0f27f736…`) equals the run record's `artifact_blake2b` — key-hash and stored-hash are the same file hash (no inconsistency).
- **Different params → different key (no false HIT):** `key(golden)=7a599707…` vs `key(json)=4d10d448…`, differ=True. Confirmed through the real CLI too: with the golden entry cached, `run posit --json --cache` reported `[CACHE MISS]` (did not wrongly serve the golden entry) and, being an error run, was not stored.
- **Binary-change invalidation (adversarial, demonstrated):** monkeypatched `file_blake2b` to simulate a rebuilt tool → key changes from `7a599707…` to `bb8b0dbf…`; no cache file exists at the changed key → **guaranteed MISS, no stale serve**. The binary hash is genuinely load-bearing in the key.

## Check 5 — Cache subcommand — **PASS**
```
cache          -> cache: 1 run(s), 1606 bytes  (C:\ORRERY\runs\cache)
                    7a599707fc61e557…  posit     7a22dd229a42…  pass
cache --get <k>-> full JSON record {tool, params, binary_blake2b, exit_class, envelope, declared_blake2b:7a22dd22...}  exit=0
cache --clear  -> cleared 1 cached run(s)  ; subsequent run posit --golden --cache -> [CACHE MISS]
```
- Stats report entry count + total bytes sanely. `--get` returns the stored entry. `--clear` empties it and the next run is a MISS again.
- Cache dir is `C:\ORRERY\runs\cache`. **Gitignored:** `.gitignore` line 21 = `runs/cache/`. Confirmed.

## Check 6 — Adversarial: can the cache mask a changed result? — **PASS (no such path found)**
Three independent guarantees, each verified:
1. **Binary hash in the key** → a changed tool misses (demonstrated in check 4: changed-binary key has no file → MISS). No stale serve possible after a rebuild.
2. **Only declared-output runs are cached** — verified on disk: after a `--golden` MISS plus a failed `--json` error run, the cache holds **exactly 1 entry** (the error left nothing; `_run_cached` only stores when `declared_blake2b is not None`, orrery.py:81).
3. **Tools are deterministic** → a stored declared output equals a fresh one; and empirically MISS/HIT/no-cache stdout are byte-identical (check 3).

Additionally proved the HIT genuinely **short-circuits the subprocess** (not just returns the same bytes): instrumented `mcp.do_run_tool` with a spawn counter — MISS → 1 spawn; HIT → **still 1 spawn** (no re-spawn), with `HIT.declared == MISS.declared` and `HIT.envelope == MISS.envelope` both True. No code path was found where a HIT could return a result inconsistent with a fresh run.

## Check 7 — Selftest — **PASS**
```
python tools/orrery/orrery.py --selftest  -> exit 0, "SELFTEST PASS"
12 checks, all [PASS]; 3 are cache-related:
  [PASS] cache key deterministic
  [PASS] cache miss stores on first --cache run
  [PASS] cache hit returns posit's frozen hash
```
The v1.1.0 delta shipped its own regression coverage. The selftest's cache round-trip **cleans up after itself** — verified: `runs/cache` has 0 entries after a selftest run (no test pollution).

## Check 8 — Determinism — **PASS**
- `--golden` stdout byte-identical across 3 runs (SHA256 `6F728024…`); declared hash `439771854c…` stable each time and == the frozen `declared.hash` file.
- Enabling the cache introduces **no** nondeterminism into the declared output: MISS/HIT/no-cache declared objects are byte-identical (check 3).
- The cache never enters the golden/determinism claim: after clearing the cache and running `--golden` then `--json` (neither uses `--cache`), `runs/cache` is **still 0 entries** — the meta-modes never touch the cache.

---

## Summary of evidence for the cache safety argument
The intended design holds under adversarial test:
- HIT output ≡ MISS output ≡ no-cache output (byte-identical, same declared receipt).
- Key = `blake2b(tool + canonical-params + binary-hash)`; independently reproduced; binary-hash inclusion demonstrated to force a MISS on a (simulated) rebuild.
- Errors/timeouts are never cached (verified on disk).
- A HIT does not spawn the tool (spawn-counter instrumented).
- The cache is NON-declared and gitignored; `--golden`/`--json` never populate or consult it.

## Defects / weaknesses
- **WEAKNESS (non-blocking, artifact hygiene):** `goldens/orrery/stdout.txt` (and `goldens/orrery/NOTE.md`) are stale — frozen under v1.0.0, one byte (the `version` minor digit) behind the live v1.1.0 envelope. Does not affect the load-bearing `declared.hash` golden (which reproduces exactly) nor any cache behavior. Fix: re-freeze `stdout.txt` and bump `NOTE.md` to v1.1.0 in the operator-signed commit that lands v1.1.0.
- **No correctness defects in the R-5 cache.**

**checks passed: 8/8**
