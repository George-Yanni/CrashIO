cmake_minimum_required(VERSION 3.16)
project(crashio_intro_aflpp CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(USE_AFL_PERSISTENT "Enable AFL++ persistent mode loop" OFF)

add_library(parser_lib STATIC
  ${CMAKE_CURRENT_LIST_DIR}/parser_lib.cpp
)
target_include_directories(parser_lib PUBLIC ${CMAKE_CURRENT_LIST_DIR})

add_executable(afl_harness
  ${CMAKE_CURRENT_LIST_DIR}/../harness/afl_harness.cpp
)
target_link_libraries(afl_harness PRIVATE parser_lib)

if (USE_AFL_PERSISTENT)
  target_compile_definitions(afl_harness PRIVATE USE_AFL_PERSISTENT=1)
endif()

