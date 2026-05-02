cmake_minimum_required(VERSION 3.20)
project(Assignment12InlineDCE C CXX)

set(LLVM_BUILD_DIR "" CACHE PATH "Path to your LLVM build/install directory")

if(NOT "${LLVM_BUILD_DIR}" STREQUAL "")
  find_package(LLVM REQUIRED CONFIG
    PATHS "${LLVM_BUILD_DIR}/lib/cmake/llvm"
    NO_DEFAULT_PATH)
else()
  find_package(LLVM REQUIRED CONFIG
    PATHS "/usr/lib/llvm-19/lib/cmake/llvm"
    NO_DEFAULT_PATH)
endif()

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION} at ${LLVM_DIR}")

# ── Includes ────────────────────────────────────────────────────────────────
include_directories(${LLVM_INCLUDE_DIRS})

# FIX FOR MAC SOURCE BUILD:
# If you are building from source, PassPlugin.h is often in 'llvm/include' 
# within the source tree, not the build tree.
if(APPLE AND EXISTS "${LLVM_BUILD_DIR}/../llvm-project/llvm/include")
  include_directories("${LLVM_BUILD_DIR}/../llvm-project/llvm/include")
endif()

# EXTRA SEARCH PATHS for PassPlugin.h variations
if(APPLE)
  include_directories("${LLVM_INCLUDE_DIRS}/llvm/Passes")
  include_directories("${LLVM_INCLUDE_DIRS}/llvm/Plugins")
endif()

separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFINITIONS_LIST})

# ── Plugin target ───────────────────────────────────────────────────────────
add_library(InlineDCEPass MODULE src/InlinePass.cpp)

target_compile_options(InlineDCEPass PRIVATE
  -std=c++17 -Wall -Wextra -fno-rtti -fPIC
)

set_target_properties(InlineDCEPass PROPERTIES PREFIX "")

if(APPLE)
  set_target_properties(InlineDCEPass PROPERTIES SUFFIX ".dylib")
else()
  set_target_properties(InlineDCEPass PROPERTIES SUFFIX ".so")
endif()

# ── Linking ─────────────────────────────────────────────────────────────────
if(APPLE)
  llvm_map_components_to_libnames(LLVM_LIBS support core irreader analysis transformutils passes)
  target_link_libraries(InlineDCEPass PRIVATE ${LLVM_LIBS})
else()
  # Use shared LLVM to avoid the "duplicate command line options" crash on Linux CI
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