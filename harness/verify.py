#!/usr/bin/env python3
"""
harness/verify.py — ORRERY compile-as-verification (the instrument's immune system).

For every tool under tools/<tool>/:
  1. build it via the build command in its MODULE.md ("## Build" fenced block),
  2. run `<tool>.exe --selftest` (expect exit 0),
  3. run `<tool>.exe --golden`   (expect exit 0 — reproduces the frozen golden hash).
Write a dated report to runs/verify_<stamp>.md and exit 0 iff every tool is green.

stdlib only. Windows: build/exe are invoked through PowerShell (the machine's shell),
matching BUILD.md's `cmd /c '...'` incantation. Timeouts: selftest 60 s, golden 900 s
(NFR target is <30 s / <5 min; someone's golden is bandwidth-bound ~8 min — see D-014,
flagged as a WARN, not a hard failure).

Usage:  python harness/verify.py [--no-build] [--tool NAME]
Exit:   0 all green · 1 a tool failed build/selftest/golden · 2 harness error.
"""
import sys, os, re, subprocess, datetime, argparse

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
RUNS = os.path.join(ROOT, "runs")
SELFTEST_TIMEOUT = 60
GOLDEN_TIMEOUT = 900
NFR_SELFTEST_S = 30
NFR_GOLDEN_S = 300

def is_windows():
    return os.name == "nt"

def run(cmd, cwd, timeout):
    """Run a command string through the platform shell. Returns (exit, seconds, tail)."""
    t0 = datetime.datetime.now()
    if is_windows():
        argv = ["powershell", "-NoProfile", "-Command", cmd]
    else:
        argv = ["bash", "-lc", cmd]
    try:
        p = subprocess.run(argv, cwd=cwd, timeout=timeout,
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        secs = (datetime.datetime.now() - t0).total_seconds()
        tail = ((p.stdout or "") + (p.stderr or "")).strip().splitlines()
        return p.returncode, secs, "\n".join(tail[-6:])
    except subprocess.TimeoutExpired:
        secs = (datetime.datetime.now() - t0).total_seconds()
        return 124, secs, f"TIMEOUT after {timeout}s"

def extract_build_cmd(module_md):
    """First fenced code block after a '## Build' heading."""
    txt = open(module_md, encoding="utf-8").read()
    m = re.search(r"##+\s*Build\b.*?```[a-zA-Z]*\n(.*?)```", txt, re.S)
    if not m:
        return None
    # collapse to a single logical command (strip blank lines / comments)
    lines = [l for l in m.group(1).splitlines() if l.strip() and not l.strip().startswith("#")]
    return "\n".join(lines).strip() or None

def discover_tools(only=None):
    out = []
    if not os.path.isdir(TOOLS):
        return out
    for name in sorted(os.listdir(TOOLS)):
        d = os.path.join(TOOLS, name)
        mod = os.path.join(d, "MODULE.md")
        if os.path.isdir(d) and os.path.isfile(mod):
            if only and name != only:
                continue
            out.append((name, d, mod))
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-build", action="store_true", help="skip the build step (verify existing binaries)")
    ap.add_argument("--tool", default=None, help="verify only this tool")
    args = ap.parse_args()

    tools = discover_tools(args.tool)
    if not tools:
        print("no tools found under tools/*/MODULE.md", file=sys.stderr)
        return 2

    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    rows, all_green = [], True
    print(f"ORRERY verify — {len(tools)} tool(s) — {stamp}")

    for name, d, mod in tools:
        exe = name + (".exe" if is_windows() else "")
        r = {"tool": name, "build": "-", "selftest": "-", "golden": "-", "notes": []}

        if not args.no_build:
            bc = extract_build_cmd(mod)
            if not bc:
                r["build"] = "NO-BUILD-CMD"; all_green = False
                rows.append(r); print(f"  {name}: MODULE.md has no ## Build block"); continue
            code, secs, tail = run(bc, d, GOLDEN_TIMEOUT)
            r["build"] = "OK" if code == 0 else f"FAIL({code})"
            if code != 0:
                all_green = False; r["notes"].append(f"build: {tail}")
                rows.append(r); print(f"  {name}: BUILD {r['build']} ({secs:.0f}s)"); continue

        exe_path = os.path.join(d, exe)
        if not os.path.isfile(exe_path):
            r["build"] = r["build"] if r["build"] != "-" else "NO-EXE"
            r["selftest"] = "NO-EXE"; all_green = False
            rows.append(r); print(f"  {name}: no {exe}"); continue

        code, secs, tail = run(f".\\{exe} --selftest", d, SELFTEST_TIMEOUT)
        r["selftest"] = "OK" if code == 0 else f"FAIL({code})"
        if secs > NFR_SELFTEST_S: r["notes"].append(f"selftest {secs:.0f}s > {NFR_SELFTEST_S}s NFR")
        if code != 0: all_green = False; r["notes"].append(f"selftest: {tail}")

        code, secs, tail = run(f".\\{exe} --golden", d, GOLDEN_TIMEOUT)
        r["golden"] = "OK" if code == 0 else f"FAIL({code})"
        if secs > NFR_GOLDEN_S: r["notes"].append(f"golden {secs:.0f}s > {NFR_GOLDEN_S}s NFR (WARN)")
        if code != 0: all_green = False; r["notes"].append(f"golden: {tail}")

        rows.append(r)
        print(f"  {name}: build={r['build']} selftest={r['selftest']} golden={r['golden']}")

    os.makedirs(RUNS, exist_ok=True)
    report = os.path.join(RUNS, f"verify_{stamp}.md")
    with open(report, "w", encoding="utf-8") as f:
        f.write(f"# ORRERY verify — {stamp}\n\n")
        f.write(f"Overall: {'GREEN' if all_green else 'RED'}\n\n")
        f.write("| tool | build | selftest | golden | notes |\n|---|---|---|---|---|\n")
        for r in rows:
            f.write(f"| {r['tool']} | {r['build']} | {r['selftest']} | {r['golden']} | "
                    f"{'; '.join(r['notes']) if r['notes'] else ''} |\n")
    print(f"report: {report}")
    print("OVERALL:", "GREEN" if all_green else "RED")
    return 0 if all_green else 1

if __name__ == "__main__":
    sys.exit(main())
