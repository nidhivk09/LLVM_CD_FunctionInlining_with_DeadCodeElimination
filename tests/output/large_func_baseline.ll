; ModuleID = 'tests/ll/large_func.ll'
source_filename = "tests/large_func.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @heavy_compute(i32 noundef %x) #0 {
entry:
  %mul = mul nsw i32 %x, 2
  %add = add nsw i32 %mul, 1
  %mul1 = mul nsw i32 %add, 3
  %add2 = add nsw i32 %mul1, 5
  %mul3 = mul nsw i32 %add2, 2
  %add4 = add nsw i32 %mul3, 7
  %mul5 = mul nsw i32 %add4, 2
  %add6 = add nsw i32 %mul5, 11
  %mul7 = mul nsw i32 %add6, 3
  %add8 = add nsw i32 %mul7, 13
  %mul9 = mul nsw i32 %add8, 2
  %add10 = add nsw i32 %mul9, 17
  %mul11 = mul nsw i32 %add10, 2
  %add12 = add nsw i32 %mul11, 19
  %mul13 = mul nsw i32 %add12, 3
  %add14 = add nsw i32 %mul13, 23
  %mul15 = mul nsw i32 %add14, 2
  %add16 = add nsw i32 %mul15, 29
  %mul17 = mul nsw i32 %add16, 2
  %add18 = add nsw i32 %mul17, 31
  %mul19 = mul nsw i32 %add18, 3
  %add20 = add nsw i32 %mul19, 37
  %mul21 = mul nsw i32 %add20, 2
  %add22 = add nsw i32 %mul21, 41
  %mul23 = mul nsw i32 %add22, 2
  %add24 = add nsw i32 %mul23, 43
  %mul25 = mul nsw i32 %add24, 3
  %add26 = add nsw i32 %mul25, 47
  %mul27 = mul nsw i32 %add26, 2
  %add28 = add nsw i32 %mul27, 53
  %mul29 = mul nsw i32 %add28, 3
  %add30 = add nsw i32 %mul29, 59
  %mul31 = mul nsw i32 %add30, 2
  %add32 = add nsw i32 %mul31, 61
  %mul33 = mul nsw i32 %add32, 2
  %add34 = add nsw i32 %mul33, 67
  %mul35 = mul nsw i32 %add34, 3
  %add36 = add nsw i32 %mul35, 71
  %mul37 = mul nsw i32 %add36, 2
  %add38 = add nsw i32 %mul37, 73
  %mul39 = mul nsw i32 %add38, 3
  %add40 = add nsw i32 %mul39, 79
  %mul41 = mul nsw i32 %add40, 2
  %add42 = add nsw i32 %mul41, 83
  %mul43 = mul nsw i32 %add42, 2
  %add44 = add nsw i32 %mul43, 89
  %mul45 = mul nsw i32 %add44, 3
  %add46 = add nsw i32 %mul45, 97
  %mul47 = mul nsw i32 %add46, 2
  %add48 = add nsw i32 %mul47, 101
  %mul49 = mul nsw i32 %add48, 2
  %add50 = add nsw i32 %mul49, 103
  %mul51 = mul nsw i32 %add50, 3
  %add52 = add nsw i32 %mul51, 107
  %mul53 = mul nsw i32 %add52, 2
  %add54 = add nsw i32 %mul53, 999
  ret i32 %add54
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @main() #0 {
entry:
  %call = call i32 @heavy_compute(i32 noundef 5)
  ret i32 %call
}

attributes #0 = { noinline nounwind ssp uwtable(sync) "frame-pointer"="non-leaf-no-reserve" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" "tune-cpu"="apple-m5" }

!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}

!0 = !{i32 8, !"PIC Level", i32 2}
!1 = !{i32 7, !"uwtable", i32 1}
!2 = !{i32 7, !"frame-pointer", i32 4}
!3 = !{!"clang version 23.0.0git (https://github.com/llvm/llvm-project.git 580910073482c0b49be5364f9595ba2dc2bf8f2e)"}
