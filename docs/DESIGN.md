# DESIGN.md — Assignment 12: Function Inlining with Dead Code Elimination

## 1. Overview

This document describes the design decisions behind our LLVM ModulePass that
performs function inlining followed by dead code elimination. The pass
implements a cost-heuristic-based inlining strategy combined with two
safety guards: declaration skipping, and cycle/recursive function detection.

---

## 2. Why ModulePass and Not FunctionPass?

LLVM offers two primary pass granularities. A `FunctionPass` processes one
function in isolation; a `ModulePass` sees the entire translation unit at once.

We require `ModulePass` for two fundamental reasons:

**Cross-function visibility for call frequency counting.** Our cost formula
is `cost = instruction_count × call_frequency`. Computing `call_frequency`
requires counting how many times a function is called across ALL functions in
the module. A `FunctionPass` only sees one caller at a time and cannot produce
a module-wide count.

**Function deletion requires module-level access.** After inlining all call
sites of a function, we call `F.eraseFromParent()` to remove the now-dead
original function. This operation removes the function from the `Module` object.
A `FunctionPass` does not have access to the enclosing `Module`, so deletion
is impossible from within one.

---

## 3. The Cost Heuristic: Why `instructions × call_frequency`?

### The problem with instruction count alone

A naive heuristic might be: "inline functions with fewer than N instructions."
This fails to account for how many copies of those instructions will be
created. A 5-instruction function called 100 times would add 500 instructions
to the binary — worse than a 40-instruction function called once.

### The problem with call frequency alone

Counting only how many times a function is called ignores how expensive each
copy is. Inlining a 500-instruction function called once is far more costly
than inlining a 2-instruction function called once.

### Why the product captures both dimensions

`cost = instruction_count × call_frequency` represents the **total number of
instruction copies** that inlining would add to the module. This directly
predicts the binary size growth from inlining:

| Function | Instructions | Calls | Cost | Binary Growth |
|----------|-------------|-------|------|---------------|
| @add     | 2           | 1     | 2    | ~2 instructions added |
| @square  | 2           | 5     | 10   | ~10 instructions added |
| @heavy   | 56          | 1     | 56   | ~56 instructions added |
| @compute | 10          | 8     | 80   | ~80 instructions added |

With threshold = 45, the first two are inlined and the last two are skipped.
This gives us predictable binary size control.

---

## 4. Why Block Recursive Functions Before Cost Analysis?

Inlining a recursive function would mean pasting its body into the call site.
But the body itself contains a call to the same function. If we pasted that
too, we would have another call to paste, and so on — creating an infinite
expansion at compile time.

Our cycle detection using a CallGraph Worklist runs first (before cost analysis) to catch
this case. It walks the call graph starting from the function to see if it can reach itself. If a cycle is found, the function is blocked immediately.

---

## 5. Alternative Heuristics Considered

**Fixed instruction count threshold only.** Simpler but ignores call frequency.
Chosen against because of the binary bloat problem described above.

**Loop presence detection.** Don't inline any function that contains a loop
(a back-edge in the CFG). Inlining loop-containing functions can cause
significant code size growth and may worsen instruction cache behavior.
Not implemented here for simplicity, but documented as a natural extension.

**Call depth heuristic.** Don't inline functions that are deeper than D levels
down in the call stack. Prevents large chains of nested inlining. Not
implemented because it requires call graph depth traversal.

**Profile-guided inlining.** Use runtime profiling data to identify the
actually-hot call sites and inline only those. Highly effective but requires
a profiling infrastructure. Out of scope for this assignment.

---

## 6. Cycle Detection: Handling Mutual Recursion

A simple direct recursion check (checking if function A calls itself) is insufficient for complex programs. It does NOT detect **mutual** recursion, where function A calls function B and function B calls function A.

To properly detect all forms of recursion (including mutual recursion), our pass uses the LLVM `CallGraph` analysis:
1. We retrieve the `CallGraphNode` for the current function.
2. We run a worklist-based search following the outgoing call edges.
3. If the search ever re-visits the starting function's node, a cycle exists.

Because of this robust detection mechanism, mutual recursion is correctly identified and blocked. The `mutual_recursive.ll` test case in `tests/` demonstrates that mutually recursive functions are properly blocked from inlining.

---

## 7. Threshold Sensitivity Analysis

| Threshold | @tiny (cost 1) | @square (cost 5) | @big (cost 47) | @heavy_compute (cost 56) | Trade-off |
|-----------|----------------|------------------|----------------|--------------------------|-----------|
| 1         | Skip           | Skip             | Skip           | Skip                     | Too conservative, no inlining |
| 3         | Inline         | Skip             | Skip           | Skip                     | Only 1-instruction functions inline |
| 10        | Inline         | Inline           | Skip           | Skip                     | Small utilities inline |
| 45 (default)| Inline       | Inline           | Skip           | Skip                     | Good balance |
| 50        | Inline         | Inline           | Inline         | Skip                     | Aggressive, binary grows more |
| 100       | Inline         | Inline           | Inline         | Inline                   | Very aggressive, potential size explosion |

The default threshold of 45 was chosen because it correctly handles the
10 test cases in this assignment while representing a realistic production
trade-off between binary size and runtime performance.

---

## 8. Safety: Collection Before Modification

The pass separates its work into two distinct loops. In the first loop
(Phase 1), we collect pointers to all `CallInst` objects we plan to inline.
In the second loop (Phase 2), we call `InlineFunction()` on each one.

This separation is essential. `InlineFunction()` modifies the IR in place:
it removes the `CallInst` and inserts new basic blocks. If we were still
iterating over the function's instruction list while calling `InlineFunction()`,
our iterator would point to freed memory → undefined behavior or crash.

Collecting all pointers first, then modifying, makes the pass safe.

---

## 9. Handling LLVMContext Boundaries and Attributes

When compiling LLVM passes out-of-tree as dynamic libraries (`.dylib` or `.so`) against a statically compiled LLVM build, the plugin sometimes receives its own distinct copy of core static variables and context structures (such as `LLVMContextImpl`).

By default, the `InlineFunction()` API attempts to insert `llvm.lifetime.start` and `llvm.lifetime.end` intrinsic calls for any dynamically allocated stack variables it brings into the caller. During this synthesis, it uses the plugin's internal `LLVMContext` to create the intrinsic's `AttributeList`. When the pass returns control to the host executable (`opt`), the LLVM verifier notices that these new attributes belong to a different context than the `Module` being verified, triggering a fatal error (`Attribute list does not match Module context!`).

To solve this, our design disables the automatic generation of lifetime intrinsics by passing `InsertLifetime = false` to `InlineFunction()`. In addition, we proactively strip any existing clang-generated lifetime intrinsics during Phase 0 to ensure the IR remains clean and the verifier passes on all platforms without crashing.
