; Test: chain_inline.ll


define i32 @funcC(i32 %x) {
entry:
  %res = add i32 %x, 10
  ret i32 %res
}

define i32 @funcB(i32 %x) {
entry:
  %res = call i32 @funcC(i32 %x)
  ret i32 %res
}

define i32 @funcA(i32 %x) {
entry:
  %res = call i32 @funcB(i32 %x)
  ret i32 %res
}

define i32 @main() {
entry:
  %val = call i32 @funcA(i32 5)
  ret i32 %val
}
