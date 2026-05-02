define i32 @fib(i32 %n) {
entry:
  %cmp = icmp slt i32 %n, 2
  br i1 %cmp, label %base, label %recurse
base:
  ret i32 %n
recurse:
  %n1 = sub i32 %n, 1
  %n2 = sub i32 %n, 2
  %r1 = call i32 @fib(i32 %n1)
  %r2 = call i32 @fib(i32 %n2)
  %r = add i32 %r1, %r2
  ret i32 %r
}

define i32 @negate(i32 %x) {
entry:
  %r = sub i32 0, %x
  ret i32 %r
}

define i32 @main() {
entry:
  %f = call i32 @fib(i32 6)
  %r = call i32 @negate(i32 %f)
  ret i32 %r
}