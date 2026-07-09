#!/usr/bin/env python3
# mcp.py -- ORRERY tool `mcp` (v1.0.0). The MCP surface (D-022).
# Headless stdio JSON-RPC 2.0 server exposing the catalogue to LLM callers.
# Contract: contracts/mcp.contract.md v1.0.0. The contract is authoritative.
#
# THE SPLIT (ARCHITECTURE section 2) PASSES THROUGH UNCHANGED: this surface SUBPROCESSES the sacred
# executables and serves their contracts verbatim; it never links tool internals, never computes.
# I-12: every run response embeds the D-013 declared-object blake2b + the artifact blake2b.
# Python is right here (D-005/D-022): pure IPC bookkeeping -- subprocess, JSON, file reads. No RNG.
#
# Run:  python mcp.py --serve                 (the operational mode: MCP on stdio)
#       python mcp.py --once '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
#       python mcp.py --json | --selftest | --golden
import sys, os, json, hashlib, argparse, subprocess, re, datetime

try:
    sys.stdout.reconfigure(encoding="utf-8")   # Windows console is cp1252
except Exception:
    pass

VERSION = "1.0.0"
FIREWALL = ("A transport/orchestration surface: it computes nothing scientific itself and says "
            "nothing about qualia - III-sealed. The sacred CLI executables remain the contract of "
            "record; this surface subprocesses them and serves their contracts verbatim.")
PROTOCOL_PIN = "2025-06-18"
V1_CATALOGUE = ["algebra", "autotune", "mcts", "posit", "ratchet", "someone"]
CHAIN_TIMEOUT_S = 120
RUN_TIMEOUT_S = 900
MAX_TIMEOUT_S = 3600

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS_DIR = os.path.join(ROOT, "tools")
CONTRACTS_DIR = os.path.join(ROOT, "contracts")
GOLDENS_DIR = os.path.join(ROOT, "goldens")
RUNS_DIR = os.path.join(ROOT, "runs", "mcp")

class ToolError(Exception):
    """A caller-input problem inside an MCP tool -> isError:true tool result (never a crash)."""

def blake2b_hex(data):
    if isinstance(data, str): data = data.encode("utf-8")
    return hashlib.blake2b(data, digest_size=32).hexdigest()

def fmt6(x):
    x = float(x)
    if abs(x) < 0.5e-6: x = 0.0
    return "%.6f" % x

def jstr(s):
    return json.dumps(s, ensure_ascii=True)

def read_first_token(path):
    try:
        with open(path, encoding="utf-8") as f:
            parts = f.read().split()
            return parts[0] if parts else None
    except OSError:
        return None

def file_blake2b(path):
    try:
        with open(path, "rb") as f:
            return blake2b_hex(f.read())
    except OSError:
        return None

# ------------------------------------------------------------------ registry (the harness's own discovery rule)
def registry_scan():
    out = []
    if not os.path.isdir(TOOLS_DIR):
        return out
    for name in sorted(os.listdir(TOOLS_DIR)):
        d = os.path.join(TOOLS_DIR, name)
        if not (os.path.isdir(d) and os.path.isfile(os.path.join(d, "MODULE.md"))):
            continue
        py = os.path.join(d, name + ".py")
        exe = os.path.join(d, name + ".exe")
        if os.path.isfile(py):
            lang, artifact = "python", py
        elif os.path.isfile(exe):
            lang, artifact = "exe", exe
        else:
            lang, artifact = "missing", None
        cpath = os.path.join(CONTRACTS_DIR, name + ".contract.md")
        ver = None
        if os.path.isfile(cpath):
            try:
                with open(cpath, encoding="utf-8") as f:
                    m = re.search(r"v(\d+\.\d+\.\d+)", f.readline())
                    ver = m.group(1) if m else None
            except OSError:
                pass
        out.append({
            "name": name, "lang": lang, "artifact": artifact,
            "contract_version": ver,
            "has_contract": os.path.isfile(cpath),
            "has_schema": os.path.isfile(os.path.join(CONTRACTS_DIR, name + ".schema.json")),
            "golden_hash": read_first_token(os.path.join(GOLDENS_DIR, name, "declared.hash")),
        })
    return out

def registry_get(name):
    for t in registry_scan():
        if t["name"] == name:
            return t
    return None

