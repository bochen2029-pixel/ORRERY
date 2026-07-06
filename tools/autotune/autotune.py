#!/usr/bin/env python3
# autotune.py -- ORRERY tool `autotune` (v1.0.0). The parameter sweep / basin-finder.
# Headless, deterministic, contract-bounded. Contract: contracts/autotune.contract.md v1.0.0.
#
# Sweeps one parameter over a range, evaluates an OBJECTIVE (a built-in analytic function OR a real
# ORRERY tool subprocessed and read for a JSON metric), and LOCATES a feature -- an argmax (band/basin
# peak) or a level-crossing (threshold / critical point) -- vs a PRE-REGISTERED --target with a gate.
# Locates a feature of a swept curve (a search/orchestration mechanism); says nothing about qualia.
# III-sealed. Python is right here (D-019): orchestration glue, no compute/scale/GPU, no RNG.
#
# Run:  python autotune.py --objective peak --obj-center 0.37 --target 0.37 --json
#       python autotune.py --tool ratchet.exe --sweep rho --metric p_unwrite_mc \
#              --fixed "--p 0.2 --R 3 --trials 2000000 --seed 7" --lo 0.1 --hi 0.6 --locate crossing \
#              --level 0.9 --target 0.25 --json
import sys, json, hashlib, argparse, subprocess, os, math
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

VERSION = "1.0.0"
FIREWALL = ("This locates a feature of a swept curve (a search/orchestration mechanism); it says "
            "nothing about whether anything feels (acquaintance) - III-sealed.")

class BadInput(Exception):
    pass

# ------------------------------------------------------------------ canonical serialization
def fmt6(x):
    x = float(x)
    if abs(x) < 0.5e-6: x = 0.0
    return "%.6f" % x
def jstr(s): return json.dumps(str(s), ensure_ascii=True)

# ------------------------------------------------------------------ objectives
def builtin_eval(kind, C, W, x):
    if kind == "peak":      return math.exp(-((x - C) / W) ** 2)
    if kind == "threshold": return 1.0 / (1.0 + math.exp(-(x - C) / W))
    raise BadInput(f"unknown --objective '{kind}'")

def dotted(doc, path):
    cur = doc
    for k in path.split("."):
        if not isinstance(cur, dict) or k not in cur:
            raise BadInput(f"metric field '{path}' not found in result")
        cur = cur[k]
    if isinstance(cur, bool) or not isinstance(cur, (int, float)):
        raise BadInput(f"metric field '{path}' is not numeric: {cur!r}")
    return float(cur)

def tool_eval(tool, sweep, metric, fixed, x):
    """Run `tool <fixed> <sweep> x --json`, parse stdout JSON, read result.<metric>."""
    argv = [tool] + (fixed.split() if fixed else []) + ["--" + sweep, ("%.10g" % x), "--json"]
    if tool.endswith(".py"): argv = [sys.executable] + argv
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=1800)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise BadInput(f"tool subprocess failed ({tool}): {e}")
    if p.returncode == 2:
        raise BadInput(f"tool returned error exit 2 at {sweep}={x}: {(p.stderr or '').strip()[:200]}")
    try:
        doc = json.loads(p.stdout.strip().splitlines()[-1])   # last line = the JSON envelope
    except Exception as e:
        raise BadInput(f"could not parse tool JSON at {sweep}={x}: {e}")
    return dotted(doc.get("result", {}), metric)

# ------------------------------------------------------------------ locate
def locate_argmax(xs, fs):
    """Parabolic-refined argmax."""
    i = max(range(len(fs)), key=lambda k: (fs[k], -k))     # deterministic tie -> lowest index
    if 0 < i < len(fs) - 1:
        a, b, c = fs[i-1], fs[i], fs[i+1]
        denom = (a - 2*b + c)
        if abs(denom) > 1e-15:
            delta = 0.5 * (a - c) / denom                  # in grid units, |delta|<=~0.5
            delta = max(-1.0, min(1.0, delta))
            dx = xs[1] - xs[0]
            return xs[i] + delta * dx, b - 0.25 * (a - c) * delta
    return xs[i], fs[i]

def locate_crossing(xs, fs, level):
    """First level-crossing (linear interp); if none, the closest-approach point."""
    for k in range(len(fs) - 1):
        if (fs[k] - level) == 0.0:
            return xs[k], level
        if (fs[k] - level) * (fs[k+1] - level) < 0.0:
            t = (level - fs[k]) / (fs[k+1] - fs[k])
            return xs[k] + t * (xs[k+1] - xs[k]), level
    # no crossing: closest approach (gate will catch the miss vs target)
    k = min(range(len(fs)), key=lambda j: (abs(fs[j] - level), j))
    return xs[k], fs[k]

