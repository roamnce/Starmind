# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "rust_lib_starmind")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../../../../../../rust rust_lib_starmind "")

# Copy rust.dll to output directory with correct name
set(RUST_DLL_SOURCE "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/rust.dll")
set(RUST_DLL_DEST "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/rust_lib_starmind.dll")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(rust_lib_starmind_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
