# IMPLEMENTATION.md — Assignment 12: Function Inlining with Dead Code Elimination

## 1. LLVM APIs Used

| API | Header | Purpose in our pass |
|-----|--------|---------------------|
| `PassInfoMixin<T>` | `llvm/IR/PassManager.h` | Base class for New Pass Manager passes |
| `PreservedAnalyses` | `llvm/IR/PassManager.h` | Return type of `run` indicating what analyses are still valid |
| `ModuleAnalysisManager`| `llvm/IR/PassManager.h` | Provides analyses |
| `llvmGetPassPluginInfo`| `llvm/Passes/PassPlugin.h` | Registers pass with opt's `-passes="inline-dce"` flag |
| `Module` | `llvm/IR/Module.h` | The entire .ll file; iterate with `for (Function &F : M)` |
| `Function` | `llvm/IR/Function.h` | Represents one function definition |
| `Function::isDeclaration()` | `llvm/IR/Function.h` | Returns true if no body (external prototype) |
| `Function::getName()` | `llvm/IR/Function.h` | Returns the function's name string |
| `Function::use_empty()` | `llvm/IR/Function.h` | True if nothing in the module calls this function |
| `Function::eraseFromParent()` | `llvm/IR/Function.h` | Deletes function from module |
| `BasicBlock` | `llvm/IR/BasicBlock.h` | One BB = one entry, one exit, sequential instructions |
| `isa<DbgInfoIntrinsic>` | `llvm/IR/IntrinsicInst.h` | True if the instruction is debug metadata |
| `Instruction` | `llvm/IR/Instructions.h` | One IR instruction (%x = add i32 ...) |
| `dyn_cast<CallBase>` | `llvm/IR/Instructions.h` | Safe RTTI-less cast to CallBase, returns nullptr on failure |
| `CallBase::getCalledFunction()` | `llvm/IR/Instructions.h` | Returns Function* for direct calls, nullptr for indirect |
| `InlineFunction(CI, IFI)` | `llvm/Transforms/Utils/Cloning.h` | Does the actual inlining — replaces call with callee body |
| `InlineFunctionInfo` | `llvm/Transforms/Utils/Cloning.h` | Output struct from InlineFunction() |
| `InlineResult::isSuccess()` | `llvm/Transforms/Utils/Cloning.h` | Did the inlining succeed? |
| `InlineResult::getFailureReason()` | `llvm/Transforms/Utils/Cloning.h` | Why did inlining fail? |
| `SmallVector<T, N>` | `llvm/ADT/SmallVector.h` | Stack-allocated vector for small lists |
| `raw_ostream / errs()` | `llvm/Support/raw_ostream.h` | LLVM's stderr output stream |
| `CallGraph` | `llvm/Analysis/CallGraph.h` | Used to detect cycles and dependencies |

---

## 2. Pass Execution Flow

```
opt loads InlineDCEPass.so
         │
         ▼
opt calls InlineAndDCEPass::run(Module &M, ModuleAnalysisManager &MAM)
         │
         ├─ Phase 1: ANALYZE ──────────────────────────────────────────────
         │     for each Function F in M:
         │       skip if: declaration, main, or part of a cycle (via CallGraph)
         │       compute: instruction_count = non-debug instructions
         │       find:    call_count = |call_sites pointing to F|
         │       compute: cost = instruction_count × call_count
         │       if cost < THRESHOLD → add to ToInline list
         │
         ├─ Phase 2: INLINE ──────────────────────────────────────────────
         │     for each Candidate in ToInline:
         │       find all CallInsts CI pointing to Candidate
         │       for each CI:
         │         InlineFunction(CI, IFI)  ← pastes callee body here
         │
         └─ Phase 3: DELETE ──────────────────────────────────────────────
               do:
                 local_changed = false
                 for each Function F in M:
                   if F.use_empty() (and not main/decl):
                     F.eraseFromParent()  ← removed from module
                     local_changed = true
               while local_changed
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
  for (Use &U : F->uses()) {
    if (auto *CB = dyn_cast<CallBase>(U.getUser())) {
      InlineFunction(*CB, IFI);  // ← modifies the use list while iterating it!
    }
  }

RIGHT (safe):
  // First pass: collect all call sites
  SmallVector<CallBase *, 8> Calls;
  for (Use &U : F->uses()) {
    if (auto *CB = dyn_cast<CallBase>(U.getUser()))
      if (CB->getCalledFunction() == F) Calls.push_back(CB);
  }

  // Second pass: modify safely
  for (CallBase *CB : Calls) {
    if (CB->getParent())
      InlineFunction(*CB, IFI);
  }
```

The inlining loop in Phase 2 performs this exact collection first. It stores all `CallBase` pointers in a `SmallVector`. The subsequent loop calls `InlineFunction` safely because it is iterating over the vector, not the live use list.

