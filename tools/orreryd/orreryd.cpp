// orreryd.cpp — ORRERY tool `orreryd` (v0.1.0). The GPU-tenancy job daemon (D-022 surface #2).
// Headless file-spool serializer: jobs in <spool>/pending/ run ONE AT A TIME (one GPU tenant,
// lexicographic FIFO) under per-job wall-clock budgets, with .stop/.DONE sentinels and an
// atomically-updated status.html/status.json. Contract: contracts/orreryd.contract.md v0.1.0.
//
// THE SPLIT (ARCHITECTURE section 2) PASSES THROUGH UNCHANGED: the daemon SUBPROCESSES the sacred
// executables; it never links tool internals, never computes. I-12: every job record embeds the
// D-013 declared-object blake2b + the artifact blake2b. First new-tool consumer of lib/ (D-020).
// A scheduling surface: computes nothing scientific; III-sealed.
//
// Build (from tools/orreryd/, see BUILD.md — host-only C++20, no CUDA):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && cl /nologo /O2 /std:c++20 /EHsc orreryd.cpp ../../lib/envelope.cpp /Fe:orreryd.exe'

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include <algorithm>
#include <filesystem>
#include <fstream>
#include "../../lib/envelope.h"
using namespace orrery;
namespace fs = std::filesystem;

static const char* ORRERYD_VERSION = "0.1.0";
static const char* FIREWALL =
    "A scheduling/orchestration surface: it computes nothing scientific itself and says nothing "
    "about qualia - III-sealed. The sacred CLI executables remain the contract of record; this "
    "daemon subprocesses them one at a time (one GPU tenant, FIFO) under wall-clock budgets.";
static const int BUDGET_DEFAULT_S = 900, BUDGET_MAX_S = 3600, CHAIN_BUDGET_S = 120;

// ================================================================== minimal JSON (parse only)
// Recursive-descent, KAT-gated in --selftest. Objects preserve key order (deterministic argv).
// Numbers keep their RAW text slice so job params pass to tool CLIs with the caller's exact spelling.
struct JVal {
    enum T { NUL, BOO, NUM, STR, ARR, OBJ } t = NUL;
    bool b = false;
    bool isInt = false; long long i = 0;
    std::string raw;                                  // NUM: original text
    std::string s;                                    // STR
    std::vector<JVal> arr;
    std::vector<std::pair<std::string, JVal>> obj;
    const JVal* get(const std::string& k) const {
        for (auto& kv : obj) if (kv.first == k) return &kv.second;
        return nullptr;
    }
};
struct JParser {
    const char* p; const char* end; bool ok = true;
    JParser(const std::string& text) : p(text.data()), end(text.data() + text.size()) {}
    void ws() { while (p < end && (*p==' '||*p=='\t'||*p=='\n'||*p=='\r')) p++; }
    bool lit(const char* s) { size_t n = strlen(s); if ((size_t)(end-p) >= n && !memcmp(p, s, n)) { p += n; return true; } return false; }
    bool parse_string(std::string& out) {
        if (p >= end || *p != '"') return false;
        p++;
        out.clear();
        while (p < end && *p != '"') {
            if (*p == '\\') {
                p++;
                if (p >= end) return false;
                switch (*p) {
                    case '"': out += '"'; break;   case '\\': out += '\\'; break;
                    case '/': out += '/'; break;   case 'b': out += '\b'; break;
                    case 'f': out += '\f'; break;  case 'n': out += '\n'; break;
                    case 'r': out += '\r'; break;  case 't': out += '\t'; break;
                    case 'u': {
                        auto hex4 = [&](unsigned& v)->bool {
                            if (end - p < 4) return false; v = 0;
                            for (int k = 0; k < 4; k++) { char c = p[k]; v <<= 4;
                                if (c>='0'&&c<='9') v |= (unsigned)(c-'0');
                                else if (c>='a'&&c<='f') v |= (unsigned)(c-'a'+10);
                                else if (c>='A'&&c<='F') v |= (unsigned)(c-'A'+10);
                                else return false; }
                            p += 4; return true; };
                        p++;
                        unsigned cp;
                        if (!hex4(cp)) return false;
                        if (cp >= 0xD800 && cp <= 0xDBFF && end - p >= 6 && p[0]=='\\' && p[1]=='u') {
                            p += 2; unsigned lo;
                            if (!hex4(lo) || lo < 0xDC00 || lo > 0xDFFF) return false;
                            cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                        }
                        if (cp < 0x80) out += (char)cp;
                        else if (cp < 0x800) { out += (char)(0xC0|(cp>>6)); out += (char)(0x80|(cp&0x3F)); }
                        else if (cp < 0x10000) { out += (char)(0xE0|(cp>>12)); out += (char)(0x80|((cp>>6)&0x3F)); out += (char)(0x80|(cp&0x3F)); }
                        else { out += (char)(0xF0|(cp>>18)); out += (char)(0x80|((cp>>12)&0x3F)); out += (char)(0x80|((cp>>6)&0x3F)); out += (char)(0x80|(cp&0x3F)); }
                        continue;                     // p already advanced past hex digits
                    }
                    default: return false;
                }
                p++;
            } else {
                out += *p++;
            }
        }
        if (p >= end) return false;
        p++;                                          // closing quote
        return true;
    }
    bool parse_value(JVal& v) {
        ws();
        if (p >= end) return false;
        if (*p == '{') {
            p++; v.t = JVal::OBJ;
            ws();
            if (p < end && *p == '}') { p++; return true; }
            while (true) {
                std::string key; ws();
                if (!parse_string(key)) return false;
                ws(); if (p >= end || *p != ':') return false; p++;
                JVal child;
                if (!parse_value(child)) return false;
                v.obj.emplace_back(std::move(key), std::move(child));
                ws();
                if (p < end && *p == ',') { p++; continue; }
                if (p < end && *p == '}') { p++; return true; }
                return false;
            }
        }
        if (*p == '[') {
            p++; v.t = JVal::ARR;
            ws();
            if (p < end && *p == ']') { p++; return true; }
            while (true) {
                JVal child;
                if (!parse_value(child)) return false;
                v.arr.push_back(std::move(child));
                ws();
                if (p < end && *p == ',') { p++; continue; }
                if (p < end && *p == ']') { p++; return true; }
                return false;
            }
        }
        if (*p == '"') { v.t = JVal::STR; return parse_string(v.s); }
        if (lit("true"))  { v.t = JVal::BOO; v.b = true;  return true; }
        if (lit("false")) { v.t = JVal::BOO; v.b = false; return true; }
        if (lit("null"))  { v.t = JVal::NUL; return true; }
        // number
        const char* start = p;
        if (p < end && (*p=='-'||*p=='+')) p++;
        bool digits=false, flt=false;
        while (p < end) {
            char c = *p;
            if (c>='0'&&c<='9') { digits=true; p++; }
            else if (c=='.'||c=='e'||c=='E'||c=='+'||c=='-') { flt=true; p++; }
            else break;
        }
        if (!digits) return false;
        v.t = JVal::NUM; v.raw.assign(start, p);
        if (!flt) { v.isInt = true; v.i = strtoll(v.raw.c_str(), nullptr, 10); }
        return true;
    }
};
static bool json_parse(const std::string& text, JVal& out) {
    JParser jp(text);
    if (!jp.parse_value(out)) return false;
    jp.ws();
    return jp.p == jp.end;
}

