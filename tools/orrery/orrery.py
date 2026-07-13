#!/usr/bin/env python3
# orrery.py — ORRERY tool `orrery` (v1.0.0): the ergonomic CLI over the catalogue.
# TinyUniverse R-1 (thin CLI) + R-2 (mcp-register) + R-3 (receipt-verifier); D-033.
# Contract: contracts/orrery.contract.md. The contract is authoritative.
#
# A transport/orchestration CLI surface: computes nothing scientific, says nothing about qualia (III-sealed).
# It REUSES the vetted `mcp` surface primitives (registry_scan / do_run_tool / do_describe_contract /
# do_sweep / blake2b_hex) instead of reimplementing tool-calling or hashing — so the I-12 declared-object
# blake2b chain is inherited. It is a CALLER of the sacred executables (subprocess), never a replacement.
#
# Run:  python orrery.py list|describe|run|sweep|verify|mcp-register ...
#       python orrery.py --json | --selftest | --golden
import sys, os, json, re

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# --- reuse the mcp surface core (tools/mcp/mcp.py) ---
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(_HERE), "mcp"))
import mcp  # registry_scan, do_run_tool, do_describe_contract, do_sweep, blake2b_hex, extract_declared,
             # V1_CATALOGUE, GOLDENS_DIR, read_first_token, jstr, fmt6, ToolError

VERSION = "1.1.0"
FIREWALL = ("A transport/orchestration CLI surface: it computes nothing scientific and says nothing about "
            "qualia - III-sealed. It calls the sacred executables and serves their contracts verbatim.")
KEY_RE = re.compile(r"^[A-Za-z0-9-]+$")
EXIT_CLASS = {"pass": 0, "gate-fired": 1, "error": 2, "timeout": 2}

def _mcp_path():
    return os.path.join(os.path.dirname(_HERE), "mcp", "mcp.py")

def collect_params(argv):
    """Pass-through flags: '--key value' -> params[key]='value'; bare '--flag' -> params[flag]=True."""
    params = {}; i = 0
    while i < len(argv):
        a = argv[i]
        if not a.startswith("--"):
            raise SystemExit(f"error: expected a --flag, got: {a}")
        key = a[2:]
        if not KEY_RE.match(key):
            raise SystemExit(f"error: bad flag name: --{key}")
        if i + 1 < len(argv) and not argv[i + 1].startswith("--"):
            params[key] = argv[i + 1]; i += 2
        else:
            params[key] = True; i += 1
    return params

# ------------------------------------------------------------------ content-addressed run cache (R-5, v1.1.0)
# Keyed by (tool, canonical-params, tool-binary-blake2b) -> the stored declared output. Because the tools
# are deterministic (same params ⇒ byte-identical declared output), a cache hit is safe; because the key
# includes the binary hash, a rebuilt tool correctly MISSES (invalidation is automatic). Non-declared,
# operational (gitignored under runs/cache/). Lets agents verify by hash-lookup instead of re-running.
def _cache_dir():
    d = os.path.join(mcp.ROOT, "runs", "cache")
    try: os.makedirs(d, exist_ok=True)
    except OSError: pass
    return d

def _cache_key(tool, params, artifact_path):
    bh = mcp.file_blake2b(artifact_path) or ""
    canon = json.dumps({"tool": tool, "params": params, "binary": bh}, sort_keys=True, separators=(",", ":"))
    return mcp.blake2b_hex(canon)

def _run_cached(tool, params):
    """Cache-aware run: returns the run record (from cache or fresh; stores on a declared-output miss).
    Adds rec['_cache'] = 'hit'|'miss'. Errors/timeouts (no declared object) are never cached."""
    entry = mcp.registry_get(tool)
    if entry is None or entry.get("artifact") is None:
        rec = _run_record(tool, params); rec["_cache"] = "miss"; return rec   # will surface the error
    cp = os.path.join(_cache_dir(), _cache_key(tool, params, entry["artifact"]) + ".json")
    if os.path.isfile(cp):
        try:
            with open(cp, encoding="utf-8") as f: rec = json.load(f)
            rec["_cache"] = "hit"; return rec
        except (OSError, ValueError):
            pass
    rec = _run_record(tool, params); rec["_cache"] = "miss"
    if rec.get("declared_blake2b") is not None:
        try:
            with open(cp, "w", encoding="utf-8") as f:
                json.dump({"tool": tool, "params": params, "binary_blake2b": rec.get("artifact_blake2b"),
                           "exit_class": rec["exit_class"], "envelope": rec["envelope"],
                           "declared_blake2b": rec["declared_blake2b"]}, f, indent=1)
        except OSError:
            pass
    return rec

