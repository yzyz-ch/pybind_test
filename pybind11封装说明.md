# 用 pybind11 把 C++ / CUDA 暴露成 Python 接口

这份说明根据本目录里的三个例子整理：`step1` 把一个 C++ 函数做成 Python 模块，`step2` 把一个 C++ 类做成 Python 类。`step3` 沿用同样的绑法封装 CUDA：核函数留在 `.cu` 里，pybind11 只绑定主机侧的 C++ 类。

pybind11 生成的是普通 Python 扩展模块（`.so`）。Python 里 `import` 它，调用方式与普通模块一样。

## 固定拆法

把代码分成三块，不要把算法写进绑定文件。

| 文件 | 作用 | 本仓库对应 |
| --- | --- | --- |
| 实现 | 纯 C++ 或 CUDA，不包含 pybind11 | `step2/matrix.h`、`step2/matrix.cpp` |
| 绑定 | 只负责把已有函数、类登记给 Python | `step1/example.cpp`、`step2/bind.cpp` |
| 构建 | `pybind11_add_module` 编出 `.so` | 两个目录的 `CMakeLists.txt` |

模块名必须三处一致：

1. `PYBIND11_MODULE(名字, m)` 的第一个参数
2. `pybind11_add_module(名字 ...)` 的目标名
3. Python 里 `import 名字`

`step1` 的名字是 `example`，`step2` 的名字是 `toy_matrix`。编译结果类似 `example.cpython-311-x86_64-linux-gnu.so`，中间的 `cpython-311` 由当前 Python 版本决定。换了一个 Python，就要用那个 Python 重新配置并编译。

## step1：绑定一个函数

`step1/example.cpp` 把 `add` 暴露成 `example.add`：

```cpp
#include <pybind11/pybind11.h>

int add(int i, int j) {
    return i + j;
}

PYBIND11_MODULE(example, m) {
    m.doc() = "pybind11 example plugin";
    m.def("add", &add, "A function which adds two numbers");
}
```

`m.def` 的三个参数分别是 Python 里的函数名、C++ 函数指针、文档字符串。`int` 这类基础类型 pybind11 会自动转换。

`step1/CMakeLists.txt`：

```cmake
cmake_minimum_required(VERSION 3.5)
project(example)

add_subdirectory(extern/pybind11)
pybind11_add_module(example example.cpp)
```

`add_subdirectory(extern/pybind11)` 引入随仓库带的 pybind11。`pybind11_add_module` 会编一个 Python 扩展模块，并链上 Python 和 pybind11，不要改成普通的 `add_library`。

编译和调用。下面的 `python3` 必须是 CMake 找到的那一个（本机是 `/home/shawn/anaconda3/bin/python3`，3.11.7）：

```bash
cd step1
rm -rf build && mkdir build && cd build
cmake ..
make -j
python3 -c "import example; print(example.add(1, 1))"
```

要在 `build` 目录里执行，或者把该目录加进 `PYTHONPATH`，否则 `import example` 找不到 `.so`。

## step2：绑定一个类

实现和绑定是分开的。`matrix.h` / `matrix.cpp` 是普通 C++，`main.cpp` 用它编出可执行文件 `TestMatrix`，`bind.cpp` 用同一份实现编出 Python 模块 `toy_matrix`。

`step2/bind.cpp`：

```cpp
#include <pybind11/pybind11.h>
#include "matrix.h"

namespace py = pybind11;

PYBIND11_MODULE(toy_matrix, m) {
    py::class_<Matrix>(m, "Matrix")
        .def(py::init<size_t, size_t>())
        .def("Set", &Matrix::Set)
        .def("Get", &Matrix::Get)
        .def("Rows", &Matrix::Rows)
        .def("Cols", &Matrix::Cols)
        .def("FillRandom", &Matrix::FillRandom)
        .def("Print", &Matrix::Print)
        .def("PrintSummary", &Matrix::PrintSummary)
        .def_static("Dot", py::overload_cast<const Matrix&, const Matrix&, Matrix&>(&Matrix::Dot));
}
```

对应关系：

- `py::class_<Matrix>(m, "Matrix")`：C++ 类 `Matrix` 在 Python 里叫 `Matrix`
- `.def(py::init<size_t, size_t>())`：构造函数 `Matrix(rows, cols)`
- `.def("Set", &Matrix::Set)`：成员函数，Python 里是 `A.Set(i, j, value)`
- `.def_static(...)`：静态函数，Python 里是 `Matrix.Dot(A, B, C)`
- `py::overload_cast<...>`：`Matrix::Dot` 有两个重载，这里显式选出「三个矩阵引用、结果写入第三个」那一个

