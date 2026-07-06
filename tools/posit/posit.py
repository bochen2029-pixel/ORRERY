#!/usr/bin/env python3
# posit.py -- ORRERY tool `posit` (v1.0.0). The parsimony auditor.
# Headless, deterministic, contract-bounded. Contract: contracts/posit.contract.md v1.0.0.
#
# Measures the PARSIMONY STRUCTURE of two accounts (exact bookkeeping); makes no claim either is
# true, and nothing about qualia (the overlay layer is reported separately, never counted a win).
# Python is right here (D-005): exact symbolic accounting, no compute/scale/GPU, no RNG.
# Ports C:\Fable_LLC\QUALIA_LAB\gym\posit_counter.py.
#
# Run:  python posit.py --case CASE.json --json   |   python posit.py --stdin --json
#       python posit.py --selftest   |   python posit.py --golden
import sys, json, hashlib, argparse
try:
    sys.stdout.reconfigure(encoding="utf-8")   # Windows console is cp1252
except Exception:
    pass

VERSION = "1.0.0"
FIREWALL = ("This measures the parsimony structure of two accounts (bookkeeping); it makes no claim "
            "either account is true, and nothing about qualia - the overlay layer is III-sealed.")
W = {"posit": 1.0, "bridge": 1.0, "import": 0.2, "derived": 0.0}
KINDS = set(W.keys())
LAYERS = {"physics", "overlay"}

class BadInput(Exception):
    pass

# ------------------------------------------------------------------ model (ported from posit_counter)
def _items(raw, who):
    if not isinstance(raw, dict): raise BadInput(f"{who} must be an object")
    items = raw.get("items")
    if not isinstance(items, list): raise BadInput(f"{who}.items must be a list")
    out = []
    seen_shape = set()
    for i, it in enumerate(items):
        if not isinstance(it, dict): raise BadInput(f"{who}.items[{i}] must be an object")
        iid = it.get("id")
        if not isinstance(iid, str) or not iid: raise BadInput(f"{who}.items[{i}].id must be a non-empty string")
        kind = it.get("kind")
        if kind not in KINDS: raise BadInput(f"{who}.items[{i}].kind '{kind}' not in {sorted(KINDS)}")
        layer = it.get("layer")
        if layer not in LAYERS: raise BadInput(f"{who}.items[{i}].layer '{layer}' not in {sorted(LAYERS)}")
        covers = it.get("covers", [])
        via = it.get("via", [])
        if not isinstance(covers, list) or not all(isinstance(c, str) for c in covers):
            raise BadInput(f"{who}.items[{i}].covers must be a list of strings")
        if not isinstance(via, list) or not all(isinstance(v, str) for v in via):
            raise BadInput(f"{who}.items[{i}].via must be a list of strings")
        out.append({"id": iid, "kind": kind, "layer": layer, "covers": list(covers), "via": list(via)})
    return raw.get("name", who), out

def budget(items, layer=None):
    seen = set(); total = 0.0
    for it in items:
        if layer and it["layer"] != layer: continue
        if it["id"] in seen: continue
        seen.add(it["id"]); total += W[it["kind"]]
    return total

def counts(items):
    seen = set(); c = {"posit":0,"bridge":0,"import":0,"derived":0}
    for it in items:
        if it["id"] in seen: continue
        seen.add(it["id"]); c[it["kind"]] += 1
    return c

def covered(items):
    t = set()
    for it in items:
        for cc in it["covers"]: t.add(cc)
    return t

def floating(items):
    ids = {it["id"]: it for it in items}
    bad = []
    for it in items:
        if it["kind"] == "derived":
            roots = [ids[v]["kind"] for v in it["via"] if v in ids]
            if not any(k in ("posit", "bridge", "import") for k in roots):
                bad.append(it["id"])
    # dedup preserving order
    out = []
    for b in bad:
        if b not in out: out.append(b)
    return out