# ------------------------------------------------------------------ subcommands
def cmd_list(argv):
    reg = mcp.registry_scan()
    if "--json" in argv:
        print(json.dumps(reg, indent=1)); return 0
    print(f"{'tool':<12}{'lang':<9}{'version':<10}golden")
    print("-" * 44)
    for t in reg:
        gh = (t["golden_hash"] or "-")
        gh = gh[:12] + "…" if t["golden_hash"] else "-"
        print(f"{t['name']:<12}{t['lang']:<9}{(t['contract_version'] or '-'):<10}{gh}")
    print(f"\n{len(reg)} tools.")
    return 0

def cmd_describe(argv):
    if not argv:
        sys.stderr.write("usage: orrery describe <tool>\n"); return 2
    tool = argv[0]
    try:
        dc = mcp.do_describe_contract({"tool": tool})
    except mcp.ToolError as e:
        sys.stderr.write(f"error: {e}\n"); return 2
    if dc.get("schema_json"):
        print(f"# {tool} — schema.json  (blake2b {dc['schema_blake2b']})")
        print(dc["schema_json"])
    if dc.get("contract_md"):
        print(f"\n# {tool} — contract.md  (blake2b {dc['contract_blake2b']})")
        print(dc["contract_md"])
    return 0

def _run_record(tool, params):
    return mcp.do_run_tool({"tool": tool, "params": params}, store=False)

def cmd_run(argv):
    if not argv:
        sys.stderr.write("usage: orrery run <tool> [--flag val ...] [--golden] [--json] [--cache]\n"); return 2
    tool, params = argv[0], collect_params(argv[1:])
    use_cache = bool(params.pop("cache", False))   # --cache is orrery's, not forwarded to the tool
    try:
        rec = _run_cached(tool, params) if use_cache else _run_record(tool, params)
    except mcp.ToolError as e:
        sys.stderr.write(f"error: {e}\n"); return 2
    if rec.get("envelope") is not None:
        print(json.dumps(rec["envelope"]))
    tag = f"  [CACHE {rec['_cache'].upper()}]" if rec.get("_cache") else ""
    sys.stderr.write(f"[orrery] exit_class={rec['exit_class']}  declared_blake2b={rec['declared_blake2b']}  "
                     f"artifact_blake2b={rec.get('artifact_blake2b') or rec.get('binary_blake2b')}{tag}\n")
    if rec.get("envelope") is None and rec.get("stderr_tail"):
        sys.stderr.write(rec["stderr_tail"] + "\n")
    return EXIT_CLASS.get(rec["exit_class"], 2)

def cmd_cache(argv):
    d = _cache_dir()
    if "--clear" in argv:
        n = 0
        for f in os.listdir(d):
            if f.endswith(".json"):
                try: os.remove(os.path.join(d, f)); n += 1
                except OSError: pass
        print(f"cleared {n} cached run(s)"); return 0
    if "--get" in argv:
        i = argv.index("--get")
        if i + 1 >= len(argv):
            sys.stderr.write("error: cache --get needs a key\n"); return 2
        cp = os.path.join(d, argv[i + 1] + ".json")
        if not os.path.isfile(cp):
            sys.stderr.write(f"error: no cached run for key {argv[i+1]}\n"); return 2
        with open(cp, encoding="utf-8") as f: print(f.read())
        return 0
    files = [f for f in os.listdir(d) if f.endswith(".json")]
    total = sum(os.path.getsize(os.path.join(d, f)) for f in files)
    print(f"cache: {len(files)} run(s), {total} bytes  ({d})")
    for f in sorted(files)[:30]:
        try:
            with open(os.path.join(d, f), encoding="utf-8") as fh: r = json.load(fh)
            print(f"  {f[:-5][:16]}…  {r.get('tool',''):<10}{(r.get('declared_blake2b') or '')[:12]}…  {r.get('exit_class','')}")
        except Exception:
            pass
    return 0