# ------------------------------------------------------------------ the I-12 hash chain
def extract_declared(envelope_text):
    """Textual extraction of the D-013 declared object from a raw envelope line.
    Exact by construction: every tool emits {"tool":..,"version":..,"seed":..,...,"verdict":..,"notes":..}
    in this fixed order (lib-pinned), so the declared object is the substring seed..verdict re-wrapped."""
    i = envelope_text.find('"seed":')
    j = envelope_text.rfind(',"notes":')
    if i < 0 or j < 0 or j <= i:
        return None
    return "{" + envelope_text[i:j] + "}"

def envelope_line(stdout_text):
    for line in stdout_text.splitlines():
        if line.startswith("{"):
            return line
    return None

# ------------------------------------------------------------------ run_tool
KEY_RE = re.compile(r"^[A-Za-z0-9-]+$")   # case-sensitive: the catalogue has --R (ratchet), --N (someone)
RUNID_RE = re.compile(r"^[A-Za-z0-9_-]+$")

def build_argv(entry, params):
    if entry["lang"] == "python":
        argv = [sys.executable, entry["artifact"]]
    elif entry["lang"] == "exe":
        argv = [entry["artifact"]]
    else:
        raise ToolError(f"tool '{entry['name']}' has no runnable artifact")
    params = params or {}
    for k, v in params.items():
        if not isinstance(k, str) or not KEY_RE.match(k):
            raise ToolError(f"bad param key '{k}' (want ^[a-z0-9-]+$)")
        if v is True:
            argv.append("--" + k)
        elif v is False or v is None:
            continue
        else:
            argv += ["--" + k, str(v)]
    if "golden" not in params and "selftest" not in params and "json" not in params:
        argv.append("--json")
    return argv

def next_run_id(tool):
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    return f"{tool}-{stamp}-{os.getpid()}"

def do_run_tool(args, store=True, run_id=None, timeout_default=RUN_TIMEOUT_S):
    tool = args.get("tool")
    if not isinstance(tool, str):
        raise ToolError("run_tool.tool must be a string")
    entry = registry_get(tool)
    if entry is None:
        raise ToolError(f"unknown tool '{tool}' (not in the registry)")
    timeout_s = args.get("timeout_s", timeout_default)
    if not isinstance(timeout_s, (int, float)) or not (1 <= timeout_s <= MAX_TIMEOUT_S):
        raise ToolError(f"timeout_s out of range [1,{MAX_TIMEOUT_S}]")
    argv = build_argv(entry, args.get("params"))
    stdin_data = None
    if "stdin_json" in args and args["stdin_json"] is not None:
        sj = args["stdin_json"]
        stdin_data = sj if isinstance(sj, str) else json.dumps(sj)
    t0 = datetime.datetime.now()
    try:
        p = subprocess.run(argv, cwd=os.path.dirname(entry["artifact"]),
                           input=stdin_data, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=timeout_s)
        exit_code, timed_out = p.returncode, False
        out, err = p.stdout or "", p.stderr or ""
    except subprocess.TimeoutExpired as e:
        exit_code, timed_out = None, True
        out = (e.stdout or "") if isinstance(e.stdout, str) else ""
        err = (e.stderr or "") if isinstance(e.stderr, str) else ""
    except OSError as e:
        raise ToolError(f"cannot spawn '{tool}': {e}")
    duration_s = (datetime.datetime.now() - t0).total_seconds()
    if timed_out:
        exit_class = "timeout"
    elif exit_code == 0:
        exit_class = "pass"
    elif exit_code == 1:
        exit_class = "gate-fired"
    else:
        exit_class = "error"
    raw = envelope_line(out)
    envelope = None
    declared_hash = None
    if raw is not None:
        declared = extract_declared(raw)
        if declared is not None:
            declared_hash = blake2b_hex(declared)
        try:
            envelope = json.loads(raw)
        except json.JSONDecodeError:
            envelope = None
    rec = {
        "run_id": run_id or next_run_id(tool),           # non-declared
        "tool": tool,
        "argv": argv,
        "exit_code": exit_code,
        "exit_class": exit_class,
        "envelope": envelope,
        "declared_blake2b": declared_hash,
        "artifact_blake2b": file_blake2b(entry["artifact"]),
        "stderr_tail": "\n".join(err.strip().splitlines()[-4:]),
        "duration_s": round(duration_s, 3),              # non-declared
    }
    if store:
        try:
            os.makedirs(RUNS_DIR, exist_ok=True)
            with open(os.path.join(RUNS_DIR, rec["run_id"] + ".json"), "w", encoding="utf-8") as f:
                json.dump(rec, f, indent=1)
        except OSError as e:
            rec["store_error"] = str(e)                  # record survives; storage is best-effort
    return rec