def account_summary(items, targets):
    cov = covered(items)
    c = counts(items)
    miss = sorted(set(targets) - cov)
    return {
        "total": budget(items), "physics": budget(items, "physics"), "overlay": budget(items, "overlay"),
        "posits": c["posit"], "bridges": c["bridge"], "imports": c["import"], "derived": c["derived"],
        "covered": len(cov & set(targets)), "missing": miss, "floating": floating(items),
    }

# ------------------------------------------------------------------ canonical serialization
def fmt6(x):
    x = float(x)
    if abs(x) < 0.5e-6: x = 0.0
    return "%.6f" % x

def jstr(s):
    return json.dumps(s, ensure_ascii=True)   # deterministic string escaping

def canon_case(case):
    """Deterministic re-serialization of the input case (pins it by blake2b)."""
    def item(it): return ("{" + f'"id":{jstr(it["id"])},"kind":{jstr(it["kind"])},"layer":{jstr(it["layer"])},'
                          f'"covers":[{",".join(jstr(c) for c in it["covers"])}],'
                          f'"via":[{",".join(jstr(v) for v in it["via"])}]' + "}")
    def acct(name, items): return "{" + f'"name":{jstr(name)},"items":[{",".join(item(i) for i in items)}]' + "}"
    pn, pit = case["_p"]; un, uit = case["_u"]
    return ("{" + f'"name":{jstr(case["name"])},"targets":[{",".join(jstr(t) for t in case["targets"])}],'
            f'"patchwork":{acct(pn,pit)},"unified":{acct(un,uit)}' + "}")

def acct_json(a):
    return ("{" + f'"total":{fmt6(a["total"])},"physics":{fmt6(a["physics"])},"overlay":{fmt6(a["overlay"])},'
            f'"posits":{a["posits"]},"bridges":{a["bridges"]},"imports":{a["imports"]},"derived":{a["derived"]},'
            f'"covered":{a["covered"]},"missing":[{",".join(jstr(m) for m in a["missing"])}],'
            f'"floating":[{",".join(jstr(f) for f in a["floating"])}]' + "}")

def result_json(r):
    return ("{" + f'"targets_n":{r["targets_n"]},"patchwork":{acct_json(r["patchwork"])},'
            f'"unified":{acct_json(r["unified"])},"delta_physics":{fmt6(r["delta_physics"])},'
            f'"delta_overlay":{fmt6(r["delta_overlay"])},"delta_total":{fmt6(r["delta_total"])},'
            f'"same_reach":{"true" if r["same_reach"] else "false"},"parsimony":{jstr(r["parsimony"])}' + "}")

def params_json(p):
    return ("{" + f'"case_name":{jstr(p["case_name"])},"targets_n":{p["targets_n"]},'
            f'"patchwork_items":{p["patchwork_items"]},"unified_items":{p["unified_items"]},'
            f'"tie_band":{fmt6(p["tie_band"])},"case_blake2b":{jstr(p["case_blake2b"])}' + "}")

def gates_json(gs):
    return "[" + ",".join("{" + f'"id":{jstr(g["id"])},"fired":{"true" if g["fired"] else "false"},'
                          f'"value":{fmt6(g["value"])},"threshold":{fmt6(g["threshold"])}' + "}" for g in gs) + "]"

def declared_body(seed, params, result, gates, verdict):
    return (f'"seed":{seed},"params":{params_json(params)},"result":{result_json(result)},'
            f'"gates":{gates_json(gates)},"verdict":{jstr(verdict)}')

def declared_object(seed, params, result, gates, verdict):
    return "{" + declared_body(seed, params, result, gates, verdict) + "}"

def full_envelope(seed, params, result, gates, verdict):
    return ("{" + f'"tool":"posit","version":{jstr(VERSION)},'
            + declared_body(seed, params, result, gates, verdict)
            + f',"notes":{jstr(FIREWALL)}' + "}")