def do_verify(tool, params, expect):
    """R-3 core: run the tool, return (match_bool, got_hash). got_hash None if no declared object."""
    rec = _run_record(tool, params)
    got = rec["declared_blake2b"]
    return (got is not None and got == expect), got

def cmd_verify(argv):
    if not argv:
        sys.stderr.write("usage: orrery verify <tool> [--flag val ...] --expect-hash <64-hex>\n"); return 2
    tool, rest = argv[0], argv[1:]
    expect = None; passthrough = []; i = 0
    while i < len(rest):
        if rest[i] == "--expect-hash":
            if i + 1 >= len(rest):
                sys.stderr.write("error: --expect-hash needs a value\n"); return 2
            expect = rest[i + 1]; i += 2
        else:
            passthrough.append(rest[i]); i += 1
    if not expect:
        sys.stderr.write("error: --expect-hash is required\n"); return 2
    try:
        match, got = do_verify(tool, collect_params(passthrough), expect)
    except mcp.ToolError as e:
        sys.stderr.write(f"error: {e}\n"); return 2
    if got is None:
        sys.stderr.write(f"error: no declared object from {tool} (bad params, or a non-JSON mode)\n"); return 2
    print(f"{'MATCH' if match else 'MISMATCH'}  tool={tool}  got={got}  expect={expect}")
    return 0 if match else 1   # MISMATCH is a real finding (exit 1), not an error

def cmd_sweep(argv):
    if not argv:
        sys.stderr.write("usage: orrery sweep <tool> --sweep NAME --metric FIELD --lo L --hi H --target T [...]\n"); return 2
    tool, params = argv[0], collect_params(argv[1:])
    args = {"tool": tool}
    for k in ("sweep", "metric", "lo", "hi", "target", "points", "fixed", "locate", "level", "tol", "seed"):
        if k in params:
            args[k] = params[k]
    for k in ("lo", "hi", "target", "tol", "level"):
        if k in args:
            try: args[k] = float(args[k])
            except (TypeError, ValueError): pass
    for k in ("points", "seed"):
        if k in args:
            try: args[k] = int(args[k])
            except (TypeError, ValueError): pass
    try:
        rec = mcp.do_sweep(args)
    except mcp.ToolError as e:
        sys.stderr.write(f"error: {e}\n"); return 2
    if rec["envelope"] is not None:
        print(json.dumps(rec["envelope"]))
    sys.stderr.write(f"[orrery] sweep exit_class={rec['exit_class']}  declared_blake2b={rec['declared_blake2b']}\n")
    return EXIT_CLASS.get(rec["exit_class"], 2)

def cmd_mcp_register(argv):
    mp = _mcp_path()
    cfg = {"command": "python", "args": [mp, "--serve"]}
    if "--json" in argv:
        print(json.dumps({"mcpServers": {"orrery": cfg}}, indent=2)); return 0
    print("# Register the ORRERY MCP surface as mcp__orrery__* in a Claude Code session:")
    print(f'claude mcp add orrery -- python "{mp}" --serve')
    print("\n# ...or add to your MCP config (.mcp.json / settings.json \"mcpServers\") manually:")
    print(json.dumps({"mcpServers": {"orrery": cfg}}, indent=2))
    print("\n# Exposed tools: list_tools, describe_contract, run_tool, get_run, sweep, golden_status")
    return 0

# ------------------------------------------------------------------ self-check (--json / --golden)
def _posit_frozen():
    return mcp.read_first_token(os.path.join(mcp.GOLDENS_DIR, "posit", "declared.hash"))

