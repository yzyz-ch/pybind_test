# pybind_test

用 pybind11 把 C++ 和 CUDA 做成 Python 可以 `import` 的模块。更细的说明在 [pybind11封装说明.md](pybind11封装说明.md)。

## 这个仓库是做什么的

仓库里有三步示例，pybind11 源码通过子模块放在 `extern/pybind11`，三个示例共用这一份。

- `step1`：把一个 C++ 函数绑定成 Python 函数。
- `step2`：把一个 C++ 类绑定成 Python 类，同一份实现还可以编成普通的 C++ 程序。
- `step3`：用一个持有显存的 C++ 类包住多个 CUDA 核函数，再把这些方法暴露成 Python 接口。

## 创建这个仓库的目的

用来学习 pybind11 的封装方式：绑定代码和真正的计算分开，Python 只调用登记好的接口。CUDA 也沿用这套做法，核函数留在 `.cu` 里，pybind11 只绑定主机侧的 C++ 类。

## 如何克隆

先克隆本仓库，再拉取 pybind11 子模块：

```bash
git clone git@github.com:yzyz-ch/pybind_test.git
cd pybind_test
git submodule update --init
```

`git submodule` 只查看状态，不会下载代码。`git submodule update --init` 才会把 pybind11 克隆到 `extern/pybind11`。

也可以在克隆时一次完成：

```bash
git clone --recurse-submodules git@github.com:yzyz-ch/pybind_test.git
```