`step2/CMakeLists.txt` 里两个目标共用 `matrix.cpp`：

```cmake
cmake_minimum_required(VERSION 3.5)
project(toy_matrix)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_BUILD_TYPE Release)
set(CMAKE_CXX_FLAGS_RELEASE "-O3")

add_subdirectory(extern/pybind11)

add_executable(TestMatrix main.cpp matrix.cpp)
pybind11_add_module(toy_matrix bind.cpp matrix.cpp)
```

编译：

```bash
cd step2
rm -rf build && mkdir build && cd build
cmake ..
make -j
```

`make` 之后 `build` 里会有：

- `TestMatrix`：纯 C++ 程序，运行后从标准输入读矩阵边长
- `toy_matrix....so`：Python 模块

三种跑法：

```bash
# 纯 C++，在 build 目录
./TestMatrix

# 只测 NumPy，或只测纯 Python，在 step2 目录，参数是矩阵边长
python3 main.py 200
python3 pymatrix.py 100

# 对比 NumPy、C++ 绑定、纯 Python。compare.py 写的是 from build import toy_matrix
python3 compare.py 100
```

`compare.py` 必须在 `step2` 目录运行，因为它从子目录 `build` 导入模块。纯 Python 是三重循环，边长先用 `100` 或 `200`。

直接在 `build` 里也可以：

```python
import toy_matrix
A = toy_matrix.Matrix(4, 4)
A.FillRandom()
print(A.Rows(), A.Get(0, 0))
```

## step3：把 CUDA 类暴露给 Python

`step1` 绑定的是一个普通函数，`step2` 绑定的是一个在 CPU 上算的类。`step3` 还是绑定一个类，只是这个类的数据放在显卡上，计算由 CUDA 核函数完成。Python 里的写法跟 step2 很像：先 `import` 一个模块，再创建对象、调用方法。

### 为什么中间要多一层 C++

Python 和 NumPy 数组都在 CPU 内存里，也叫主机内存。CUDA 核函数跑在 GPU 上，只能读写显存，不能直接拿一个 NumPy 数组来算。

所以 pybind11 登记的是普通 C++ 成员函数，例如 `GpuVector::scale`。这个函数自己还在 CPU 上执行，它负责三件 GPU 自己做不到的事：确认显存已经分配好、用 `<<<...>>>` 把核函数启动起来、用 `cudaDeviceSynchronize()` 等到 GPU 算完。核函数（名字以 `_kernel` 结尾、带 `__global__` 的那个）只负责「每个线程算一个元素」。

可以把它想成两层员工：

- 成员函数是调度员，站在 CPU 上
- 核函数是工人，在 GPU 上并行干活

Python 只跟调度员说话。

### 四个文件各管一件事

| 文件 | 你可以把它理解成 | 里面有什么 |
| --- | --- | --- |
| `gpu_vector.h` | 类的目录 | 有哪些方法。没有 CUDA 的头文件，所以 `bind.cpp` 能当普通 C++ 来编译 |
| `gpu_vector.cu` | 真正干活的地方 | 申请/释放显存，以及四个核函数 |
| `bind.cpp` | 前台登记处 | 把类和方法的名字告诉 Python。这里不写计算公式 |
| `CMakeLists.txt` | 怎么把它们编到一起 | `.cu` 交给 nvcc，`bind.cpp` 交给 g++，最后打成一个 `.so` |

`extern/pybind11` 是指向 `step2/extern/pybind11` 的符号链接，step3 没有再复制一份 pybind11。

类里真正保存的只有两样东西：显存地址 `data_`，以及长度 `n_`。Python 看不到 `data_`，只能通过方法使用这块显存。

```cpp
GpuVector(n)   // cudaMalloc，再把显存清成 0
~GpuVector()   // cudaFree
```

因此在 Python 里写 `a = gpu_vector.GpuVector(4)`，就是在显卡上申请 4 个 `float`。`a` 这个 Python 变量销毁时，C++ 析构函数会把显存还回去。

### 顺着一次调用看数据怎么走

下面这三行覆盖了 step3 里最常见的路径：数据从 NumPy 进显存，在 GPU 上改掉，再拿回 NumPy。

```python
a = gpu_vector.GpuVector(4)
a.from_numpy(np.array([1, 2, 3, 4], dtype=np.float32))
a.scale(2)
print(a.to_numpy())   # [2. 4. 6. 8.]
```

