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

Expected result: **10/10 PASS**.

---

## Running a Single Test Manually

```bash
# macOS
LLVM="/Volumes/..."

"$LLVM/bin/opt" \
  -load-pass-plugin "./pass-build/InlineDCEPass.dylib" \
  -passes="inline-dce" \
  -S tests/small_func.ll \
  -o /tmp/out.ll

cat /tmp/out.ll
```

---

## What the Pass Does

The pass runs 3 phases on any `.ll` file:

| Phase | What happens |
|-------|-------------|
| **1 — Analyze** | For each function: check for recursion/cycles, count instructions, compute `cost = instrs × call_count` |
| **2 — Inline** | Call `InlineFunction()` at every approved call site (`cost < 45`) |
| **3 — Delete** | Erase dead functions that have zero callers (repeats until stable) |

---

## Expected Test Results

| Test | Functions in | Functions out | Why |
|------|-------------|--------------|-----|
| `small_func` | 2 | 1 | `@add` (cost 2) inlined and deleted |
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
