; ModuleID = 'tests/mixed.c'
source_filename = "tests/mixed.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @tiny(i32 noundef %x) #0 {
entry:
  %x.addr = alloca i32, align 4
  store i32 %x, ptr %x.addr, align 4
  %0 = load i32, ptr %x.addr, align 4
  %add = add nsw i32 %0, 1
  ret i32 %add
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @big(i32 noundef %x) #0 {
entry:
  %x.addr = alloca i32, align 4
  %a0 = alloca i32, align 4
  %a1 = alloca i32, align 4
  %a2 = alloca i32, align 4
  %a3 = alloca i32, align 4
  %a4 = alloca i32, align 4
  %a5 = alloca i32, align 4
  %a6 = alloca i32, align 4
  %a7 = alloca i32, align 4
  %a8 = alloca i32, align 4
  %a9 = alloca i32, align 4
  %a10 = alloca i32, align 4
  %a11 = alloca i32, align 4
  %a12 = alloca i32, align 4
  %a13 = alloca i32, align 4
  %a14 = alloca i32, align 4
  %a15 = alloca i32, align 4
  %a16 = alloca i32, align 4
  %a17 = alloca i32, align 4
  %a18 = alloca i32, align 4
  %a19 = alloca i32, align 4
  %a20 = alloca i32, align 4
  %a21 = alloca i32, align 4
  %a22 = alloca i32, align 4
  %a23 = alloca i32, align 4
  %a24 = alloca i32, align 4
  %a25 = alloca i32, align 4
  %a26 = alloca i32, align 4
  %a27 = alloca i32, align 4
  %a28 = alloca i32, align 4
  %a29 = alloca i32, align 4
  %a30 = alloca i32, align 4
  %a31 = alloca i32, align 4
  %a32 = alloca i32, align 4
  %a33 = alloca i32, align 4
  %a34 = alloca i32, align 4
  %a35 = alloca i32, align 4
  %a36 = alloca i32, align 4
  %a37 = alloca i32, align 4
  %a38 = alloca i32, align 4
  %a39 = alloca i32, align 4
  %a40 = alloca i32, align 4
  %a41 = alloca i32, align 4
  %a42 = alloca i32, align 4
  %a43 = alloca i32, align 4
  %a44 = alloca i32, align 4
  %a45 = alloca i32, align 4
  %final = alloca i32, align 4
  store i32 %x, ptr %x.addr, align 4
  %0 = load i32, ptr %x.addr, align 4
  %mul = mul nsw i32 %0, 2
  store i32 %mul, ptr %a0, align 4
  %1 = load i32, ptr %a0, align 4
  %add = add nsw i32 %1, 1
  store i32 %add, ptr %a1, align 4
  %2 = load i32, ptr %a1, align 4
  %mul1 = mul nsw i32 %2, 3
  store i32 %mul1, ptr %a2, align 4
  %3 = load i32, ptr %a2, align 4
  %add2 = add nsw i32 %3, 5
  store i32 %add2, ptr %a3, align 4
  %4 = load i32, ptr %a3, align 4
  %mul3 = mul nsw i32 %4, 2
  store i32 %mul3, ptr %a4, align 4
  %5 = load i32, ptr %a4, align 4
  %add4 = add nsw i32 %5, 7
  store i32 %add4, ptr %a5, align 4
  %6 = load i32, ptr %a5, align 4
  %mul5 = mul nsw i32 %6, 2
  store i32 %mul5, ptr %a6, align 4
  %7 = load i32, ptr %a6, align 4
  %add6 = add nsw i32 %7, 11
  store i32 %add6, ptr %a7, align 4
  %8 = load i32, ptr %a7, align 4
  %mul7 = mul nsw i32 %8, 3
  store i32 %mul7, ptr %a8, align 4
  %9 = load i32, ptr %a8, align 4
  %add8 = add nsw i32 %9, 13
  store i32 %add8, ptr %a9, align 4
  %10 = load i32, ptr %a9, align 4
  %mul9 = mul nsw i32 %10, 2
  store i32 %mul9, ptr %a10, align 4
  %11 = load i32, ptr %a10, align 4
  %add10 = add nsw i32 %11, 17
  store i32 %add10, ptr %a11, align 4
  %12 = load i32, ptr %a11, align 4
  %mul11 = mul nsw i32 %12, 2
  store i32 %mul11, ptr %a12, align 4
  %13 = load i32, ptr %a12, align 4
  %add12 = add nsw i32 %13, 19
  store i32 %add12, ptr %a13, align 4
  %14 = load i32, ptr %a13, align 4
  %mul13 = mul nsw i32 %14, 3
  store i32 %mul13, ptr %a14, align 4
  %15 = load i32, ptr %a14, align 4
  %add14 = add nsw i32 %15, 23
  store i32 %add14, ptr %a15, align 4
  %16 = load i32, ptr %a15, align 4
  %mul15 = mul nsw i32 %16, 2
  store i32 %mul15, ptr %a16, align 4
  %17 = load i32, ptr %a16, align 4
  %add16 = add nsw i32 %17, 29
  store i32 %add16, ptr %a17, align 4
  %18 = load i32, ptr %a17, align 4
  %mul17 = mul nsw i32 %18, 2
  store i32 %mul17, ptr %a18, align 4
  %19 = load i32, ptr %a18, align 4
  %add18 = add nsw i32 %19, 31
  store i32 %add18, ptr %a19, align 4
  %20 = load i32, ptr %a19, align 4
  %mul19 = mul nsw i32 %20, 3
  store i32 %mul19, ptr %a20, align 4
  %21 = load i32, ptr %a20, align 4
  %add20 = add nsw i32 %21, 37
  store i32 %add20, ptr %a21, align 4
  %22 = load i32, ptr %a21, align 4
  %mul21 = mul nsw i32 %22, 2
  store i32 %mul21, ptr %a22, align 4
  %23 = load i32, ptr %a22, align 4
  %add22 = add nsw i32 %23, 41
  store i32 %add22, ptr %a23, align 4
  %24 = load i32, ptr %a23, align 4
  %mul23 = mul nsw i32 %24, 2
  store i32 %mul23, ptr %a24, align 4
  %25 = load i32, ptr %a24, align 4
  %add24 = add nsw i32 %25, 43
  store i32 %add24, ptr %a25, align 4
  %26 = load i32, ptr %a25, align 4
  %mul25 = mul nsw i32 %26, 3
  store i32 %mul25, ptr %a26, align 4
  %27 = load i32, ptr %a26, align 4
  %add26 = add nsw i32 %27, 47
  store i32 %add26, ptr %a27, align 4
  %28 = load i32, ptr %a27, align 4
  %mul27 = mul nsw i32 %28, 2
  store i32 %mul27, ptr %a28, align 4
  %29 = load i32, ptr %a28, align 4
  %add28 = add nsw i32 %29, 53
  store i32 %add28, ptr %a29, align 4
  %30 = load i32, ptr %a29, align 4
  %mul29 = mul nsw i32 %30, 3
  store i32 %mul29, ptr %a30, align 4
  %31 = load i32, ptr %a30, align 4
  %add30 = add nsw i32 %31, 59
  store i32 %add30, ptr %a31, align 4
  %32 = load i32, ptr %a31, align 4
  %mul31 = mul nsw i32 %32, 2
  store i32 %mul31, ptr %a32, align 4
  %33 = load i32, ptr %a32, align 4
  %add32 = add nsw i32 %33, 61
  store i32 %add32, ptr %a33, align 4
  %34 = load i32, ptr %a33, align 4
  %mul33 = mul nsw i32 %34, 2
  store i32 %mul33, ptr %a34, align 4
  %35 = load i32, ptr %a34, align 4
  %add34 = add nsw i32 %35, 67
  store i32 %add34, ptr %a35, align 4
  %36 = load i32, ptr %a35, align 4
  %mul35 = mul nsw i32 %36, 3
  store i32 %mul35, ptr %a36, align 4
  %37 = load i32, ptr %a36, align 4
  %add36 = add nsw i32 %37, 71
  store i32 %add36, ptr %a37, align 4
  %38 = load i32, ptr %a37, align 4
  %mul37 = mul nsw i32 %38, 2
  store i32 %mul37, ptr %a38, align 4
  %39 = load i32, ptr %a38, align 4
  %add38 = add nsw i32 %39, 73
  store i32 %add38, ptr %a39, align 4
  %40 = load i32, ptr %a39, align 4
  %mul39 = mul nsw i32 %40, 3
  store i32 %mul39, ptr %a40, align 4
  %41 = load i32, ptr %a40, align 4
  %add40 = add nsw i32 %41, 79
  store i32 %add40, ptr %a41, align 4
  %42 = load i32, ptr %a41, align 4
  %mul41 = mul nsw i32 %42, 2
  store i32 %mul41, ptr %a42, align 4
  %43 = load i32, ptr %a42, align 4
  %add42 = add nsw i32 %43, 83
  store i32 %add42, ptr %a43, align 4
  %44 = load i32, ptr %a43, align 4
  %mul43 = mul nsw i32 %44, 2
  store i32 %mul43, ptr %a44, align 4
  %45 = load i32, ptr %a44, align 4
  %add44 = add nsw i32 %45, 89
  store i32 %add44, ptr %a45, align 4
  %46 = load i32, ptr %a45, align 4
  %add45 = add nsw i32 %46, 999
  store i32 %add45, ptr %final, align 4
  %47 = load i32, ptr %final, align 4
  ret i32 %47
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @recur(i32 noundef %n) #0 {
entry:
  %retval = alloca i32, align 4
  %n.addr = alloca i32, align 4
  store i32 %n, ptr %n.addr, align 4
  %0 = load i32, ptr %n.addr, align 4
  %cmp = icmp eq i32 %0, 0
  br i1 %cmp, label %if.then, label %if.end