def do_get_run(args):
    rid = args.get("run_id")
    if not isinstance(rid, str) or not RUNID_RE.match(rid):
        raise ToolError("get_run.run_id must match ^[A-Za-z0-9_-]+$")
    path = os.path.join(RUNS_DIR, rid + ".json")
    if not os.path.isfile(path):
        raise ToolError(f"unknown run_id '{rid}'")
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def do_describe_contract(args):
    tool = args.get("tool")
    if not isinstance(tool, str):
        raise ToolError("describe_contract.tool must be a string")
    if registry_get(tool) is None:
        raise ToolError(f"unknown tool '{tool}'")
    spath = os.path.join(CONTRACTS_DIR, tool + ".schema.json")
    cpath = os.path.join(CONTRACTS_DIR, tool + ".contract.md")
    schema_text = contract_text = None
    for p, key in ((spath, "schema"), (cpath, "contract")):
        if os.path.isfile(p):
            with open(p, encoding="utf-8") as f:
                if key == "schema": schema_text = f.read()
                else: contract_text = f.read()
    if schema_text is None and contract_text is None:
        raise ToolError(f"tool '{tool}' has no contract files")
    return {
        "tool": tool,
        "schema_json": schema_text,                       # verbatim
        "contract_md": contract_text,                     # verbatim
        "schema_blake2b": blake2b_hex(schema_text) if schema_text is not None else None,
        "contract_blake2b": blake2b_hex(contract_text) if contract_text is not None else None,
    }

def do_list_tools(_args):
    tools = registry_scan()
    return {"tools": tools, "count": len(tools)}

def do_sweep(args):
    for req in ("tool", "sweep", "metric", "lo", "hi", "target"):
        if req not in args:
            raise ToolError(f"sweep.{req} is required")
    target_entry = registry_get(args["tool"])
    if target_entry is None:
        raise ToolError(f"unknown tool '{args['tool']}'")
    if target_entry["artifact"] is None:
        raise ToolError(f"tool '{args['tool']}' has no runnable artifact")
    at = registry_get("autotune")
    if at is None or at["artifact"] is None:
        raise ToolError("autotune is not in the registry")
    params = {
        "tool": target_entry["artifact"],                 # absolute path (Windows-safe)
        "sweep": args["sweep"], "metric": args["metric"],
        "lo": args["lo"], "hi": args["hi"], "target": args["target"],
    }
    for opt in ("points", "fixed", "locate", "level", "tol", "seed"):
        if opt in args and args[opt] is not None:
            params[opt] = args[opt]
    return do_run_tool({"tool": "autotune", "params": params,
                        "timeout_s": args.get("timeout_s", RUN_TIMEOUT_S)})

def do_golden_status(args):
    verify = os.path.join(ROOT, "harness", "verify.py")
    if not os.path.isfile(verify):
        raise ToolError("harness/verify.py not found")
    argv = [sys.executable, verify]
    if args.get("no_build", True):
        argv.append("--no-build")
    tool = args.get("tool")
    if tool is not None:
        if registry_get(tool) is None:
            raise ToolError(f"unknown tool '{tool}'")
        argv += ["--tool", tool]
    timeout_s = args.get("timeout_s", 1200)
    if not isinstance(timeout_s, (int, float)) or not (1 <= timeout_s <= MAX_TIMEOUT_S):
        raise ToolError(f"timeout_s out of range [1,{MAX_TIMEOUT_S}]")
    try:
        p = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=timeout_s)
    except subprocess.TimeoutExpired:
        return {"overall": "TIMEOUT", "rows": [], "report": None}
    rows = []
    report = None
    for line in (p.stdout or "").splitlines():
        m = re.match(r"^\s{2}(\S+): build=(\S+) selftest=(\S+) golden=(\S+)$", line)
        if m:
            rows.append({"tool": m.group(1), "build": m.group(2),
                         "selftest": m.group(3), "golden": m.group(4)})
            continue
        if line.startswith("report: "):
            report = line[len("report: "):].strip()
    overall = "GREEN" if "OVERALL: GREEN" in (p.stdout or "") else "RED"
    return {"overall": overall, "rows": rows, "report": report}   # report is non-declared

