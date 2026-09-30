# 三个 step 共用这一份设置。
# pybind11 源码不放在各个 step 里，默认在仓库根目录的 extern/pybind11，并且不纳入 Git。
# 换位置时改下面的默认路径，或配置时传入 -DPYBIND11_DIR=/你的/pybind11。
if(NOT DEFINED PYBIND11_DIR)
    set(PYBIND11_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../extern/pybind11")
endif()

if(NOT EXISTS "${PYBIND11_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
        "找不到 pybind11：${PYBIND11_DIR}\n"
        "在仓库根目录执行一次：\n"
        "  git clone --depth 1 https://github.com/pybind/pybind11.git extern/pybind11")
endif()

# 源码目录在当前 step 外面，必须另外指定编译输出目录。
add_subdirectory(${PYBIND11_DIR} ${CMAKE_CURRENT_BINARY_DIR}/pybind11)