# ------------------------------------------------------------------ audit
def run_audit(case, tie_band, seed):
    targets = case["targets"]
    _, pit = case["_p"]; _, uit = case["_u"]
    P = account_summary(pit, targets); U = account_summary(uit, targets)
    dp = P["physics"] - U["physics"]
    do = U["overlay"] - P["overlay"]
    dt = P["total"] - U["total"]
    same_reach = (P["covered"] == len(targets)) and (U["covered"] == len(targets))
    win = same_reach and (dp > tie_band) and (len(U["floating"]) == 0)
    result = {"targets_n": len(targets), "patchwork": P, "unified": U,
              "delta_physics": dp, "delta_overlay": do, "delta_total": dt,
              "same_reach": same_reach, "parsimony": "win" if win else "reject"}
    g_nopars = not (same_reach and dp > tie_band)
    g_float = len(U["floating"]) > 0
    gates = [
        {"id": "G-NO-PARSIMONY", "fired": g_nopars, "value": dp, "threshold": tie_band},
        {"id": "G-FLOATING", "fired": g_float, "value": float(len(U["floating"])), "threshold": 0.0},
    ]
    verdict = "fail" if (g_nopars or g_float) else "pass"
    case_hash = hashlib.blake2b(canon_case(case).encode("utf-8"), digest_size=32).hexdigest()
    params = {"case_name": case["name"], "targets_n": len(targets),
              "patchwork_items": len(pit), "unified_items": len(uit),
              "tie_band": tie_band, "case_blake2b": case_hash}
    exit_code = 1 if (g_nopars or g_float) else 0
    return params, result, gates, verdict, exit_code

def load_case(raw):
    if not isinstance(raw, dict): raise BadInput("case must be a JSON object")
    name = raw.get("name", "case")
    if not isinstance(name, str): raise BadInput("case.name must be a string")
    targets = raw.get("targets")
    if not isinstance(targets, list) or not all(isinstance(t, str) for t in targets) or not targets:
        raise BadInput("case.targets must be a non-empty list of strings")
    if "patchwork" not in raw or "unified" not in raw:
        raise BadInput("case must have 'patchwork' and 'unified'")
    p = _items(raw["patchwork"], "patchwork")
    u = _items(raw["unified"], "unified")
    return {"name": name, "targets": targets, "_p": p, "_u": u}

# ------------------------------------------------------------------ golden case (embedded seed cluster)
GOLDEN_CASE = {
    "name": "seed_cluster",
    "targets": ["arrow_of_time", "measurement_classicality", "low_entropy_start"],
    "patchwork": {"name": "PATCHWORK (orthodox)", "items": [
        {"id": "past_hypothesis", "kind": "posit", "layer": "physics", "covers": ["arrow_of_time", "low_entropy_start"]},
        {"id": "stat_mech_typicality", "kind": "posit", "layer": "physics", "covers": ["arrow_of_time"]},
        {"id": "born_postulate", "kind": "posit", "layer": "physics", "covers": ["measurement_classicality"]},
        {"id": "collapse_or_interp", "kind": "posit", "layer": "physics", "covers": ["measurement_classicality"]},
    ]},
    "unified": {"name": "UNIFIED (recoverability/record)", "items": [
        {"id": "record_primitive", "kind": "posit", "layer": "physics", "covers": []},
        {"id": "noncontextual_credence", "kind": "posit", "layer": "physics", "covers": []},
        {"id": "blank_boundary", "kind": "bridge", "layer": "physics", "covers": ["low_entropy_start"]},
        {"id": "decoherence_darwinism", "kind": "import", "layer": "physics", "covers": []},
        {"id": "arrow_derived", "kind": "derived", "layer": "physics", "covers": ["arrow_of_time"], "via": ["record_primitive"]},
        {"id": "measurement_derived", "kind": "derived", "layer": "physics", "covers": ["measurement_classicality"],
         "via": ["record_primitive", "decoherence_darwinism", "noncontextual_credence"]},
        {"id": "arrow_is_felt_time", "kind": "bridge", "layer": "overlay", "covers": [], "via": ["arrow_derived"]},
    ]},
}

