# IMPLEMENTATION.md — Assignment 12: Function Inlining with Dead Code Elimination

## 1. LLVM APIs Used

| API | Header | Purpose in our pass |
|-----|--------|---------------------|
| `ModulePass` | `llvm/Pass.h` | Base class; gives us `runOnModule(Module &M)` |
| `RegisterPass<T>` | `llvm/Pass.h` | Registers pass with opt's `-inline-dce` flag |
| `Module` | `llvm/IR/Module.h` | The entire .ll file; iterate with `for (Function &F : M)` |
| `Function` | `llvm/IR/Function.h` | Represents one function definition |
| `Function::isDeclaration()` | `llvm/IR/Function.h` | Returns true if no body (external prototype) |
| `Function::isVarArg()` | `llvm/IR/Function.h` | True for variadic functions like printf |
| `Function::getName()` | `llvm/IR/Function.h` | Returns the function's name string |
| `Function::use_empty()` | `llvm/IR/Function.h` | True if nothing in the module calls this function |
| `Function::eraseFromParent()` | `llvm/IR/Function.h` | Deletes function from module |
| `BasicBlock` | `llvm/IR/BasicBlock.h` | One BB = one entry, one exit, sequential instructions |
| `BasicBlock::size()` | `llvm/IR/BasicBlock.h` | Number of instructions in the block |
| `Instruction` | `llvm/IR/Instructions.h` | One IR instruction (%x = add i32 ...) |
| `dyn_cast<CallInst>` | `llvm/IR/Instructions.h` | Safe RTTI-less cast to CallInst, returns nullptr on failure |
| `CallInst::getCalledFunction()` | `llvm/IR/Instructions.h` | Returns Function* for direct calls, nullptr for indirect |
| `InlineFunction(CI, IFI)` | `llvm/Transforms/Utils/Cloning.h` | Does the actual inlining — replaces call with callee body |
| `InlineFunctionInfo` | `llvm/Transforms/Utils/Cloning.h` | Output struct from InlineFunction() |
| `InlineResult::isSuccess()` | `llvm/Transforms/Utils/Cloning.h` | Did the inlining succeed? |
| `InlineResult::getFailureReason()` | `llvm/Transforms/Utils/Cloning.h` | Why did inlining fail? |
| `removeUnreachableBlocks(F)` | `llvm/Transforms/Utils/Local.h` | Deletes unreachable basic blocks from a function |
| `SmallVector<T, N>` | `llvm/ADT/SmallVector.h` | Stack-allocated vector for small lists |
| `raw_ostream / errs()` | `llvm/Support/raw_ostream.h` | LLVM's stderr output stream |
| `AnalysisUsage` | `llvm/Pass.h` | Declares what analyses the pass uses/preserves |

---

## 2. Pass Execution Flow

```
opt loads InlineDCEPass.so
         │
         ▼
opt calls InlineAndDCEPass::runOnModule(Module &M)
         │
         ├─ Phase 1: ANALYZE ──────────────────────────────────────────────
         │     for each Function F in M:
         │       skip if: declaration, variadic, main, recursive
         │       compute: instruction_count = Σ BB.size() for BB in F
         │       find:    call_sites = all CallInsts pointing to F
         │       compute: cost = instruction_count × |call_sites|
         │       if cost < THRESHOLD → add to ToInline list
         │
         ├─ Phase 2: INLINE ──────────────────────────────────────────────
         │     for each Candidate in ToInline:
         │       for each CallInst CI in Candidate.CallSites:
         │         InlineFunction(CI, IFI)  ← pastes callee body here
         │         CI is now invalid/gone
         │
         ├─ Phase 3: DELETE ──────────────────────────────────────────────
         │     for each Candidate in ToInline:
         │       if Candidate.Callee->use_empty():
         │         Callee->eraseFromParent()  ← removed from module
         │
         └─ Phase 4: CLEANUP ─────────────────────────────────────────────
               for each Function F in M:
                 removeUnreachableBlocks(F)
```

---

## 3. How InlineFunction() Works Internally

When we call `InlineFunction(*CI, IFI)`, LLVM performs the following steps
internally (you don't need to implement these, but understanding them helps
you reason about what the output IR looks like):

