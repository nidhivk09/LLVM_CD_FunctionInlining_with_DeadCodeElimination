define i32 @add_one(i32 %x) {
entry:
  %r = add i32 %x, 1
  ret i32 %r
}

define i32 @times_two(i32 %x) {
entry:
  %r = mul i32 %x, 2
  ret i32 %r
}

define i32 @main() {
entry:
  %a = call i32 @add_one(i32 5)
  %b = call i32 @times_two(i32 %a)
  ret i32 %b
}