# ------------------------------------------------------------------ MCP protocol (stdio JSON-RPC 2.0)
MCP_TOOLS = [
    {"name": "list_tools",
     "description": "List the ORRERY tool registry (name, language, contract version, golden hash).",
     "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "describe_contract",
     "description": "Serve a tool's machine-checkable JSON schema and human contract VERBATIM from contracts/.",
     "inputSchema": {"type": "object", "required": ["tool"], "additionalProperties": False,
                     "properties": {"tool": {"type": "string"}}}},
    {"name": "run_tool",
     "description": "Run a registry tool headlessly (--json forced) and return its envelope plus the D-013 declared-object blake2b and artifact blake2b (I-12). Exit classes: pass | gate-fired | error | timeout.",
     "inputSchema": {"type": "object", "required": ["tool"], "additionalProperties": False,
                     "properties": {"tool": {"type": "string"},
                                    "params": {"type": "object"},
                                    "stdin_json": {},
                                    "timeout_s": {"type": "number", "minimum": 1, "maximum": MAX_TIMEOUT_S}}}},
    {"name": "get_run",
     "description": "Fetch a stored run_tool record by run_id.",
     "inputSchema": {"type": "object", "required": ["run_id"], "additionalProperties": False,
                     "properties": {"run_id": {"type": "string"}}}},
    {"name": "sweep",
     "description": "Sweep a registry tool's parameter via autotune (real-tool mode) against a PRE-REGISTERED target; returns the autotune run record (autotune's contract governs semantics).",
     "inputSchema": {"type": "object", "required": ["tool", "sweep", "metric", "lo", "hi", "target"],
                     "additionalProperties": False,
                     "properties": {"tool": {"type": "string"}, "sweep": {"type": "string"},
                                    "metric": {"type": "string"}, "lo": {"type": "number"},
                                    "hi": {"type": "number"}, "target": {"type": "number"},
                                    "points": {"type": "integer"}, "fixed": {"type": "string"},
                                    "locate": {"type": "string"}, "level": {"type": "number"},
                                    "tol": {"type": "number"}, "seed": {"type": "integer"},
                                    "timeout_s": {"type": "number"}}}},
    {"name": "golden_status",
     "description": "Run harness/verify.py (default --no-build) and report GREEN/RED per tool.",
     "inputSchema": {"type": "object", "additionalProperties": False,
                     "properties": {"tool": {"type": "string"}, "no_build": {"type": "boolean"},
                                    "timeout_s": {"type": "number"}}}},
]
TOOL_IMPL = {"list_tools": do_list_tools, "describe_contract": do_describe_contract,
             "run_tool": do_run_tool, "get_run": do_get_run,
             "sweep": do_sweep, "golden_status": do_golden_status}

def rpc_result(rid, result):
    return {"jsonrpc": "2.0", "id": rid, "result": result}

def rpc_error(rid, code, message):
    return {"jsonrpc": "2.0", "id": rid, "error": {"code": code, "message": message}}

def handle_request(req):
    """Dispatch one JSON-RPC request dict -> response dict, or None for notifications."""
    if not isinstance(req, dict) or req.get("jsonrpc") != "2.0" or not isinstance(req.get("method"), str):
        return rpc_error(req.get("id") if isinstance(req, dict) else None, -32600, "invalid request")
    method = req["method"]
    rid = req.get("id")
    params = req.get("params") or {}
    if method == "initialize":
        client_pv = params.get("protocolVersion")
        pv = client_pv if isinstance(client_pv, str) and client_pv else PROTOCOL_PIN
        return rpc_result(rid, {"protocolVersion": pv, "capabilities": {"tools": {}},
                                "serverInfo": {"name": "orrery-mcp", "version": VERSION}})
    if method == "notifications/initialized":
        return None
    if method == "ping":
        return rpc_result(rid, {})
    if method == "tools/list":
        return rpc_result(rid, {"tools": MCP_TOOLS})
    if method == "tools/call":
        name = params.get("name")
        args = params.get("arguments") or {}
        impl = TOOL_IMPL.get(name)
        if impl is None:
            return rpc_result(rid, {"content": [{"type": "text", "text": f"unknown tool '{name}'"}],
                                    "isError": True})
        try:
            out = impl(args)
            return rpc_result(rid, {"content": [{"type": "text", "text": json.dumps(out)}],
                                    "isError": False})
        except ToolError as e:
            return rpc_result(rid, {"content": [{"type": "text", "text": f"error: {e}"}],
                                    "isError": True})
        except Exception as e:                            # never crash the server on a tool bug
            return rpc_result(rid, {"content": [{"type": "text", "text": f"internal error: {e}"}],
                                    "isError": True})
    if rid is None:
        return None                                       # unknown notification: ignore
    return rpc_error(rid, -32601, f"method not found: {method}")