def self_check():
    frozen = _posit_frozen()
    rec = mcp.do_run_tool({"tool": "posit", "params": {"golden": True}, "timeout_s": 120}, store=False, run_id="orrery-chain")
    chain_hash = rec["declared_blake2b"] or ""
    chain_matches = (chain_hash != "" and frozen is not None and chain_hash == frozen)
    # exercise the R-3 verify path both ways (right hash MATCHes, wrong hash MISMATCHes)
    ok_right, _ = do_verify("posit", {"golden": True}, frozen or "")
    ok_wrong, _ = do_verify("posit", {"golden": True}, "0" * 64)
    verify_ok = bool(ok_right) and not bool(ok_wrong)
    reg = {t["name"]: t for t in mcp.registry_scan()}
    complete = all(n in reg and reg[n]["has_contract"] and reg[n]["has_schema"] and reg[n]["golden_hash"]
                   for n in mcp.V1_CATALOGUE)
    result = {"chain_tool": "posit", "chain_exit_class": rec["exit_class"],
              "chain_declared_blake2b": chain_hash, "chain_matches_frozen": chain_matches,
              "verify_ok": verify_ok, "v1_catalogue_complete": complete}
    g_chain = (rec["exit_class"] != "pass") or (not chain_matches)
    g_verify = (not verify_ok) or (not complete)
    gates = [{"id": "G-CHAIN-MISMATCH", "fired": g_chain, "value": 1.0 if g_chain else 0.0, "threshold": 0.0},
             {"id": "G-VERIFY-BROKEN", "fired": g_verify, "value": 1.0 if g_verify else 0.0, "threshold": 0.0}]
    verdict = "fail" if (g_chain or g_verify) else "pass"
    return result, gates, verdict, (1 if verdict == "fail" else 0)

# ------------------------------------------------------------------ canonical serialization (mcp-style)
def params_json(p):
    return "{" + f'"chain_tool":{mcp.jstr(p["chain_tool"])},"timeout_s":{int(p["timeout_s"])}' + "}"
def result_json(r):
    b = lambda x: "true" if x else "false"
    return ("{" + f'"chain_tool":{mcp.jstr(r["chain_tool"])},'
            f'"chain_exit_class":{mcp.jstr(r["chain_exit_class"])},'
            f'"chain_declared_blake2b":{mcp.jstr(r["chain_declared_blake2b"])},'
            f'"chain_matches_frozen":{b(r["chain_matches_frozen"])},'
            f'"verify_ok":{b(r["verify_ok"])},'
            f'"v1_catalogue_complete":{b(r["v1_catalogue_complete"])}' + "}")
def gates_json(gs):
    return "[" + ",".join("{" + f'"id":{mcp.jstr(g["id"])},"fired":{"true" if g["fired"] else "false"},'
                          f'"value":{mcp.fmt6(g["value"])},"threshold":{mcp.fmt6(g["threshold"])}' + "}" for g in gs) + "]"
def declared_body(seed, p, r, gs, v):
    return f'"seed":{seed},"params":{params_json(p)},"result":{result_json(r)},"gates":{gates_json(gs)},"verdict":{mcp.jstr(v)}'
def declared_object(seed, p, r, gs, v):
    return "{" + declared_body(seed, p, r, gs, v) + "}"
def full_envelope(seed, p, r, gs, v):
    return "{" + f'"tool":"orrery","version":{mcp.jstr(VERSION)},' + declared_body(seed, p, r, gs, v) + f',"notes":{mcp.jstr(FIREWALL)}' + "}"

def _orrery_frozen():
    for c in ("goldens/orrery/declared.hash", "../../goldens/orrery/declared.hash",
              os.path.join(mcp.GOLDENS_DIR, "orrery", "declared.hash")):
        v = mcp.read_first_token(c)
        if v:
            return v
    return None

def run_golden():
    params = {"chain_tool": "posit", "timeout_s": 120}
    result, gates, verdict, _ = self_check()
    declared = declared_object(0, params, result, gates, verdict)
    h = mcp.blake2b_hex(declared)
    print(full_envelope(0, params, result, gates, verdict))
    frozen = _orrery_frozen()
    if frozen is None:
        sys.stderr.write(f"GOLDEN NOT FROZEN (bootstrap) blake2b={h}\n  freeze into goldens/orrery/declared.hash\n"); return 0
    if h == frozen:
        sys.stderr.write(f"GOLDEN OK blake2b={h}\n"); return 0
    sys.stderr.write(f"GOLDEN MISMATCH\n  got  {h}\n  want {frozen}\n"); return 1

# ------------------------------------------------------------------ selftest
def _chk(name, ok, fails):
    sys.stderr.write(f"  [{'PASS' if ok else 'FAIL'}] {name}\n")
    if not ok: fails.append(name)
    return ok

