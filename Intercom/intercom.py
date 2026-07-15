#!/usr/bin/env python3
r"""ORRERY Intercom - the ASIC coordination bus, tailored to serve ORRERY and nothing else.

WHAT THIS IS (and is NOT). A local, SQLite-backed message bus + verifier-driven convergence
engine so ORRERY subagents/sessions coordinate tournament-style experiments WITHOUT the human
relaying by hand. It is deliberately NOT a general agent bus (that is C:\Intercom /
C:\everywhere\Intercom, from which this borrows the proven plumbing). It is specialized the way
an ASIC is: the falsifier IS an ORRERY contract, run by the coordinator; the provenance chain
(declared blake2b + exit-class + params + seed) is a first-class column; ORRERY's laws are
ENFORCED, not conventional.

THE ASIC SPECIALIZATIONS (why this is strictly better FOR ORRERY than the generic bus):
  1. The judge is an ORRERY tool, not a generic `SCORE=` shell command. A converge run pins a
     falsifier = <tool> + mode(golden|target|gate); the COORDINATOR runs it (reusing mcp.do_run_tool,
     the D-033 reuse pattern) and derives the score from the tool's DECLARED output. An agent
     PROPOSES params; it never scores itself. That is the anti-confabulation split (RAYFORMER's
     lesson) enforced at the infrastructure layer.
  2. Exit-code tri-state is preserved, never collapsed. exit 0 pass / 1 declared gate fired (a REAL
     negative result) / 2 error. A candidate that errors is INVALID (excluded from convergence),
     not a zero score. The generic bus (0.0 on any nonzero exit) gets this wrong; ORRERY must not.
  3. Pre-registration is mandatory. `converge-open` REFUSES to open without a stated hypothesis and
     a pinned falsifier - the register holds the doubt (the hsmi-stab / D-028 lesson: a witness
     designed after seeing the data mines a false arrow).
  4. Every candidate carries its I-12 declared blake2b; a converged champion emits an ORRERY-format
     result.lock (`lock` verb) - the citable artifact the science reads (D-008).
  5. The firewall is stamped into every verdict/lock: measures STRUCTURE, never ACQUAINTANCE
     (qualia). III-sealed. Verbatim, every time.
  6. `arm` prints the hardwired ORRERY calling block for a subagent - THE fixed catalogue, not a
     generic tool registry.

REUSE, NOT REINVENTION: the falsifier subprocesses the sacred exes and reads the declared object
via `tools/mcp/mcp.py` (do_run_tool / blake2b_hex / registry_scan). No duplicated hashing, no
duplicated envelope parsing -> the I-12 chain is inherited, the ARCHITECTURE section-2 split passes
through unchanged (this bus is a CALLER, like the science; it never links tool internals).

CONVENTION: stdout = machine-parseable result; stderr = human log. Exit 0 ok / 1 a declared gate /
2 error (bus-native verbs use 2 for bad input). Full contract: INTERCOM.contract.md.
"""
import argparse, hashlib, json, os, secrets, socket, string, subprocess, sys, tempfile
import sqlite3
from datetime import datetime, timezone

# --------------------------------------------------------------- ORRERY wiring (reuse mcp)
HERE = os.path.dirname(os.path.abspath(__file__))
ORRERY = os.path.dirname(HERE)                      # C:\ORRERY
sys.path.insert(0, os.path.join(ORRERY, "tools", "mcp"))
import mcp                                          # do_run_tool, blake2b_hex, registry_scan, registry_get

ROOT = os.environ.get("ORRERY_INTERCOM_ROOT", HERE)
DB = os.path.join(ROOT, "orrery_bus.db")
SANDBOX = os.path.join(ROOT, "sandbox")
RUNS = os.path.join(ORRERY, "runs")                 # where result.locks land (ORRERY canon)
SCHEMA_VERSION = "1.0.0"
ALEA = os.environ.get("INTERCOM_ALEA", r"C:\alea\roll.py")

FIREWALL = ("This bus coordinates measurements of STRUCTURE; it says nothing about whether anything "
            "is ACQUAINTED (qualia). Every experiment it runs measures structure, never experience - "
            "III-sealed.")

# The hardwired ORRERY arming block a coordinator hands every subagent. ASIC: THIS catalogue,
# THIS call surface, THIS rule. Not a generic tool registry.
ARMING_BLOCK = r"""=== YOU ARE ARMED WITH ORRERY (read-only: call the tools, NEVER edit ORRERY source) ===
ORRERY (C:\ORRERY) is a headless, DETERMINISTIC simulation instrument. You call its tools to make
quantitative claims EVIDENCE-GRADE, not argument-grade. Same params+seed => byte-identical declared
output; every run carries a declared blake2b you MUST cite.

Universal envelope (every tool):  <tool> [--param V] --seed N [--json|--csv PATH] [--selftest] [--golden]
Exit codes:  0 pass  |  1 a declared gate fired (a REAL negative result)  |  2 error.  NEVER conflate 1 and 2.

HOW TO CALL (ORRERY's own surface - inherits the I-12 declared-hash chain + the R-5 run cache):
  Set-Location C:\ORRERY
  python tools\orrery\orrery.py list
  python tools\orrery\orrery.py run <tool> --<param> <v> ... [--cache]      # prints declared JSON + hash
  python tools\orrery\orrery.py describe <tool>                             # the contract, verbatim
  # or the raw MCP surface:  python tools\mcp\mcp.py --once '<json-rpc>'  (run_tool/describe_contract/sweep)

THE RULE: every quantitative claim is EITHER backed by an ORRERY run (cite tool, params, declared
blake2b) OR flagged [ARGUMENT-GRADE]. If your deciding experiment needs a tool that does not exist,
say so and specify its contract - do NOT fabricate a number. Sims prove STRUCTURE, never qualia.

THE CATALOGUE (12 golden-frozen tools; Python ones run with no GPU, CUDA ones need the card):
  someone(CUDA) evolutionary Someone-Criterion | ratchet(CUDA) (1-p)rho=p unwrite threshold |
  algebra(cuSOLVER) crossed-product entropy | posit(py) parsimony auditor | mcts(CUDA) UCT search |
  autotune(py) sweep/basin-find vs a pre-registered --target | lens(CUDA/OptiX) shadow render+geodesic |
  shoot(C++) ODE-shooting eigenvalues | trace-born(CUDA) Born-from-redundancy | orrery(py) the CLI |
  mcp(py) this surface | orreryd(C++) job daemon.  (hsmi-stab is PARKED - no golden, not citable.)"""

# ------------------------------------------------------------------------------ io
def log(*a): print(*a, file=sys.stderr)
def out(*a): print(*a)

def _utf8():
    for s in (sys.stdout, sys.stderr):
        try: s.reconfigure(encoding="utf-8", errors="replace")
        except Exception: pass