def serve():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            sys.stdout.write(json.dumps(rpc_error(None, -32700, "parse error")) + "\n")
            sys.stdout.flush()
            continue
        resp = handle_request(req)
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()
    return 0

# ------------------------------------------------------------------ the chain check (--json / --golden body)
def chain_check(timeout_s=CHAIN_TIMEOUT_S):
    """Returns (params, result, gates, verdict, exit_code). Deterministic given the repo at a commit."""
    reg = {t["name"]: t for t in registry_scan()}
    missing = 0
    for name in V1_CATALOGUE:
        t = reg.get(name)
        if t is None or not t["has_contract"] or not t["has_schema"] or t["golden_hash"] is None:
            missing += 1
    complete = (missing == 0)
    # in-process JSON-RPC round-trip
    ok = True
    r1 = handle_request({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                         "params": {"protocolVersion": PROTOCOL_PIN}})
    ok &= bool(r1 and r1.get("result", {}).get("serverInfo", {}).get("name") == "orrery-mcp")
    r2 = handle_request({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
    ok &= bool(r2 and len(r2.get("result", {}).get("tools", [])) == len(MCP_TOOLS))
    r3 = handle_request({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
                         "params": {"name": "list_tools", "arguments": {}}})
    try:
        listed = json.loads(r3["result"]["content"][0]["text"])
        ok &= (r3["result"]["isError"] is False) and (listed["count"] >= len(V1_CATALOGUE))
    except Exception:
        ok = False
    # the real chain: posit --golden through the generic subprocess path
    if reg.get("posit") is None or reg["posit"]["artifact"] is None:
        sys.stderr.write("error: posit artifact not found (the chain tool)\n")
        sys.exit(2)
    rec = do_run_tool({"tool": "posit", "params": {"golden": True}, "timeout_s": timeout_s},
                      store=False, run_id="golden-chain")
    frozen = read_first_token(os.path.join(GOLDENS_DIR, "posit", "declared.hash"))
    matches = (rec["declared_blake2b"] is not None and frozen is not None
               and rec["declared_blake2b"] == frozen)
    params = {"chain_tool": "posit", "v1_catalogue": list(V1_CATALOGUE), "timeout_s": timeout_s}
    result = {"jsonrpc_roundtrip_ok": bool(ok), "tools_exposed": len(MCP_TOOLS),
              "v1_catalogue_complete": complete, "chain_tool": "posit",
              "chain_exit_class": rec["exit_class"],
              "chain_declared_blake2b": rec["declared_blake2b"] or "",
              "chain_matches_frozen": matches}
    g_chain = (rec["exit_class"] != "pass") or (not matches)
    gates = [
        {"id": "G-CHAIN-MISMATCH", "fired": g_chain, "value": 1.0 if g_chain else 0.0, "threshold": 0.0},
        {"id": "G-REGISTRY-INCOMPLETE", "fired": not complete, "value": float(missing), "threshold": 0.0},
    ]
    verdict = "fail" if (g_chain or not complete) else "pass"
    return params, result, gates, verdict, (1 if verdict == "fail" else 0)

# ------------------------------------------------------------------ canonical serialization (posit-style)
def params_json(p):
    return ("{" + f'"chain_tool":{jstr(p["chain_tool"])},'
            f'"v1_catalogue":[{",".join(jstr(n) for n in p["v1_catalogue"])}],'
            f'"timeout_s":{int(p["timeout_s"])}' + "}")

def result_json(r):
    return ("{" + f'"jsonrpc_roundtrip_ok":{"true" if r["jsonrpc_roundtrip_ok"] else "false"},'
            f'"tools_exposed":{r["tools_exposed"]},'
            f'"v1_catalogue_complete":{"true" if r["v1_catalogue_complete"] else "false"},'
            f'"chain_tool":{jstr(r["chain_tool"])},'
            f'"chain_exit_class":{jstr(r["chain_exit_class"])},'
            f'"chain_declared_blake2b":{jstr(r["chain_declared_blake2b"])},'
            f'"chain_matches_frozen":{"true" if r["chain_matches_frozen"] else "false"}' + "}")

def gates_json(gs):
    return "[" + ",".join("{" + f'"id":{jstr(g["id"])},"fired":{"true" if g["fired"] else "false"},'
                          f'"value":{fmt6(g["value"])},"threshold":{fmt6(g["threshold"])}' + "}" for g in gs) + "]"

def declared_body(seed, params, result, gates, verdict):
    return (f'"seed":{seed},"params":{params_json(params)},"result":{result_json(result)},'
            f'"gates":{gates_json(gates)},"verdict":{jstr(verdict)}')

def declared_object(seed, params, result, gates, verdict):
    return "{" + declared_body(seed, params, result, gates, verdict) + "}"

def full_envelope(seed, params, result, gates, verdict):
    return ("{" + f'"tool":"mcp","version":{jstr(VERSION)},'
            + declared_body(seed, params, result, gates, verdict)
            + f',"notes":{jstr(FIREWALL)}' + "}")

# ------------------------------------------------------------------ golden
def read_golden_hash():
    for p in ("goldens/mcp/declared.hash", "../../goldens/mcp/declared.hash", "../../../goldens/mcp/declared.hash"):
        if os.path.isfile(p):
            with open(p) as f:
                return f.read().split()[0].strip()
    return None

def run_golden():
    params, result, gates, verdict, _ = chain_check()
    declared = declared_object(0, params, result, gates, verdict)
    h = blake2b_hex(declared)
    print(full_envelope(0, params, result, gates, verdict))
    frozen = read_golden_hash()
    if frozen is None:
        sys.stderr.write(f"GOLDEN NOT FROZEN (bootstrap) blake2b={h}\n  freeze into goldens/mcp/declared.hash\n")
        return 0
    if h == frozen:
        sys.stderr.write(f"GOLDEN OK blake2b={h}\n"); return 0
    sys.stderr.write(f"GOLDEN MISMATCH\n  got   {h}\n  want  {frozen}\n"); return 1

# ------------------------------------------------------------------ selftest
def _chk(name, ok, fails):
    sys.stderr.write(f"  [{'PASS' if ok else 'FAIL'}] {name}\n")
    if not ok: fails.append(name)
    return ok

def run_selftest():
    fails = []
    sys.stderr.write(f"mcp --selftest (v{VERSION})\n")
    # 1. blake2b KAT
    _chk('blake2b-256("abc") KAT',
         blake2b_hex("abc") == "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319", fails)
    # 2. declared-extraction KAT on a synthetic envelope
    syn = '{"tool":"x","version":"9.9.9","seed":7,"params":{"a":1},"result":{"b":2},"gates":[],"verdict":"pass","notes":"n"}'
    _chk("declared extraction (synthetic envelope)",
         extract_declared(syn) == '{"seed":7,"params":{"a":1},"result":{"b":2},"gates":[],"verdict":"pass"}', fails)
    # 3. registry finds the six v1 tools, complete
    reg = {t["name"]: t for t in registry_scan()}
    _chk("registry has the six v1 tools with contract+schema+golden",
         all(n in reg and reg[n]["has_contract"] and reg[n]["has_schema"] and reg[n]["golden_hash"]
             for n in V1_CATALOGUE), fails)
    # 4. contract-version parse
    _chk("posit contract version parses (1.0.x)",
         (reg.get("posit") or {}).get("contract_version", "").startswith("1.0"), fails)
    # 5. describe_contract serves posit's schema verbatim-parseable
    try:
        dc = do_describe_contract({"tool": "posit"})
        sc = json.loads(dc["schema_json"])
        ok5 = sc.get("properties", {}).get("tool", {}).get("const") == "posit" and dc["schema_blake2b"]
    except Exception:
        ok5 = False
    _chk('describe_contract(posit) serves schema with tool const "posit"', bool(ok5), fails)
    # 6. initialize shape
    r = handle_request({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "X"}})
    _chk("initialize echoes protocolVersion + serverInfo",
         r["result"]["protocolVersion"] == "X" and r["result"]["serverInfo"]["name"] == "orrery-mcp", fails)
    # 7. tools/list = the six MCP tools
    r = handle_request({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
    _chk("tools/list serves 6 MCP tools with the contract names",
         [t["name"] for t in r["result"]["tools"]] ==
         ["list_tools", "describe_contract", "run_tool", "get_run", "sweep", "golden_status"], fails)
    # 8. error paths: unknown method -32601; unknown tool -> isError
    r = handle_request({"jsonrpc": "2.0", "id": 3, "method": "nope"})
    r2 = handle_request({"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "nope"}})
    _chk("unknown method -> -32601; unknown tool -> isError:true",
         r["error"]["code"] == -32601 and r2["result"]["isError"] is True, fails)
    # 9. REAL stdio round-trip: subprocess self with --once
    try:
        p = subprocess.run([sys.executable, os.path.abspath(__file__), "--once",
                            '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'],
                           capture_output=True, text=True, encoding="utf-8", timeout=60)
        line = envelope_line(p.stdout)
        ok9 = p.returncode == 0 and line and len(json.loads(line)["result"]["tools"]) == 6
    except Exception:
        ok9 = False
    _chk("stdio --once round-trip (real subprocess of self)", bool(ok9), fails)
    # 10. THE I-12 CHAIN KAT: run_tool(posit --golden) declared hash == frozen
    rec = do_run_tool({"tool": "posit", "params": {"golden": True}}, store=False, run_id="selftest-chain")
    frozen = read_first_token(os.path.join(GOLDENS_DIR, "posit", "declared.hash"))
    _chk("I-12 chain: run_tool(posit,golden) declared blake2b == frozen golden",
         rec["exit_class"] == "pass" and frozen is not None and rec["declared_blake2b"] == frozen, fails)
    # 11. argv builder unit KATs
    ent = {"name": "posit", "lang": "python", "artifact": os.path.join(TOOLS_DIR, "posit", "posit.py")}
    a = build_argv(ent, {"golden": True})
    b = build_argv(ent, {"tie-band": 0.5})
    c = build_argv(ent, {"R": 3})                       # uppercase flags exist (ratchet --R, someone --N)
    try:
        build_argv(ent, {"BAD KEY": 1}); ok11 = False
    except ToolError:
        ok11 = (a[-1] == "--golden" and b[-3:] == ["--tie-band", "0.5", "--json"]
                and c[-3:] == ["--R", "3", "--json"])
    _chk("argv builder: bool flag, valued flag, uppercase flag, bad key rejected", ok11, fails)
    # 12. run store round-trip
    rec2 = do_run_tool({"tool": "posit", "params": {"golden": True}}, store=True)
    got = do_get_run({"run_id": rec2["run_id"]})
    _chk("run store round-trip (run_tool -> get_run)", got["declared_blake2b"] == rec2["declared_blake2b"], fails)
    # 13. determinism: chain-check declared built twice, byte-identical
    d1 = declared_object(0, *chain_check()[:4])
    d2 = declared_object(0, *chain_check()[:4])
    _chk("declared object identical across two chain checks", d1 == d2, fails)
    ok = len(fails) == 0
    sys.stderr.write("SELFTEST PASS\n" if ok else f"SELFTEST FAIL ({len(fails)})\n")
    return 0 if ok else 1

# ------------------------------------------------------------------ CLI
def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--serve", action="store_true")
    ap.add_argument("--once")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--golden", action="store_true")
    try:
        args = ap.parse_args()
    except SystemExit:
        return 2
    if args.seed < 0:
        sys.stderr.write("error: --seed must be >= 0\n"); return 2
    modes = sum(1 for m in (args.serve, args.once is not None, args.json, args.selftest, args.golden) if m)
    if modes != 1:
        sys.stderr.write("error: exactly one of --serve | --once | --json | --selftest | --golden\n"); return 2
    if args.selftest: return run_selftest()
    if args.golden:   return run_golden()
    if args.serve:    return serve()
    if args.once is not None:
        try:
            req = json.loads(args.once)
        except json.JSONDecodeError as e:
            sys.stderr.write(f"error: --once is not valid JSON: {e}\n"); return 2
        resp = handle_request(req)
        if resp is not None:
            print(json.dumps(resp))
        return 0
    # --json: the chain check at golden params
    params, result, gates, verdict, code = chain_check()
    print(full_envelope(args.seed, params, result, gates, verdict))
    return code

if __name__ == "__main__":
    sys.exit(main())
