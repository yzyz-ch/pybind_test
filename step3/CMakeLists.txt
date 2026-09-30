cmake_minimum_required(VERSION 3.18)
project(gpu_vector LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# RTX 4070 Ti SUPER 是 sm_89。换显卡时改这里。
if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
    set(CMAKE_CUDA_ARCHITECTURES 89)
endif()

set(CMAKE_BUILD_TYPE Release)

# 用哪个 python3 编译，就要用哪个 python3 来 import。
set(Python_EXECUTABLE "/home/shawn/anaconda3/bin/python3")

include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/use_pybind11.cmake)

# 类的实现在 .cu，Python 接口在 bind.cpp，打进同一个扩展模块。
# NO_EXTRAS 关掉 pybind11 默认的 LTO，避免和 nvcc 冲突。
pybind11_add_module(gpu_vector NO_EXTRAS bind.cpp gpu_vector.cu)
