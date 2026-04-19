; ============================================================================
; tests/small_func.ll — TEST 1: Should Inline
; ============================================================================
;
; SCENARIO:
;   A two-instruction function @add called exactly once from @main.
;
; COST ANALYSIS:
;   Instructions in @add: 2 (the "add" instruction + the "ret" instruction)
;   Call sites: 1 (only called from @main)
;   Cost = 2 × 1 = 2
;   Threshold = 50
;   Decision: 2 < 50 → INLINE
;
; EXPECTED RESULT AFTER PASS:
;   @add is inlined into @main: the "call i32 @add(3, 4)" is replaced
;   by the body of @add with arguments substituted.
;   @add is then deleted (no more callers).
;   Output file has exactly 1 function: @main
;
; VERIFICATION:
;   grep "^define" output.ll   → should show only "@main"
;   grep "call " output.ll     → should show no user-level calls
;   grep "add nsw" output.ll   → arithmetic appears directly in @main
;
; LLVM IR SYNTAX NOTES:
;   "define i32 @add(i32 %a, i32 %b)" = define a function named add
;     that takes two 32-bit ints and returns a 32-bit int
;   "entry:" = name of the first basic block (must have at least one block)
;   "%sum = add nsw i32 %a, %b" = %sum = a + b
;     "nsw" = "no signed wrap" — tells the optimizer overflow won't happen
;   "ret i32 %sum" = return %sum
; ============================================================================

define i32 @add(i32 %a, i32 %b) {
entry:
  %sum = add nsw i32 %a, %b
  ret i32 %sum
}

define i32 @main() {
entry:
  %result = call i32 @add(i32 3, i32 4)
  ret i32 %result
}
