; ============================================================================
; tests/mixed.ll — TEST 5: Integration Test (All Cases Together)
; ============================================================================
;
; SCENARIO:
;   A realistic module with THREE different functions demonstrating all three
;   pass behaviors at once:
;     @tiny  → 2 instructions, called once  → cost=2  → INLINE ✓
;     @big   → 56 instructions, called once → cost=56 → SKIP  ✗
;     @recur → recursive                     → BLOCK   ⊘
;
; THIS IS THE MOST IMPORTANT TEST because it shows your pass makes
; SELECTIVE decisions — it doesn't inline everything blindly, and it
; doesn't skip everything conservatively. It correctly applies each rule.
;
; COST ANALYSIS:
;   @tiny:  2 instrs × 1 call = 2  < 50 → INLINE
;   @big:   56 instrs × 1 call = 56 >= 50 → SKIP
;   @recur: recursive → BLOCKED (cost not computed)
;
; EXPECTED RESULT AFTER PASS:
;   @tiny is inlined into @main, then deleted.
;   @big remains as a separate function.
;   @recur remains as a separate function.
;   @main remains.
;   Output: 3 functions (@main, @big, @recur)
;
; VERIFICATION:
;   grep "^define" output.ll   → @main, @big, @recur (3 total)
;   grep "call " output.ll     → calls to @big and @recur remain (NOT @tiny)
; ============================================================================

; ── @tiny: 2 instructions, below threshold ─────────────────────────────────
; cost = 2 × 1 = 2 → INLINE
define i32 @tiny(i32 %x) {
entry:
  %r = add nsw i32 %x, 1
  ret i32 %r
}

; ── @big: 56 instructions, above threshold ─────────────────────────────────
; cost = 56 × 1 = 56 → SKIP (not inlined, stays as a function call)
define i32 @big(i32 %x) {
entry:
  %a0  = mul nsw i32 %x,  2
  %a1  = add nsw i32 %a0, 1
  %a2  = mul nsw i32 %a1, 3
  %a3  = add nsw i32 %a2, 5
  %a4  = mul nsw i32 %a3, 2
  %a5  = add nsw i32 %a4, 7
  %a6  = mul nsw i32 %a5, 2
  %a7  = add nsw i32 %a6, 11
  %a8  = mul nsw i32 %a7, 3
  %a9  = add nsw i32 %a8, 13
  %a10 = mul nsw i32 %a9, 2
  %a11 = add nsw i32 %a10, 17
  %a12 = mul nsw i32 %a11, 2
  %a13 = add nsw i32 %a12, 19
  %a14 = mul nsw i32 %a13, 3
  %a15 = add nsw i32 %a14, 23
  %a16 = mul nsw i32 %a15, 2
  %a17 = add nsw i32 %a16, 29
  %a18 = mul nsw i32 %a17, 2
  %a19 = add nsw i32 %a18, 31
  %a20 = mul nsw i32 %a19, 3
  %a21 = add nsw i32 %a20, 37
  %a22 = mul nsw i32 %a21, 2
  %a23 = add nsw i32 %a22, 41
  %a24 = mul nsw i32 %a23, 2
  %a25 = add nsw i32 %a24, 43
  %a26 = mul nsw i32 %a25, 3
  %a27 = add nsw i32 %a26, 47
  %a28 = mul nsw i32 %a27, 2
  %a29 = add nsw i32 %a28, 53
  %a30 = mul nsw i32 %a29, 3
  %a31 = add nsw i32 %a30, 59
  %a32 = mul nsw i32 %a31, 2
  %a33 = add nsw i32 %a32, 61
  %a34 = mul nsw i32 %a33, 2
  %a35 = add nsw i32 %a34, 67
  %a36 = mul nsw i32 %a35, 3
  %a37 = add nsw i32 %a36, 71
  %a38 = mul nsw i32 %a37, 2
  %a39 = add nsw i32 %a38, 73
  %a40 = mul nsw i32 %a39, 3
  %a41 = add nsw i32 %a40, 79
  %a42 = mul nsw i32 %a41, 2
  %a43 = add nsw i32 %a42, 83
  %a44 = mul nsw i32 %a43, 2
  %a45 = add nsw i32 %a44, 89
  %final = add nsw i32 %a45, 999
  ret i32 %final
}

; ── @recur: recursive function, must be blocked ──────────────────────────────
; isDirectlyRecursive() detects "call i32 @recur" inside @recur → BLOCKED
define i32 @recur(i32 %n) {
entry:
  %cmp = icmp eq i32 %n, 0
  br i1 %cmp, label %done, label %go_deeper

done:
  ret i32 1

go_deeper:
  %n1  = sub nsw i32 %n, 1
  %sub = call i32 @recur(i32 %n1)      ; ← self-call detected here
  %r   = mul nsw i32 %n, %sub
  ret i32 %r
}

; ── @main: calls all three functions ─────────────────────────────────────────
define i32 @main() {
entry:
  ; @tiny will be inlined — this call instruction will disappear
  %a = call i32 @tiny(i32 10)

  ; @big will NOT be inlined — this call instruction stays
  %b = call i32 @big(i32 %a)

  ; @recur will NOT be inlined (blocked) — this call instruction stays
  %c = call i32 @recur(i32 5)

  %total = add nsw i32 %b, %c
  ret i32 %total
}
