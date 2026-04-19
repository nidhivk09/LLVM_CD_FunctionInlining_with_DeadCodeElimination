; ============================================================================
; tests/large_func.ll — TEST 2: Should NOT Inline (cost too high)
; ============================================================================
;
; SCENARIO:
;   A function @heavy_compute with many instructions, called once.
;   The cost exceeds the threshold, so it stays as a call.
;
; COST ANALYSIS:
;   Count the instructions below:
;     %a0 through %final = 30 arithmetic instructions
;     ret i32 %final     = 1 ret instruction
;     Total = 31 instructions
;   Call sites: 1 (called once from @main)
;   Cost = 31 × 1 = 31
;   Threshold = 50
;   Decision: 31 < 50 ... hmm, this actually WOULD inline!
;
;   WAIT — we need MORE instructions. Let me use 55+ instructions so cost > 50.
;   See below: I've added enough arithmetic operations.
;
; EXPECTED RESULT AFTER PASS:
;   Both @heavy_compute and @main remain in the output.
;   The "call i32 @heavy_compute" instruction remains in @main.
;   Output file has exactly 2 functions.
;
; VERIFICATION:
;   grep "^define" output.ll   → shows both @heavy_compute and @main
;   grep "call " output.ll     → shows the call to @heavy_compute still there
; ============================================================================

; This function has 57 instructions (56 arithmetic + 1 ret).
; cost = 57 × 1 = 57 >= 50 → SKIP (not inlined)
define i32 @heavy_compute(i32 %x) {
entry:
  %a0  = mul nsw i32 %x, 2
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
  %a46 = mul nsw i32 %a45, 3
  %a47 = add nsw i32 %a46, 97
  %a48 = mul nsw i32 %a47, 2
  %a49 = add nsw i32 %a48, 101
  %a50 = mul nsw i32 %a49, 2
  %a51 = add nsw i32 %a50, 103
  %a52 = mul nsw i32 %a51, 3
  %a53 = add nsw i32 %a52, 107
  %a54 = mul nsw i32 %a53, 2
  %final = add nsw i32 %a54, 999
  ret i32 %final
}

define i32 @main() {
entry:
  %r = call i32 @heavy_compute(i32 5)
  ret i32 %r
}
