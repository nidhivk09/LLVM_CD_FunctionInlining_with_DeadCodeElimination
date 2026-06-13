// Implementation of the LLVM ModulePass for Function Inlining and Dead Code Elimination.
#include "llvm/IR/Function.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/PassManager.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Attributes.h"

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

// ---------------------------------------------------------------------------
// Strip ALL lifetime intrinsics from the entire module BEFORE any inlining.
//
// Root cause of the crash on LLVM 23 / Apple M1:
//   clang -O0 emits llvm.lifetime.start.p0 / llvm.lifetime.end.p0 calls.
//   These intrinsic *declarations* carry an AttributeList that is interned
//   in the LLVMContext of the process that created the .ll file (opt's
//   context).  When our plugin dylib calls InlineFunction(), LLVM's inliner
//   copies those call instructions into the caller; the post-pass verifier
//   then checks that every AttributeList belongs to the current Module's
//   LLVMContext.  Because the plugin is a separately-loaded dylib it gets a
//   fresh LLVMContext for its own static data, so the interned attribute
//   objects don't match and the verifier aborts.
//
//   Lifetime markers are purely optimisation hints (they help mem2reg and
//   alias analysis).  Deleting them before inlining is safe and correct —
//   the program's observable behaviour is unchanged.
// ---------------------------------------------------------------------------
static void stripAllLifetimeIntrinsics(Module &M) {
    SmallVector<Instruction *, 32> ToErase;
    for (Function &F : M) {
        for (BasicBlock &BB : F) {
            for (Instruction &I : BB) {
                if (auto *II = dyn_cast<IntrinsicInst>(&I)) {
                    Intrinsic::ID ID = II->getIntrinsicID();
                    if (ID == Intrinsic::lifetime_start ||
                        ID == Intrinsic::lifetime_end) {
                        ToErase.push_back(II);
                    }
                }
            }
        }
    }
    for (Instruction *I : ToErase)
        I->eraseFromParent();
}

// ---------------------------------------------------------------------------
// clang -O0 emits `noinline` on every function.
// Remove it (and `optnone` for safety) so InlineFunction() will actually
// inline the call.  We only touch functions we have already decided to
// inline, so we never silently inline something we shouldn't.
// ---------------------------------------------------------------------------
static void removeInlineBarriers(Function &F) {
    F.removeFnAttr(Attribute::NoInline);
    F.removeFnAttr(Attribute::OptimizeNone);
}

// ---------------------------------------------------------------------------
// Count semantically meaningful instructions only.
// clang -O0 wraps every local variable in alloca/store/load — those are
// scaffolding, not logic.  We skip them plus ret, unconditional branches,
// and all llvm.* intrinsic calls so the cost numbers match the intent of
// the original hand-written .ll tests.
// ---------------------------------------------------------------------------
static unsigned countMeaningfulInstructions(Function &F) {
    unsigned Count = 0;
    for (auto &BB : F) {
        for (auto &I : BB) {
            if (isa<DbgInfoIntrinsic>(&I)) continue;
            if (isa<AllocaInst>(&I))       continue;
            if (isa<StoreInst>(&I))        continue;
            if (isa<LoadInst>(&I))         continue;
            if (isa<ReturnInst>(&I))       continue;
            // Skip llvm.* intrinsic calls (lifetime, dbg, etc.)
            if (auto *CB = dyn_cast<CallBase>(&I))
                if (CB->getCalledFunction() &&
                    CB->getCalledFunction()->isIntrinsic()) continue;
            // Skip unconditional branches — they are just block glue
            if (isa<UncondBrInst>(&I)) continue;
            Count++;
        }
    }
    return Count;
}

static const unsigned INLINE_THRESHOLD = 45;

namespace {

struct InlineAndDCEPass : public PassInfoMixin<InlineAndDCEPass> {
    PreservedAnalyses run(Module &M, ModuleAnalysisManager &MAM) {
        bool Changed = false;

        // ── Phase 0: sanitise the IR clang -O0 emits ──────────────────────
        // Must happen before ANY inlining attempt.
        stripAllLifetimeIntrinsics(M);

        {
            CallGraph CG(M);
            SmallVector<Function *, 16> ToInline;

            for (Function &F : M) {
                if (F.isDeclaration()) continue;
                if (F.getName() == "main") continue;

                CallGraphNode *CGN = CG[&F];
                if (!CGN) continue;

                // ── cycle detection: DFS from F's callees ─────────────────
                bool InCycle = false;
                SmallPtrSet<CallGraphNode *, 16> Visited;
                SmallVector<CallGraphNode *, 16> Worklist;

                for (auto &Edge : *CGN)
                    if (Edge.second) Worklist.push_back(Edge.second);

                while (!Worklist.empty() && !InCycle) {
                    CallGraphNode *N = Worklist.pop_back_val();
                    if (N == CGN) { InCycle = true; break; }
                    if (N && Visited.insert(N).second)
                        for (auto &Edge : *N)
                            if (Edge.second) Worklist.push_back(Edge.second);
                }

                if (InCycle) {
                    errs() << "  @" << F.getName() << ": recursive -> blocked\n";
                    continue;
                }

                unsigned InstCount = countMeaningfulInstructions(F);

                unsigned CallCount = 0;
                for (auto &U : F.uses())
                    if (auto *CB = dyn_cast<CallBase>(U.getUser()))
                        if (CB->getCalledFunction() == &F) CallCount++;

                unsigned Cost = InstCount * CallCount;
                errs() << "  @" << F.getName()
                       << ": instrs=" << InstCount
                       << " calls=" << CallCount
                       << " cost=" << Cost;

                if (CallCount > 0 && Cost < INLINE_THRESHOLD) {
                    errs() << " -> inline\n";
                    ToInline.push_back(&F);
                } else {
                    errs() << " -> skip\n";
                }
            }

            // ── Phase 2: inline ───────────────────────────────────────────
            for (Function *F : ToInline) {
                // Remove noinline / optnone that clang -O0 adds
                removeInlineBarriers(*F);

                SmallVector<CallBase *, 8> Calls;
                for (Use &U : F->uses())
                    if (auto *CB = dyn_cast<CallBase>(U.getUser()))
                        if (CB->getCalledFunction() == F)
                            Calls.push_back(CB);

                for (CallBase *CB : Calls) {
                    if (!CB->getParent()) continue;
                    InlineFunctionInfo IFI;
                    // Pass `false` for MergeAttributes, `nullptr` for CalleeAAR, and `false` for InsertLifetime.
                    // This prevents InlineFunction from creating new llvm.lifetime intrinsics with the plugin's LLVMContext.
                    if (InlineFunction(*CB, IFI, false, nullptr, false).isSuccess())
                        Changed = true;
                }
            }
        } // CallGraph destroyed here

        // ── Phase 3: DCE — delete functions with no remaining uses ─────────
        bool LocalChanged;
        do {
            LocalChanged = false;
            SmallVector<Function *, 16> Dead;
            for (Function &F : M) {
                if (F.isDeclaration()) continue;
                if (F.getName() == "main") continue;
                if (F.use_empty()) Dead.push_back(&F);
            }
            for (Function *F : Dead) {
                errs() << "  @" << F->getName() << ": no uses -> deleted\n";
                F->eraseFromParent();
                LocalChanged = true;
                Changed = true;
            }
        } while (LocalChanged);

        return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
    }
};

} // namespace

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