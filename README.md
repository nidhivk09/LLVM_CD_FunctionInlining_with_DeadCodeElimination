# Assignment 12: Function Inlining with Dead Code Elimination

An LLVM `ModulePass` that selectively inlines small functions using a cost
heuristic (`instructions × call_sites`), then removes dead functions and
unreachable basic blocks.

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

Expected result: **5/5 PASS**.

---

## Running a Single Test Manually

```bash
# macOS
LLVM="/Volumes/..."

"$LLVM/bin/opt" \
  --enable-new-pm=0 \
  -load "./pass-build/InlineDCEPass.dylib" \
  -inline-dce -S \
  tests/small_func.ll \
  -o /tmp/out.ll

cat /tmp/out.ll
```

> **Why `--enable-new-pm=0`?**  
> LLVM 17+ defaults to the "new pass manager." Our pass uses the
> **legacy pass manager** API (`ModulePass` / `RegisterPass`). Without
> this flag, `opt` ignores the `-load` plugin entirely and the pass
> never runs — no error, just no transformation. This flag switches opt
> back to the legacy manager where `RegisterPass<>` works correctly.

---

## What the Pass Does

The pass runs 4 phases on any `.ll` file:

| Phase | What happens |
|-------|-------------|
| **1 — Analyze** | For each function: check for recursion, count instructions, find call sites, compute `cost = instrs × sites` |
| **2 — Inline** | Call `InlineFunction()` at every approved site (`cost < 50`) |
| **3 — Delete** | Erase original functions that now have zero callers |
| **4 — Clean up** | Remove unreachable basic blocks via `removeUnreachableBlocks()` |

---

## Expected Test Results

| Test | Functions in | Functions out | Why |
|------|-------------|--------------|-----|
| `small_func` | 2 | 1 | `@add` (cost 2) inlined and deleted |
| `large_func` | 2 | 2 | `@heavy_compute` (cost 56) skipped |
| `recursive_func` | 2 | 2 | `@factorial` blocked (direct recursion) |
| `multi_call` | 2 | 1 | `@square` inlined at all 5 sites |
| `mixed` | 4 | 3 | `@tiny` inlined; `@big` skipped; `@recur` blocked |

---

## Project Structure

```
src/
  InlinePass.cpp        The pass implementation
tests/
  small_func.ll         Test 1: tiny function → should inline
  large_func.ll         Test 2: large function → should skip
  recursive_func.ll     Test 3: recursive → should block
  multi_call.ll         Test 4: called 5 times → all sites inlined
  mixed.ll              Test 5: integration test
  mutual_recursive.ll   Bonus: mutual recursion failure case
docs/
  DESIGN.md             Cost heuristic rationale, alternatives
  IMPLEMENTATION.md     LLVM APIs, iterator safety, deletion
  EVALUATION.md         Test results, baseline comparison, thresholds
CMakeLists.txt          Build configuration
build.sh                Build the plugin
run.sh                  Run all tests
```

---

## Troubleshooting

**"Pass not found" or no transformation happens**  
→ You forgot `--enable-new-pm=0`. Add it before `-load`.

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
