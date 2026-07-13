# Assignment 12: Function Inlining with Dead Code Elimination

An LLVM `ModulePass` that selectively inlines small functions using a cost
heuristic (`instructions × call_sites`), then removes dead functions and 
unreachable basic blocks.

---

## Table of Contents

- [Quick Start](#quick-start)
  - [Step 1 — Set your LLVM build path](#step-1--edit-your-llvm-build-path)
  - [Step 2 — Build](#step-2--build)
  - [Step 3 — Run all tests](#step-3--run-all-tests)
  - [Step 4 — Run the Web UI](#step-4--run-the-web-ui)
- [Running a Single Test Manually](#running-a-single-test-manually)
- [What the Pass Does](#what-the-pass-does)
- [Expected Test Results](#expected-test-results)
- [Screenshots](#screenshots)
- [Project Structure](#project-structure)
  - [`src/InlinePass.cpp`](src/InlinePass.cpp)
  - [`tests/`](tests/)
  - [`docs/DESIGN.md`](docs/DESIGN.md)
  - [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md)
  - [`docs/EVALUATION.md`](docs/EVALUATION.md)
  - [`static/index.html`](static/index.html)
  - [`app.py`](app.py)
  - [`CMakeLists.txt`](CMakeLists.txt)
  - [`build.sh`](build.sh)
  - [`run.sh`](run.sh)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Step 1 — Edit your LLVM build path

Open `build.sh` and `run.sh` and set `DEFAULT_LLVM_BUILD` to wherever your
LLVM build lives. **Both files must have the same path.**

```bash
# macOS example (path with a space — keep the quotes!):
DEFAULT_LLVM_BUILD="/Volumes/..."

# Linux example:
DEFAULT_LLVM_BUILD="/home/yourname/llvm-project/build"
```

Alternatively, export it as an environment variable so you never have to
edit any file:

```bash
export LLVM_BUILD="/Volumes/..."
```

### Step 2 — Build

```bash
chmod +x build.sh run.sh
./build.sh
```

Output: `pass-build/InlineDCEPass.dylib` (macOS) or `.so` (Linux).

### Step 3 — Run all tests

```bash
./run.sh
```

Expected result: **10/10 PASS**.

### Step 4 — Run the Web UI

The project includes a web interface to visualize inlining decisions and LLVM IR changes.

```bash
# Install dependencies if needed
pip install flask

# Run the Flask app
python app.py
```

Then open `http://localhost:5000` in your browser. The frontend UI is served from [`static/index.html`](static/index.html).

---

## Running a Single Test Manually

```bash
# macOS
LLVM="/Volumes/..."

# 1. Compile C to LLVM IR
"$LLVM/bin/clang" -O0 -Xclang -disable-O0-optnone -emit-llvm -S tests/small_func.c -o tests/ll/small_func.ll

# 2. Run the pass
"$LLVM/bin/opt" \
  -load-pass-plugin "./pass-build/InlineDCEPass.dylib" \
  -passes="inline-dce" \
  -S tests/ll/small_func.ll \
  -o /tmp/out.ll

cat /tmp/out.ll
```

---

## What the Pass Does

The pass runs 4 phases on any `.ll` file:

| Phase | What happens |
|-------|-------------|
| **0 — Pre-clean** | Erases existing `llvm.lifetime` intrinsic calls from the clang-generated IR to avoid cross-context verifier failures. |
| **1 — Analyze** | For each function: check for recursion/cycles, count instructions, compute `cost = instrs × call_count` |
| **2 — Inline** | Call `InlineFunction()` at every approved call site (`cost < 45`) |
| **3 — Delete** | Erase dead functions that have zero callers (repeats until stable) |

---

## Expected Test Results

| Test | Functions in | Functions out | Why |
|------|-------------|--------------|-----|
| `small_func` | 2 | 1 | `@add` (cost 1) inlined and deleted |
| `large_func` | 2 | 2 | `@heavy_compute` (cost 56) skipped |
| `recursive_func` | 2 | 2 | `@factorial` blocked (cycle detected) |
| `multi_call` | 2 | 1 | `@square` inlined at all 5 sites |
| `mixed` | 4 | 3 | `@tiny` inlined; `@big` skipped; `@recur` blocked |
| `single_use` | 2 | 1 | `@double` inlined and deleted |
| `multi_func` | 3 | 1 | `@add_one` and `@times_two` both inlined |
| `mutual_recursive` | 3 | 3 | `@is_even` and `@is_odd` blocked (cycle detected) |
| `mixed_recursive` | 3 | 2 | `@fib` blocked, `@negate` inlined |
| `chain_inline` | 4 | 1 | `@funcA->B->C` collapsed into main |

---

## Screenshots

Screenshots are stored in [`docs/Screenshots/`](docs/Screenshots/).

### 1. Terminal — Build
Run `./build.sh`, showing the successful build output ending with `Build successful! Plugin: ./pass-build/InlineDCEPass.dylib`.

![Terminal - Build Run](docs/Screenshots/Terminal%20-%20Build%20Run.png)

### 2. Terminal — Full Test Run
Run `./run.sh`, showing all 10 tests passing with the baseline comparison table at the bottom.

![Terminal - Full Test Run](docs/Screenshots/Terminal%20-%20Full%20Test%20Run.png)

### 3. Terminal — Working Case (zoom in)
Crop/zoom into a clean inline case (e.g., `small_func` or `chain_inline`). Shows `@add: no uses -> deleted`, functions before/after count, IR verify valid, PASS.

![Terminal - Working Case](docs/Screenshots/Terminal%20-%20Working%20Case.png)

### 4. Terminal — Failure/Blocked Case (zoom in)
Crop/zoom into `recursive_func` or `mutual_recursive`. Shows the blocked decision, functions unchanged, IR verify valid, PASS.

![Terminal - Blocked Cases](docs/Screenshots/Terminal%20-%20Failure:%20Blocked%20cases.png)

### 5. Web UI — IR Viewer tab
Open `http://localhost:5000`, select `chain_inline.ll`. Shows the decision cards (INLINE for all three), the before/after IR panels side by side with diff highlighting, and the metrics row showing 4→1 functions.

![Web UI - IR Viewer tab](docs/Screenshots/Web%20UI%20-%20IR%20Viewer%20tab.png)

### 6. Web UI — Report tab
Switch to the Report tab with any test selected. Shows the trade-off analysis and pass outcome section.

![Web UI - Report tab](docs/Screenshots/Web%20UI%20-%20Report%20tab.png)

### 7. Web UI — All Tests tab
Switch to the Summary/All Tests tab. Shows the full cross-test table with all 10 files, their inlined/skipped/blocked columns, and IR reduction percentages.

![Web UI - All tests tab](docs/Screenshots/Web%20UI%20-%20All%20tests%20tab.png)

### 8. Proof of Integration
Running on GitHub Actions (CI).

![GitHub - Proof of Integration](docs/Screenshots/Github%20-%20Proof%20of%20Integration.png)

---

## Project Structure

```
src/
  InlinePass.cpp        The pass implementation
tests/
  small_func.c          Test 1: tiny function → should inline
  large_func.c          Test 2: large function → should skip
  recursive_func.c      Test 3: recursive → should block
  multi_call.c          Test 4: called 5 times → all sites inlined
  mixed.c               Test 5: integration test
  single_use.c          Test 6: single use function inlined
  multi_func.c          Test 7: multiple functions inlined
  mutual_recursive.c    Test 8: mutual recursion failure case
  mixed_recursive.c     Test 9: mixed recursive blocked
  chain_inline.c        Test 10: chain inline collapsed
  ll/                   Compiled LLVM IR files from clang
  output/               Output IR files and baselines generated by the pass
docs/
  DESIGN.md             Cost heuristic rationale, alternatives
  IMPLEMENTATION.md     LLVM APIs, iterator safety, deletion
  EVALUATION.md         Test results, baseline comparison, thresholds
  Screenshots/          Images demonstrating terminal execution and Web UI
static/
  index.html            Web frontend UI
app.py                  Flask web application backend
CMakeLists.txt          Build configuration
build.sh                Build the plugin
run.sh                  Run all tests
README.md               Project documentation
```

---

## Troubleshooting

**"Pass not found" or no transformation happens**  
→ Ensure you are using `-load-pass-plugin` and `-passes="inline-dce"` with the new pass manager.

**"opt not found" or cmake fails**  
→ Check `DEFAULT_LLVM_BUILD` in `build.sh`. It must point to the directory
that contains `bin/opt`.

**Linker error mentioning `typeinfo` or `vtable`**  
→ Your LLVM was compiled without RTTI. The `-fno-rtti` flag in CMakeLists.txt
handles this — verify it's present.

**Path with spaces breaks cmake**  
→ Always quote `"$LLVM_BUILD"` in shell commands. The scripts already do this.

**macOS: wrong architecture (arm64 vs x86_64)**  
→ If your LLVM was built for `AArch64` and your compiler targets `x86_64`,
add `-DCMAKE_OSX_ARCHITECTURES=arm64` to the cmake command in `build.sh`.

**"Attribute list does not match Module context! ... llvm.lifetime" crash**
→ This happens when `InlineFunction()` tries to insert lifetime intrinsics into the IR, using the dynamically loaded plugin's static `LLVMContextImpl`, which conflicts with the host `opt` executable's context. The current implementation passes `InsertLifetime = false` to `InlineFunction()` to fix this issue.
