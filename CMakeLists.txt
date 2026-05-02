cmake_minimum_required(VERSION 3.20)
project(Assignment12InlineDCE C CXX)

# ── LLVM discovery ──────────────────────────────────────────────────────────
# Priority order:
#   1. -DLLVM_BUILD_DIR=... (explicit, used by build.sh and local dev)
#   2. llvm-config on PATH (used by CI after apt install llvm-18-dev)
# ────────────────────────────────────────────────────────────────────────────
set(LLVM_BUILD_DIR "" CACHE PATH "Path to your LLVM build/install directory")

if(NOT "${LLVM_BUILD_DIR}" STREQUAL "")
  find_package(LLVM REQUIRED CONFIG
    PATHS "${LLVM_BUILD_DIR}/lib/cmake/llvm"
    NO_DEFAULT_PATH)
else()
  # apt install puts cmake files here on Ubuntu
  find_package(LLVM REQUIRED CONFIG
    PATHS "/usr/lib/llvm-19/lib/cmake/llvm"
    NO_DEFAULT_PATH)
endif()

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION} at ${LLVM_DIR}")

# ── Includes ────────────────────────────────────────────────────────────────
# LLVM_INCLUDE_DIRS already contains everything we need on both macOS and Linux.
# The hardcoded macOS source-tree path has been intentionally removed.
include_directories(${LLVM_INCLUDE_DIRS})

separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFINITIONS_LIST})

# ── Plugin target ───────────────────────────────────────────────────────────
add_library(InlineDCEPass MODULE src/InlinePass.cpp)

if(APPLE)
  # macOS: link statically against LLVM component libs
  llvm_map_components_to_libnames(LLVM_LIBS
    support core irreader analysis transformutils passes)
  target_link_libraries(InlineDCEPass PRIVATE ${LLVM_LIBS})
else()
  # Linux: link against the single shared libLLVM.so to avoid
  # duplicate CommandLine option registration when opt loads the plugin
  target_link_libraries(InlineDCEPass PRIVATE LLVM)
endif()


# ── Summary ─────────────────────────────────────────────────────────────────
message(STATUS "")
message(STATUS "=== Build configuration ===")
message(STATUS "  LLVM version : ${LLVM_PACKAGE_VERSION}")
message(STATUS "  LLVM dir     : ${LLVM_DIR}")
message(STATUS "  LLVM includes: ${LLVM_INCLUDE_DIRS}")
message(STATUS "  Build type   : ${CMAKE_BUILD_TYPE}")
if(APPLE)
  message(STATUS "  Output       : pass-build/InlineDCEPass.dylib  (macOS)")
else()
  message(STATUS "  Output       : pass-build/InlineDCEPass.so     (Linux)")
endif()
message(STATUS "===========================")
message(STATUS "")