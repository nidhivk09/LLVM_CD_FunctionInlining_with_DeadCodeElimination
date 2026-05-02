; PHASE 1: A calls B, B calls C
; All are very small (cost < 45), so they should all be inlined into main.

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