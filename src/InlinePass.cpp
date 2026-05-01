//===----------------------------------------------------------------------===//
// Assignment 12: Function Inlining + Dead Code Elimination
// File: src/InlinePass.cpp
//===----------------------------------------------------------------------===//

#include "llvm/IR/Function.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/PassManager.h"      // ModuleAnalysisManager is defined here
#include "llvm/Plugins/PassPlugin.h"
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

    // Get the CallGraph from the analysis manager
    CallGraph &CG = MAM.getResult<CallGraphAnalysis>(M);

    // ── PHASE 1: IDENTIFY candidates via CallGraph ───────────────────────
    for (Function &F : M) {
      if (F.isDeclaration() || F.getName() == "main") continue;

      CallGraphNode *CGN = CG[&F];

      // 1. Recursion check
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

      // 2. Cost model
      unsigned InstCount = 0;
      for (auto &BB : F) {
        for (auto &I : BB) {
          if (!isa<DbgInfoIntrinsic>(&I)) InstCount++;
        }
      }

      // 3. Call frequency via CallGraph
      unsigned CallCount = 0;
      for (auto &KV : CG) {
        CallGraphNode *CallerNode = KV.second.get();
        if (!CallerNode->getFunction() || CallerNode->getFunction() == &F) continue;
        for (auto &CallRecord : *CallerNode) {
          if (CallRecord.second == CGN) CallCount++;
        }
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
      SmallVector<CallBase *, 8> Calls;
      for (User *U : F->users())
        if (auto *CB = dyn_cast<CallBase>(U)) Calls.push_back(CB);

      for (CallBase *CB : Calls) {
        InlineFunctionInfo IFI;
        if (InlineFunction(*CB, IFI).isSuccess())
          Changed = true;
      }
    }

    // ── PHASE 3: DCE (Safe Deletion) ─────────────────────────────────────
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
      // REGISTER ANALYSIS HERE
      PB.registerAnalysisRegistrationCallback(
        [](ModuleAnalysisManager &MAM) {
          MAM.registerPass([&] { return CallGraphAnalysis(); });
        });

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