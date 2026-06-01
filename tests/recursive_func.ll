; tests/recursive_func.ll — TEST 3: Recursive Function (Must Be Blocked)


define i32 @factorial(i32 %n) {
entry:
  %cmp = icmp eq i32 %n, 0
  br i1 %cmp, label %base_case, label %recursive_case

base_case:
  ret i32 1

recursive_case:
  %n_minus_1  = sub nsw i32 %n, 1
  %sub_result = call i32 @factorial(i32 %n_minus_1)
  %result     = mul nsw i32 %n, %sub_result
  ret i32 %result
}

define i32 @main() {
entry:
  %r = call i32 @factorial(i32 5)
  ret i32 %r
}
