; ============================================================================
; tests/multi_call.ll — TEST 4: Function Called at Many Sites
; ============================================================================
;
; SCENARIO:
;   A tiny function @square (just one mul + ret) called at FIVE different
;   places in @main. This tests that ALL call sites get inlined, not just one.
;
; COST ANALYSIS:
;   Instructions in @square: 2 (mul + ret)
;   Call sites: 5 (called five times from @main)
;   Cost = 2 × 5 = 10
;   Threshold = 50
;   Decision: 10 < 50 → INLINE at all 5 sites
;
; WHAT HAPPENS DURING INLINING:
;   The pass calls findCallSites(@square, M) → returns list of 5 CallInsts.
;   Then for each of the 5 CallInsts, it calls InlineFunction().
;   Each call replaces one "call i32 @square(...)" with the body:
;     %x_mul_x = mul nsw i32 %argval, %argval
;   After all 5 inlinings, @square has 0 callers → deleted.
;
; EXPECTED RESULT AFTER PASS:
;   @main now contains 5 separate mul instructions (one per inlined site).
;   No call to @square anywhere.
;   @square is deleted.
;   Output file has exactly 1 function: @main
;
; VERIFICATION:
;   grep "^define" output.ll   → only @main
;   grep "call " output.ll     → no user calls
;   grep "mul nsw" output.ll   → 5 mul instructions (one per inline site)
; ============================================================================

define i32 @square(i32 %x) {
entry:
  %r = mul nsw i32 %x, %x
  ret i32 %r
}

define i32 @main() {
entry:
  ; Five separate call sites — all will be inlined
  %r0 = call i32 @square(i32 1)
  %r1 = call i32 @square(i32 2)
  %r2 = call i32 @square(i32 3)
  %r3 = call i32 @square(i32 4)
  %r4 = call i32 @square(i32 5)
  ; Sum all results
  %sum0 = add nsw i32 %r0, %r1
  %sum1 = add nsw i32 %sum0, %r2
  %sum2 = add nsw i32 %sum1, %r3
  %sum3 = add nsw i32 %sum2, %r4
  ret i32 %sum3
}