`a.scale(2)` 发生时，依次是：

1. Python 调用 `a.scale(2)`。
2. pybind11 根据 `bind.cpp` 里的登记，找到 C++ 的 `GpuVector::scale`。
3. `scale` 仍在 CPU 上运行。它按「每个线程算一个数、每 256 个线程组成一个 block」算出要启动多少个 block，然后执行 `scale_kernel<<<blocks, 256>>>(data_, n, 2)`。
4. GPU 上最多 4 个线程各自做一次 `data[i] *= 2`。多出来的线程因为 `i < n` 不成立，什么也不写。
5. CPU 在 `cudaDeviceSynchronize()` 处等待，直到这 4 个数都写完。
6. 函数回到 Python。结果还在显存里，NumPy 那边还是原来的 `[1, 2, 3, 4]`。
7. `a.to_numpy()` 再申请一个 CPU 上的数组，用 `cudaMemcpy` 把显存拷回来，你才打印出 `[2, 4, 6, 8]`。

`from_numpy` 和 `to_numpy` 本身不算数，只做整块拷贝。计算方法和拷贝方法分开，是为了避免每次 `add`、`scale` 都把数据搬来搬去。

### 对外的几个方法分别做什么

假设 `a` 里是 `[1, 2, 3]`，`b` 里是 `[10, 20, 30]`。

| Python 写法 | 谁在算 | 算完之后 |
| --- | --- | --- |
| `a.fill(1.0)` | `fill_kernel`，每个元素写成同一个值 | `a` 变成 `[1, 1, 1]` |
| `a.add(b)` | `add_kernel`，结果写回 `a` 自己的显存 | `a` 变成 `[11, 22, 33]`，`b` 不变 |
| `GpuVector.add_to(a, b, out)` | 还是 `add_kernel`，结果写入 `out` | `a`、`b` 都不变，`out` 变成两者之和 |
| `a.scale(2.0)` | `scale_kernel` | `a` 的每个元素乘 2 |
| `total = a.sum()` | `reduce_sum_kernel` | 返回一个普通 Python 数，例如 `1+2+3 = 6` |

`add` 和 `add_to` 共用一个核函数，区别只在结果写到哪。`add` 是成员函数，Python 里写成 `a.add(b)`。`add_to` 是静态函数，不依赖某一个对象，所以写成 `GpuVector.add_to(a, b, out)`，并且调用前要先准备好用来接结果的 `out`。这和 step2 里 `Matrix.Dot(A, B, C)` 是同一种登记方式。

`sum` 的核函数不能让所有线程同时往一个变量上加，否则会互相覆盖。它让每个 block 先把自己负责的那一段加好，得到少量中间结果，再把这些中间结果拷回 CPU 加总。你在 Python 里只看得到最后那个总数。

长度不一致时，C++ 会抛异常。pybind11 把它转成 Python 异常，所以 `a.add(b)` 在两边长度不同时会直接报错，不会悄悄算错。

### `bind.cpp` 里每一行在登记什么

模块名仍然要三处一致：这里的 `gpu_vector`、CMake 目标名、Python 的 `import gpu_vector`。

```cpp
py::class_<GpuVector>(m, "GpuVector")
    .def(py::init<size_t>(), py::arg("n"))
    .def("size", &GpuVector::size)
```

这三行和 step2 相同。`py::class_` 把 C++ 类登记成 Python 类 `GpuVector`，`py::init<size_t>()` 对应 `GpuVector(4)` 这种构造，`"size"` 对应 `a.size()`。

拷贝不能直接写 `&GpuVector::copy_from_host`，因为那个函数要的是 C++ 指针 `const float*`，而 Python 传进来的是 NumPy 数组。所以 `from_numpy` 用了一小段 lambda 做翻译：

1. 把输入收成连续的一维 `float32`。如果本来是 `float64`，这里会先拷一份再转成 `float32`。
2. 取出这块 CPU 内存的地址。
3. 调用 `copy_from_host`，里面才是 `cudaMemcpy`。

`to_numpy` 方向相反：先在 CPU 上建一个长度相同的 `float32` 数组，把地址交给 `copy_to_host`，再把这个数组 `return` 给 Python。

`fill`、`add`、`scale`、`sum` 的参数已经是 `float` 或另一个 `GpuVector`，pybind11 会自动转换，所以可以直接登记函数指针：

```cpp
.def("fill", &GpuVector::fill, py::arg("value"), py::call_guard<py::gil_scoped_release>())
.def("add", &GpuVector::add, py::arg("other"), py::call_guard<py::gil_scoped_release>())
.def_static("add_to", &GpuVector::add_to, py::arg("a"), py::arg("b"), py::arg("out"),
            py::call_guard<py::gil_scoped_release>())
```

