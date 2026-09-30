cmake_minimum_required(VERSION 3.5)
project(example)

# you may need these 2 lines, and set your own paths
set(PYTHON_EXECUTABLE "/home/shawn/anaconda3/include")
set(PYTHON_INCLUDE_DIRECTORY "/home/shawn/anaconda3/include/python3.11")

include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/use_pybind11.cmake)
pybind11_add_module(example example.cpp)
