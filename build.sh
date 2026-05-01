#!/bin/bash
# ============================================================================
# build.sh — Builds the InlineDCEPass plugin
# Updated for LLVM 15+ (new pass manager only)
# ============================================================================

set -e

DEFAULT_LLVM_BUILD="/Volumes/Nayu 1TB/llvm-workspace/build"
LLVM_BUILD="${LLVM_BUILD:-$DEFAULT_LLVM_BUILD}"

if [[ "$(uname)" == "Darwin" ]]; then
  LIB_EXT="dylib"
  OS_NAME="macOS"
else
  LIB_EXT="so"
  OS_NAME="Linux"
fi

echo "=============================================="
echo "  Building InlineDCEPass ($OS_NAME)"
echo "  LLVM build: $LLVM_BUILD"
echo "=============================================="
echo ""

if [ ! -f "$LLVM_BUILD/bin/opt" ]; then
  echo "ERROR: opt not found at:"
  echo "  $LLVM_BUILD/bin/opt"
  echo ""
  echo "Please check your LLVM build path."
  echo "Either:"
  echo "  1. Edit DEFAULT_LLVM_BUILD in this script, or"
  echo "  2. Run:  LLVM_BUILD=\"/your/path\" ./build.sh"
  exit 1
fi

LLVM_VERSION=$("$LLVM_BUILD/bin/opt" --version 2>&1 | head -1)
echo "LLVM found: $LLVM_VERSION"
echo ""

mkdir -p pass-build
cd pass-build

echo "Configuring with CMake..."
cmake .. \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_BUILD_DIR="$LLVM_BUILD"

echo ""
echo "Compiling..."
ninja

cd ..

PLUGIN="./pass-build/InlineDCEPass.$LIB_EXT"

if [ -f "$PLUGIN" ]; then
  echo ""
  echo "=============================================="
  echo "  Build successful!"
  echo "  Plugin: $PLUGIN"
  echo ""
  echo "  Run tests:  ./run.sh"
  echo ""
  echo "  Or manually (new PM syntax):"
  echo "    \"$LLVM_BUILD/bin/opt\" \\"
  echo "      -load-pass-plugin \"$PLUGIN\" \\"
  echo "      -passes=\"inline-dce\" \\"
  echo "      -S tests/small_func.ll"
  echo "=============================================="
else
  echo "ERROR: Build appeared to succeed but plugin not found at $PLUGIN"
  exit 1
fi