`.def` 登记成员函数，`.def_static` 登记静态函数。`py::arg("value")` 只是给参数起个名字，方便以后在 Python 里写 `a.fill(value=1.0)`。

最后那个 `py::call_guard<py::gil_scoped_release>()` 跟计算无关。Python 解释器有一把锁，称为 GIL，平时同一时刻只让一个线程执行 Python 代码。GPU 运算要等待，等待期间可以先把这把锁放开，别的 Python 线程就能继续跑；函数返回前 pybind11 会自动把锁拿回来。初学时可以把它看成固定写法：会启动核函数的方法加上它。`from_numpy` 和 `to_numpy` 没有用这一种写法，因为它们还要创建和检查 NumPy 对象，那些步骤必须拿着锁；只在真正 `cudaMemcpy` 的几行周围手动放开。

### 编译时比 step2 多出来的设置

`CMakeLists.txt` 里和 CUDA 相关的只有这几处：

```cmake
project(gpu_vector LANGUAGES CXX CUDA)
set(CMAKE_CUDA_ARCHITECTURES 89)
pybind11_add_module(gpu_vector NO_EXTRAS bind.cpp gpu_vector.cu)
```

`LANGUAGES CXX CUDA` 让 CMake 同时找 g++ 和 nvcc。`.cu` 自动用 nvcc 编译，`bind.cpp` 仍然用 g++。两个编译结果最后链成同一个 `gpu_vector....so`。

`89` 是这台机器上 RTX 4070 Ti SUPER 的计算能力。它决定 nvcc 按哪一种 GPU 指令来生成代码。换显卡时改这个数字，例如 80、86、90。

`NO_EXTRAS` 关掉 pybind11 默认打开的链接期优化。那种优化和 nvcc 混在一起时经常链接失败，这个例子用不到它。

### 编译并运行

在 `step3` 目录：

```bash
rm -rf build && mkdir build && cd build
cmake ..
make -j
cd ..
python3 main.py
```

`main.py` 写的是 `from build import gpu_vector`，所以要在 `step3` 目录运行，不能在 `build` 里面运行这个脚本。它用长度为 100 万的向量检查 `add_to`、原地 `add`、`scale`、`fill` 和 `sum`。通过时会打印 `ok`。

想自己看小数据，进入 `build` 再开 Python，模块就在当前目录，可以直接 `import`：

```python
import numpy as np
import gpu_vector

a = gpu_vector.GpuVector(4)
b = gpu_vector.GpuVector(4)
out = gpu_vector.GpuVector(4)

a.from_numpy(np.array([1, 2, 3, 4], dtype=np.float32))
b.from_numpy(np.array([10, 20, 30, 40], dtype=np.float32))

gpu_vector.GpuVector.add_to(a, b, out)
print(out.to_numpy())   # [11. 22. 33. 44.]，a 和 b 不变

a.add(b)
print(a.to_numpy())     # [11. 22. 33. 44.]，结果写回了 a

a.scale(2)
print(a.to_numpy())     # [22. 44. 66. 88.]
print(a.sum())          # 220.0
```

## 配置和编译时要注意的事

目录如果换过位置，旧的 `build/CMakeCache.txt` 会报 source directory 不一致。删掉整个 `build` 再 `cmake ..`，不要在旧 cache 上继续 `make`。本仓库曾经放在 `~/workspace/try_pybind11`，现在在 `~/workspace/workSpace/try_pybind11`，就是这个原因。

现有 `CMakeLists.txt` 里这两行可以不写，pybind11 会自己找当前 `python3`：

```cmake
set(PYTHON_EXECUTABLE "/home/shawn/anaconda3/include")
set(PYTHON_INCLUDE_DIRECTORY "/home/shawn/anaconda3/include/python3.11")
```

第一行还指到了头文件目录，不是解释器。需要固定解释器时写成：

```cmake
set(Python_EXECUTABLE "/home/shawn/anaconda3/bin/python3")
```

并且用这个 `python3` 来 `import` 编出来的模块。模块是按编译时的 Python 版本生成的，3.11 编出来的 `.so` 不能给 3.10 用。

`step2/CMakeLists.txt` 里的 `MAKE_CXX_STANDARD_REQUIRED` 少了 `C`，没有生效。要强制 C++17 应写成 `CMAKE_CXX_STANDARD_REQUIRED`。
