//===----------------------------------------------------------------------===//
// Assignment 12: Function Inlining + Dead Code Elimination
// File: src/InlinePass.cpp
//===----------------------------------------------------------------------===//

#include "llvm/ADT/SmallVector.h"
#include "llvm/Analysis/CallGraph.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Utils/Cloning.h"
#include "llvm/Transforms/Utils/Local.h"

using namespace llvm;

static const unsigned INLINE_THRESHOLD = 50;

namespace {

struct InlineAndDCEPass : public ModulePass {
  static char ID;
  InlineAndDCEPass() : ModulePass(ID) {}

  unsigned NumInlined = 0;
  unsigned NumDeleted = 0;
  unsigned NumBlocked = 0;
  unsigned NumSkipped = 0;

  bool runOnModule(Module &M) override {

    bool Changed = false;

    errs() << "\n========================================\n";
    errs() << "  InlineAndDCE Pass Starting\n";
    errs() << "  Threshold = " << INLINE_THRESHOLD << "\n";
    errs() << "========================================\n\n";

    // ── CANDIDATE STRUCT ────────────────────────────────────────────────────
    // Holds everything about one function we plan to inline.
    // We collect candidates in Phase 1 BEFORE modifying anything,
    // because InlineFunction() invalidates iterators.
    struct Candidate {
      Function               *Callee;
      SmallVector<CallInst*,8> CallSites;
      unsigned               InstCount;
      unsigned               CallFreq;
      unsigned               Cost;
    };

    SmallVector<Candidate, 16> ToInline;

    // ── PHASE 1: ANALYZE ────────────────────────────────────────────────────
    for (Function &F : M) {
      if (F.isDeclaration()) continue; // No body → nothing to inline
      if (F.isVarArg())      continue; // InlineFunction() can't handle these
      if (F.getName() == "main") continue;

      if (isDirectlyRecursive(F)) {
        errs() << "[BLOCKED-RECURSIVE] " << F.getName() << "\n";
        NumBlocked++;
        continue;
      }

      unsigned InstCount = countInstructions(F);
      SmallVector<CallInst*, 8> Sites = findCallSites(F, M);

      if (Sites.empty()) {
        errs() << "[UNCALLED] " << F.getName()
               << " (instructions=" << InstCount << ")\n";
        continue;
      }

      unsigned Freq = Sites.size();
      unsigned Cost = InstCount * Freq;

      errs() << "[ANALYZING] " << F.getName()
             << "  insts=" << InstCount
             << "  calls=" << Freq
             << "  cost=" << Cost;

      if (Cost < INLINE_THRESHOLD) {
        errs() << "  → WILL INLINE\n";
        ToInline.push_back({&F, Sites, InstCount, Freq, Cost});
      } else {
        errs() << "  → SKIPPED (cost " << Cost
               << " >= threshold " << INLINE_THRESHOLD << ")\n";
        NumSkipped++;
      }
    }

    // ── PHASE 2: INLINE ─────────────────────────────────────────────────────
    for (auto &Cand : ToInline) {
      errs() << "\n[INLINING] " << Cand.Callee->getName()
             << " at " << Cand.CallSites.size() << " site(s)\n";

      for (CallInst *CI : Cand.CallSites) {
        InlineFunctionInfo IFI;
        InlineResult IR = InlineFunction(*CI, IFI);

        if (IR.isSuccess()) {
          errs() << "  ✓ inlined into "
                 << CI->getParent()->getParent()->getName() << "\n";
          NumInlined++;
          Changed = true;
        } else {
          errs() << "  ✗ inline failed: " << IR.getFailureReason() << "\n";
        }
      }
    }

    // ── PHASE 3: DELETE DEAD FUNCTIONS ──────────────────────────────────────
    SmallVector<Function*, 8> ToDelete;

    for (auto &Cand : ToInline) {
      if (Cand.Callee->use_empty()) {
        errs() << "[DELETING] " << Cand.Callee->getName() << "\n";
        ToDelete.push_back(Cand.Callee);
      } else {
        errs() << "[KEEPING] " << Cand.Callee->getName()
               << " (still has users)\n";
      }
    }

    for (Function *F : ToDelete) {
      F->eraseFromParent();
      NumDeleted++;
      Changed = true;
    }

    // ── PHASE 4: DEAD BLOCK ELIMINATION ─────────────────────────────────────
    unsigned FuncsWithDeadBlocks = 0;
    for (Function &F : M) {
      if (F.isDeclaration()) continue;
      if (removeUnreachableBlocks(F)) {
        FuncsWithDeadBlocks++;
        Changed = true;
      }
    }

    errs() << "\n========================================\n";
    errs() << "  InlineAndDCE Pass Summary\n";
    errs() << "  Inlined:           " << NumInlined  << " call site(s)\n";
    errs() << "  Functions deleted: " << NumDeleted  << "\n";
    errs() << "  Blocked recursive: " << NumBlocked  << "\n";
    errs() << "  Skipped (cost):    " << NumSkipped  << "\n";
    errs() << "  Dead blocks in:    " << FuncsWithDeadBlocks << " function(s)\n";
    errs() << "========================================\n\n";

    return Changed;
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────────

  bool isDirectlyRecursive(Function &F) {
    for (BasicBlock &BB : F)
      for (Instruction &I : BB)
        if (auto *CI = dyn_cast<CallInst>(&I))
          if (CI->getCalledFunction() == &F)
            return true;
    return false;
  }

  unsigned countInstructions(Function &F) {
    unsigned Count = 0;
    for (BasicBlock &BB : F)
      Count += BB.size();
    return Count;
  }

  SmallVector<CallInst*, 8> findCallSites(Function &Target, Module &M) {
    SmallVector<CallInst*, 8> Sites;
    for (Function &Caller : M) {
      if (&Caller == &Target) continue;
      for (BasicBlock &BB : Caller)
        for (Instruction &I : BB)
          if (auto *CI = dyn_cast<CallInst>(&I))
            if (CI->getCalledFunction() == &Target)
              Sites.push_back(CI);
    }
    return Sites;
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {}
};

} // end anonymous namespace

char InlineAndDCEPass::ID = 0;

static RegisterPass<InlineAndDCEPass>
    X("inline-dce",
      "Assignment 12: Function Inlining + Dead Code Elimination",
      false,
      false);
