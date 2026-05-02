#include "llvm/IR/Function.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/PassManager.h"

// Robust PassPlugin Include
#if __has_include("llvm/Passes/PassPlugin.h")
#  include "llvm/Passes/PassPlugin.h"
#elif __has_include("llvm/Plugins/PassPlugin.h")
#  include "llvm/Plugins/PassPlugin.h"
#else
#  include "PassPlugin.h"
#endif

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
    
    // We use a local scope to ensure CG is destroyed before we start 
    // erasing functions from the module in Phase 3.
    {
      CallGraph CG(M); 
      SmallVector<Function *, 16> ToInline;

      // ── PHASE 1: IDENTIFY ──────────────────────────────────────────────
      for (Function &F : M) {
        if (F.isDeclaration() || F.getName() == "main") continue;

        CallGraphNode *CGN = CG[&F];
        if (!CGN) continue;

        bool InCycle = false;
        SmallPtrSet<CallGraphNode *, 8> Visited;
        SmallVector<CallGraphNode *, 8> Worklist;
        
        for (auto &IT : *CGN) {
            if (IT.second) Worklist.push_back(IT.second);
        }

        while (!Worklist.empty()) {
            CallGraphNode *N = Worklist.pop_back_val();
            if (N == CGN) { InCycle = true; break; }
            if (N && Visited.insert(N).second) {
                for (auto &Edge : *N) 
                    if (Edge.second) Worklist.push_back(Edge.second);
            }
        }

        if (InCycle) continue;

        unsigned InstCount = 0;
        for (auto &BB : F)
          for (auto &I : BB)
            if (!isa<DbgInfoIntrinsic>(&I)) InstCount++;

        unsigned CallCount = 0;
        for (auto &U : F.uses()) {
          if (auto *CB = dyn_cast<CallBase>(U.getUser())) {
              if (CB->getCalledFunction() == &F) CallCount++;
          }
        }

        if (CallCount > 0 && (InstCount * CallCount) < INLINE_THRESHOLD) {
          ToInline.push_back(&F);
        }
      }

      // ── PHASE 2: INLINE ────────────────────────────────────────────────
      for (Function *F : ToInline) {
        SmallVector<CallBase *, 8> Calls;
        for (Use &U : F->uses()) {
          if (auto *CB = dyn_cast<CallBase>(U.getUser()))
            if (CB->getCalledFunction() == F) Calls.push_back(CB);
        }

        for (CallBase *CB : Calls) {
          InlineFunctionInfo IFI;
          // We must check if the instruction still has a parent block 
          // because a previous inline might have deleted the block.
          if (CB->getParent() && InlineFunction(*CB, IFI).isSuccess()) {
            Changed = true;
          }
        }
      }
    } // CallGraph CG is destroyed here

    // ── PHASE 3: DCE ───────────────────────────────────────────────────
    bool LocalDeadChanged;
    do {
      LocalDeadChanged = false;
      SmallVector<Function *, 16> DeadPool;
      for (Function &F : M) {
        if (F.isDeclaration() || F.getName() == "main") continue;
        if (F.use_empty()) DeadPool.push_back(&F);
      }
      for (Function *F : DeadPool) {
        errs() << "  @" << F->getName() << ": no uses -> deleted\n";
        F->eraseFromParent();
        LocalDeadChanged = true;
        Changed = true;
      }
    } while (LocalDeadChanged);

    return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
  }
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