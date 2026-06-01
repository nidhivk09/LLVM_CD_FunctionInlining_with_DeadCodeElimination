; tests/small_func.ll — TEST 1: Should Inline


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