# ------------------------------------------------------------------ run
def run_autotune(A, csv_rows):
    if A["points"] < 3: raise BadInput("--points must be >= 3")
    if not (A["hi"] > A["lo"]): raise BadInput("--hi must be > --lo")
    xs = [A["lo"] + i * (A["hi"] - A["lo"]) / (A["points"] - 1) for i in range(A["points"])]
    if A["objective"]:
        fs = [builtin_eval(A["objective"], A["obj_center"], A["obj_width"], x) for x in xs]
        desc = A["objective"]
    else:
        fs = [tool_eval(A["tool"], A["sweep"], A["metric"], A["fixed"], x) for x in xs]
        desc = "tool:" + os.path.basename(A["tool"])
    if csv_rows is not None:
        for x, f in zip(xs, fs): csv_rows.append(f"{fmt6(x)},{fmt6(f)}")
    if A["locate"] == "argmax":
        xloc, floc = locate_argmax(xs, fs)
    else:
        xloc, floc = locate_crossing(xs, fs, A["level"])
    err = abs(xloc - A["target"])
    on = err <= A["tol"]
    result = {"objective": desc, "locate": A["locate"], "points": A["points"], "lo": A["lo"], "hi": A["hi"],
              "x_located": xloc, "f_at_located": floc, "target": A["target"], "located_error": err,
              "on_target": on, "f_min": min(fs), "f_max": max(fs)}
    gates = [{"id": "G-OFF-TARGET", "fired": (not on), "value": err, "threshold": A["tol"]}]
    verdict = "fail" if not on else "pass"
    return result, gates, verdict, (1 if not on else 0)

# ------------------------------------------------------------------ serialize
def params_json(A):
    return ("{" + f'"objective":{jstr(A["objective"])},"obj_center":{fmt6(A["obj_center"])},'
            f'"obj_width":{fmt6(A["obj_width"])},"tool":{jstr(A["tool"])},"sweep":{jstr(A["sweep"])},'
            f'"metric":{jstr(A["metric"])},"fixed":{jstr(A["fixed"])},"lo":{fmt6(A["lo"])},"hi":{fmt6(A["hi"])},'
            f'"points":{A["points"]},"locate":{jstr(A["locate"])},"level":{fmt6(A["level"])},'
            f'"target":{fmt6(A["target"])},"tol":{fmt6(A["tol"])}' + "}")
def result_json(r):
    return ("{" + f'"objective":{jstr(r["objective"])},"locate":{jstr(r["locate"])},"points":{r["points"]},'
            f'"lo":{fmt6(r["lo"])},"hi":{fmt6(r["hi"])},"x_located":{fmt6(r["x_located"])},'
            f'"f_at_located":{fmt6(r["f_at_located"])},"target":{fmt6(r["target"])},'
            f'"located_error":{fmt6(r["located_error"])},"on_target":{"true" if r["on_target"] else "false"},'
            f'"f_min":{fmt6(r["f_min"])},"f_max":{fmt6(r["f_max"])}' + "}")
def gates_json(gs):
    return "[" + ",".join("{" + f'"id":{jstr(g["id"])},"fired":{"true" if g["fired"] else "false"},'
                          f'"value":{fmt6(g["value"])},"threshold":{fmt6(g["threshold"])}' + "}" for g in gs) + "]"
def declared_body(seed, A, r, gs, v):
    return f'"seed":{seed},"params":{params_json(A)},"result":{result_json(r)},"gates":{gates_json(gs)},"verdict":{jstr(v)}'
def declared_object(seed, A, r, gs, v): return "{" + declared_body(seed, A, r, gs, v) + "}"
def full_envelope(seed, A, r, gs, v):
    return "{" + f'"tool":"autotune","version":{jstr(VERSION)},' + declared_body(seed, A, r, gs, v) + f',"notes":{jstr(FIREWALL)}' + "}"

# ------------------------------------------------------------------ golden
def golden_args():
    return {"objective": "peak", "obj_center": 0.37, "obj_width": 0.12, "tool": "", "sweep": "", "metric": "",
            "fixed": "", "lo": 0.0, "hi": 1.0, "points": 41, "locate": "argmax", "level": 0.5, "target": 0.37, "tol": 0.02}
def golden_hash_and_env():
    A = golden_args(); r, gs, v, _ = run_autotune(A, None)
    return hashlib.blake2b(declared_object(0, A, r, gs, v).encode("utf-8"), digest_size=32).hexdigest(), (A, r, gs, v)
def read_golden_hash():
    for p in ("goldens/autotune/declared.hash", "../../goldens/autotune/declared.hash", "../../../goldens/autotune/declared.hash"):
        if os.path.isfile(p):
            with open(p) as f: return f.read().split()[0].strip()
    return None
def run_golden():
    A = golden_args(); r, gs, v, _ = run_autotune(A, None)
    h = hashlib.blake2b(declared_object(0, A, r, gs, v).encode("utf-8"), digest_size=32).hexdigest()
    print(full_envelope(0, A, r, gs, v))
    frozen = read_golden_hash()
    if frozen is None:
        sys.stderr.write(f"GOLDEN NOT FROZEN (bootstrap) blake2b={h}\n  freeze into goldens/autotune/declared.hash\n"); return 0
    if h == frozen: sys.stderr.write(f"GOLDEN OK blake2b={h}\n"); return 0
    sys.stderr.write(f"GOLDEN MISMATCH\n  got   {h}\n  want  {frozen}\n"); return 1

