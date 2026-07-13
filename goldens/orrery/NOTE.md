# golden — `orrery` v1.0.0

## What is frozen
The declared output of `python orrery.py --golden` — the CLI's **self-check**: run `posit --golden`
through the generic run path (the I-12 chain), exercise the `verify` receipt-check both ways, and confirm
the six v1 tools are registry-complete.

Measured: `chain_declared_blake2b = 7a22dd22…` == posit's frozen golden (`chain_matches_frozen = true`),
`verify_ok = true` (MATCH on the right hash, MISMATCH on a wrong one), `v1_catalogue_complete = true`;
both gates clear; `verdict = pass`. Declared blake2b:
`439771854c718fd460a2282c49f763856564c807455c74bc3b25531e289141c0`.

Files: `declared.hash` (blake2b-256 of the canonical declared object), `stdout.txt` (full JSON envelope).

## Hash domain (D-013, same as every ORRERY tool)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — `tool`/
`version`/`notes` excluded. `orrery --golden` recomputes and compares.

## What it proves
1. **Determinism** — Python, no RNG/GPU; the self-check is byte-identical given the repo at a commit.
2. **The I-12 chain end-to-end through the CLI** — `orrery run posit --golden` reproduces posit's frozen
   declared hash `7a22dd22…` (the receipt an agent would cite), inherited from the reused `mcp` primitives.
3. **The R-3 receipt-verifier works both ways** — `verify` MATCHes the correct hash and MISMATCHes a wrong
   one (exit 0 / 1).

## Golden coupling (deliberate, narrow — same as `mcp`)
A CLI surface's value IS the calling of other tools, so the golden runs the narrowest real chain
(`posit --golden`, exact, no GPU/RNG, ms). **If posit's golden is legitimately superseded under review,
`orrery` re-baselines in the same operator-signed commit** (this NOTE carries that, like `mcp`'s).

## Environment
Reuses `tools/mcp/mcp.py` (imported). Python 3.13. No GPU. Determinism is Python-exact.

## Re-baseline record
- (none — v1.0.0 freeze.)
