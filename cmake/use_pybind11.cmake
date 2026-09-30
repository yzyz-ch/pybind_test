# 三个 step 共用这一份设置。
# pybind11 是仓库根目录的子模块 extern/pybind11，源码不放进各个 step。
# 换位置时改下面的默认路径，或配置时传入 -DPYBIND11_DIR=/你的/pybind11。
if(NOT DEFINED PYBIND11_DIR)
    set(PYBIND11_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../extern/pybind11")
endif()

if(NOT EXISTS "${PYBIND11_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
        "找不到 pybind11：${PYBIND11_DIR}\n"
        "在仓库根目录执行一次：\n"
        "  git submodule update --init")
endif()

# 源码目录在当前 step 外面，必须另外指定编译输出目录。
add_subdirectory(${PYBIND11_DIR} ${CMAKE_CURRENT_BINARY_DIR}/pybind11)