# ------------------------------------------------------------------ selftest
def _chk(n, ok, fails):
    sys.stderr.write(f"  [{'PASS' if ok else 'FAIL'}] {n}\n")
    if not ok: fails.append(n)
def run_selftest():
    fails = []
    sys.stderr.write(f"autotune --selftest (v{VERSION})\n")
    _chk('blake2b-256("abc") KAT', hashlib.blake2b(b"abc", digest_size=32).hexdigest()
         == "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319", fails)
    # peak: parabolic-refined argmax recovers the center
    A = golden_args(); r, gs, v, code = run_autotune(A, None)
    _chk("peak argmax recovers center 0.37 (on_target, exit 0)", r["on_target"] and abs(r["x_located"]-0.37) < 0.02 and code == 0, fails)
    _chk("f_max near 1.0 (grid approaches the peak C)", 0.99 < r["f_max"] <= 1.0, fails)
    # threshold: crossing 0.5 recovers the center
    At = {**golden_args(), "objective": "threshold", "obj_center": 0.62, "obj_width": 0.05,
          "locate": "crossing", "level": 0.5, "target": 0.62}
    rt, gt, vt, ct = run_autotune(At, None)
    _chk("threshold crossing-0.5 recovers center 0.62 (on_target)", rt["on_target"] and abs(rt["x_located"]-0.62) < 0.02, fails)
    # off-target -> G-OFF-TARGET fires, exit 1
    Ao = {**golden_args(), "target": 0.9, "tol": 0.02}
    ro, go, vo, co = run_autotune(Ao, None)
    _chk("wrong pre-registered target -> G-OFF-TARGET fires, exit 1", (not ro["on_target"]) and go[0]["fired"] and co == 1, fails)
    # determinism: two full runs -> identical declared object
    r1 = run_autotune(golden_args(), None); r2 = run_autotune(golden_args(), None)
    d1 = declared_object(0, golden_args(), r1[0], r1[1], r1[2]); d2 = declared_object(0, golden_args(), r2[0], r2[1], r2[2])
    _chk("declared object identical across two runs", d1 == d2, fails)
    ok = len(fails) == 0
    sys.stderr.write("SELFTEST PASS\n" if ok else f"SELFTEST FAIL ({len(fails)})\n")
    return 0 if ok else 1

# ------------------------------------------------------------------ CLI
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--objective"); ap.add_argument("--obj-center", type=float, default=0.5, dest="obj_center")
    ap.add_argument("--obj-width", type=float, default=0.1, dest="obj_width")
    ap.add_argument("--tool"); ap.add_argument("--sweep", default=""); ap.add_argument("--metric", default=""); ap.add_argument("--fixed", default="")
    ap.add_argument("--lo", type=float, default=0.0); ap.add_argument("--hi", type=float, default=1.0)
    ap.add_argument("--points", type=int, default=41); ap.add_argument("--locate", default="argmax")
    ap.add_argument("--level", type=float, default=0.5); ap.add_argument("--target", type=float)
    ap.add_argument("--tol", type=float, default=0.02); ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--json", action="store_true"); ap.add_argument("--csv"); ap.add_argument("--selftest", action="store_true"); ap.add_argument("--golden", action="store_true")
    try:
        args = ap.parse_args()
    except SystemExit:
        return 2
    if args.selftest: return run_selftest()
    if args.golden:   return run_golden()
    try:
        if args.seed < 0: raise BadInput("--seed must be >= 0")
        if args.locate not in ("argmax", "crossing"): raise BadInput("--locate must be argmax|crossing")
        if bool(args.objective) == bool(args.tool): raise BadInput("give exactly one of --objective or --tool")
        if args.objective and args.objective not in ("peak", "threshold"): raise BadInput("--objective must be peak|threshold")
        if args.tool and (not args.sweep or not args.metric): raise BadInput("--tool requires --sweep and --metric")
        if args.target is None: raise BadInput("--target is required (the pre-registered expected location)")
        if not (3 <= args.points <= 4096): raise BadInput("--points out of range [3,4096]")
        if args.tol < 0.0: raise BadInput("--tol must be >= 0")
        A = {"objective": args.objective or "", "obj_center": args.obj_center, "obj_width": args.obj_width,
             "tool": args.tool or "", "sweep": args.sweep, "metric": args.metric, "fixed": args.fixed,
             "lo": args.lo, "hi": args.hi, "points": args.points, "locate": args.locate, "level": args.level,
             "target": args.target, "tol": args.tol}
        csv_rows = [] if args.csv else None
        result, gates, verdict, code = run_autotune(A, csv_rows)
    except BadInput as e:
        sys.stderr.write(f"error: {e}\n"); return 2
    if args.csv:
        try:
            with open(args.csv, "w", encoding="utf-8", newline="") as f:
                f.write("x,f\n" + "\n".join(csv_rows) + "\n")
        except OSError as e:
            sys.stderr.write(f"error: cannot write --csv: {e}\n"); return 2
    if args.json or not args.csv:
        print(full_envelope(args.seed, A, result, gates, verdict))
    return code

if __name__ == "__main__":
    sys.exit(main())
