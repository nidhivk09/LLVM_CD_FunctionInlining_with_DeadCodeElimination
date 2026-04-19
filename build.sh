#!/bin/bash
# ============================================================================
# build.sh — Builds the InlineDCEPass plugin
#
# Works on both macOS (produces .dylib) and Linux (produces .so).
# Handles LLVM build paths that contain spaces.
#
# USAGE:
#   # Option A — set the path here (edit the line below):
#   ./build.sh
#
#   # Option B — pass path as environment variable:
#   LLVM_BUILD="/Volumes/Nayu 1TB/llvm-workspace/build" ./build.sh
# ============================================================================

set -e  # Exit on any error

# ─── Configure your LLVM build path ─────────────────────────────────────────
# Edit this if you are not passing LLVM_BUILD as an env variable.
# For your friend on macOS: "/Volumes/Nayu 1TB/llvm-workspace/build"
# For you on Linux:         "/home/<user>/llvm-project/build"
#
# The script also accepts LLVM_BUILD as an environment variable,
# which takes priority over the value set here.
DEFAULT_LLVM_BUILD="/Volumes/Nayu 1TB/llvm-workspace/build"

# Use env variable if set, otherwise use the default above
LLVM_BUILD="${LLVM_BUILD:-$DEFAULT_LLVM_BUILD}"

# ─── Detect OS → set library extension ──────────────────────────────────────
# macOS produces .dylib, Linux produces .so
# opt's -load flag needs the correct extension to find the file.
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

# ─── Validate LLVM build ─────────────────────────────────────────────────────
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
echo "✓ LLVM found: $LLVM_VERSION"
echo ""

# ─── Create build directory ──────────────────────────────────────────────────
mkdir -p pass-build
cd pass-build

# ─── Run CMake ───────────────────────────────────────────────────────────────
# We quote "$LLVM_BUILD" carefully — the path may contain spaces.
# CMake receives it as a single argument string.
echo "Configuring with CMake..."
cmake .. \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_BUILD_DIR="$LLVM_BUILD"

echo ""
echo "Compiling..."

# ─── Run Ninja ───────────────────────────────────────────────────────────────
ninja

cd ..

PLUGIN="./pass-build/InlineDCEPass.$LIB_EXT"

if [ -f "$PLUGIN" ]; then
  echo ""
  echo "=============================================="
  echo "  ✓ Build successful!"
  echo "  Plugin: $PLUGIN"
  echo ""
  echo "  Run tests:  ./run.sh"
  echo ""
  echo "  Or manually:"
  echo "    \"$LLVM_BUILD/bin/opt\" \\"
  echo "      --enable-new-pm=0 \\"
  echo "      -load \"$PLUGIN\" \\"
  echo "      -inline-dce -S tests/small_func.ll"
  echo "=============================================="
else
  echo "ERROR: Build appeared to succeed but plugin not found at $PLUGIN"
  exit 1
fi
