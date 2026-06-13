; ModuleID = 'tests/ll/mixed_recursive.ll'
source_filename = "tests/mixed_recursive.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @fib(i32 noundef %n) #0 {
entry:
  %cmp = icmp slt i32 %n, 2
  br i1 %cmp, label %if.then, label %if.end

if.then:                                          ; preds = %entry
  br label %return

if.end:                                           ; preds = %entry
  %sub = sub nsw i32 %n, 1
  %call = call i32 @fib(i32 noundef %sub)
  %sub1 = sub nsw i32 %n, 2
  %call2 = call i32 @fib(i32 noundef %sub1)
  %add = add nsw i32 %call, %call2
  br label %return

return:                                           ; preds = %if.end, %if.then
  %retval.0 = phi i32 [ %n, %if.then ], [ %add, %if.end ]
  ret i32 %retval.0
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @negate(i32 noundef %x) #0 {
entry:
  %sub = sub nsw i32 0, %x
  ret i32 %sub
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @main() #0 {
entry:
  %call = call i32 @fib(i32 noundef 6)
  %call1 = call i32 @negate(i32 noundef %call)
  ret i32 %call1
}

attributes #0 = { noinline nounwind ssp uwtable(sync) "frame-pointer"="non-leaf-no-reserve" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" "tune-cpu"="apple-m5" }

!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}

!0 = !{i32 8, !"PIC Level", i32 2}
!1 = !{i32 7, !"uwtable", i32 1}
!2 = !{i32 7, !"frame-pointer", i32 4}
!3 = !{!"clang version 23.0.0git (https://github.com/llvm/llvm-project.git 580910073482c0b49be5364f9595ba2dc2bf8f2e)"}
