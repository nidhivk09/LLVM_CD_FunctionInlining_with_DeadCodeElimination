//===----------------------------------------------------------------------===//
// Assignment 12: Function Inlining + Dead Code Elimination
// File: src/InlinePass.cpp
// Uses CallGraph as required by the assignment spec.
//===----------------------------------------------------------------------===//

#include "llvm/IR/Function.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Transforms/Utils/Cloning.h"
#include "llvm/Transforms/Utils/Local.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Analysis/CallGraph.h"

using namespace llvm;

static const unsigned INLINE_THRESHOLD = 45;

namespace {

struct InlineAndDCEPass : public PassInfoMixin<InlineAndDCEPass> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &MAM) {
    bool Changed = false;
    SmallVector<Function *, 16> ToInline;

    // ── Build CallGraph directly (works on all LLVM versions) ───────────
    // We construct it ourselves rather than using MAM.getResult<CallGraphAnalysis>
    // to avoid registration differences between LLVM versions.
    CallGraph CG(M);

    // ── PHASE 1: IDENTIFY candidates via CallGraph ───────────────────────
    for (Function &F : M) {
      if (F.isDeclaration() || F.getName() == "main") continue;

      CallGraphNode *CGN = CG[&F];

      // 1. Recursion check via CallGraph edges
      bool Recursive = false;
      for (auto &CallRecord : *CGN) {
        if (CallRecord.second == CGN) {
          Recursive = true;
          break;
        }
      }
      if (Recursive) {
        errs() << "  @" << F.getName() << ": recursive -> blocked\n";
        continue;
      }

      // 2. Cost model — count non-debug instructions
      unsigned InstCount = 0;
      for (auto &BB : F)
        for (auto &I : BB)
          if (!isa<DbgInfoIntrinsic>(&I)) InstCount++;

      // 3. Call frequency — count call sites via CallGraph
      unsigned CallCount = 0;
      for (auto &KV : CG) {
        CallGraphNode *CallerNode = KV.second.get();
        if (!CallerNode->getFunction()) continue;
        if (CallerNode->getFunction() == &F) continue;
        for (auto &CallRecord : *CallerNode)
          if (CallRecord.second == CGN) CallCount++;
      }

      unsigned Cost = InstCount * CallCount;
      if (CallCount > 0 && Cost < INLINE_THRESHOLD) {
        errs() << "  @" << F.getName() << ": cost " << InstCount
               << "x" << CallCount << "=" << Cost
               << " < " << INLINE_THRESHOLD << " -> will inline\n";
        ToInline.push_back(&F);
      } else if (CallCount > 0) {
        errs() << "  @" << F.getName() << ": cost " << InstCount
               << "x" << CallCount << "=" << Cost
               << " >= " << INLINE_THRESHOLD << " -> skipped\n";
      }
    }

    // ── PHASE 2: INLINE sites ────────────────────────────────────────────
    for (Function *F : ToInline) {
      // Collect ALL call sites first into a separate vector.
      // F->users() becomes invalid as soon as the first InlineFunction()
      // replaces a call instruction — collect eagerly before touching anything.
      SmallVector<CallBase *, 8> Calls;
      for (Use &U : F->uses()) {
        auto *CB = dyn_cast<CallBase>(U.getUser());
        // Only inline direct calls where F is the callee, not a function pointer
        if (CB && CB->getCalledFunction() == F)
          Calls.push_back(CB);
      }

      for (CallBase *CB : Calls) {
        // Guard: the call may have been removed by a prior inline in this loop
        if (CB->getParent() == nullptr) continue;
        InlineFunctionInfo IFI;
        if (InlineFunction(*CB, IFI).isSuccess())
          Changed = true;
      }
    }

    // ── PHASE 3: DCE — remove functions with no remaining callers ────────
    SmallVector<Function *, 16> DeadPool;
    for (Function &F : M) {
      if (F.isDeclaration() || F.getName() == "main") continue;
      if (F.use_empty()) DeadPool.push_back(&F);
    }
    for (Function *F : DeadPool) {
      errs() << "  @" << F->getName() << ": no uses -> deleted\n";
      F->eraseFromParent();
      Changed = true;
    }

    // ── PHASE 4: Remove unreachable basic blocks ──────────────────────────
    for (Function &F : M)
      if (!F.isDeclaration())
        Changed |= removeUnreachableBlocks(F);

    return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
  }

  static bool isRequired() { return true; }
};

} // end anonymous namespace

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "InlineDCEPass", LLVM_VERSION_STRING,
    [](PassBuilder &PB) {
      PB.registerPipelineParsingCallback(
        [](StringRef Name, ModulePassManager &MPM,
           ArrayRef<PassBuilder::PipelineElement>) -> bool {
          if (Name == "inline-dce") {
            MPM.addPass(InlineAndDCEPass());
            return true;
          }
          return false;
        });
    }
  };
}