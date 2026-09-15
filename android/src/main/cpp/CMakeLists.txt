cmake_minimum_required(VERSION 3.18)
project(pinput_kit LANGUAGES CXX)

add_library(pinput_kit SHARED pinput_kit.cpp)

# The NDK provides JNI headers; find_package(JNI) would look for a host JDK.
find_library(log-lib log)
find_library(android-lib android)
target_link_libraries(pinput_kit ${log-lib} ${android-lib})
target_compile_options(pinput_kit PRIVATE -fvisibility=hidden)
