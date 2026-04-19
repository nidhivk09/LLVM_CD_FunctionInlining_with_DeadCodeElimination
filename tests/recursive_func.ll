; ============================================================================
; tests/recursive_func.ll — TEST 3: Recursive Function (Must Be Blocked)
; ============================================================================
;
; SCENARIO:
;   A recursive factorial function @factorial.
;   Recursive functions MUST be blocked before we even compute cost.
;
; WHY WE BLOCK IT:
;   Inlining @factorial would mean pasting its body into every call site.
;   But @factorial's body CONTAINS a call to @factorial.
;   If we pasted the body, the pasted copy would also call @factorial.
;   We'd paste THAT too. And so on → infinite loop at COMPILE TIME.
;
;   This is why isDirectlyRecursive() runs BEFORE cost analysis.
;   We detect the self-call: "call i32 @factorial(i32 %n_minus_1)" inside @factorial.
;
; HOW THE CFG LOOKS:
;   @factorial has 3 basic blocks:
;     entry:          → tests n == 0, branches to base_case or recursive_case
;     base_case:      → returns 1
;     recursive_case: → calls itself with n-1, multiplies result by n, returns
;
;   This is a typical control flow for recursive functions.
;   The "br i1 %cmp, label %base_case, label %recursive_case" is a
;   CONDITIONAL BRANCH instruction — it goes to base_case if %cmp is true,
;   recursive_case if false.
;
; EXPECTED RESULT AFTER PASS:
;   isDirectlyRecursive(@factorial) returns true.
;   [BLOCKED-RECURSIVE] @factorial is printed.
;   Both @factorial and @main remain in the output.
;   No crash, no modification to the IR.
;   Output file has exactly 2 functions.
;
; LLVM IR SYNTAX NOTES:
;   "icmp eq i32 %n, 0"  = integer compare: is %n equal to 0? Returns i1 (bool)
;   "br i1 %cmp, label %base_case, label %recursive_case"
;     = if %cmp is true (1), jump to base_case; else jump to recursive_case
;   "sub nsw i32 %n, 1"  = %n - 1
;   "mul nsw i32 %n, %sub_result"  = %n * %sub_result
; ============================================================================

define i32 @factorial(i32 %n) {
entry:
  %cmp = icmp eq i32 %n, 0
  br i1 %cmp, label %base_case, label %recursive_case

base_case:
  ret i32 1

recursive_case:
  %n_minus_1  = sub nsw i32 %n, 1
  ; This call to @factorial inside @factorial makes it recursive.
  ; Our isDirectlyRecursive() detects this exact pattern.
  %sub_result = call i32 @factorial(i32 %n_minus_1)
  %result     = mul nsw i32 %n, %sub_result
  ret i32 %result
}

define i32 @main() {
entry:
  %r = call i32 @factorial(i32 5)
  ret i32 %r
}