def run_selftest():
    fails = []
    sys.stderr.write(f"orrery --selftest (v{VERSION})\n")
    _chk('blake2b-256("abc") KAT (via mcp)',
         mcp.blake2b_hex("abc") == "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319", fails)
    # collect_params KATs
    _chk("collect_params: valued + bool flags",
         collect_params(["--R", "3", "--golden"]) == {"R": "3", "golden": True}, fails)
    ok_badkey = False
    try: collect_params(["--bad key", "1"])
    except SystemExit: ok_badkey = True
    _chk("collect_params: bad key rejected", ok_badkey, fails)
    # registry has the v1 tools with contract+schema+golden
    reg = {t["name"]: t for t in mcp.registry_scan()}
    _chk("registry has the six v1 tools (contract+schema+golden)",
         all(n in reg and reg[n]["has_contract"] and reg[n]["has_schema"] and reg[n]["golden_hash"]
             for n in mcp.V1_CATALOGUE), fails)
    # describe posit serves its schema with tool const
    try:
        dc = mcp.do_describe_contract({"tool": "posit"}); sc = json.loads(dc["schema_json"])
        ok_desc = sc.get("properties", {}).get("tool", {}).get("const") == "posit"
    except Exception:
        ok_desc = False
    _chk('describe posit -> schema tool const "posit"', ok_desc, fails)
    # R-3 verify works BOTH ways against posit's frozen golden
    frozen = _posit_frozen()
    mR, _ = do_verify("posit", {"golden": True}, frozen or "")
    mW, _ = do_verify("posit", {"golden": True}, "0" * 64)
    _chk("verify posit --golden: MATCH on frozen hash", bool(mR), fails)
    _chk("verify posit --golden: MISMATCH on wrong hash", not bool(mW), fails)
    # self-check passes (chain + verify + v1 complete)
    result, gates, verdict, _ = self_check()
    _chk("self-check verdict == pass (chain matches, verify ok, v1 complete)", verdict == "pass", fails)
    # determinism
    a = declared_object(0, {"chain_tool": "posit", "timeout_s": 120}, *self_check()[:3])
    b = declared_object(0, {"chain_tool": "posit", "timeout_s": 120}, *self_check()[:3])
    _chk("declared object identical across two self-checks", a == b, fails)
    # R-5 run cache: deterministic key + a real round-trip (miss stores, hit returns the same), cleaned up
    ent = mcp.registry_get("posit")
    if ent and ent.get("artifact"):
        k1 = _cache_key("posit", {"golden": True}, ent["artifact"])
        _chk("cache key deterministic", k1 == _cache_key("posit", {"golden": True}, ent["artifact"]), fails)
        cp = os.path.join(_cache_dir(), k1 + ".json")
        if os.path.exists(cp):
            try: os.remove(cp)
            except OSError: pass
        r1 = _run_cached("posit", {"golden": True})
        _chk("cache miss stores on first --cache run", r1.get("_cache") == "miss" and os.path.isfile(cp), fails)
        r2 = _run_cached("posit", {"golden": True})
        _chk("cache hit returns posit's frozen hash", r2.get("_cache") == "hit" and r2.get("declared_blake2b") == _posit_frozen(), fails)
        try: os.remove(cp)
        except OSError: pass
    ok = len(fails) == 0
    sys.stderr.write("SELFTEST PASS\n" if ok else f"SELFTEST FAIL ({len(fails)})\n")
    return 0 if ok else 1

# ------------------------------------------------------------------ CLI
USAGE = "usage: orrery <list|describe|run|sweep|verify|mcp-register> ...  |  --json | --selftest | --golden"

def main():
    argv = sys.argv[1:]
    # optional leading inert --seed N (echoed only; the self-check envelope uses seed 0)
    if len(argv) >= 2 and argv[0] == "--seed":
        argv = argv[2:]
    if not argv:
        sys.stderr.write(USAGE + "\n"); return 2
    mode = argv[0]
    if mode == "--selftest": return run_selftest()
    if mode == "--golden":   return run_golden()
    if mode == "--json":
        result, gates, verdict, code = self_check()
        print(full_envelope(0, {"chain_tool": "posit", "timeout_s": 120}, result, gates, verdict)); return code
    dispatch = {"list": cmd_list, "describe": cmd_describe, "run": cmd_run, "cache": cmd_cache,
                "sweep": cmd_sweep, "verify": cmd_verify, "mcp-register": cmd_mcp_register}
    if mode not in dispatch:
        sys.stderr.write(f"error: unknown command '{mode}'\n{USAGE}\n"); return 2
    return dispatch[mode](argv[1:])

if __name__ == "__main__":
    sys.exit(main())
