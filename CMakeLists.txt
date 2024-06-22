cmake_minimum_required(VERSION 3.21)
project(gbc VERSION 1.0)

include_directories(include())
file(GLOB SOURCE_FILES "src/*.c")
add_executable(gbc main.c ${SOURCE_FILES})

set_target_properties(gbc PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
)

target_compile_options(gbc PRIVATE -Wall -Wextra -O3 -g -Winline)
find_package(SDL2 REQUIRED)
include_directories(${SDL2_INCLUDE_DIRS})
target_link_libraries(gbc ${SDL2_LIBRARIES})
