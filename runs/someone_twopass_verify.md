# someone — Two-Pass Cold-Context Verification Verdict

**Verifier:** Independent **cold-context** black-box pass (this is the fresh-session cold two-pass
that the prior single-agent pass recorded as *owed*). No build knowledge; did NOT read
`tools/someone/someone.cu`, MODULE.md, RUN_STATE.md, DECISIONS.md, or any build write-up. Behavior
verified only against **contract v1.1.0** (`contracts/someone.contract.md`),
`contracts/someone.schema.json`, the frozen golden hash `goldens/someone/declared.hash`, and the
built binary `C:\ORRERY\tools\someone\someone.exe`.

**Stamp:** 2026-07-05 19:23 -05:00
**Harness run report:** `C:\ORRERY\runs\verify_20260705_190525.md`

## Golden hash

| | value |
|---|---|
| Frozen (`goldens/someone/declared.hash`) | `aa5b731da7b5e26827471af1e5aa6b38809233793591da71469dc3353bc24544` |
| Reproduced by rebuilt binary (`someone.exe --golden`, cold) | `aa5b731da7b5e26827471af1e5aa6b38809233793591da71469dc3353bc24544` |
| Match | **YES — exact, bit-for-bit** |

The harness rebuilt the binary from source and `--golden` on that fresh binary reproduced the frozen
hash exactly. `--golden` exit 0.

## Harness (STEP 1)

`python C:\ORRERY\harness\verify.py --tool someone` → `someone: build=OK selftest=OK golden=OK`,
final line **`OVERALL: GREEN`**, process exit 0. Report row: `build OK / selftest OK / golden OK`.
Sole advisory: `golden 495s > 300s NFR (WARN)` — a non-functional performance note, **not** a
contract violation (the run completed and reproduced the hash). Does not affect conformance.

## Conformance battery (STEP 2)

| # | check | result | evidence |
|---|---|---|---|
| 1 | Harness OVERALL | **PASS** | `OVERALL: GREEN`, exit 0; report `build/selftest/golden = OK` |
| 2 | Golden reproduced by rebuilt binary | **PASS** | observed hash == frozen `aa5b731d…`; `--golden` exit 0 |
| 3 | `--selftest` exit 0 | **PASS** | `SELFTEST PASS`, exit 0; 9 internal cases (blake2b KATs, base-layout confound-fix, determinism smoke, gap>0.01, gapless→G-NO-GAP, sign-test, counter_gauss) |
| 4a | Schema valid — L3 (`--pop 48 --gens 4 --steps 150 --N 48 --k 12 --complexity L3 --ensemble 2 --seed 7`) | **PASS** | `jsonschema.validate` PASS |
| 4b | Schema valid — L0 (`--complexity L0 --seed 8`) | **PASS** | `jsonschema.validate` PASS |
| 5 | `tool` == "someone" | **PASS** | observed `tool='someone'` on all JSON runs |
| 6 | `version` == "1.1.0" | **PASS** | observed `version='1.1.0'` on all JSON runs |
| 7 | `notes` carries the qualia firewall (says nothing about whether the agent "feels") | **PASS** | notes = "This measures whether the gap confers fitness (structure); it says nothing about whether the agent feels (acquaintance) - III-sealed." |
| 8a | Exit 2 — undersize `--pop 5` | **PASS** | exit 2 |
| 8b | Exit 2 — bad enum `--complexity L9` | **PASS** | exit 2 |
| 8c | Exit 2 — unknown flag `--zzz 1` | **PASS** | exit 2 |
| 8d | Exit 2 — missing required `--seed` (`--pop 100 --json`) | **PASS** | exit 2 |
| 8e | Valid run → 0 or 1, never 2 | **PASS** | valid L3 run exit **1** (G-ZOMBIE-WINS fired — declared finding); clean small run exit 0 |
| 9a | Default `--k` == N/4 | **PASS** | run w/o `--k` at N=64 → `params.k` = 16 |
| 9b | Default `--ensemble` == 1 | **PASS** | run w/o `--ensemble` → `params.ensemble` = 1 |
| 9c | Complexity enum accepts L0..L3 | **PASS** | L0/L1 exit 0, L2/L3 exit {0,1} — all accepted as valid runs |
| 9d | Complexity enum rejects others | **PASS** | `L4` → exit 2; lowercase `l1` → exit 2 (strict) |
| 10 | Determinism — same (params, seed) ⇒ byte-identical output | **PASS** | two identical runs → `cmp` byte-identical |

## Exit-code semantics (contract compliance)

- The contract distinguishes exit **0** (pass) / **1** (a declared gate fired — a genuine negative
  *result*) / **2** (bad params or CUDA error). Observed behavior honors this cleanly: bad input is
  uniformly exit 2; a real gate firing (G-ZOMBIE-WINS, `delta_fit < -tie_band`) is exit 1 with a
  full JSON envelope and `verdict:"fail"`; no valid run ever returned 2. Exit 1 is never conflated
  with exit 2.
- `--golden` returns exit 0 on hash match even though the golden's own `verdict` is "fail"
  (G-ZOMBIE-WINS fired). This is correct: `--golden`'s exit encodes *hash reproduction*, which is
  distinct from a normal run's gate-driven exit. The frozen golden behavior reproduced exactly:
  L3, zombies win, `delta_fit=-0.456938`, `mean_pure_gap=0.25`, `win_rate=0.25`, `p_value=0.9375`,
  `zombie_extinct_gen=13`.
- The golden output satisfies the v1.1.0 guard: it reports `delta_fit` + alive-counts (not the
  banned post-extinction fitness *ratio*) and includes the additive `win_rate` / `p_value` fields.

## Overall verdict

**CONFORMANT** to `someone` contract v1.1.0.

Every requirement checked in this independent cold pass passed. The rebuilt binary reproduced the
frozen golden hash bit-for-bit; the harness is GREEN; the JSON envelope validates against the schema
under strict `additionalProperties:false`; `tool`/`version`/`notes` (qualia firewall) are correct;
exit-code discipline (0/1/2, never conflating a finding with an error) holds; defaults (`k=N/4`,
`ensemble=1`) and the strict `L0..L3` enum are correct; and declared output is byte-deterministic
under fixed (params, seed).

**No failures found.** Sole advisory: golden wall-clock (495s) exceeds the 300s soft NFR — a
performance WARN, not a contract breach. This satisfies the previously-owed fresh cold two-pass; the
tool is cold-two-pass-verified against contract v1.1.0.
