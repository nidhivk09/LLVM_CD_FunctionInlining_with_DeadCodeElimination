import re, json, difflib
from pathlib import Path

TESTS_DIR    = Path("tests")
OUTPUT_DIR   = Path("tests/output")

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
                and "llvm.dbg" not in s and "llvm.lifetime" not in s):
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

def analyse_functions(before_ir):
    functions = extract_functions(before_ir)
    results = []
    edges = []
    for name, body in functions.items():
        callees = re.findall(r"\bcall\b[^@]*@(\w+)\s*\(", body)
        for callee in callees:
            edges.append({"source": name, "target": callee})

        if name == "main": continue
        instrs = count_real_instructions(body)
        calls  = count_call_sites(name, before_ir)
        cost   = instrs * calls
        cycle  = has_cycle(name, functions)
        
        results.append({
            "name": name,
            "instrs": instrs,
            "calls": calls,
            "cost": cost,
            "cycle": cycle
        })
    return results, edges

def main():
    files = sorted([f.name for f in TESTS_DIR.glob("*.c")])
    results_map = {}
    
    for filename in files:
        path = TESTS_DIR / filename
        stem = path.stem
        
        ll_path = TESTS_DIR / f"{stem}.ll"
        if not ll_path.exists(): continue
        before_ir = ll_path.read_text()
        
        after_path    = OUTPUT_DIR / f"{stem}_after.ll"
        baseline_path = OUTPUT_DIR / f"{stem}_baseline.ll"
        after_ir  = after_path.read_text()    if after_path.exists()    else None
        base_ir   = baseline_path.read_text() if baseline_path.exists() else None
        
        funcs, edges = analyse_functions(before_ir)
        
        inlined_ir = None
        if after_ir:
            before_funcs = extract_functions(before_ir)
            after_funcs = extract_functions(after_ir)
            inlined_ir = after_ir
            for f_name, f_body in before_funcs.items():
                if f_name not in after_funcs:
                    inlined_ir += "\n\n" + f_body

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

        before_lines_full = before_ir.splitlines() if before_ir else []
        after_lines_full = after_ir.splitlines() if after_ir else []

        sync_before, sync_after = [], []
        if after_ir:
            matcher = difflib.SequenceMatcher(None, before_lines_full, after_lines_full)
            opcodes = matcher.get_opcodes()
            
            merged_opcodes = []
            i = 0
            while i < len(opcodes):
                tag, i1, i2, j1, j2 = opcodes[i]
                if tag == 'delete' and i + 1 < len(opcodes) and opcodes[i+1][0] == 'insert':
                    _, _, _, next_j1, next_j2 = opcodes[i+1]
                    merged_opcodes.append(('replace', i1, i2, next_j1, next_j2))
                    i += 2
                elif tag == 'insert' and i + 1 < len(opcodes) and opcodes[i+1][0] == 'delete':
                    _, next_i1, next_i2, _, _ = opcodes[i+1]
                    merged_opcodes.append(('replace', next_i1, next_i2, j1, j2))
                    i += 2
                else:
                    merged_opcodes.append(opcodes[i])
                    i += 1

            for tag, i1, i2, j1, j2 in merged_opcodes:
                if tag == 'equal':
                    for i, j in zip(range(i1, i2), range(j1, j2)):
                        sync_before.append({"text": before_lines_full[i], "type": "equal"})
                        sync_after.append({"text": after_lines_full[j], "type": "equal"})
                elif tag == 'replace':
                    b_lines = before_lines_full[i1:i2]
                    a_lines = after_lines_full[j1:j2]
                    for idx in range(max(len(b_lines), len(a_lines))):
                        if idx < len(b_lines):
                            sync_before.append({"text": b_lines[idx], "type": "delete"})
                        else:
                            sync_before.append({"text": " ", "type": "empty"})
                        if idx < len(a_lines):
                            sync_after.append({"text": a_lines[idx], "type": "insert"})
                        else:
                            sync_after.append({"text": " ", "type": "empty"})
                elif tag == 'delete':
                    for i in range(i1, i2):
                        sync_before.append({"text": before_lines_full[i], "type": "delete"})
                        sync_after.append({"text": " ", "type": "empty"})
                elif tag == 'insert':
                    for j in range(j1, j2):
                        sync_before.append({"text": " ", "type": "empty"})
                        sync_after.append({"text": after_lines_full[j], "type": "insert"})

        c_path = TESTS_DIR / f"{stem}.c"
        c_code = c_path.read_text() if c_path.exists() else None
        
        c_after_path = OUTPUT_DIR / f"{stem}_after.c"
        c_after_code = c_after_path.read_text() if c_after_path.exists() else None

        results_map[filename] = {
            "c_code":     c_code,
            "c_after_code": c_after_code,
            "before_ir":  before_ir,
            "inlined_ir": inlined_ir,
            "after_ir":   after_ir,
            "base_ir":    base_ir,
            "functions":  funcs,
            "call_graph": edges,
            "metrics":    metrics,
            "sync_before": sync_before,
            "sync_after":  sync_after,
        }

    final_data = {
        "files": files,
        "results": results_map
    }
    
    Path("static").mkdir(exist_ok=True)
    with open("static/data.js", "w") as f:
        f.write("window.LLVM_DATA = " + json.dumps(final_data) + ";\n")
    print(f"Exported {len(files)} files to static/data.js")

if __name__ == "__main__":
    main()
