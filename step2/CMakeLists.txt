cmake_minimum_required(VERSION 3.5)
project(toy_matrix)

set(CMAKE_CXX_STANDARD 17)
set(MAKE_CXX_STANDARD_REQUIRED True)

set(CMAKE_BUILD_TYPE Release)
set(CMAKE_CXX_FLAGS_RELEASE "-O3")

# you may need these 2 lines, and set your own paths
set(PYTHON_EXECUTABLE "/home/shawn/anaconda3/include")
set(PYTHON_INCLUDE_DIRECTORY "/home/shawn/anaconda3/include/python3.11")

include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/use_pybind11.cmake)

add_executable(TestMatrix main.cpp matrix.cpp)
pybind11_add_module(toy_matrix bind.cpp matrix.cpp)
