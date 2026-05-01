cmake_minimum_required(VERSION 3.20)
project(Assignment12InlineDCE C CXX)

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

# Add the specific source directory where Plugins/PassPlugin.h lives
include_directories(
    ${LLVM_INCLUDE_DIRS}
    "/Volumes/Nayu 1TB/llvm-workspace/llvm-project/llvm/include"
)
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFINITIONS_LIST})

add_library(InlineDCEPass MODULE src/InlinePass.cpp)

# Added 'passes' — required for PassPlugin.h / PassBuilder in LLVM 15+
llvm_map_components_to_libnames(LLVM_LIBS
  support core irreader analysis transformutils passes)

target_link_libraries(InlineDCEPass PRIVATE ${LLVM_LIBS})

target_compile_options(InlineDCEPass PRIVATE
  -std=c++17
  -Wall
  -Wextra
  -fno-rtti
  -fPIC
)

set_target_properties(InlineDCEPass PROPERTIES PREFIX "")

# Fixed: was duplicated, and needs to be conditional per OS
if(APPLE)
  set_target_properties(InlineDCEPass PROPERTIES SUFFIX ".dylib")
else()
  set_target_properties(InlineDCEPass PROPERTIES SUFFIX ".so")
endif()

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