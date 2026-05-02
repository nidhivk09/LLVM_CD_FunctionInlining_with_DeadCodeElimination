define i32 @double(i32 %x) {
entry:
  %result = mul i32 %x, 2
  ret i32 %result
}

define i32 @main() {
entry:
  %r = call i32 @double(i32 7)
  ret i32 %r
}