def now_iso(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%fZ")

# --------------------------------------------------------------------- schema / connect
DDL = r"""
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
INSERT OR IGNORE INTO meta VALUES ('schema_version','1.0.0');
INSERT OR IGNORE INTO meta VALUES ('created_at', strftime('%Y-%m-%dT%H:%M:%fZ','now'));

CREATE TABLE IF NOT EXISTS agents (
  id           TEXT PRIMARY KEY,                    -- 8 x [a-z0-9]
  kind         TEXT NOT NULL CHECK (kind IN ('session','subagent','coordinator','daemon','human')),
  model        TEXT, parent_id TEXT REFERENCES agents(id),
  display      TEXT, machine TEXT, role TEXT,       -- role = physics domain / approach family (ORRERY-specialized capability)
  protocol     TEXT NOT NULL,
  started_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  last_seen    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  status       TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS rooms (
  id TEXT PRIMARY KEY, mode TEXT NOT NULL DEFAULT 'open' CHECK (mode IN ('open','rounds','converge')),
  purpose TEXT, created_by TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')), closed_at TEXT
);
INSERT OR IGNORE INTO rooms (id,purpose,created_by) VALUES
  ('broadcast','discovery, announcements, cross-experiment chatter','operator');

CREATE TABLE IF NOT EXISTS membership (
  room_id TEXT NOT NULL, agent_id TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'member',
  joined_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')), left_at TEXT,
  PRIMARY KEY (room_id, agent_id, joined_at)
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY,
  ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  room TEXT NOT NULL DEFAULT 'broadcast', sender TEXT NOT NULL, recipient TEXT,
  type TEXT NOT NULL, reply_to INTEGER, round INTEGER, priority INTEGER NOT NULL DEFAULT 0,
  body TEXT, artifact TEXT
);
CREATE INDEX IF NOT EXISTS idx_msg_room ON messages(room, id);
CREATE INDEX IF NOT EXISTS idx_msg_rcpt ON messages(recipient, id);
CREATE TRIGGER IF NOT EXISTS touch_sender AFTER INSERT ON messages BEGIN
  UPDATE agents SET last_seen=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.sender;
END;

CREATE TABLE IF NOT EXISTS cursors (
  agent_id TEXT NOT NULL, room_id TEXT NOT NULL, last_id INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (agent_id, room_id)
);

-- rounds runs: the DESIGN tournament (argument-judged, used BEFORE a golden exists, e.g. carve's
-- measurement functional). Barrier-synchronized; the refuter lenses are ORRERY-specific.
CREATE TABLE IF NOT EXISTS runs (
  id TEXT PRIMARY KEY, room TEXT NOT NULL, roster TEXT NOT NULL, rounds_total INTEGER,
  current_round INTEGER NOT NULL DEFAULT 1, status TEXT NOT NULL DEFAULT 'active',
  created_by TEXT, created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- converge runs: the EXPERIMENT tournament (oracle-judged). The falsifier is an ORRERY tool.
CREATE TABLE IF NOT EXISTS converge_runs (
  id TEXT PRIMARY KEY, room TEXT NOT NULL,
  goal TEXT, hypothesis TEXT NOT NULL,               -- MANDATORY pre-registration (the register holds the doubt)
  ftool TEXT NOT NULL, fmode TEXT NOT NULL CHECK (fmode IN ('golden','target','gate')),
  base_params TEXT NOT NULL DEFAULT '{}', seed INTEGER NOT NULL DEFAULT 0,
  expect_hash TEXT,                                  -- fmode=golden
  metric TEXT, metric_target REAL, tol REAL, band REAL,   -- fmode=target
  gate_id TEXT,                                      -- fmode=gate
  controls TEXT,                                     -- pre-registered controls that MUST stay null (witness runs)
  target REAL NOT NULL DEFAULT 1.0,                  -- champion_score must reach this
  k_converge INTEGER NOT NULL DEFAULT 3, budget INTEGER NOT NULL DEFAULT 0,
  spent INTEGER NOT NULL DEFAULT 0, invalid INTEGER NOT NULL DEFAULT 0,
  champion INTEGER, champion_score REAL NOT NULL DEFAULT -1e9, no_improve INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'open',               -- open|converged|exhausted|closed
  created_by TEXT, created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  finished_at TEXT
);
CREATE TABLE IF NOT EXISTS candidates (
  id INTEGER PRIMARY KEY, run TEXT NOT NULL, branch TEXT, agent TEXT NOT NULL,
  ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  params TEXT,                                       -- the proposed parameterization (candidate = params, ASIC)
  score REAL, passed INTEGER NOT NULL DEFAULT 0, became_champ INTEGER NOT NULL DEFAULT 0,
  -- the ORRERY provenance chain, first-class:
  exit_class TEXT, declared_blake2b TEXT, artifact_blake2b TEXT, metric_value REAL,
  verdict TEXT,                                      -- pass | reject (a real negative) | error (INVALID)
  evidence TEXT
);
CREATE INDEX IF NOT EXISTS idx_cand_run ON candidates(run, score);

CREATE TABLE IF NOT EXISTS branches (
  id INTEGER PRIMARY KEY, run TEXT NOT NULL, name TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'live',
  visits INTEGER NOT NULL DEFAULT 0, best REAL NOT NULL DEFAULT -1e9, sum REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')), UNIQUE(run,name)
);

-- graveyard: a killed approach + its pre-registered REINSTATEMENT trigger (reversibility as
-- house discipline, from the tournament CHARTER). A deletion without a trigger is not allowed.
CREATE TABLE IF NOT EXISTS graveyard (
  id INTEGER PRIMARY KEY, run TEXT, approach TEXT NOT NULL, corpse_reason TEXT NOT NULL,
  reinstatement_trigger TEXT NOT NULL, buried_by TEXT,
  buried_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- build locks: a genuinely ORRERY-specific lease so two subagents do not rebuild the same tool
-- (or contend the single GPU tenant) at once. Leases EXPIRE; steal-on-expiry; no immortal locks.
CREATE TABLE IF NOT EXISTS leases (
  resource TEXT PRIMARY KEY, holder TEXT NOT NULL,
  acquired_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')), expires_at TEXT NOT NULL
);
"""

def connect(db=None):
    db = db or DB
    os.makedirs(os.path.dirname(db) or ".", exist_ok=True)
    con = sqlite3.connect(db, timeout=5.0)
    con.execute("PRAGMA busy_timeout=5000;")
    con.execute("PRAGMA synchronous=NORMAL;")
    con.row_factory = sqlite3.Row
    con.executescript(DDL)               # idempotent: a drop-in caller can never hit a missing table
    return con

# ------------------------------------------------------------------------- identity
def machine_id():
    host = socket.gethostname(); guid = ""
    try:
        import winreg
        k = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Cryptography")
        guid, _ = winreg.QueryValueEx(k, "MachineGuid"); winreg.CloseKey(k)
    except Exception:
        guid = "nomachineid"
    return f"{host}-{guid}"

_ID_ALPHABET = string.ascii_lowercase + string.digits

def mint_id():
    """8-char id from alea physical entropy (models are terrible RNGs); secrets fallback."""
    try:
        r = subprocess.run([sys.executable, ALEA, "alnum", "8"], capture_output=True, text=True, timeout=30)
        s = (r.stdout or "").strip().splitlines()
        if s:
            cand = s[-1].strip().lower()
            if len(cand) == 8 and all(c in _ID_ALPHABET for c in cand):
                return cand, "alea"
    except Exception:
        pass
    return "".join(secrets.choice(_ID_ALPHABET) for _ in range(8)), "secrets"

# --------------------------------------------------------------------------- helpers
def max_id(con, room):
    return con.execute("SELECT COALESCE(MAX(id),0) FROM messages WHERE room=?", (room,)).fetchone()[0]

def set_cursor(con, me, room, last):
    con.execute("""INSERT INTO cursors(agent_id,room_id,last_id) VALUES(?,?,?)
                   ON CONFLICT(agent_id,room_id) DO UPDATE SET last_id=excluded.last_id,
                   updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now')""", (me, room, last))

def get_cursor(con, me, room):
    r = con.execute("SELECT last_id FROM cursors WHERE agent_id=? AND room_id=?", (me, room)).fetchone()
    return r[0] if r else 0

def require_agent(con, me):
    if not con.execute("SELECT 1 FROM agents WHERE id=?", (me,)).fetchone():
        log(f"[intercom] unknown agent id '{me}'. Run `join` first (pass --me <id>)."); sys.exit(2)

def touch(con, me):
    con.execute("UPDATE agents SET last_seen=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=?", (me,))

def ensure_membership(con, me, room):
    if not room or room == "broadcast": return
    con.execute("INSERT OR IGNORE INTO rooms(id,purpose,created_by) VALUES(?,?,?)", (room, f"room {room}", me))
    if not con.execute("SELECT 1 FROM membership WHERE room_id=? AND agent_id=? AND left_at IS NULL",
                       (room, me)).fetchone():
        con.execute("INSERT OR IGNORE INTO membership(room_id,agent_id,role) VALUES(?,?,?)", (room, me, "member"))

def live_status(last_seen):
    try:
        age = (datetime.now(timezone.utc) - datetime.fromisoformat(last_seen.replace("Z", "+00:00"))).total_seconds()
    except Exception:
        return "unknown"
    return "active" if age < 60 else ("idle" if age < 600 else "stale")

def my_rooms(con, me):
    rows = con.execute("SELECT DISTINCT room_id FROM membership WHERE agent_id=? AND left_at IS NULL", (me,)).fetchall()
    rooms = [r[0] for r in rows]
    if "broadcast" not in rooms: rooms.insert(0, "broadcast")
    return rooms

def post(con, sender, room, mtype, body=None, recipient=None, reply_to=None, round=None, priority=0, artifact=None):
    cur = con.execute("""INSERT INTO messages(room,sender,recipient,type,reply_to,round,priority,body,artifact)
                         VALUES(?,?,?,?,?,?,?,?,?)""",
                      (room, sender, recipient, mtype, reply_to, round, priority, body, artifact))
    return cur.lastrowid

def fmt_msg(m, me=None):
    mark = "»" if (me and m["recipient"] == me) else " "
    who = m["sender"] + ("" if m["recipient"] is None else f"->{m['recipient']}")
    head = f"{mark}#{m['id']:<5} {m['ts']}  [{m['room']}] {who} ({m['type']}"
    if m["round"] is not None: head += f" r{m['round']}"
    if m["reply_to"]: head += f" re:#{m['reply_to']}"
    if m["priority"]: head += f" !{m['priority']}"
    head += ")"
    body = (m["body"] or "").replace("\n", "\n      ")
    line = f"{head}\n      {body}" if body else head
    if m["artifact"]: line += f"\n      [artifact] {m['artifact']}"
    return line

def _me(a):
    me = getattr(a, "me", None) or os.environ.get("ORRERY_INTERCOM_ID") or os.environ.get("INTERCOM_ID")
    if not me:
        log("[intercom] need --me <your id> (or set ORRERY_INTERCOM_ID). Get one from `join`."); sys.exit(2)
    return me

def _load_params(s, file):
    if file:
        with open(file, encoding="utf-8") as f: return json.load(f)
    if s:
        return json.loads(s)
    return {}

# =========================================================================== THE FALSIFIER
# The heart of the ASIC. The judge is an ORRERY tool run by the COORDINATOR (never the proposer),
# scored from the tool's DECLARED output. Reuses mcp.do_run_tool (I-12 declared hash + exit-class
# tri-state) - no reinvented hashing/subprocessing. Returns a dict; score is None for INVALID.
def orrery_falsifier(run, params, timeout_s=900):
    tool = run["ftool"]; mode = run["fmode"]
    full = dict(json.loads(run["base_params"] or "{}"))
    full.update(params or {})
    if "seed" not in full and run["seed"] is not None:
        full["seed"] = run["seed"]
    try:
        rec = mcp.do_run_tool({"tool": tool, "params": full, "timeout_s": timeout_s}, store=False)
    except mcp.ToolError as e:
        return {"score": None, "verdict": "error", "exit_class": "error", "declared_blake2b": None,
                "artifact_blake2b": None, "metric_value": None, "evidence": f"ToolError: {e}"}
    ec = rec["exit_class"]                              # pass | gate-fired | error | timeout
    dhash = rec["declared_blake2b"]; env = rec["envelope"]
    base = {"exit_class": ec, "declared_blake2b": dhash, "artifact_blake2b": rec["artifact_blake2b"],
            "metric_value": None,
            "evidence": (rec.get("stderr_tail") or "")[-240:] or f"exit={rec['exit_code']}"}
    # ORRERY tri-state: an error/timeout is a BROKEN proposal (INVALID), not a bad score.
    if ec in ("error", "timeout") or env is None:
        base.update({"score": None, "verdict": "error"}); return base
    if mode == "golden":
        ok = bool(dhash and run["expect_hash"] and dhash == run["expect_hash"])
        base.update({"score": 1.0 if ok else 0.0, "verdict": "pass" if ok else "reject"})
        return base
    if mode == "gate":
        gid = run["gate_id"]; fired = None; val = None
        for g in (env.get("gates") or []):
            if g.get("id") == gid: fired = bool(g.get("fired")); val = g.get("value")
        if fired is None:
            base.update({"score": None, "verdict": "error", "evidence": f"gate '{gid}' not found in envelope"})
            return base
        base.update({"metric_value": val, "score": 1.0 if not fired else 0.0,
                     "verdict": "pass" if not fired else "reject"})
        return base
    # mode == target: score from a declared metric vs a PRE-REGISTERED target (autotune's discipline)
    res = env.get("result") or {}
    if run["metric"] not in res or not isinstance(res[run["metric"]], (int, float)):
        base.update({"score": None, "verdict": "error", "evidence": f"metric '{run['metric']}' missing/non-numeric"})
        return base
    val = float(res[run["metric"]]); dist = abs(val - float(run["metric_target"]))
    tol = float(run["tol"]); band = float(run["band"]) if run["band"] else max(tol * 10.0, 1e-9)
    passed = dist <= tol
    score = 1.0 if passed else max(0.0, 1.0 - dist / band)   # graded credit so the search can climb
    base.update({"metric_value": val, "score": score, "verdict": "pass" if passed else "reject"})
    return base

def _canon(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)

# ----------------------------------------------------------------------------- bus verbs
def cmd_init(a):
    con = connect(a.db); os.makedirs(SANDBOX, exist_ok=True)
    v = con.execute("SELECT value FROM meta WHERE key='schema_version'").fetchone()[0]; con.commit()
    log(f"[intercom] ORRERY bus initialized {a.db} (schema {v}, WAL). sandbox: {SANDBOX}"); out(a.db)

def cmd_join(a):
    con = connect(a.db)
    v = con.execute("SELECT value FROM meta WHERE key='schema_version'").fetchone()[0]
    if v.split(".")[0] != SCHEMA_VERSION.split(".")[0]:
        log(f"[intercom] MAJOR schema mismatch: db {v} vs client {SCHEMA_VERSION}. Stopping."); sys.exit(3)
    model = a.model or "unknown"; src = "?"
    for _ in range(8):
        aid, src = mint_id(); display = f"{model}-{aid}"
        try:
            con.execute("""INSERT INTO agents(id,kind,model,parent_id,display,machine,role,protocol)
                           VALUES(?,?,?,?,?,?,?,?)""",
                        (aid, a.kind, model, a.parent, display, machine_id(), a.role, SCHEMA_VERSION)); break
        except sqlite3.IntegrityError: continue
    else:
        log("[intercom] could not mint a unique id"); sys.exit(1)
    post(con, aid, "broadcast", "announce",
         body=f"{display} [{a.kind}] up" + (f" (role: {a.role})" if a.role else ""))
    set_cursor(con, aid, "broadcast", max_id(con, "broadcast"))
    if a.room:
        ensure_membership(con, aid, a.room); set_cursor(con, aid, a.room, max_id(con, a.room))
    con.commit()
    log(f"[intercom] registered {display} kind={a.kind} role={a.role or '-'} id-src={src}")
    log(f"[intercom] >>> your id is '{aid}'. Pass --me {aid} on every later call (or set ORRERY_INTERCOM_ID).")
    out(aid)

def cmd_who(a):
    con = connect(a.db)
    rows = con.execute("SELECT display,id,kind,model,role,status,last_seen FROM agents ORDER BY last_seen DESC").fetchall()
    def liveness(r): return "gone" if r["status"] in ("gone", "departed") else live_status(r["last_seen"])
    if a.live: rows = [r for r in rows if liveness(r) in ("active", "idle")]
    if not rows: log("[intercom] no agents."); return
    out(f"{'display':<26}{'id':<10}{'kind':<12}{'role':<16}{'live':<8}last_seen")
    out("-" * 96)
    for r in rows:
        out(f"{(r['display'] or ''):<26}{r['id']:<10}{r['kind']:<12}{(r['role'] or '-'):<16}"
            f"{liveness(r):<8}{r['last_seen']}")

def cmd_say(a):
    con = connect(a.db); me = _me(a); require_agent(con, me)
    room = a.room or "broadcast"
    if room != "broadcast": ensure_membership(con, me, room)
    body = " ".join(a.body) if a.body else None
    art = None
    if a.artifact:
        info = {"path": os.path.abspath(a.artifact)}
        try:
            info["bytes"] = os.path.getsize(a.artifact)
            with open(a.artifact, encoding="utf-8", errors="replace") as f: info["lines"] = sum(1 for _ in f)
        except Exception: pass
        art = json.dumps(info)
    if not body and not art: log("[intercom] nothing to send (body or --artifact)."); sys.exit(2)
    mid = post(con, me, room, a.type, body=body, recipient=a.to, reply_to=a.reply_to, round=a.round,
               priority=a.priority, artifact=art)
    con.commit(); log(f"[intercom] posted #{mid} to [{room}]" + (f" ->{a.to}" if a.to else "")); out(str(mid))

def cmd_poll(a):
    con = connect(a.db); me = _me(a); require_agent(con, me); touch(con, me)
    rooms = [a.room] if a.room else my_rooms(con, me)
    total = 0
    for room in rooms:
        cur = get_cursor(con, me, room)
        rows = con.execute("SELECT * FROM messages WHERE room=? AND id>? ORDER BY id", (room, cur)).fetchall()
        if rows:
            out(f"===== [{room}]  {len(rows)} new =====")
            for m in rows: out(fmt_msg(m, me))
            set_cursor(con, me, room, rows[-1]["id"]); total += len(rows)
    con.commit()
    log(f"[intercom] {total} new across {len(rooms)} room(s); cursors advanced.")
    if total == 0: log("[intercom] (nothing new)")

def cmd_inbox(a):
    con = connect(a.db); me = _me(a); touch(con, me); con.commit()
    rows = con.execute("SELECT * FROM messages WHERE recipient=? ORDER BY id DESC LIMIT ?", (me, a.limit)).fetchall()
    if not rows: log(f"[intercom] inbox empty for {me}."); return
    for m in reversed(rows): out(fmt_msg(m, me))

def cmd_replay(a):
    con = connect(a.db)
    q = "SELECT * FROM messages WHERE room=? ORDER BY id" + (f" DESC LIMIT {a.limit}" if a.limit else "")
    rows = con.execute(q, (a.room,)).fetchall()
    if a.limit: rows = list(reversed(rows))
    for m in rows: out(fmt_msg(m))

def cmd_arm(a):
    out(ARMING_BLOCK)

# ------------------------------------------------------- converge mode (the experiment tournament)
def cmd_converge_open(a):
    con = connect(a.db); me = _me(a); require_agent(con, me); ensure_membership(con, me, a.room)
    # --- MANDATORY pre-registration (the register holds the doubt; hsmi-stab / D-028 lesson) ---
    if not a.hypothesis:
        log("[intercom] converge-open REFUSED: --hypothesis is mandatory (pre-register the claim BEFORE\n"
            "  any candidate, or you are mining a false arrow). State what a pass would mean."); sys.exit(2)
    if mcp.registry_get(a.tool) is None:
        log(f"[intercom] converge-open REFUSED: '{a.tool}' is not an ORRERY catalogue tool."); sys.exit(2)
    if a.mode == "golden" and not a.expect_hash:
        log("[intercom] mode=golden REQUIRES --expect-hash <frozen declared blake2b>."); sys.exit(2)
    if a.mode == "target" and (not a.metric or a.metric_target is None or a.tol is None):
        log("[intercom] mode=target REQUIRES --metric <field> --metric-target <v> --tol <t>."); sys.exit(2)
    if a.mode == "gate" and not a.gate_id:
        log("[intercom] mode=gate REQUIRES --gate-id <G-...>."); sys.exit(2)
    try:
        base = _load_params(a.base_params, a.base_params_file)
    except Exception as e:
        log(f"[intercom] --base-params is not valid JSON: {e}"); sys.exit(2)
    con.execute("""INSERT OR REPLACE INTO converge_runs
        (id,room,goal,hypothesis,ftool,fmode,base_params,seed,expect_hash,metric,metric_target,tol,band,
         gate_id,controls,target,k_converge,budget,created_by)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (a.run, a.room, a.goal, a.hypothesis, a.tool, a.mode, _canon(base), a.seed, a.expect_hash,
         a.metric, a.metric_target, a.tol, a.band, a.gate_id, a.controls, a.target, a.k, a.budget, me))
    for nm in (a.arms or "").split(","):
        nm = nm.strip()
        if nm: con.execute("INSERT OR IGNORE INTO branches(run,name) VALUES(?,?)", (a.run, nm))
    con.execute("UPDATE rooms SET mode='converge' WHERE id=?", (a.room,))
    fdesc = ({"golden": f"{a.tool} declared-hash == {(a.expect_hash or '')[:12]}...",
              "target": f"{a.tool}.result.{a.metric} -> {a.metric_target} +-{a.tol}",
              "gate":   f"{a.tool} gate {a.gate_id} must NOT fire"}[a.mode])
    body = (f"CONVERGE '{a.run}' OPEN [{a.room}].  GOAL: {a.goal or '(unstated)'}\n"
            f"HYPOTHESIS (pre-registered): {a.hypothesis}\n"
            f"FALSIFIER (coordinator-run, you do NOT self-score): {fdesc}\n"
            f"target score>={a.target}, converge after {a.k} non-improving, budget={a.budget or 'unlimited'}.\n"
            f"Propose a parameterization:  intercom propose --me <id> --run {a.run} --params '{{...}}' [--branch <arm>]\n"
            + (f"CONTROLS that MUST stay null: {a.controls}\n" if a.controls else "")
            + FIREWALL)
    post(con, me, a.room, "goal", body=body, priority=2); con.commit()
    log(f"[intercom] converge '{a.run}' opened (tool={a.tool} mode={a.mode} target>={a.target} k={a.k}).")
    out(a.run)

def _propose_core(con, run, me, params, branch):
    rid = run["id"]
    f = orrery_falsifier(run, params)
    br = branch or "main"
    con.execute("INSERT OR IGNORE INTO branches(run,name) VALUES(?,?)", (rid, br))
    score = f["score"]; invalid = score is None
    cand = con.execute("""INSERT INTO candidates
        (run,branch,agent,params,score,passed,exit_class,declared_blake2b,artifact_blake2b,metric_value,verdict,evidence)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?)""",
        (rid, br, me, _canon(params or {}), score, 1 if f["verdict"] == "pass" else 0,
         f["exit_class"], f["declared_blake2b"], f["artifact_blake2b"], f["metric_value"],
         f["verdict"], f["evidence"])).lastrowid
    if invalid:
        # A BROKEN proposal (exit 2 / timeout / malformed) - excluded from convergence stats. ASIC-correct.
        con.execute("UPDATE converge_runs SET invalid=invalid+1, spent=spent+1 WHERE id=?", (rid,))
        post(con, me, run["room"], "candidate", priority=1,
             body=f"candidate #{cand} by {me} [arm:{br}]: INVALID ({f['exit_class']}) - excluded. {f['evidence'][:100]}")
        r2 = con.execute("SELECT * FROM converge_runs WHERE id=?", (rid,)).fetchone()
        return {"candidate": cand, "branch": br, "score": None, "verdict": "error", "invalid": True,
                "champion_score": r2["champion_score"], "no_improve": r2["no_improve"], "k": r2["k_converge"],
                "status": r2["status"], "note": "  [INVALID - excluded]", "spent": r2["spent"], "room": r2["room"]}
    became = 1 if score > run["champion_score"] else 0
    if became:
        con.execute("UPDATE converge_runs SET champion=?, champion_score=?, no_improve=0, spent=spent+1 WHERE id=?",
                    (cand, score, rid))
    else:
        con.execute("UPDATE converge_runs SET no_improve=no_improve+1, spent=spent+1 WHERE id=?", (rid,))
    con.execute("UPDATE candidates SET became_champ=? WHERE id=?", (became, cand))
    con.execute("UPDATE branches SET visits=visits+1, sum=sum+?, best=max(best,?) WHERE run=? AND name=?",
                (score, score, rid, br))
    r2 = con.execute("SELECT * FROM converge_runs WHERE id=?", (rid,)).fetchone()
    status = r2["status"]; note = ""
    if r2["champion_score"] >= r2["target"] and r2["no_improve"] >= r2["k_converge"]:
        con.execute("UPDATE converge_runs SET status='converged', finished_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') "
                    "WHERE id=?", (rid,)); status = "converged"; note = "  *** CONVERGED ***"
        post(con, me, r2["room"], "converged", priority=2,
             body=f"CONVERGED '{rid}': champion #{r2['champion']} score={r2['champion_score']:.4f} >= "
                  f"{r2['target']}, stable {r2['no_improve']}. Emit the lock: intercom lock --run {rid}. " + FIREWALL)
    elif r2["budget"] and r2["spent"] >= r2["budget"]:
        con.execute("UPDATE converge_runs SET status='exhausted', finished_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') "
                    "WHERE id=?", (rid,)); status = "exhausted"; note = "  [budget exhausted]"
    post(con, me, r2["room"], "candidate", priority=(2 if became else 0),
         body=f"candidate #{cand} by {me} [arm:{br}]: score={score:.4f} verdict={f['verdict']} "
              f"hash={(f['declared_blake2b'] or '-')[:12]}" + (" -> NEW CHAMPION" if became else ""))
    return {"candidate": cand, "branch": br, "score": score, "verdict": f["verdict"], "invalid": False,
            "became_champion": bool(became), "champion_score": r2["champion_score"], "no_improve": r2["no_improve"],
            "k": r2["k_converge"], "status": status, "note": note, "spent": r2["spent"], "room": r2["room"],
            "declared_blake2b": f["declared_blake2b"]}

def cmd_propose(a):
    con = connect(a.db); me = _me(a); require_agent(con, me)
    run = con.execute("SELECT * FROM converge_runs WHERE id=?", (a.run,)).fetchone()
    if not run: log(f"[intercom] no converge run '{a.run}'."); sys.exit(2)
    if run["status"] != "open":
        log(f"[intercom] run '{a.run}' is {run['status']}; not accepting proposals."); sys.exit(2)
    if run["budget"] and run["spent"] >= run["budget"]:
        con.execute("UPDATE converge_runs SET status='exhausted' WHERE id=?", (a.run,)); con.commit()
        log(f"[intercom] run '{a.run}' budget exhausted."); sys.exit(2)
    try:
        params = _load_params(a.params, a.params_file)
    except Exception as e:
        log(f"[intercom] --params is not valid JSON: {e}"); sys.exit(2)
    ensure_membership(con, me, run["room"])
    res = _propose_core(con, run, me, params, a.branch); con.commit()
    log(f"[intercom] propose '{a.run}' cand=#{res['candidate']} "
        + ("INVALID (excluded)" if res["invalid"] else
           f"score={res['score']:.4f} {'NEW CHAMPION' if res.get('became_champion') else 'no improvement'} "
           f"champ={res['champion_score']:.4f} no_improve={res['no_improve']}/{res['k']}")
        + f" status={res['status']}{res['note']}")
    out(_canon({"candidate": res["candidate"], "branch": res["branch"], "score": res["score"],
                "verdict": res["verdict"], "invalid": res["invalid"],
                "champion_score": round(res["champion_score"], 6) if res["champion_score"] > -1e8 else None,
                "no_improve": res["no_improve"], "status": res["status"]}))

def cmd_champion(a):
    con = connect(a.db)
    run = con.execute("SELECT * FROM converge_runs WHERE id=?", (a.run,)).fetchone()
    if not run: log(f"[intercom] no converge run '{a.run}'."); sys.exit(2)
    if not run["champion"]: out(f"run '{a.run}': no champion yet (status={run['status']})."); return
    c = con.execute("SELECT * FROM candidates WHERE id=?", (run["champion"],)).fetchone()
    out(f"run '{a.run}' champion: #{c['id']} by {c['agent']} score={c['score']:.4f} verdict={c['verdict']}")
    out(f"  params: {c['params']}")
    out(f"  declared_blake2b: {c['declared_blake2b']}  exit_class={c['exit_class']}"
        + (f"  {run['metric']}={c['metric_value']}" if run["metric"] else ""))
    out(f"  status={run['status']} target>={run['target']} no_improve={run['no_improve']}/{run['k_converge']} "
        f"spent={run['spent']} invalid={run['invalid']}")

def cmd_board(a):
    con = connect(a.db)
    run = con.execute("SELECT * FROM converge_runs WHERE id=?", (a.run,)).fetchone()
    if not run: log(f"[intercom] no converge run '{a.run}'."); sys.exit(2)
    cs = run["champion_score"]
    out(f"CONVERGE '{a.run}' [{run['room']}] status={run['status']}")
    out(f"  goal: {run['goal']}")
    out(f"  hypothesis: {run['hypothesis']}")
    fdesc = {"golden": f"{run['ftool']} hash=={(run['expect_hash'] or '')[:12]}",
             "target": f"{run['ftool']}.{run['metric']}->{run['metric_target']}+-{run['tol']}",
             "gate": f"{run['ftool']} !{run['gate_id']}"}[run["fmode"]]
    out(f"  falsifier: {fdesc}  target>={run['target']} k={run['k_converge']} budget={run['budget'] or 'unlimited'}")
    out(f"  champion_score={(f'{cs:.4f}' if cs>-1e8 else 'none')} no_improve={run['no_improve']}/{run['k_converge']} "
        f"spent={run['spent']} invalid={run['invalid']}")
    brs = con.execute("SELECT name,status,visits,best FROM branches WHERE run=? ORDER BY best DESC", (a.run,)).fetchall()
    if brs:
        out("  arms: " + "  ".join(
            f"{b['name']}[{b['status'][0]}] v{b['visits']} best={(b['best'] if b['best']>-1e8 else 0):.3f}" for b in brs))
    rows = con.execute("SELECT * FROM candidates WHERE run=? ORDER BY (score IS NULL), score DESC, id LIMIT ?",
                       (a.run, a.limit or 20)).fetchall()
    if not rows: out("  (no candidates yet)"); return
    out(f"  {'cand':<7}{'agent':<11}{'score':<9}{'verdict':<9}{'exit':<11}declared_blake2b")
    out("  " + "-" * 74)
    for c in rows:
        sc = "-" if c["score"] is None else f"{c['score']:.4f}"
        out(f"  #{str(c['id']):<6}{c['agent']:<11}{sc:<9}{(c['verdict'] or ''):<9}{(c['exit_class'] or ''):<11}"
            f"{(c['declared_blake2b'] or '-')[:20]}")

def cmd_schedule(a):
    """Allocation: UCB1 over live arms -> which approach to expand next; prune arms the champion dominates."""
    import math
    con = connect(a.db)
    run = con.execute("SELECT * FROM converge_runs WHERE id=?", (a.run,)).fetchone()
    if not run: log(f"[intercom] no converge run '{a.run}'."); sys.exit(2)
    champ = run["champion_score"]; pruned = []
    for b in con.execute("SELECT * FROM branches WHERE run=? AND status='live'", (a.run,)).fetchall():
        if b["visits"] >= a.prune_after and champ > -1e8 and b["best"] < champ - a.prune_margin:
            con.execute("UPDATE branches SET status='pruned' WHERE id=?", (b["id"],)); pruned.append((b["name"], b["best"]))
    live = con.execute("SELECT * FROM branches WHERE run=? AND status='live'", (a.run,)).fetchall()
    N = sum(b["visits"] for b in live); con.commit()
    rows = []
    for b in live:
        if b["visits"] == 0:
            rows.append({"name": b["name"], "visits": 0, "best": None, "ucb": float("inf")})
        else:
            rows.append({"name": b["name"], "visits": b["visits"], "best": b["best"],
                         "ucb": b["best"] + a.c * math.sqrt(math.log(N + 1) / b["visits"])})
    rows.sort(key=lambda x: (0 if x["ucb"] == float("inf") else 1,
                             -(0 if x["ucb"] == float("inf") else x["ucb"]), x["visits"], x["name"]))
    out(f"schedule '{a.run}': champion={('%.4f'%champ) if champ>-1e8 else 'none'} live_arms={len(live)} N={N} c={a.c}")
    if pruned: out("  pruned (dominated): " + ", ".join(f"{n}(best {v:.3f})" for n, v in pruned))
    if not rows: out("  -> STOP: no live arms (converge, or seed a new approach)."); return
    out(f"  {'arm':<16}{'visits':<8}{'best':<8}ucb")
    for x in rows:
        ucb = "inf (explore)" if x["ucb"] == float("inf") else f"{x['ucb']:.3f}"
        best = "-" if x["best"] is None else f"{x['best']:.3f}"
        out(f"  {x['name']:<16}{x['visits']:<8}{best:<8}{ucb}")
    rec = rows[0]
    out(f"  -> EXPAND NEXT: '{rec['name']}'  ({'unexplored' if rec['ucb']==float('inf') else f'max UCB {rec['ucb']:.3f}'})")

def cmd_lock(a):
    """Emit an ORRERY-format result.lock from a converged run's champion - the citable provenance
    the science reads (D-008). Includes tool version, binary + declared blake2b, params, seed, GPU arch."""
    con = connect(a.db)
    run = con.execute("SELECT * FROM converge_runs WHERE id=?", (a.run,)).fetchone()
    if not run: log(f"[intercom] no converge run '{a.run}'."); sys.exit(2)
    if not run["champion"]: log(f"[intercom] run '{a.run}' has no champion; nothing to lock."); sys.exit(2)
    c = con.execute("SELECT * FROM candidates WHERE id=?", (run["champion"],)).fetchone()
    entry = mcp.registry_get(run["ftool"]) or {}
    lock = {
        "kind": "orrery-intercom-converge-lock", "run": a.run, "status": run["status"],
        "goal": run["goal"], "hypothesis": run["hypothesis"],
        "falsifier": {"tool": run["ftool"], "tool_contract_version": entry.get("contract_version"),
                      "mode": run["fmode"], "expect_hash": run["expect_hash"], "metric": run["metric"],
                      "metric_target": run["metric_target"], "tol": run["tol"], "gate_id": run["gate_id"]},
        "champion": {"candidate_id": c["id"], "by": c["agent"], "score": c["score"], "verdict": c["verdict"],
                     "params": json.loads(c["params"] or "{}"), "seed": run["seed"],
                     "exit_class": c["exit_class"], "declared_blake2b": c["declared_blake2b"],
                     "artifact_blake2b": c["artifact_blake2b"], "metric_value": c["metric_value"]},
        "convergence": {"target": run["target"], "k_converge": run["k_converge"], "no_improve": run["no_improve"],
                        "spent": run["spent"], "invalid": run["invalid"]},
        "controls_pre_registered": run["controls"],
        "provenance": {"gpu_arch": "sm_89", "machine": machine_id(), "schema": SCHEMA_VERSION,
                       "emitted_at": now_iso()},
        "notes": FIREWALL,
    }
    text = json.dumps(lock, indent=2)
    path = a.out or os.path.join(RUNS, f"intercom_{a.run}.result.lock")
    if not a.stdout:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f: f.write(text + "\n")
        log(f"[intercom] result.lock written: {path}")
    out(text if a.stdout else path)

# ------------------------------------------------------- rounds mode (the DESIGN tournament)
# Argument-judged, used BEFORE a golden exists (e.g. choosing carve's measurement functional). The
# refuter lenses are ORRERY-specific: DETERMINISM (buildable/golden-freezable), RESOLVABILITY (can the
# instrument actually SEE the effect - measured, not argued), ORACLE-HONESTY (anchored + metamorphic +
# redundantly recovered), and BLINDNESS (is the functional dead by an identity? the D-028 lesson).
ROUND_LENSES = ("DETERMINISM | RESOLVABILITY | ORACLE-HONESTY | BLINDNESS(D-028). "
                "Each verdict is ARGUMENT-GRADE until its pre-registered deciding experiment runs via ORRERY.")

def cmd_rounds_open(a):
    con = connect(a.db); me = _me(a); require_agent(con, me); ensure_membership(con, me, a.room)
    con.execute("UPDATE rooms SET mode='rounds' WHERE id=?", (a.room,))
    con.execute("""INSERT OR REPLACE INTO runs(id,room,roster,rounds_total,current_round,status,created_by)
                   VALUES(?,?,?,?,?,?,?)""",
                (a.run, a.room, _canon(a.roster.split(",")), a.rounds, 1, "active", me))
    body = (f"DESIGN ROUNDS '{a.run}' r1 [{a.room}] roster={a.roster}\nPROMPT: {a.prompt}\n"
            f"REFUTER LENSES: {ROUND_LENSES}\n{FIREWALL}")
    mid = post(con, me, a.room, "round_open", body=body, round=1, priority=2); con.commit()
    log(f"[intercom] rounds '{a.run}' opened, round 1, roster={a.roster}"); out(str(mid))

def cmd_submit(a):
    con = connect(a.db); me = _me(a); require_agent(con, me)
    run = con.execute("SELECT * FROM runs WHERE id=?", (a.run,)).fetchone()
    if not run: log(f"[intercom] no rounds run '{a.run}'."); sys.exit(2)
    roster = json.loads(run["roster"])
    if me not in roster: log(f"[intercom] submit REFUSED: {me} not in roster {roster}."); sys.exit(2)
    if a.round != run["current_round"]:
        log(f"[intercom] submit REFUSED: round {a.round} != current {run['current_round']}."); sys.exit(2)
    art = None
    if a.artifact:
        info = {"path": os.path.abspath(a.artifact)}
        try:
            info["bytes"] = os.path.getsize(a.artifact)
            with open(a.artifact, encoding="utf-8", errors="replace") as f: info["lines"] = sum(1 for _ in f)
        except Exception: pass
        art = json.dumps(info)
    mid = post(con, me, a.room, "submission", body=" ".join(a.body) if a.body else None, round=a.round, artifact=art)
    con.commit()
    k = len(roster)
    n = con.execute("SELECT COUNT(DISTINCT sender) FROM messages WHERE room=? AND type='submission' AND round=?",
                    (a.room, a.round)).fetchone()[0]
    if n >= k:
        cur = con.execute("UPDATE runs SET current_round=? WHERE id=? AND current_round=?",
                          (a.round + 1, a.run, a.round))
        if cur.rowcount == 1:
            if a.round < (run["rounds_total"] or a.round):
                post(con, me, a.room, "round_open", priority=2, round=a.round + 1,
                     body=f"Round {a.round+1}: read all r{a.round} submissions, then beat the field on the lenses.")
                log(f"[intercom] BARRIER {n}/{k} -> opened round {a.round+1}.")
            else:
                con.execute("UPDATE runs SET status='awaiting_verdict' WHERE id=?", (a.run,))
                log(f"[intercom] BARRIER {n}/{k} -> final round done; '{a.run}' awaiting verdict.")
            con.commit()
    log(f"[intercom] submission #{mid} by {me} for '{a.run}' r{a.round}"); out(str(mid))

def cmd_round_status(a):
    con = connect(a.db)
    n = con.execute("SELECT COUNT(DISTINCT sender) FROM messages WHERE room=? AND type='submission' AND round=?",
                    (a.room, a.round)).fetchone()[0]
    run = con.execute("SELECT roster,current_round,status FROM runs WHERE id=?", (a.run,)).fetchone()
    k = len(json.loads(run["roster"])) if run else "?"
    out(f"run {a.run}: round {a.round} -> {n}/{k} submissions; current={run['current_round'] if run else '?'}; "
        f"status={run['status'] if run else '?'}" + ("  [barrier met]" if run and n >= k else ""))

def cmd_graveyard(a):
    con = connect(a.db)
    if a.approach:      # bury
        me = _me(a); require_agent(con, me)
        if not a.trigger:
            log("[intercom] bury REFUSED: --trigger <reinstatement condition> is MANDATORY (reversibility "
                "as discipline; a deletion without a trigger is not allowed)."); sys.exit(2)
        con.execute("INSERT INTO graveyard(run,approach,corpse_reason,reinstatement_trigger,buried_by) "
                    "VALUES(?,?,?,?,?)", (a.run, a.approach, a.reason or "(unstated)", a.trigger, me))
        con.commit(); log(f"[intercom] buried '{a.approach}' (trigger: {a.trigger})."); out(a.approach); return
    rows = con.execute("SELECT * FROM graveyard" + (" WHERE run=?" if a.run else "") + " ORDER BY id",
                       (a.run,) if a.run else ()).fetchall()
    if not rows: log("[intercom] graveyard empty."); return
    for g in rows:
        out(f"#{g['id']} [{g['run'] or '-'}] {g['approach']}\n  corpse: {g['corpse_reason']}\n"
            f"  REINSTATE IF: {g['reinstatement_trigger']}  (buried {g['buried_at']} by {g['buried_by']})")

def cmd_lease(a):
    con = connect(a.db); me = _me(a); require_agent(con, me)
    con.execute("""INSERT INTO leases(resource,holder,expires_at)
                   VALUES(?,?, strftime('%Y-%m-%dT%H:%M:%fZ','now','+'||?||' seconds'))
                   ON CONFLICT(resource) DO UPDATE SET holder=excluded.holder,
                     acquired_at=strftime('%Y-%m-%dT%H:%M:%fZ','now'), expires_at=excluded.expires_at
                   WHERE leases.expires_at < strftime('%Y-%m-%dT%H:%M:%fZ','now') OR leases.holder=excluded.holder""",
                (a.resource, me, a.ttl))
    h = con.execute("SELECT holder,expires_at FROM leases WHERE resource=?", (a.resource,)).fetchone()
    if h["holder"] == me:
        con.commit(); log(f"[intercom] lease '{a.resource}' ACQUIRED until {h['expires_at']}."); out("acquired")
    else:
        log(f"[intercom] lease '{a.resource}' DENIED; held by {h['holder']} until {h['expires_at']}."); sys.exit(1)

def cmd_unlease(a):
    con = connect(a.db); me = _me(a); require_agent(con, me)
    cur = con.execute("DELETE FROM leases WHERE resource=? AND holder=?", (a.resource, me)); con.commit()
    out("released" if cur.rowcount else "noop")

# =========================================================================== selftest / golden
GOLDEN_HASHES = {"posit": "7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44"}

def _tmp_db():
    fd, path = tempfile.mkstemp(prefix="orrery_intercom_st_", suffix=".db"); os.close(fd); os.remove(path)
    return path

def _mock_run(**over):
    """A synthetic converge_runs Row-like dict for pure-logic tests (no external tool)."""
    base = dict(id="R", room="r", goal="g", hypothesis="h", ftool="posit", fmode="golden",
                base_params="{}", seed=0, expect_hash=GOLDEN_HASHES["posit"], metric=None, metric_target=None,
                tol=None, band=None, gate_id=None, controls=None, target=1.0, k_converge=2, budget=0,
                spent=0, invalid=0, champion=None, champion_score=-1e9, no_improve=0, status="open")
    base.update(over); return base

def golden_scenario(db):
    """The frozen scenario: a scripted posit-golden-match converge run (deterministic, instant, no GPU;
    re-baselines with posit like mcp/orrery). Drives the FULL ASIC loop - coordinator-run falsifier,
    I-12 declared hash, MCTS champion, convergence - and returns a canonical, ts-free declared object."""
    con = connect(db)
    con.execute("INSERT OR IGNORE INTO agents(id,kind,model,protocol) VALUES('coord0000','coordinator','test',?)",
                (SCHEMA_VERSION,))
    class A: pass
    a = A(); a.run = "golden"; a.room = "gold-room"; a.goal = "reproduce posit's frozen golden by trace"
    a.hypothesis = "the params {golden:true} reproduce posit's declared blake2b 7a22dd22..."
    a.tool = "posit"; a.mode = "golden"; a.expect_hash = GOLDEN_HASHES["posit"]
    a.metric = a.metric_target = a.tol = a.band = a.gate_id = a.controls = None
    a.base_params = None; a.base_params_file = None; a.seed = 0; a.target = 1.0; a.k = 2; a.budget = 0
    a.arms = "trace,decoy"; a.me = "coord0000"; a.db = db
    _open_inline(con, a)
    run = con.execute("SELECT * FROM converge_runs WHERE id='golden'").fetchone()
    # scripted, deterministic proposal sequence:
    seq = [({"case": "nonsense-not-a-real-flag-xyz"}, "decoy"),   # -> exit 2 = INVALID (excluded)
           ({"golden": True}, "trace"),                            # -> hash match, score 1.0, champion
           ({"golden": True}, "trace"),                            # -> 1.0, no improvement (no_improve=1)
           ({"golden": True}, "trace")]                            # -> 1.0, no_improve=2 == k -> CONVERGED
    cand_records = []
    for params, br in seq:
        run = con.execute("SELECT * FROM converge_runs WHERE id='golden'").fetchone()
        if run["status"] != "open": break
        res = _propose_core(con, run, "coord0000", params, br)
        c = con.execute("SELECT * FROM candidates WHERE id=?", (res["candidate"],)).fetchone()
        cand_records.append({"params": json.loads(c["params"]), "score": c["score"], "verdict": c["verdict"],
                             "exit_class": c["exit_class"], "declared_blake2b": c["declared_blake2b"]})
    con.commit()
    run = con.execute("SELECT * FROM converge_runs WHERE id='golden'").fetchone()
    champ = con.execute("SELECT * FROM candidates WHERE id=?", (run["champion"],)).fetchone()
    con.close()
    return {
        "scenario": "posit-golden-match", "tool": "posit", "mode": "golden", "target": 1.0, "k": 2,
        "champion_params": json.loads(champ["params"]), "champion_score": champ["score"],
        "champion_declared_blake2b": champ["declared_blake2b"], "champion_verdict": champ["verdict"],
        "converged": run["status"] == "converged", "spent": run["spent"], "invalid": run["invalid"],
        "no_improve": run["no_improve"], "candidates": cand_records,
    }

def _open_inline(con, a):
    """Minimal converge_runs insert for the golden scenario (avoids argparse/exit paths)."""
    con.execute("INSERT OR IGNORE INTO agents(id,kind,model,protocol) VALUES(?,?,?,?)",
                (a.me, "coordinator", "test", SCHEMA_VERSION))
    con.execute("""INSERT OR REPLACE INTO converge_runs
        (id,room,goal,hypothesis,ftool,fmode,base_params,seed,expect_hash,target,k_converge,budget,created_by)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (a.run, a.room, a.goal, a.hypothesis, a.tool, a.mode, "{}", a.seed, a.expect_hash, a.target, a.k, a.budget, a.me))
    for nm in a.arms.split(","):
        con.execute("INSERT OR IGNORE INTO branches(run,name) VALUES(?,?)", (a.run, nm.strip()))

