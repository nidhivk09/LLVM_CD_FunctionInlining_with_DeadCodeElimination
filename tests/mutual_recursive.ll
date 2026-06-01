; WHAT TO DO WITH THIS TEST:


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
