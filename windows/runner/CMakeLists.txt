cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Set C++ standard for Firebase compatibility
set_property(TARGET ${BINARY_NAME} PROPERTY CXX_STANDARD 17)
set_property(TARGET ${BINARY_NAME} PROPERTY CXX_STANDARD_REQUIRED ON)

# Add Firebase-specific compiler flags for Windows
if(WIN32)
  target_compile_options(${BINARY_NAME} PRIVATE "/std:c++17")
  target_compile_definitions(${BINARY_NAME} PRIVATE "_HAS_STD_BYTE=0")
  target_compile_definitions(${BINARY_NAME} PRIVATE "_SILENCE_ALL_CXX17_DEPRECATION_WARNINGS")
endif()

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")

# Fix Firebase C++ SDK linking issues on Windows
if(CMAKE_BUILD_TYPE STREQUAL "Release")
  target_link_libraries(${BINARY_NAME} PRIVATE "msvcrt.lib")
else()
  target_link_libraries(${BINARY_NAME} PRIVATE "msvcrtd.lib")
endif()

# Add additional Windows system libraries needed for Firebase
target_link_libraries(${BINARY_NAME} PRIVATE "iphlpapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "psapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "userenv.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