// ================================================================== repo root + registry
static std::string find_root() {
    for (const char* c : { ".", "..", "../..", "../../.." }) {
        fs::path r(c);
        if (fs::exists(r/"tools") && fs::exists(r/"goldens") && fs::exists(r/"contracts"))
            return fs::absolute(r).string();
    }
    die2("cannot locate the ORRERY repo root (need tools/ + goldens/ + contracts/); run from the repo or a tool dir");
}
struct ToolEntry { std::string name, lang, artifact; bool found = false; };
static ToolEntry registry_find(const std::string& root, const std::string& name) {
    ToolEntry e; e.name = name;
    for (char c : name)
        if (!((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='_'||c=='-')) return e;
    fs::path d = fs::path(root)/"tools"/name;
    if (!fs::is_directory(d) || !fs::is_regular_file(d/"MODULE.md")) return e;
    fs::path py = d/(name + ".py"), exe = d/(name + ".exe");
    if (fs::is_regular_file(py))      { e.lang = "python"; e.artifact = fs::absolute(py).string();  e.found = true; }
    else if (fs::is_regular_file(exe)){ e.lang = "exe";    e.artifact = fs::absolute(exe).string(); e.found = true; }
    return e;
}

// ================================================================== argv / command line
static bool key_ok(const std::string& k) {
    if (k.empty()) return false;
    for (char c : k)
        if (!((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='-')) return false;
    return true;
}
// Build the argv vector for a job. Throws std::runtime_error on caller-input problems.
static std::vector<std::string> build_argv(const ToolEntry& e, const JVal* params) {
    std::vector<std::string> argv;
    if (e.lang == "python") { argv.push_back("python"); argv.push_back(e.artifact); }
    else argv.push_back(e.artifact);
    bool has_mode = false;
    if (params) {
        if (params->t != JVal::OBJ) throw std::runtime_error("params must be an object");
        for (auto& kv : params->obj) {
            const std::string& k = kv.first; const JVal& v = kv.second;
            if (!key_ok(k)) throw std::runtime_error("bad param key '" + k + "' (want ^[A-Za-z0-9-]+$)");
            if (k == "golden" || k == "selftest" || k == "json") has_mode = true;
            if (v.t == JVal::BOO) { if (v.b) argv.push_back("--" + k); continue; }
            if (v.t == JVal::NUL) continue;
            argv.push_back("--" + k);
            if (v.t == JVal::STR) argv.push_back(v.s);
            else if (v.t == JVal::NUM) argv.push_back(v.raw);      // caller's exact spelling
            else throw std::runtime_error("param '" + k + "' must be a scalar");
        }
    }
    if (!has_mode) argv.push_back("--json");
    return argv;
}
// Windows command-line quoting (the standard CommandLineToArgv rules).
static std::string quote_arg(const std::string& a) {
    if (!a.empty() && a.find_first_of(" \t\"") == std::string::npos) return a;
    std::string o = "\"";
    size_t bs = 0;
    for (char c : a) {
        if (c == '\\') { bs++; continue; }
        if (c == '"') { o.append(bs*2 + 1, '\\'); o += '"'; bs = 0; continue; }
        o.append(bs, '\\'); bs = 0; o += c;
    }
    o.append(bs*2, '\\');
    o += '"';
    return o;
}
static std::string join_cmdline(const std::vector<std::string>& argv) {
    std::string s;
    for (size_t i = 0; i < argv.size(); i++) { if (i) s += ' '; s += quote_arg(argv[i]); }
    return s;
}

// ================================================================== Win32 spawn (capture + budget)
struct SpawnResult { bool spawned=false, timed_out=false; int exit_code=-1; std::string out, err, why; };
static std::string read_all(const fs::path& p) {
    std::ifstream f(p, std::ios::binary);
    return std::string((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
}
static SpawnResult spawn_capture(const std::vector<std::string>& argv, const std::string& cwd,
                                 const std::string* stdin_data, int budget_s, const fs::path& tmpdir) {
    SpawnResult r;
    static long seq = 0; seq++;
    fs::path fo = tmpdir / ("_cap_out_" + std::to_string(GetCurrentProcessId()) + "_" + std::to_string(seq) + ".txt");
    fs::path fe = tmpdir / ("_cap_err_" + std::to_string(GetCurrentProcessId()) + "_" + std::to_string(seq) + ".txt");
    fs::path fi = tmpdir / ("_cap_in_"  + std::to_string(GetCurrentProcessId()) + "_" + std::to_string(seq) + ".txt");
    SECURITY_ATTRIBUTES sa{ sizeof(sa), nullptr, TRUE };
    HANDLE ho = CreateFileA(fo.string().c_str(), GENERIC_WRITE, FILE_SHARE_READ, &sa, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    HANDLE he = CreateFileA(fe.string().c_str(), GENERIC_WRITE, FILE_SHARE_READ, &sa, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    HANDLE hi = INVALID_HANDLE_VALUE;
    if (stdin_data) {
        { std::ofstream f(fi, std::ios::binary); f << *stdin_data; }
        hi = CreateFileA(fi.string().c_str(), GENERIC_READ, FILE_SHARE_READ, &sa, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    } else {
        hi = CreateFileA("NUL", GENERIC_READ, FILE_SHARE_READ, &sa, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    }
    if (ho == INVALID_HANDLE_VALUE || he == INVALID_HANDLE_VALUE || hi == INVALID_HANDLE_VALUE) {
        r.why = "cannot open capture files";
        if (ho != INVALID_HANDLE_VALUE) CloseHandle(ho);
        if (he != INVALID_HANDLE_VALUE) CloseHandle(he);
        if (hi != INVALID_HANDLE_VALUE) CloseHandle(hi);
        return r;
    }
    STARTUPINFOA si{}; si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdOutput = ho; si.hStdError = he; si.hStdInput = hi;
    PROCESS_INFORMATION pi{};
    std::string cmd = join_cmdline(argv);
    std::vector<char> buf(cmd.begin(), cmd.end()); buf.push_back(0);
    BOOL okc = CreateProcessA(nullptr, buf.data(), nullptr, nullptr, TRUE, 0, nullptr,
                              cwd.empty() ? nullptr : cwd.c_str(), &si, &pi);
    CloseHandle(ho); CloseHandle(he); CloseHandle(hi);
    if (!okc) {
        r.why = "CreateProcess failed (code " + std::to_string((long long)GetLastError()) + ")";
        fs::remove(fo); fs::remove(fe); if (stdin_data) fs::remove(fi);
        return r;
    }
    r.spawned = true;
    DWORD w = WaitForSingleObject(pi.hProcess, (DWORD)budget_s * 1000u);
    if (w == WAIT_TIMEOUT) {
        r.timed_out = true;
        TerminateProcess(pi.hProcess, 258);
        WaitForSingleObject(pi.hProcess, INFINITE);
    }
    DWORD code = 0; GetExitCodeProcess(pi.hProcess, &code);
    r.exit_code = (int)code;
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
    r.out = read_all(fo); r.err = read_all(fe);
    fs::remove(fo); fs::remove(fe); if (stdin_data) fs::remove(fi);
    return r;
}

// ================================================================== job records (I-12)
static std::string extract_declared(const std::string& env) {
    size_t i = env.find("\"seed\":");
    size_t j = env.rfind(",\"notes\":");
    if (i == std::string::npos || j == std::string::npos || j <= i) return std::string();
    return "{" + env.substr(i, j - i) + "}";
}
static std::string envelope_line(const std::string& out) {
    size_t pos = 0;
    while (pos < out.size()) {
        size_t nl = out.find('\n', pos);
        std::string line = out.substr(pos, nl == std::string::npos ? std::string::npos : nl - pos);
        while (!line.empty() && (line.back() == '\r' || line.back() == '\n')) line.pop_back();
        if (!line.empty() && line[0] == '{') return line;
        if (nl == std::string::npos) break;
        pos = nl + 1;
    }
    return std::string();
}
static std::string file_hash(const std::string& path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) return std::string();
    std::string bytes((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    return blake2b_hex(bytes);
}
static std::string now_stamp() {
    SYSTEMTIME st; GetLocalTime(&st);
    char b[32]; snprintf(b, sizeof(b), "%04u-%02u-%02u %02u:%02u:%02u", st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);
    return b;
}
struct JobRecord {
    std::string job, tool, exit_class, envelope_raw, declared_hash, artifact_hash, stderr_tail, why;
    std::vector<std::string> argv;
    int exit_code = -1;
    double duration_s = 0;
    std::string started, finished;                    // non-declared
};
static std::string tail4(const std::string& s) {
    std::vector<std::string> lines; std::string cur;
    for (char c : s) { if (c == '\n') { lines.push_back(cur); cur.clear(); } else if (c != '\r') cur += c; }
    if (!cur.empty()) lines.push_back(cur);
    while (!lines.empty() && lines.back().empty()) lines.pop_back();
    size_t start = lines.size() > 4 ? lines.size() - 4 : 0;
    std::string o;
    for (size_t i = start; i < lines.size(); i++) { if (i > start) o += "\n"; o += lines[i]; }
    return o;
}
static JobRecord run_job(const std::string& root, const std::string& jobname, const std::string& job_text,
                         int default_budget_s, const fs::path& tmpdir) {
    JobRecord r; r.job = jobname; r.started = now_stamp();
    ULONGLONG t0 = GetTickCount64();
    auto fin = [&](const char* cls) { r.exit_class = cls; r.finished = now_stamp();
                                      r.duration_s = (GetTickCount64() - t0) / 1000.0; return r; };
    JVal spec;
    if (!json_parse(job_text, spec) || spec.t != JVal::OBJ) { r.why = "malformed job JSON"; return fin("error"); }
    const JVal* tool = spec.get("tool");
    if (!tool || tool->t != JVal::STR) { r.why = "job.tool must be a string"; return fin("error"); }
    r.tool = tool->s;
    ToolEntry e = registry_find(root, tool->s);
    if (!e.found) { r.why = "unknown tool '" + tool->s + "' (not in the registry)"; return fin("error"); }
    int budget = default_budget_s;
    if (const JVal* ts = spec.get("timeout_s")) {
        long long v = (ts->t == JVal::NUM) ? (ts->isInt ? ts->i : (long long)strtod(ts->raw.c_str(), nullptr)) : -1;
        if (v < 1 || v > BUDGET_MAX_S) { r.why = "timeout_s out of range [1,3600]"; return fin("error"); }
        budget = (int)v;
    }
    std::string stdin_data; bool has_stdin = false;
    if (const JVal* sj = spec.get("stdin_json")) {
        if (sj->t == JVal::STR) { stdin_data = sj->s; has_stdin = true; }
        else if (sj->t != JVal::NUL) { r.why = "stdin_json must be a string in v0.1.0 (pre-serialized JSON)"; return fin("error"); }
    }
    try { r.argv = build_argv(e, spec.get("params")); }
    catch (const std::exception& ex) { r.why = ex.what(); return fin("error"); }
    std::string cwd = fs::path(e.artifact).parent_path().string();
    SpawnResult sp = spawn_capture(r.argv, cwd, has_stdin ? &stdin_data : nullptr, budget, tmpdir);
    r.artifact_hash = file_hash(e.artifact);
    if (!sp.spawned) { r.why = sp.why; return fin("error"); }
    r.exit_code = sp.exit_code;
    r.stderr_tail = tail4(sp.err);
    r.envelope_raw = envelope_line(sp.out);
    if (!r.envelope_raw.empty()) {
        std::string d = extract_declared(r.envelope_raw);
        if (!d.empty()) r.declared_hash = blake2b_hex(d);
    }
    if (sp.timed_out) return fin("timeout");
    if (sp.exit_code == 0) return fin("pass");
    if (sp.exit_code == 1) return fin("gate-fired");
    return fin("error");
}
static std::string jarr(const std::vector<std::string>& v) {
    std::string s = "[";
    for (size_t i = 0; i < v.size(); i++) { if (i) s += ","; s += "\"" + jesc(v[i]) + "\""; }
    return s + "]";
}
static std::string record_json(const JobRecord& r) {
    std::string s = "{";
    s += "\"job\":\"" + jesc(r.job) + "\",\"tool\":\"" + jesc(r.tool) + "\"";
    s += ",\"argv\":" + jarr(r.argv);
    s += ",\"exit_code\":" + (r.exit_code < 0 ? std::string("null") : fmti(r.exit_code));
    s += ",\"exit_class\":\"" + jesc(r.exit_class) + "\"";
    s += ",\"envelope\":" + (r.envelope_raw.empty() ? std::string("null") : r.envelope_raw);   // JSON-in-JSON, verbatim
    s += ",\"declared_blake2b\":" + (r.declared_hash.empty() ? std::string("null") : "\"" + r.declared_hash + "\"");
    s += ",\"artifact_blake2b\":" + (r.artifact_hash.empty() ? std::string("null") : "\"" + r.artifact_hash + "\"");
    s += ",\"stderr_tail\":\"" + jesc(r.stderr_tail) + "\"";
    if (!r.why.empty()) s += ",\"error_reason\":\"" + jesc(r.why) + "\"";
    s += ",\"duration_s\":" + fmt6(r.duration_s);
    s += ",\"started\":\"" + jesc(r.started) + "\",\"finished\":\"" + jesc(r.finished) + "\"}";
    return s;
}

// ================================================================== spool + status
struct Spool { fs::path root, pending, running, done; };
static Spool spool_open(const std::string& dir, bool create) {
    Spool s; s.root = fs::path(dir);
    s.pending = s.root/"pending"; s.running = s.root/"running"; s.done = s.root/"done";
    if (create) { fs::create_directories(s.pending); fs::create_directories(s.running); fs::create_directories(s.done); }
    if (!fs::is_directory(s.pending)) die2("spool has no pending/ directory: " + dir);
    return s;
}
static void atomic_write(const fs::path& target, const std::string& content) {
    fs::path tmp = target; tmp += ".tmp";
    { std::ofstream f(tmp, std::ios::binary); f << content; }
    MoveFileExA(tmp.string().c_str(), target.string().c_str(), MOVEFILE_REPLACE_EXISTING);
}
static void status_write(const Spool& sp, const std::string& state, const std::string& current,
                         size_t pending_n, const std::vector<JobRecord>& last) {
    std::string j = "{\"daemon\":\"orreryd\",\"version\":\"" + std::string(ORRERYD_VERSION) + "\"";
    j += ",\"state\":\"" + jesc(state) + "\"";
    j += ",\"current\":" + (current.empty() ? std::string("null") : "\"" + jesc(current) + "\"");
    j += ",\"pending\":" + fmti((long long)pending_n);
    j += ",\"updated\":\"" + now_stamp() + "\",\"last_results\":[";
    for (size_t i = 0; i < last.size(); i++) {
        if (i) j += ",";
        j += "{\"job\":\"" + jesc(last[i].job) + "\",\"tool\":\"" + jesc(last[i].tool)
           + "\",\"exit_class\":\"" + jesc(last[i].exit_class) + "\",\"declared_blake2b\":"
           + (last[i].declared_hash.empty() ? std::string("null") : "\"" + last[i].declared_hash + "\"") + "}";
    }
    j += "]}";
    atomic_write(sp.root/"status.json", j);
    std::string h = "<!doctype html><meta http-equiv=\"refresh\" content=\"2\"><title>orreryd</title>"
                    "<body style=\"font-family:monospace;background:#111;color:#ddd\">"
                    "<h2>orreryd v" + std::string(ORRERYD_VERSION) + " &mdash; " + state + "</h2>"
                    "<p>current: <b>" + (current.empty() ? "-" : current) + "</b> &middot; pending: "
                    + std::to_string(pending_n) + " &middot; updated: " + now_stamp() + "</p><ul>";
    for (auto it = last.rbegin(); it != last.rend(); ++it)
        h += "<li>" + it->job + " [" + it->tool + "] &rarr; <b>" + it->exit_class + "</b> "
           + (it->declared_hash.empty() ? "" : it->declared_hash.substr(0, 16) + "&hellip;") + "</li>";
    h += "</ul></body>";
    atomic_write(sp.root/"status.html", h);
}
static std::vector<fs::path> pending_sorted(const Spool& sp) {
    std::vector<fs::path> v;
    for (auto& e : fs::directory_iterator(sp.pending))
        if (e.is_regular_file() && e.path().extension() == ".json") v.push_back(e.path());
    std::sort(v.begin(), v.end(),
              [](const fs::path& a, const fs::path& b){ return a.filename().string() < b.filename().string(); });
    return v;
}

// The queue loop (the REAL code path; the canned drain runs through this too).
static int daemon_loop(const Spool& sp, const std::string& root, int poll_ms, int budget_s,
                       bool drain, std::vector<JobRecord>* collect) {
    std::vector<JobRecord> ring;
    status_write(sp, "idle", "", pending_sorted(sp).size(), ring);
    while (true) {
        if (fs::exists(sp.root/".stop")) {
            fs::remove(sp.root/".stop");
            status_write(sp, "stopped", "", pending_sorted(sp).size(), ring);
            fprintf(stderr, "orreryd: .stop honored, exiting\n");
            return 0;
        }
        std::vector<fs::path> pend = pending_sorted(sp);
        if (pend.empty()) {
            if (drain) {
                atomic_write(sp.root/".DONE", "DONE " + now_stamp() + "\n");
                status_write(sp, "drained", "", 0, ring);
                return 0;
            }
            Sleep((DWORD)poll_ms);
            continue;
        }
        fs::path src = pend.front();
        std::string jobname = src.stem().string();
        fs::path claimed = sp.running/src.filename();
        std::error_code ec;
        fs::rename(src, claimed, ec);
        if (ec) { Sleep((DWORD)poll_ms); continue; }             // producer mid-write; retry next poll
        status_write(sp, "running", jobname, pend.size() - 1, ring);
        std::string text = read_all(claimed);
        JobRecord rec = run_job(root, jobname, text, budget_s, sp.root);
        atomic_write(sp.done/(jobname + ".result.json"), record_json(rec));
        fs::remove(claimed, ec);
        ring.push_back(rec);
        if (ring.size() > 10) ring.erase(ring.begin());
        if (collect) collect->push_back(rec);
        status_write(sp, "idle", "", pending_sorted(sp).size(), ring);
    }
}

// ================================================================== the canned drain (--json/--golden)
struct DrainOut { int submitted=0, completed=0; bool order_ok=false, matches=false, done_sentinel=false;
                  std::vector<std::string> classes; std::string chain_hash; };
static DrainOut canned_drain(const std::string& root) {
    DrainOut o; o.submitted = 3;
    fs::path dir = fs::path("_orreryd_golden_" + std::to_string(GetCurrentProcessId()));
    std::error_code ec; fs::remove_all(dir, ec);
    Spool sp = spool_open(dir.string(), true);
    const std::string chain = "{\"tool\":\"posit\",\"params\":{\"golden\":true},\"timeout_s\":" + fmti(CHAIN_BUDGET_S) + "}";
    { std::ofstream f(sp.pending/"j1.json", std::ios::binary); f << chain; }
    { std::ofstream f(sp.pending/"j2.json", std::ios::binary); f << "{\"tool\":\"__nosuch__\"}"; }
    { std::ofstream f(sp.pending/"j3.json", std::ios::binary); f << chain; }
    std::vector<JobRecord> recs;
    daemon_loop(sp, root, 50, CHAIN_BUDGET_S, /*drain=*/true, &recs);
    o.done_sentinel = fs::exists(sp.root/".DONE");
    o.completed = 0;
    for (auto& e : fs::directory_iterator(sp.done))
        if (e.path().extension() == ".json") o.completed++;
    o.order_ok = recs.size() == 3 && recs[0].job == "j1" && recs[1].job == "j2" && recs[2].job == "j3";
    for (auto& r : recs) o.classes.push_back(r.exit_class);
    std::string frozen;
    bool have_frozen = read_golden_hash("posit", frozen);
    if (recs.size() == 3) {
        o.chain_hash = recs[0].declared_hash;
        o.matches = have_frozen && !o.chain_hash.empty()
                 && recs[0].exit_class == "pass" && recs[0].declared_hash == frozen
                 && recs[2].exit_class == "pass" && recs[2].declared_hash == frozen;
    }
    fs::remove_all(dir, ec);
    return o;
}

// ================================================================== envelope (canonical, D-013)
struct Verdict { std::string params_j, result_j, gates_j, verdict; int exit_code; };
static Verdict drain_verdict(const DrainOut& o) {
    Verdict v;
    v.params_j = "{\"chain_tool\":\"posit\",\"jobs_submitted\":3,\"budget_s\":" + fmti(CHAIN_BUDGET_S) + "}";
    std::string classes = "[";
    for (size_t i = 0; i < o.classes.size(); i++) { if (i) classes += ","; classes += "\"" + jesc(o.classes[i]) + "\""; }
    classes += "]";
    v.result_j = "{\"jobs_submitted\":" + fmti(o.submitted) + ",\"jobs_completed\":" + fmti(o.completed)
               + ",\"order_ok\":" + (o.order_ok ? "true" : "false")
               + ",\"exit_classes\":" + classes
               + ",\"chain_declared_blake2b\":\"" + o.chain_hash + "\""
               + ",\"chain_matches_frozen\":" + (o.matches ? "true" : "false")
               + ",\"done_sentinel\":" + (o.done_sentinel ? "true" : "false") + "}";
    bool g_chain = !o.matches;
    bool expected_classes = o.classes.size() == 3 && o.classes[0] == "pass" && o.classes[1] == "error" && o.classes[2] == "pass";
    bool g_drain = (o.completed != 3) || !o.order_ok || !expected_classes || !o.done_sentinel;
    int chain_wrong = o.matches ? 0 : 1;
    v.gates_j = "[{\"id\":\"G-CHAIN-MISMATCH\",\"fired\":" + std::string(g_chain ? "true" : "false")
              + ",\"value\":" + fmt6((double)chain_wrong) + ",\"threshold\":" + fmt6(0.0) + "}"
              + ",{\"id\":\"G-DRAIN-INCOMPLETE\",\"fired\":" + std::string(g_drain ? "true" : "false")
              + ",\"value\":" + fmt6(g_drain ? 1.0 : 0.0) + ",\"threshold\":" + fmt6(0.0) + "}]";
    v.verdict = (g_chain || g_drain) ? "fail" : "pass";
    v.exit_code = (g_chain || g_drain) ? 1 : 0;
    return v;
}
static std::string declared_body_s(long long seed, const Verdict& v) {
    return "\"seed\":" + fmti(seed) + ",\"params\":" + v.params_j + ",\"result\":" + v.result_j
         + ",\"gates\":" + v.gates_j + ",\"verdict\":\"" + v.verdict + "\"";
}
static std::string envelope_s(long long seed, const Verdict& v) {
    return full_envelope("orreryd", ORRERYD_VERSION, declared_body_s(seed, v), FIREWALL);
}

// ================================================================== golden / selftest
static int run_golden() {
    std::string root = find_root();
    Verdict v = drain_verdict(canned_drain(root));
    return golden_check("orreryd", declared_object(declared_body_s(0, v)), envelope_s(0, v));
}
static bool st(const char* n, bool ok) { return st_check(n, ok); }
static int run_selftest() {
    bool ok = true;
    fprintf(stderr, "orreryd --selftest (v%s)\n", ORRERYD_VERSION);
    std::string root = find_root();
    ok &= st("blake2b-256(\"abc\") KAT",
             blake2b_hex("abc") == "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    { JVal v; bool p = json_parse("{\"a\":1,\"b\":[true,null,\"x\\n\\u0041\"],\"c\":-2.5e3}", v);
      const JVal *a = v.get("a"), *b = v.get("b"), *c = v.get("c");
      ok &= st("JSON parser: object/array/escapes/numbers",
               p && a && a->isInt && a->i == 1 && b && b->arr.size() == 3 && b->arr[2].s == "x\nA"
               && c && c->t == JVal::NUM && !c->isInt && c->raw == "-2.5e3"); }
    { JVal v; ok &= st("JSON parser rejects malformed", !json_parse("{not json", v) && !json_parse("{\"a\":1} trailing", v)); }
    ok &= st("declared extraction (synthetic envelope)",
             extract_declared("{\"tool\":\"x\",\"version\":\"9\",\"seed\":7,\"params\":{},\"result\":{},\"gates\":[],\"verdict\":\"pass\",\"notes\":\"n\"}")
             == "{\"seed\":7,\"params\":{},\"result\":{},\"gates\":[],\"verdict\":\"pass\"}");
    { ToolEntry posit = registry_find(root, "posit");
      JVal p1; json_parse("{\"golden\":true}", p1);
      JVal p2; json_parse("{\"tie-band\":0.5,\"R\":3}", p2);
      auto a1 = build_argv(posit, &p1);
      auto a2 = build_argv(posit, &p2);
      bool bad_rejected = false;
      try { JVal pb; json_parse("{\"BAD KEY\":1}", pb); build_argv(posit, &pb); }
      catch (const std::exception&) { bad_rejected = true; }
      ok &= st("argv builder: bool flag, valued+uppercase flags + forced --json, bad key rejected",
               a1.back() == "--golden"
               && a2.size() >= 5 && a2[a2.size()-5] == "--tie-band" && a2[a2.size()-4] == "0.5"
               && a2[a2.size()-3] == "--R" && a2[a2.size()-2] == "3" && a2.back() == "--json"
               && bad_rejected); }
    ok &= st("cmdline quoting (space + embedded quote)",
             quote_arg("plain") == "plain" && quote_arg("a b") == "\"a b\""
             && quote_arg("x\"y") == "\"x\\\"y\"");
    { ToolEntry p = registry_find(root, "posit"), r = registry_find(root, "ratchet"), n = registry_find(root, "__nosuch__");
      ok &= st("registry: posit(python) + ratchet(exe) found; unknown -> not found",
               p.found && p.lang == "python" && r.found && r.lang == "exe" && !n.found); }
    // end-to-end mini-drain: [posit-golden, unknown, posit-golden] -> [pass, error, pass], .DONE, chain hash
    { DrainOut o = canned_drain(root);
      std::string frozen; read_golden_hash("posit", frozen);
      ok &= st("mini-drain: 3/3 completed in order, .DONE written",
               o.completed == 3 && o.order_ok && o.done_sentinel);
      ok &= st("mini-drain: classes [pass,error,pass] (queue survives an error job)",
               o.classes.size() == 3 && o.classes[0] == "pass" && o.classes[1] == "error" && o.classes[2] == "pass");
      ok &= st("I-12 chain: drained posit declared blake2b == frozen golden",
               o.matches && o.chain_hash == frozen); }
    // .stop honored: pre-dropped sentinel -> exit 0 without running the pending job; sentinel deleted
    { fs::path dir("_orreryd_selftest_" + std::to_string(GetCurrentProcessId()));
      std::error_code ec; fs::remove_all(dir, ec);
      Spool sp = spool_open(dir.string(), true);
      { std::ofstream f(sp.root/".stop", std::ios::binary); f << "stop"; }
      { std::ofstream f(sp.pending/"job.json", std::ios::binary); f << "{\"tool\":\"posit\",\"params\":{\"golden\":true}}"; }
      std::vector<JobRecord> recs;
      int code = daemon_loop(sp, root, 50, 60, false, &recs);
      ok &= st(".stop honored: exit 0, job left pending, sentinel deleted",
               code == 0 && recs.empty() && fs::exists(sp.pending/"job.json") && !fs::exists(sp.root/".stop"));
      fs::remove_all(dir, ec); }
    // malformed job -> error record; queue continues to the next job
    { fs::path dir("_orreryd_selftest2_" + std::to_string(GetCurrentProcessId()));
      std::error_code ec; fs::remove_all(dir, ec);
      Spool sp = spool_open(dir.string(), true);
      { std::ofstream f(sp.pending/"a.json", std::ios::binary); f << "{this is not json"; }
      { std::ofstream f(sp.pending/"b.json", std::ios::binary); f << "{\"tool\":\"posit\",\"params\":{\"golden\":true}}"; }
      std::vector<JobRecord> recs;
      daemon_loop(sp, root, 50, 60, true, &recs);
      std::string sj = read_all(sp.root/"status.json");
      ok &= st("malformed job -> error record; queue continues; status.json written",
               recs.size() == 2 && recs[0].exit_class == "error" && recs[1].exit_class == "pass"
               && sj.find("\"state\"") != std::string::npos);
      fs::remove_all(dir, ec); }
    // determinism: canned-drain declared built twice, byte-identical
    { Verdict v1 = drain_verdict(canned_drain(root));
      Verdict v2 = drain_verdict(canned_drain(root));
      ok &= st("declared object identical across two canned drains",
               declared_body_s(0, v1) == declared_body_s(0, v2)); }
    fprintf(stderr, ok ? "SELFTEST PASS\n" : "SELFTEST FAIL\n");
    return ok ? 0 : 1;
}

// ================================================================== CLI
int main(int argc, char** argv) {
    std::string spool_dir; std::string once;
    bool daemon = false, drain = false, json = false, selftest = false, golden = false;
    long long seed = 0; int poll_ms = 500, budget_s = BUDGET_DEFAULT_S;
    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        auto val = [&](const char* f) -> const char* {
            if (i + 1 >= argc) die2(std::string("missing value for ") + f);
            return argv[++i];
        };
        if (a == "--spool") spool_dir = val("--spool");
        else if (a == "--daemon") daemon = true;
        else if (a == "--drain") drain = true;
        else if (a == "--poll-ms") poll_ms = (int)parse_ll(val("--poll-ms"), "--poll-ms");
        else if (a == "--budget-s") budget_s = (int)parse_ll(val("--budget-s"), "--budget-s");
        else if (a == "--seed") seed = parse_ll(val("--seed"), "--seed");
        else if (a == "--json") json = true;
        else if (a == "--selftest") selftest = true;
        else if (a == "--golden") golden = true;
        else die2("unknown flag: " + a);
    }
    if (seed < 0) die2("--seed must be >= 0");
    int modes = (daemon ? 1 : 0) + (json ? 1 : 0) + (selftest ? 1 : 0) + (golden ? 1 : 0);
    if (modes != 1) die2("exactly one of --daemon | --json | --selftest | --golden");
    if (drain && !daemon) die2("--drain requires --daemon");
    if (selftest) return run_selftest();
    if (golden) return run_golden();
    if (json) {
        std::string root = find_root();
        Verdict v = drain_verdict(canned_drain(root));
        printf("%s\n", envelope_s(seed, v).c_str());
        return v.exit_code;
    }
    // --daemon
    if (spool_dir.empty()) die2("--daemon requires --spool DIR");
    if (poll_ms < 50 || poll_ms > 60000) die2("--poll-ms out of range [50,60000]");
    if (budget_s < 1 || budget_s > BUDGET_MAX_S) die2("--budget-s out of range [1,3600]");
    std::string root = find_root();
    Spool sp = spool_open(spool_dir, true);
    fprintf(stderr, "orreryd v%s: spool=%s poll=%dms budget=%ds %s\n",
            ORRERYD_VERSION, fs::absolute(sp.root).string().c_str(), poll_ms, budget_s,
            drain ? "(drain mode)" : "(watch mode; drop .stop to exit)");
    return daemon_loop(sp, root, poll_ms, budget_s, drain, nullptr);
}
