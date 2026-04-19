cmake_minimum_required(VERSION 3.20)
project(Assignment12InlineDCE CXX)

# ─── Find LLVM ───────────────────────────────────────────────────────────────
# LLVM_BUILD_DIR is set on the cmake command line by build.sh:
#   cmake .. -DLLVM_BUILD_DIR="/Volumes/Nayu 1TB/llvm-workspace/build"
# Note: build.sh always quotes this path, so spaces are handled correctly.
set(LLVM_BUILD_DIR "" CACHE PATH "Path to your LLVM build directory")

if("${LLVM_BUILD_DIR}" STREQUAL "")
  message(FATAL_ERROR
    "LLVM_BUILD_DIR is not set.\n"
    "Run cmake with: -DLLVM_BUILD_DIR=\"/path/to/your/llvm-workspace/build\"\n"
    "Or use the provided build.sh script which sets this automatically.")
endif()

find_package(LLVM REQUIRED CONFIG
  PATHS "${LLVM_BUILD_DIR}/lib/cmake/llvm"
  NO_DEFAULT_PATH)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION} at ${LLVM_DIR}")

include_directories(${LLVM_INCLUDE_DIRS})
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFINITIONS_LIST})

# ─── Build the pass as a loadable plugin ─────────────────────────────────────
# MODULE = shared library loaded at runtime by opt via -load
# Source is in src/ subdirectory
add_library(InlineDCEPass MODULE src/InlinePass.cpp)

# ─── Link LLVM components ────────────────────────────────────────────────────
# transformutils provides: InlineFunction(), removeUnreachableBlocks()
# core         provides: Module, Function, BasicBlock, Instruction, etc.
# support      provides: raw_ostream (errs()), SmallVector, etc.
# analysis     provides: AnalysisUsage, CallGraph
# irreader     provides: IR file reading (used internally by opt)
llvm_map_components_to_libnames(LLVM_LIBS
  support core irreader analysis transformutils)

target_link_libraries(InlineDCEPass PRIVATE ${LLVM_LIBS})

# ─── Compiler flags ──────────────────────────────────────────────────────────
target_compile_options(InlineDCEPass PRIVATE
  -Wall
  -Wextra
  -fno-rtti    # LLVM is built without RTTI — your pass must match or linking fails
  -fPIC        # Required for shared libraries
)

# ─── Output naming ───────────────────────────────────────────────────────────
# Without PREFIX "", CMake names it "libInlineDCEPass.so/.dylib"
# opt expects the bare name: "InlineDCEPass.so" or "InlineDCEPass.dylib"
set_target_properties(InlineDCEPass PROPERTIES PREFIX "")

# ─── Print build summary ─────────────────────────────────────────────────────
message(STATUS "")
message(STATUS "=== Build configuration ===")
message(STATUS "  LLVM version : ${LLVM_PACKAGE_VERSION}")
message(STATUS "  LLVM dir     : ${LLVM_DIR}")
message(STATUS "  Build type   : ${CMAKE_BUILD_TYPE}")
if(APPLE)
  message(STATUS "  Output       : pass-build/InlineDCEPass.dylib  (macOS)")
else()
  message(STATUS "  Output       : pass-build/InlineDCEPass.so     (Linux)")
endif()
message(STATUS "===========================")
message(STATUS "")
