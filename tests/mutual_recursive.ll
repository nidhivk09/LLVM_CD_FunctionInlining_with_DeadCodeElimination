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

define i32 @is_even(i32 %n) {
entry:
  %cmp = icmp eq i32 %n, 0
  br i1 %cmp, label %yes, label %no
yes:
  ret i32 1
no:
  %n1 = sub i32 %n, 1
  %r = call i32 @is_odd(i32 %n1)
  ret i32 %r
}

define i32 @is_odd(i32 %n) {
entry:
  %cmp = icmp eq i32 %n, 0
  br i1 %cmp, label %yes, label %no
yes:
  ret i32 0
no:
  %n1 = sub i32 %n, 1
  %r = call i32 @is_even(i32 %n1)
  ret i32 %r
}

define i32 @main() {
entry:
  %r = call i32 @is_even(i32 4)
  ret i32 %r
}