def golden_hash():
    case = load_case(GOLDEN_CASE)
    params, result, gates, verdict, _ = run_audit(case, 0.0, 0)
    declared = declared_object(0, params, result, gates, verdict)
    return hashlib.blake2b(declared.encode("utf-8"), digest_size=32).hexdigest(), (params, result, gates, verdict)

# ------------------------------------------------------------------ csv
def write_csv(path, case):
    rows = ["account,id,kind,layer,weight,covers,via,floating"]
    for who, (_, items) in (("patchwork", case["_p"]), ("unified", case["_u"])):
        fl = set(floating(items)); seen = set()
        for it in items:
            if it["id"] in seen: continue
            seen.add(it["id"])
            rows.append(f'{who},{it["id"]},{it["kind"]},{it["layer"]},{W[it["kind"]]:.1f},'
                        f'{";".join(it["covers"])},{";".join(it["via"])},{1 if it["id"] in fl else 0}')
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(rows) + "\n")

# ------------------------------------------------------------------ golden / selftest
def read_golden_hash():
    import os
    for p in ("goldens/posit/declared.hash", "../../goldens/posit/declared.hash", "../../../goldens/posit/declared.hash"):
        if os.path.isfile(p):
            with open(p) as f:
                return f.read().split()[0].strip()
    return None

def run_golden():
    case = load_case(GOLDEN_CASE)
    params, result, gates, verdict, _ = run_audit(case, 0.0, 0)
    declared = declared_object(0, params, result, gates, verdict)
    h = hashlib.blake2b(declared.encode("utf-8"), digest_size=32).hexdigest()
    print(full_envelope(0, params, result, gates, verdict))
    frozen = read_golden_hash()
    if frozen is None:
        sys.stderr.write(f"GOLDEN NOT FROZEN (bootstrap) blake2b={h}\n  freeze into goldens/posit/declared.hash\n")
        return 0
    if h == frozen:
        sys.stderr.write(f"GOLDEN OK blake2b={h}\n"); return 0
    sys.stderr.write(f"GOLDEN MISMATCH\n  got   {h}\n  want  {frozen}\n"); return 1

def _chk(name, ok, fails):
    sys.stderr.write(f"  [{'PASS' if ok else 'FAIL'}] {name}\n")
    if not ok: fails.append(name)
    return ok