if.then:                                          ; preds = %entry
  store i32 1, ptr %retval, align 4
  br label %return

if.end:                                           ; preds = %entry
  %1 = load i32, ptr %n.addr, align 4
  %2 = load i32, ptr %n.addr, align 4
  %sub = sub nsw i32 %2, 1
  %call = call i32 @recur(i32 noundef %sub)
  %mul = mul nsw i32 %1, %call
  store i32 %mul, ptr %retval, align 4
  br label %return

return:                                           ; preds = %if.end, %if.then
  %3 = load i32, ptr %retval, align 4
  ret i32 %3
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @main() #0 {
entry:
  %retval = alloca i32, align 4
  %a = alloca i32, align 4
  %b = alloca i32, align 4
  %c = alloca i32, align 4
  %total = alloca i32, align 4
  store i32 0, ptr %retval, align 4
  %call = call i32 @tiny(i32 noundef 10)
  store i32 %call, ptr %a, align 4
  %0 = load i32, ptr %a, align 4
  %call1 = call i32 @big(i32 noundef %0)
  store i32 %call1, ptr %b, align 4
  %call2 = call i32 @recur(i32 noundef 5)
  store i32 %call2, ptr %c, align 4
  %1 = load i32, ptr %b, align 4
  %2 = load i32, ptr %c, align 4
  %add = add nsw i32 %1, %2
  store i32 %add, ptr %total, align 4
  %3 = load i32, ptr %total, align 4
  ret i32 %3
}

attributes #0 = { noinline nounwind ssp uwtable(sync) "frame-pointer"="non-leaf-no-reserve" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" "tune-cpu"="apple-m5" }

!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}

!0 = !{i32 8, !"PIC Level", i32 2}
!1 = !{i32 7, !"uwtable", i32 1}
!2 = !{i32 7, !"frame-pointer", i32 4}
!3 = !{!"clang version 23.0.0git (https://github.com/llvm/llvm-project.git 580910073482c0b49be5364f9595ba2dc2bf8f2e)"}
