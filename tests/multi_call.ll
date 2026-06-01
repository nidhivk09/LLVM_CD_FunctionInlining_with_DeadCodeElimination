; tests/multi_call.ll — TEST 4: Function Called at Many Sites


define i32 @square(i32 %x) {
entry:
  %r = mul nsw i32 %x, %x
  ret i32 %r
}

define i32 @main() {
entry:
  %r0 = call i32 @square(i32 1)
  %r1 = call i32 @square(i32 2)
  %r2 = call i32 @square(i32 3)
  %r3 = call i32 @square(i32 4)
  %r4 = call i32 @square(i32 5)
  %sum0 = add nsw i32 %r0, %r1
  %sum1 = add nsw i32 %sum0, %r2
  %sum2 = add nsw i32 %sum1, %r3
  %sum3 = add nsw i32 %sum2, %r4
  ret i32 %sum3
}