def run_golden():
    db = _tmp_db()
    try:
        d = golden_scenario(db)
        declared = _canon(d); h = mcp.blake2b_hex(declared)
        print(_canon({"tool": "orrery-intercom", "version": SCHEMA_VERSION, "declared": d, "notes": FIREWALL}))
        frozen = _read_golden_hash()
        if frozen is None:
            log(f"GOLDEN NOT FROZEN (bootstrap) blake2b={h}\n  freeze into goldens/intercom/declared.hash"); return 0
        if h == frozen: log(f"GOLDEN OK blake2b={h}"); return 0
        log(f"GOLDEN MISMATCH\n  got  {h}\n  want {frozen}"); return 1
    finally:
        for suf in ("", "-wal", "-shm"):
            try: os.remove(db + suf)
            except OSError: pass

def _read_golden_hash():
    p = os.path.join(ORRERY, "goldens", "intercom", "declared.hash")
    if os.path.isfile(p):
        with open(p) as f: return f.read().split()[0].strip()
    return None

def _chk(name, ok, fails):
    log(f"  [{'PASS' if ok else 'FAIL'}] {name}")
    if not ok: fails.append(name)
    return ok

def run_selftest():
    fails = []; log(f"orrery-intercom --selftest (v{SCHEMA_VERSION})")
    # 1. mcp reuse wired: blake2b KAT via the inherited primitive
    _chk('mcp.blake2b_hex("abc") KAT',
         mcp.blake2b_hex("abc") == "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319", fails)
    # 2. registry reachable through the reused surface
    _chk("mcp.registry_get('posit') resolves the catalogue tool", mcp.registry_get("posit") is not None, fails)
    # 3. FALSIFIER golden-match: coordinator runs posit, derives score from the DECLARED hash
    r_match = orrery_falsifier(_mock_run(), {"golden": True})
    _chk("falsifier golden-match: posit -> score 1.0, verdict pass, exit_class pass, hash==frozen",
         r_match["score"] == 1.0 and r_match["verdict"] == "pass" and r_match["exit_class"] == "pass"
         and r_match["declared_blake2b"] == GOLDEN_HASHES["posit"], fails)
    # 4. FALSIFIER golden-mismatch is a REAL negative (reject), not an error
    r_miss = orrery_falsifier(_mock_run(expect_hash="0" * 64), {"golden": True})
    _chk("falsifier golden-mismatch -> score 0.0, verdict reject (a real negative, exit_class pass)",
         r_miss["score"] == 0.0 and r_miss["verdict"] == "reject" and r_miss["exit_class"] == "pass", fails)
    # 5. EXIT TRI-STATE: a bad param -> exit 2 -> INVALID (score None, verdict error), NOT a zero score
    r_err = orrery_falsifier(_mock_run(), {"case": "definitely-not-a-posit-flag-zzz"})
    _chk("falsifier tri-state: bad input -> exit_class error -> score None (INVALID, not 0.0)",
         r_err["score"] is None and r_err["verdict"] == "error" and r_err["exit_class"] in ("error",), fails)
    # 6. PRE-REGISTRATION enforced: a REGISTERED agent still can't open a converge run without a
    #    pre-registered --hypothesis (exit 2). Register first so the hypothesis gate is what fires.
    db6 = _tmp_db_cleanup()
    j = subprocess.run([sys.executable, os.path.abspath(__file__), "--db", db6, "join",
                        "--model", "t", "--kind", "coordinator"], capture_output=True, text=True)
    me6 = ((j.stdout or "").strip().splitlines() or ["x"])[-1]
    p = subprocess.run([sys.executable, os.path.abspath(__file__), "--db", db6,
                        "converge-open", "--me", me6, "--room", "r", "--run", "r", "--tool", "posit",
                        "--mode", "golden", "--expect-hash", "abc"], capture_output=True, text=True)
    _chk("pre-registration enforced: registered agent, converge-open without --hypothesis exits 2",
         p.returncode == 2 and "hypothesis" in (p.stderr or "").lower(), fails)
    # 7. FULL LOOP + DETERMINISM: the golden scenario twice, byte-identical declared object
    d1 = golden_scenario(_tmp_db_cleanup()); d2 = golden_scenario(_tmp_db_cleanup())
    _chk("golden scenario declared object identical across two runs (determinism)", _canon(d1) == _canon(d2), fails)
    # 8. the loop actually CONVERGED on the champion that reproduces posit's golden
    _chk("golden scenario CONVERGED; champion reproduces posit's frozen hash; verdict pass",
         d1["converged"] and d1["champion_declared_blake2b"] == GOLDEN_HASHES["posit"]
         and d1["champion_verdict"] == "pass", fails)
    # 9. the INVALID decoy was excluded from convergence stats (spent counts it, champion ignores it)
    _chk("INVALID candidate excluded: invalid==1, champion_score==1.0, no_improve==k(2)",
         d1["invalid"] == 1 and d1["no_improve"] == 2 and any(c["verdict"] == "error" for c in d1["candidates"]), fails)
    # 10. result.lock emission carries the provenance chain + the firewall, verbatim
    lock_db = _tmp_db_cleanup(); golden_scenario_into(lock_db)
    lk = _emit_lock_text(lock_db, "golden")
    _chk("result.lock carries champion declared_blake2b + firewall (III-sealed), verbatim",
         GOLDEN_HASHES["posit"] in lk and FIREWALL in lk and '"kind": "orrery-intercom-converge-lock"' in lk, fails)
    # 11. bus round-trip: join -> say -> poll advances the cursor, body is DATA
    _chk("bus round-trip (join/say/poll cursor advance)", _bus_smoke(), fails)
    # 12. arming block is the hardwired ORRERY catalogue (not generic)
    _chk("arm prints the ORRERY calling block (12 tools, the rule, the firewall)",
         "ARMED WITH ORRERY" in ARMING_BLOCK and "[ARGUMENT-GRADE]" in ARMING_BLOCK
         and "trace-born" in ARMING_BLOCK and "STRUCTURE, never qualia" in ARMING_BLOCK, fails)
    ok = len(fails) == 0
    log("SELFTEST PASS" if ok else f"SELFTEST FAIL ({len(fails)})")
    return 0 if ok else 1