def run_selftest():
    fails = []
    sys.stderr.write(f"posit --selftest (v{VERSION})\n")
    # 1. blake2b KAT (hashlib)
    _chk('blake2b-256("abc") KAT',
         hashlib.blake2b(b"abc", digest_size=32).hexdigest()
         == "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319", fails)
    # 2. seed cluster: dp=+0.8, win, no floating
    case = load_case(GOLDEN_CASE)
    params, result, gates, verdict, code = run_audit(case, 0.0, 0)
    _chk("seed cluster physics 4.0 -> 3.2", abs(result["patchwork"]["physics"]-4.0) < 1e-9 and abs(result["unified"]["physics"]-3.2) < 1e-9, fails)
    _chk("seed cluster delta_physics = +0.8", abs(result["delta_physics"]-0.8) < 1e-9, fails)
    _chk("seed cluster same_reach", result["same_reach"], fails)
    _chk("seed cluster no floating", len(result["unified"]["floating"]) == 0, fails)
    _chk("seed cluster parsimony=win, exit 0", result["parsimony"] == "win" and code == 0, fails)
    _chk("seed cluster overlay +1.0, total -0.2", abs(result["delta_overlay"]-1.0) < 1e-9 and abs(result["delta_total"]+0.2) < 1e-9, fails)
    # 3. confabulation guard: relabeling a posit as a bridge does NOT lower the budget
    _chk("bridge costs == posit cost (guard)", W["bridge"] == W["posit"] == 1.0 and W["import"] == 0.2 and W["derived"] == 0.0, fails)
    # 4. floating detection: a derived item backed by nothing is flagged, G-FLOATING fires
    fcase = load_case({"name":"f","targets":["t"],
        "patchwork":{"items":[{"id":"p","kind":"posit","layer":"physics","covers":["t"]}]},
        "unified":{"items":[{"id":"d","kind":"derived","layer":"physics","covers":["t"],"via":["ghost"]}]}})
    _, fr, fg, fv, fcode = run_audit(fcase, 0.0, 0)
    _chk("floating derived flagged + G-FLOATING fires + exit 1",
         fr["unified"]["floating"] == ["d"] and any(g["id"]=="G-FLOATING" and g["fired"] for g in fg) and fcode == 1, fails)
    # 5. no-parsimony reject: unequal budgets same -> G-NO-PARSIMONY, exit 1
    rcase = load_case({"name":"r","targets":["t"],
        "patchwork":{"items":[{"id":"a","kind":"posit","layer":"physics","covers":["t"]}]},
        "unified":{"items":[{"id":"b","kind":"posit","layer":"physics","covers":["t"]}]}})
    _, rr, rg, rv, rcode = run_audit(rcase, 0.0, 0)
    _chk("equal-budget -> parsimony reject, G-NO-PARSIMONY, exit 1",
         rr["parsimony"] == "reject" and any(g["id"]=="G-NO-PARSIMONY" and g["fired"] for g in rg) and rcode == 1, fails)
    # 6. reach guard: unified covering fewer targets is not a win even if cheaper
    ncase = load_case({"name":"n","targets":["t1","t2"],
        "patchwork":{"items":[{"id":"a","kind":"posit","layer":"physics","covers":["t1"]},
                              {"id":"b","kind":"posit","layer":"physics","covers":["t2"]}]},
        "unified":{"items":[{"id":"c","kind":"posit","layer":"physics","covers":["t1"]}]}})
    _, nr, ng, nv, ncode = run_audit(ncase, 0.0, 0)
    _chk("cheaper-but-less-reach -> not a win (same_reach False)",
         nr["same_reach"] is False and nr["parsimony"] == "reject" and ncode == 1, fails)
    # 7. determinism: same case twice -> identical declared object
    d1 = declared_object(0, *run_audit(load_case(GOLDEN_CASE), 0.0, 0)[:4])
    d2 = declared_object(0, *run_audit(load_case(GOLDEN_CASE), 0.0, 0)[:4])
    _chk("declared object identical across two runs", d1 == d2, fails)
    ok = len(fails) == 0
    sys.stderr.write("SELFTEST PASS\n" if ok else f"SELFTEST FAIL ({len(fails)})\n")
    return 0 if ok else 1

# ------------------------------------------------------------------ CLI
def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--case")
    ap.add_argument("--stdin", action="store_true")
    ap.add_argument("--tie-band", type=float, default=0.0, dest="tie_band")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--csv")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--golden", action="store_true")
    try:
        args = ap.parse_args()
    except SystemExit:
        return 2   # argparse error -> bad input
    if args.selftest: return run_selftest()
    if args.golden:   return run_golden()
    try:
        if args.seed < 0: raise BadInput("--seed must be >= 0")
        if not (0.0 <= args.tie_band <= 10.0): raise BadInput("--tie-band out of range [0,10]")
        if args.stdin and args.case: raise BadInput("give --case OR --stdin, not both")
        if args.stdin:
            raw = json.loads(sys.stdin.read())
        elif args.case:
            with open(args.case, encoding="utf-8") as f: raw = json.load(f)
        else:
            raise BadInput("one of --case PATH or --stdin is required")
        case = load_case(raw)
        params, result, gates, verdict, code = run_audit(case, args.tie_band, args.seed)
    except (BadInput, json.JSONDecodeError, FileNotFoundError, OSError) as e:
        sys.stderr.write(f"error: {e}\n"); return 2
    if args.csv:
        try: write_csv(args.csv, case)
        except OSError as e: sys.stderr.write(f"error: cannot write --csv: {e}\n"); return 2
    if args.json or not args.csv:
        print(full_envelope(args.seed, params, result, gates, verdict))
    return code

if __name__ == "__main__":
    sys.exit(main())
