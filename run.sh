#!/bin/bash
# Compiles .c tests to .ll, then runs InlineDCEPass and verifies outputs.

set -e

DEFAULT_LLVM_BUILD="/Volumes/Nayu 1TB/llvm-workspace/build"
LLVM_BUILD="${LLVM_BUILD:-$DEFAULT_LLVM_BUILD}"

if [[ "$(uname)" == "Darwin" ]]; then
  LIB_EXT="dylib"
else
  LIB_EXT="so"
fi

OPT="$LLVM_BUILD/bin/opt"
CLANG="$LLVM_BUILD/bin/clang"
PLUGIN="./pass-build/InlineDCEPass.$LIB_EXT"

if [ ! -f "$PLUGIN" ]; then
  echo ""
  echo "  ✗ plugin not found at $PLUGIN"
  echo "    run ./build.sh first"
  exit 1
fi

if [ ! -f "$OPT" ]; then
  echo ""
  echo "  ✗ opt not found at $OPT"
  echo "    check LLVM_BUILD path"
  exit 1
fi

if [ ! -f "$CLANG" ]; then
  echo ""
  echo "  ✗ clang not found at $CLANG"
  echo "    check LLVM_BUILD path"
  exit 1
fi

echo ""
echo "  InlineDCEPass — test suite"
echo "  ─────────────────────────────────────────"
echo "  plugin : $PLUGIN"
echo "  opt    : $OPT"
echo "  clang  : $CLANG"
echo ""

mkdir -p tests/output
mkdir -p tests/ll

# ── compile all .c files to .ll ────────────────────────────────────────────
echo "  compiling .c → .ll"
echo "  ─────────────────────────────────────────"
for c_file in tests/*.c; do
  name=$(basename "$c_file" .c)
  ll_file="tests/ll/${name}.ll"
  echo "  → $name.c"
  "$CLANG" \
    -O0 \
    -Xclang -disable-O0-optnone \
    -emit-llvm \
    -S \
    "$c_file" \
    -o "$ll_file"
    
  # Clean up memory scaffolding so inlining doesn't artificially bloat line counts
  "$OPT" -passes=mem2reg -S "$ll_file" -o "$ll_file" 2>/dev/null || true
done
echo ""

PASS_COUNT=0
FAIL_COUNT=0

run_test() {
  local name="$1"
  local expected="$2"
  local desc="$3"
  local input="tests/ll/${name}.ll"
  local output="tests/output/${name}_after.ll"

  echo "  ┌─ $name"
  echo "  │  $desc"

  if [ ! -f "$input" ]; then
    echo "  │  skipped — $input not found"
    echo "  └─"
    echo ""
    return
  fi

  local opt_stderr
  opt_stderr=$( "$OPT" \
    -load-pass-plugin "$PLUGIN" \
    -passes="inline-dce" \
    -S "$input" \
    -o "$output" \
    2>&1 ) || true


  echo "$opt_stderr" \
    | grep -E "recursive|blocked|inline|deleted|skipped|cost|instrs" \
    | sed 's/^/  │  /' || true

  # If opt crashed or didn't produce output, show the error and fail
  if [ ! -f "$output" ]; then
    echo "  │  ✗ opt did not produce output — crash or error:"
    echo "$opt_stderr" | head -20 | sed 's/^/  │    /'
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  └─ FAIL"
    echo ""
    return
  fi

  local before after
  before=$(grep -c "^define" "$input"  2>/dev/null || echo 0)
  after=$(grep -c  "^define" "$output" 2>/dev/null || echo 0)

  echo "  │"
  echo "  │  functions : $before → $after  (expected $expected)"

  echo "  │  remaining :"
  grep "^define" "$output" | sed 's/define[^@]*//' | sed 's/^/  │    /' \
    || echo "  │    (none)"

  echo "  │  calls left:"
  if grep -q "call " "$output" 2>/dev/null; then
    grep "call " "$output" | grep -v "llvm\." | sed 's/^/  │    /' || echo "  │    (none)"
  else
    echo "  │    (none)"
  fi

  if "$OPT" -passes="verify" -S "$output" -o /dev/null 2>/dev/null; then
    echo "  │  IR verify : valid"
  else
    echo "  │  IR verify : ✗ malformed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  └─ FAIL"
    echo ""
    return
  fi

  if [ "$after" -eq "$expected" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  └─ ✓ PASS"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  └─ ✗ FAIL  (got $after, expected $expected)"
  fi
  echo ""
}

# ── tests ──────────────────────────────────────────────────────────────────
run_test "small_func"       1  "@add: inlined and deleted"
run_test "large_func"       2  "@heavy_compute: cost too high → skipped"
run_test "recursive_func"   2  "@factorial: recursive → blocked"
run_test "multi_call"       1  "@square: all 5 sites inlined"
run_test "mixed"            3  "@tiny inlined, @big skipped, @recur blocked"
run_test "single_use"       1  "@double_val: inlined"
run_test "multi_func"       1  "@add_one and @times_two both inlined"
run_test "mutual_recursive" 3  "@is_even and @is_odd blocked (mutual recursion)"
run_test "mixed_recursive"  2  "@fib blocked, @negate inlined"
run_test "chain_inline"     1  "@funcA→B→C: entire chain collapses into main"
run_test "only_dce"         1  "@dead_func: skipped and deleted"

# ── baseline comparison ────────────────────────────────────────────────────
echo "  baseline comparison  (our pass vs -always-inline)"
echo "  ─────────────────────────────────────────"
printf "  %-22s  %-8s  %-8s  %s\n" "test" "ours" "builtin" "lines(ours)"
printf "  %-22s  %-8s  %-8s  %s\n" "──────────────────────" "────────" "────────" "──────────"

for name in small_func large_func recursive_func multi_call mixed single_use multi_func mutual_recursive mixed_recursive chain_inline only_dce; do
  baseline_out="tests/output/${name}_baseline.ll"

  "$OPT" -passes="always-inline" \
    -S "tests/ll/${name}.ll" -o "$baseline_out" 2>/dev/null || true

  yours=$(grep -c   "^define" "tests/output/${name}_after.ll"  2>/dev/null || echo "?")
  builtin=$(grep -c "^define" "$baseline_out"                  2>/dev/null || echo "?")
  lines=$(wc -l <   "tests/output/${name}_after.ll"            2>/dev/null | tr -d ' ' || echo "?")

  printf "  %-22s  %-8s  %-8s  %s\n" "$name" "$yours" "$builtin" "$lines"
done

# ── results ────────────────────────────────────────────────────────────────
echo ""
echo "  ─────────────────────────────────────────"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "  ✓ $PASS_COUNT/$((PASS_COUNT + FAIL_COUNT)) passed"
else
  echo "  $PASS_COUNT passed  ✗ $FAIL_COUNT failed"
fi
echo ""

[ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1