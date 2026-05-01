//===----------------------------------------------------------------------===//
// Assignment 12: Function Inlining + Dead Code Elimination
// File: src/InlinePass.cpp
//===----------------------------------------------------------------------===//

#include "llvm/IR/Function.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Plugins/PassPlugin.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Transforms/Utils/Cloning.h"
#include "llvm/Transforms/Utils/Local.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

static const unsigned INLINE_THRESHOLD = 45;

namespace {

struct InlineAndDCEPass : public PassInfoMixin<InlineAndDCEPass> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &/*MAM*/) {
    bool Changed = false;
    SmallVector<Function *, 16> ToInline;

    // ── PHASE 1: IDENTIFY candidates ─────────────────────────────────────
    for (Function &F : M) {
      if (F.isDeclaration() || F.getName() == "main") continue;

      // Recursion check: does F call itself?
      bool Recursive = false;
      for (User *U : F.users()) {
        if (auto *CB = dyn_cast<CallBase>(U)) {
          if (CB->getFunction() == &F) { Recursive = true; break; }
        }
      }
      if (Recursive) {
        errs() << "  @" << F.getName() << ": recursive → blocked\n";
        continue;
      }

      // Cost model: instructions × call-sites
      unsigned InstCount = 0;
      for (auto &BB : F) {
          for (auto &I : BB) {
              if (!isa<DbgInfoIntrinsic>(&I)) InstCount++;
          }
      }

      unsigned CallCount = 0;
      for (User *U : F.users())
        if (isa<CallBase>(U)) CallCount++;

      unsigned Cost = InstCount * CallCount;
      if (CallCount > 0 && Cost < INLINE_THRESHOLD) {
        errs() << "  @" << F.getName() << ": cost " << InstCount
               << "x" << CallCount << "=" << Cost
               << " < " << INLINE_THRESHOLD << " -> will inline\n";
        ToInline.push_back(&F);
      } else {
        errs() << "  @" << F.getName() << ": cost " << InstCount
               << "x" << CallCount << "=" << Cost
               << " >= " << INLINE_THRESHOLD << " -> skipped\n";
      }
    }

    // ── PHASE 2: INLINE ──────────────────────────────────────────────────
    for (Function *F : ToInline) {
      // Re-collect calls because the previous inlining might have changed things
      SmallVector<CallBase *, 8> Calls;
      for (User *U : F->users())
        if (auto *CB = dyn_cast<CallBase>(U)) Calls.push_back(CB);

      for (CallBase *CB : Calls) {
        InlineFunctionInfo IFI;
        if (InlineFunction(*CB, IFI).isSuccess())
          Changed = true;
      }
    }

    // ── PHASE 3: DCE (Safe Deletion) ──────────────────────────────────────
    // Collect all dead functions into a separate list first
    SmallVector<Function *, 16> DeadPool;
    for (Function &F : M) {
      if (F.isDeclaration() || F.getName() == "main") continue;
      if (F.use_empty()) {
        DeadPool.push_back(&F);
      }
    }

    // Now delete them outside the iteration of M.functions()
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

// ── New PM plugin entry point ─────────────────────────────────────────────
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION,
    "InlineDCEPass",
    LLVM_VERSION_STRING,
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