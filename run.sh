#!/bin/bash
# ============================================================================
# run.sh — Runs all 5 test cases through the InlineDCEPass
#
# USAGE:
#   ./run.sh
#   LLVM_BUILD="/your/path" ./run.sh   (if build path differs)
#
# REQUIRES: ./build.sh must be run first to produce the plugin.
# ============================================================================

set -e

# ─── Same path detection as build.sh ────────────────────────────────────────
DEFAULT_LLVM_BUILD="/Volumes/Nayu 1TB/llvm-workspace/build"
LLVM_BUILD="${LLVM_BUILD:-$DEFAULT_LLVM_BUILD}"

if [[ "$(uname)" == "Darwin" ]]; then
  LIB_EXT="dylib"
else
  LIB_EXT="so"
fi

OPT="$LLVM_BUILD/bin/opt"
PLUGIN="./pass-build/InlineDCEPass.$LIB_EXT"

# ─── Pre-flight checks ───────────────────────────────────────────────────────
if [ ! -f "$PLUGIN" ]; then
  echo "ERROR: Plugin not found at $PLUGIN"
  echo "Run ./build.sh first."
  exit 1
fi

if [ ! -f "$OPT" ]; then
  echo "ERROR: opt not found at $OPT"
  echo "Check your LLVM_BUILD path."
  exit 1
fi

echo "========================================================"
echo "  Assignment 12 — Inline+DCE Test Suite"
echo "  Plugin : $PLUGIN"
echo "  opt    : $OPT"
echo "========================================================"

mkdir -p tests/output

PASS_COUNT=0
FAIL_COUNT=0

# ============================================================================
# run_test NAME EXPECTED_FUNC_COUNT DESCRIPTION
# ============================================================================
run_test() {
  local name="$1"
  local expected="$2"
  local desc="$3"
  local input="tests/${name}.ll"
  local output="tests/output/${name}_after.ll"

  echo ""
  echo "──────────────────────────────────────────────────────"
  echo "  TEST: $name"
  echo "  $desc"
  echo "──────────────────────────────────────────────────────"

  if [ ! -f "$input" ]; then
    echo "  ✗ SKIP — $input not found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # ── Run the pass ───────────────────────────────────────────────────────────
  # --enable-new-pm=0 is REQUIRED for legacy-style passes (RegisterPass /
  # ModulePass) on LLVM 17+. Without it, the new pass manager runs instead
  # and silently ignores your -load plugin.
  "$OPT" \
    --enable-new-pm=0 \
    -load "$PLUGIN" \
    -inline-dce \
    -S "$input" \
    -o "$output" \
    2>&1 | grep -E "ANALYZING|INLINING|DELETING|BLOCKED|SKIPPED|KEEPING|Inlined|deleted|Blocked|Skipped" \
         | sed 's/^/    /' || true

  echo ""

  # ── Count function definitions ────────────────────────────────────────────
  local before after
  before=$(grep -c "^define" "$input"  2>/dev/null || echo 0)
  after=$(grep -c  "^define" "$output" 2>/dev/null || echo 0)

  echo "  Functions before : $before"
  echo "  Functions after  : $after"
  echo "  Expected after   : $expected"

  # ── Show what remains ─────────────────────────────────────────────────────
  echo ""
  echo "  Remaining functions:"
  grep "^define" "$output" | sed 's/define[^@]*//' | sed 's/^/    /' || echo "    (none)"

  echo ""
  echo "  Remaining user call instructions:"
  if grep -q "call " "$output" 2>/dev/null; then
    grep "call " "$output" | grep -v "llvm\." | sed 's/^/    /' || echo "    (none)"
  else
    echo "    (none)"
  fi

  # ── Verify IR correctness ─────────────────────────────────────────────────
  echo ""
  if "$OPT" --enable-new-pm=0 -verify -S "$output" -o /dev/null 2>/dev/null; then
    echo "  IR verify : ✓ valid"
  else
    echo "  IR verify : ✗ MALFORMED IR (your pass produced invalid output)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # ── Pass/Fail ─────────────────────────────────────────────────────────────
  echo ""
  if [ "$after" -eq "$expected" ]; then
    echo "  ✓ PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAIL — got $after functions, expected $expected"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ============================================================================
# THE 5 TESTS
# ============================================================================
run_test "small_func"     1  "@add: cost 2×1=2 < 50 → inlined and deleted"
run_test "large_func"     2  "@heavy_compute: cost 56×1=56 ≥ 50 → skipped"
run_test "recursive_func" 2  "@factorial: recursive → blocked before cost check"
run_test "multi_call"     1  "@square: cost 2×5=10 < 50 → all 5 sites inlined"
run_test "mixed"          3  "@tiny inlined, @big skipped, @recur blocked"

# ============================================================================
# BASELINE vs LLVM's built-in -always-inline
# ============================================================================
echo ""
echo "========================================================"
echo "  Baseline: your pass vs LLVM -always-inline"
echo "========================================================"
printf "  %-22s  %-10s  %-10s  %-10s\n" "Test" "Yours" "Built-in" "Lines(yours)"
printf "  %-22s  %-10s  %-10s  %-10s\n" "──────────────────────" "──────────" "──────────" "────────────"

for name in small_func large_func recursive_func multi_call mixed; do
  baseline_out="tests/output/${name}_baseline.ll"

  "$OPT" --enable-new-pm=0 -always-inline \
    -S "tests/${name}.ll" -o "$baseline_out" 2>/dev/null || true

  yours=$(grep -c    "^define" "tests/output/${name}_after.ll"    2>/dev/null || echo "?")
  builtin=$(grep -c  "^define" "$baseline_out"                    2>/dev/null || echo "?")
  lines=$(wc -l <    "tests/output/${name}_after.ll"              2>/dev/null | tr -d ' ' || echo "?")

  printf "  %-22s  %-10s  %-10s  %-10s\n" "$name" "$yours" "$builtin" "$lines"
done

# ============================================================================
# FINAL RESULT
# ============================================================================
echo ""
echo "========================================================"
printf "  Results: %d passed, %d failed\n" "$PASS_COUNT" "$FAIL_COUNT"
echo "========================================================"
echo ""

[ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
