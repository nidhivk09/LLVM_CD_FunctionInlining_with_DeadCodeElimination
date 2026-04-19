; ============================================================================
; tests/mutual_recursive.ll — FAILURE CASE (for DESIGN.md documentation)
; ============================================================================
;
; SCENARIO:
;   Two functions @funcA and @funcB that call each other:
;     @funcA calls @funcB
;     @funcB calls @funcA
;   This is MUTUAL (indirect) recursion.
;
; WHY THIS IS A KNOWN LIMITATION:
;   Our isDirectlyRecursive() only detects DIRECT self-calls.
;   It checks: "does @funcA contain a call to @funcA?" → NO (it calls @funcB)
;   It checks: "does @funcB contain a call to @funcB?" → NO (it calls @funcA)
;   So neither is flagged as recursive, and both get queued for inlining.
;
; WHAT HAPPENS WHEN WE TRY TO INLINE THEM:
;   Option 1: InlineFunction() detects the circular dependency at the IR
;   level and returns a failure result. Both calls remain. No crash.
;
;   Option 2: One function gets inlined into the other, creating a new
;   self-recursive call. The second InlineFunction() call then detects
;   this and fails. No crash.
;
; HOW TO DETECT MUTUAL RECURSION (for DESIGN.md):
;   You would need a Call Graph DFS:
;   1. Build a CallGraph (LLVM provides this)
;   2. From each function, do a Depth-First Search following call edges
;   3. If you can reach the starting function again → it's in a cycle
;   This is more complex and out of scope for this assignment, but you
;   should document it as a known limitation.
;
; WHAT TO DO WITH THIS TEST:
;   Run it through your pass and show in DESIGN.md that:
;   - The pass doesn't crash
;   - InlineFunction() returns failure with a reason
;   - Both functions remain unchanged
;   This demonstrates your pass handles unexpected cases gracefully.
; ============================================================================

define i32 @funcA(i32 %x) {
entry:
  ; funcA is NOT directly recursive (it calls funcB, not itself)
  ; isDirectlyRecursive(@funcA) returns false ← known limitation!
  %r = call i32 @funcB(i32 %x)
  ret i32 %r
}

define i32 @funcB(i32 %x) {
entry:
  ; funcB is NOT directly recursive (it calls funcA, not itself)
  ; isDirectlyRecursive(@funcB) returns false ← known limitation!
  %cmp = icmp sle i32 %x, 0
  br i1 %cmp, label %done, label %recurse

done:
  ret i32 1

recurse:
  %x1 = sub nsw i32 %x, 1
  %r  = call i32 @funcA(i32 %x1)
  ret i32 %r
}

define i32 @main() {
entry:
  %r = call i32 @funcA(i32 3)
  ret i32 %r
}