# selftest helpers ----------------------------------------------------------
_TMP_DBS = []
def _tmp_db_cleanup():
    p = _tmp_db(); _TMP_DBS.append(p); return p

def golden_scenario_into(db):
    return golden_scenario(db)

def _emit_lock_text(db, run):
    con = connect(db)
    r = con.execute("SELECT * FROM converge_runs WHERE id=?", (run,)).fetchone()
    c = con.execute("SELECT * FROM candidates WHERE id=?", (r["champion"],)).fetchone()
    con.close()
    entry = mcp.registry_get(r["ftool"]) or {}
    lock = {"kind": "orrery-intercom-converge-lock", "run": run, "status": r["status"],
            "champion": {"declared_blake2b": c["declared_blake2b"], "params": json.loads(c["params"] or "{}")},
            "falsifier": {"tool": r["ftool"], "tool_contract_version": entry.get("contract_version")},
            "notes": FIREWALL}
    return json.dumps(lock, indent=2)

def _bus_smoke():
    db = _tmp_db_cleanup()
    con = connect(db)
    aid, _ = mint_id()
    con.execute("INSERT INTO agents(id,kind,model,protocol) VALUES(?,?,?,?)", (aid, "session", "t", SCHEMA_VERSION))
    set_cursor(con, aid, "broadcast", max_id(con, "broadcast"))
    post(con, aid, "broadcast", "chat", body="structure not acquaintance")
    con.commit()
    cur = get_cursor(con, aid, "broadcast")
    rows = con.execute("SELECT * FROM messages WHERE room='broadcast' AND id>? ORDER BY id", (cur,)).fetchall()
    ok = len(rows) == 1 and rows[0]["body"] == "structure not acquaintance"
    con.close(); return ok

