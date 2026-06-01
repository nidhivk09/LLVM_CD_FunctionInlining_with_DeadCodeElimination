#!/bin/bash
# Builds the InlineDCEPass LLVM plugin into pass-build/

set -e

DEFAULT_LLVM_BUILD="/Volumes/Nayu 1TB/llvm-workspace/build"
LLVM_BUILD="${LLVM_BUILD:-$DEFAULT_LLVM_BUILD}"

[[ "$(uname)" == "Darwin" ]] && LIB_EXT="dylib" OS_NAME="macOS" || LIB_EXT="so" OS_NAME="Linux"

echo ""
echo "  InlineDCEPass — build"
echo "  ─────────────────────────────────────────"
echo "  OS   : $OS_NAME"
echo "  LLVM : $LLVM_BUILD"
echo ""

if [ ! -f "$LLVM_BUILD/bin/opt" ]; then
  echo "  ✗ opt not found at $LLVM_BUILD/bin/opt"
  echo "    Set LLVM_BUILD or edit DEFAULT_LLVM_BUILD in this file."
  exit 1
fi

echo "  LLVM version : $("$LLVM_BUILD/bin/opt" --version 2>&1 | head -1)"
echo ""

mkdir -p pass-build && cd pass-build

echo "  → cmake"
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLVM_BUILD_DIR="$LLVM_BUILD" -Wno-dev

echo ""
echo "  → ninja"
ninja

cd ..

PLUGIN="./pass-build/InlineDCEPass.$LIB_EXT"

if [ -f "$PLUGIN" ]; then
  echo ""
  echo "  ✓ built: $PLUGIN"
  echo ""
  echo "  next steps:"
  echo "    ./run.sh                          run all tests"
  echo "    python app.py                     open web visualizer"
  echo ""
  echo "  or manually:"
  echo "    \"$LLVM_BUILD/bin/opt\" \\"
  echo "      -load-pass-plugin \"$PLUGIN\" \\"
  echo "      -passes=\"inline-dce\" -S tests/small_func.ll"
  echo ""
else
  echo "  ✗ plugin not found after build — check cmake output above"
  exit 1
fi