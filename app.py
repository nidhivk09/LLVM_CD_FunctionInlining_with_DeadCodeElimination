# Flask backend to serve the visualizer UI and analyze LLVM IR inlining decisions.
import re, subprocess, json, difflib
from pathlib import Path
from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__, static_folder="static")

TESTS_DIR    = Path("tests")
OUTPUT_DIR   = Path("tests/output")
BUILD_SCRIPT = Path("./build.sh")
RUN_SCRIPT   = Path("./run.sh")
THRESHOLD    = 45

def extract_functions(ir):
    funcs = {}
    pattern = re.compile(r"(define\b[^\n]*@(\w+)[^\n]*\{.*?\n\})", re.DOTALL)
    for m in pattern.finditer(ir):
        funcs[m.group(2)] = m.group(1)
    return funcs

def count_real_instructions(body):
    count = 0
    for line in body.splitlines():
        s = line.strip()
        if (s and not s.startswith(";") and not s.startswith("define")
                and s != "}" and not re.match(r"^\w[\w.]*:$", s)
                and "llvm.dbg" not in s):
            count += 1
    return count

def count_call_sites(name, ir):
    return len(re.findall(rf"\bcall\b[^@]*@{re.escape(name)}\s*\(", ir))

def has_cycle(name, functions):
    visited, queue = set(), []
    for callee in re.findall(r"\bcall\b[^@]*@(\w+)\s*\(", functions.get(name, "")):
        queue.append(callee)
    while queue:
        current = queue.pop()
        if current == name: return True
        if current in visited: continue
        visited.add(current)
        for callee in re.findall(r"\bcall\b[^@]*@(\w+)\s*\(", functions.get(current, "")):
            if callee not in visited: queue.append(callee)
    return False

def analyse_decisions(before_ir, threshold):
    functions = extract_functions(before_ir)
    results = []
    for name, body in functions.items():
        if name == "main": continue
        instrs = count_real_instructions(body)
        calls  = count_call_sites(name, before_ir)
        cost   = instrs * calls
        cycle  = has_cycle(name, functions)
        if cycle:
            decision, reason, cost_str = "BLOCKED", "cycle detected in call graph", "—"
        elif calls == 0:
            decision, reason, cost_str = "SKIP", "0 call sites in module", "0"
        elif cost >= threshold:
            decision, reason, cost_str = "SKIP", f"cost {cost} ≥ threshold {threshold}", str(cost)
        else:
            decision, reason, cost_str = "INLINE", f"cost {cost} < threshold {threshold}", str(cost)
        results.append({"name": name, "instrs": instrs, "calls": calls,
                        "cost": cost, "cost_str": cost_str, "cycle": cycle,
                        "decision": decision, "reason": reason})
    return results

@app.route("/")
def index():
    return send_from_directory("static", "index.html")

@app.route("/api/files")
def list_files():
    files = sorted([f.name for f in TESTS_DIR.glob("*.ll")])
    return jsonify(files)

@app.route("/api/analyse")
def analyse():
    filename  = request.args.get("file", "")
    threshold = int(request.args.get("threshold", THRESHOLD))
    path = TESTS_DIR / filename
    if not path.exists(): return jsonify({"error": "file not found"}), 404
    before_ir = path.read_text()
    stem = path.stem
    after_path    = OUTPUT_DIR / f"{stem}_after.ll"
    baseline_path = OUTPUT_DIR / f"{stem}_baseline.ll"
    after_ir  = after_path.read_text()    if after_path.exists()    else None
    base_ir   = baseline_path.read_text() if baseline_path.exists() else None
    decisions = analyse_decisions(before_ir, threshold)

    metrics = None
    if after_ir:
        lb = before_ir.count("\n"); la = after_ir.count("\n")
        metrics = {
            "funcs_before": len(re.findall(r"^define\b", before_ir, re.MULTILINE)),
            "funcs_after":  len(re.findall(r"^define\b", after_ir,  re.MULTILINE)),
            "calls_before": len(re.findall(r"\bcall\b",  before_ir)),
            "calls_after":  len(re.findall(r"\bcall\b",  after_ir)),
            "pct": round((1 - la / max(lb, 1)) * 100, 1),
        }

    before_lines = [l.strip() for l in before_ir.splitlines() if l.strip()]
    after_lines  = [l.strip() for l in after_ir.splitlines() if l.strip()] if after_ir else []

    deleted_lines, added_lines = [], []
    if after_ir:
        matcher = difflib.SequenceMatcher(None, before_lines, after_lines)
        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag in ('delete', 'replace'):
                deleted_lines.extend(before_lines[i1:i2])
            if tag in ('insert', 'replace'):
                added_lines.extend(after_lines[j1:j2])

    return jsonify({
        "before_ir":  before_ir,
        "after_ir":   after_ir,
        "base_ir":    base_ir,
        "decisions":  decisions,
        "metrics":    metrics,
        "deleted":    deleted_lines,
        "added":      added_lines,
    })

@app.route("/api/build", methods=["POST"])
def build():
    res = subprocess.run(["bash", str(BUILD_SCRIPT)], capture_output=True, text=True)
    return jsonify({"ok": res.returncode == 0, "output": res.stderr[-1000:]})

@app.route("/api/run", methods=["POST"])
def run_all():
    res = subprocess.run(["bash", str(RUN_SCRIPT)], capture_output=True, text=True)
    return jsonify({"ok": res.returncode == 0, "output": res.stdout[-2000:]})

if __name__ == "__main__":
    Path("static").mkdir(exist_ok=True)
    app.run(debug=True, port=5000)