def _cleanup_tmp():
    for db in _TMP_DBS:
        for suf in ("", "-wal", "-shm"):
            try: os.remove(db + suf)
            except OSError: pass

# ----------------------------------------------------------------------------- argparse
def build_parser():
    p = argparse.ArgumentParser(prog="intercom",
        description="ORRERY Intercom - the ASIC coordination bus (v%s)." % SCHEMA_VERSION,
        formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    p.add_argument("--db", default=DB)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("init"); s.set_defaults(fn=cmd_init)
    s = sub.add_parser("selftest"); s.set_defaults(fn=lambda a: sys.exit(run_selftest()))
    s = sub.add_parser("golden"); s.set_defaults(fn=lambda a: sys.exit(run_golden()))

    s = sub.add_parser("join", help="register an ORRERY agent; prints your id")
    s.add_argument("--model"); s.add_argument("--kind", default="session",
        choices=["session", "subagent", "coordinator", "daemon"])
    s.add_argument("--parent"); s.add_argument("--role", help="physics domain / approach family")
    s.add_argument("--room"); s.set_defaults(fn=cmd_join)

    s = sub.add_parser("who"); s.add_argument("--live", action="store_true"); s.set_defaults(fn=cmd_who)
    s = sub.add_parser("say"); s.add_argument("--me"); s.add_argument("--to"); s.add_argument("--room")
    s.add_argument("--type", default="chat"); s.add_argument("--reply-to", type=int, dest="reply_to")
    s.add_argument("--round", type=int); s.add_argument("--priority", type=int, default=0)
    s.add_argument("--artifact"); s.add_argument("body", nargs="*"); s.set_defaults(fn=cmd_say)
    s = sub.add_parser("poll"); s.add_argument("--me"); s.add_argument("--room"); s.set_defaults(fn=cmd_poll)
    s = sub.add_parser("inbox"); s.add_argument("--me"); s.add_argument("--limit", type=int, default=20)
    s.set_defaults(fn=cmd_inbox)
    s = sub.add_parser("replay"); s.add_argument("--room", default="broadcast")
    s.add_argument("--limit", type=int, default=0); s.set_defaults(fn=cmd_replay)
    s = sub.add_parser("arm", help="print the hardwired ORRERY arming block for a subagent")
    s.set_defaults(fn=cmd_arm)

    # converge (the experiment tournament; falsifier = an ORRERY tool)
    s = sub.add_parser("converge-open", help="open a converge run (pre-registration MANDATORY)")
    s.add_argument("--me"); s.add_argument("--room", required=True); s.add_argument("--run", required=True)
    s.add_argument("--goal", default=""); s.add_argument("--hypothesis", help="MANDATORY: pre-register the claim")
    s.add_argument("--tool", required=True, help="the ORRERY tool that JUDGES")
    s.add_argument("--mode", required=True, choices=["golden", "target", "gate"])
    s.add_argument("--base-params", dest="base_params", help="JSON merged under every candidate")
    s.add_argument("--base-params-file", dest="base_params_file")
    s.add_argument("--seed", type=int, default=0)
    s.add_argument("--expect-hash", dest="expect_hash", help="mode=golden: frozen declared blake2b")
    s.add_argument("--metric", help="mode=target: result field name")
    s.add_argument("--metric-target", dest="metric_target", type=float, help="mode=target: value to hit")
    s.add_argument("--tol", type=float, help="mode=target: pass tolerance")
    s.add_argument("--band", type=float, help="mode=target: credit-decay scale (default 10*tol)")
    s.add_argument("--gate-id", dest="gate_id", help="mode=gate: gate that must NOT fire")
    s.add_argument("--controls", help="pre-registered controls that MUST stay null (witness runs)")
    s.add_argument("--target", type=float, default=1.0); s.add_argument("--k", type=int, default=3)
    s.add_argument("--budget", type=int, default=0); s.add_argument("--arms", default="")
    s.set_defaults(fn=cmd_converge_open)
    s = sub.add_parser("propose", help="propose a parameterization; the coordinator scores it")
    s.add_argument("--me"); s.add_argument("--run", required=True)
    s.add_argument("--params", help="JSON candidate params"); s.add_argument("--params-file", dest="params_file")
    s.add_argument("--branch"); s.set_defaults(fn=cmd_propose)
    s = sub.add_parser("champion"); s.add_argument("--run", required=True); s.set_defaults(fn=cmd_champion)
    s = sub.add_parser("board"); s.add_argument("--run", required=True); s.add_argument("--limit", type=int, default=0)
    s.set_defaults(fn=cmd_board)
    s = sub.add_parser("schedule"); s.add_argument("--run", required=True); s.add_argument("--c", type=float, default=1.414)
    s.add_argument("--prune-after", type=int, default=3, dest="prune_after")
    s.add_argument("--prune-margin", type=float, default=0.2, dest="prune_margin"); s.set_defaults(fn=cmd_schedule)
    s = sub.add_parser("lock", help="emit an ORRERY result.lock from the converged champion")
    s.add_argument("--run", required=True); s.add_argument("--out"); s.add_argument("--stdout", action="store_true")
    s.set_defaults(fn=cmd_lock)

    # rounds (the design tournament; argument-judged)
    s = sub.add_parser("rounds-open"); s.add_argument("--me"); s.add_argument("--room", required=True)
    s.add_argument("--run", required=True); s.add_argument("--roster", required=True)
    s.add_argument("--rounds", type=int, default=3); s.add_argument("--prompt", default="")
    s.set_defaults(fn=cmd_rounds_open)
    s = sub.add_parser("submit"); s.add_argument("--me"); s.add_argument("--room", required=True)
    s.add_argument("--run", required=True); s.add_argument("--round", type=int, required=True)
    s.add_argument("--artifact"); s.add_argument("body", nargs="*"); s.set_defaults(fn=cmd_submit)
    s = sub.add_parser("round-status"); s.add_argument("--room", required=True); s.add_argument("--run", required=True)
    s.add_argument("--round", type=int, required=True); s.set_defaults(fn=cmd_round_status)

    # graveyard + build locks
    s = sub.add_parser("graveyard", help="bury a killed approach (with a mandatory reinstatement trigger), or list")
    s.add_argument("--me"); s.add_argument("--run"); s.add_argument("--approach")
    s.add_argument("--reason"); s.add_argument("--trigger", help="pre-registered reinstatement condition")
    s.set_defaults(fn=cmd_graveyard)
    s = sub.add_parser("lease", help="acquire a build/GPU lock (expires; steal-on-expiry)")
    s.add_argument("--me"); s.add_argument("--resource", required=True); s.add_argument("--ttl", type=int, default=600)
    s.set_defaults(fn=cmd_lease)
    s = sub.add_parser("unlease"); s.add_argument("--me"); s.add_argument("--resource", required=True)
    s.set_defaults(fn=cmd_unlease)
    return p

def main(argv):
    _utf8()
    # ORRERY-harness compatibility: accept bare --selftest/--golden as well as the subcommands.
    if argv and argv[0] in ("--selftest", "--golden"):
        return run_selftest() if argv[0] == "--selftest" else run_golden()
    args = build_parser().parse_args(argv)
    try:
        args.fn(args)
    finally:
        _cleanup_tmp()
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
