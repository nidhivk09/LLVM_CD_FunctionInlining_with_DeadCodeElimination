; ModuleID = 'tests/multi_call.c'
source_filename = "tests/multi_call.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @square(i32 noundef %x) #0 {
entry:
  %x.addr = alloca i32, align 4
  store i32 %x, ptr %x.addr, align 4
  %0 = load i32, ptr %x.addr, align 4
  %1 = load i32, ptr %x.addr, align 4
  %mul = mul nsw i32 %0, %1
  ret i32 %mul
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @main() #0 {
entry:
  %retval = alloca i32, align 4
  %r0 = alloca i32, align 4
  %r1 = alloca i32, align 4
  %r2 = alloca i32, align 4
  %r3 = alloca i32, align 4
  %r4 = alloca i32, align 4
  %sum0 = alloca i32, align 4
  %sum1 = alloca i32, align 4
  %sum2 = alloca i32, align 4
  %sum3 = alloca i32, align 4
  store i32 0, ptr %retval, align 4
  %call = call i32 @square(i32 noundef 1)
  store i32 %call, ptr %r0, align 4
  %call1 = call i32 @square(i32 noundef 2)
  store i32 %call1, ptr %r1, align 4
  %call2 = call i32 @square(i32 noundef 3)
  store i32 %call2, ptr %r2, align 4
  %call3 = call i32 @square(i32 noundef 4)
  store i32 %call3, ptr %r3, align 4
  %call4 = call i32 @square(i32 noundef 5)
  store i32 %call4, ptr %r4, align 4
  %0 = load i32, ptr %r0, align 4
  %1 = load i32, ptr %r1, align 4
  %add = add nsw i32 %0, %1
  store i32 %add, ptr %sum0, align 4
  %2 = load i32, ptr %sum0, align 4
  %3 = load i32, ptr %r2, align 4
  %add5 = add nsw i32 %2, %3
  store i32 %add5, ptr %sum1, align 4
  %4 = load i32, ptr %sum1, align 4
  %5 = load i32, ptr %r3, align 4
  %add6 = add nsw i32 %4, %5
  store i32 %add6, ptr %sum2, align 4
  %6 = load i32, ptr %sum2, align 4
  %7 = load i32, ptr %r4, align 4
  %add7 = add nsw i32 %6, %7
  store i32 %add7, ptr %sum3, align 4
  %8 = load i32, ptr %sum3, align 4
  ret i32 %8
}

attributes #0 = { noinline nounwind ssp uwtable(sync) "frame-pointer"="non-leaf-no-reserve" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" "tune-cpu"="apple-m5" }

!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}

!0 = !{i32 8, !"PIC Level", i32 2}
!1 = !{i32 7, !"uwtable", i32 1}
!2 = !{i32 7, !"frame-pointer", i32 4}
!3 = !{!"clang version 23.0.0git (https://github.com/llvm/llvm-project.git 580910073482c0b49be5364f9595ba2dc2bf8f2e)"}