**Step 1: Clone the callee's basic blocks.**  
Every basic block in the callee gets a deep copy inserted into the caller.

**Step 2: Rename all values.**  
The callee's `%variables` are renamed with unique suffixes to avoid conflicts
with the caller's variable names. E.g., if both have `%result`, one becomes
`%result` and the other `%result1`.

**Step 3: Map arguments to actual values.**  
The callee's formal parameters are substituted with the actual arguments from
the call site. If we called `@add(i32 3, i32 4)`, then everywhere the callee
used `%a` it now has `3`, and `%b` becomes `4`.

**Step 4: Handle the return value.**  
The callee's `ret` instruction is converted to a branch into a new
"return block" in the caller. The return value is propagated via a PHI node
back to wherever the call result was used.

**Step 5: Remove the original call instruction.**  
The `CallInst` (`call i32 @add(...)`) is erased. This is why the `CI` pointer
is invalid after `InlineFunction()` returns.

---

## 4. How use_empty() Detects Dead Functions

LLVM maintains a **use-def chain** for every value in the IR. Every time you
write `call i32 @add(...)` in the IR, that instruction is added to `@add`'s
list of "users." The chain is updated automatically as the IR changes.

After `InlineFunction()` removes all `call @add` instructions, `@add` has no
users. `use_empty()` checks this condition in O(1) time by testing whether
the use-list head pointer is null.

This is why we can safely call `eraseFromParent()` immediately after
confirming `use_empty()` — we know no remaining instruction references
the function.

---

## 5. Why -fno-rtti Is Required

LLVM's entire codebase is compiled with `-fno-rtti` (RTTI = Run-Time Type
Information, the mechanism behind C++ `typeid` and `dynamic_cast`).

LLVM uses its own type-safe casting system (`dyn_cast<>`, `isa<>`, `cast<>`)
instead of standard RTTI. These work by checking a built-in `classof()` method
rather than querying the C++ runtime.

If you compile your pass WITH RTTI (the default) but link against an LLVM
that was compiled WITHOUT RTTI, the linker will fail with errors like:

```
undefined reference to `typeinfo for llvm::ModulePass`
```

The `-fno-rtti` flag in CMakeLists.txt prevents this by matching LLVM's
compilation settings.

---

## 6. Iterator Safety: Why Collection Must Precede Modification

```
WRONG (crashes):
  for (Instruction &I : BB) {
    if (auto *CI = dyn_cast<CallInst>(&I)) {
      InlineFunction(*CI, IFI);  // ← CI and the BB's instruction list
                                  //   are modified here, invalidating
                                  //   the range-based for iterator!
    }
  }

RIGHT (safe):
  // First pass: collect all call sites
  SmallVector<CallInst*, 8> ToProcess;
  for (Instruction &I : BB)
    if (auto *CI = dyn_cast<CallInst>(&I))
      ToProcess.push_back(CI);

  // Second pass: modify safely
  for (CallInst *CI : ToProcess)
    InlineFunction(*CI, IFI);  // ← no active iterator over BB's list
```

Our `findCallSites()` function performs the collection. The inlining loop in
Phase 2 then processes the collected `SmallVector<CallInst*>`. The two loops
are entirely separate, making iterator invalidation impossible.

---

## 7. Dead Block Elimination Details

`removeUnreachableBlocks(F)` works by:

1. Starting at the function's entry block
2. Running a reachability analysis (similar to BFS/DFS over the CFG)
3. Marking every block that can be reached from the entry by following
   possible branch targets
4. Any block NOT in the reachable set is "dead" — it cannot execute
5. Dead blocks are removed, and any PHI nodes in their successors that
   reference them are updated

After inlining, dead blocks typically arise when a conditional branch
in the callee becomes a constant branch in the caller. For example, if
the callee had `br i1 %cond, label %if, label %else` and the constant
propagation pass (not us) resolves `%cond` to `false`, then the `%if`
block becomes unreachable.

Even without constant propagation, inlining can create structural dead
blocks (e.g., a "pre-return" block that has no predecessors after the
call site is replaced).
