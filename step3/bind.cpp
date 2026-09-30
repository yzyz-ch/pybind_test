#include <pybind11/numpy.h>
#include <pybind11/pybind11.h>

#include <stdexcept>

#include "gpu_vector.h"

namespace py = pybind11;

namespace {

py::array_t<float, py::array::c_style | py::array::forcecast> as_vector(py::array input) {
    auto array = py::array_t<float, py::array::c_style | py::array::forcecast>::ensure(input);
    if (!array) {
        throw std::runtime_error("expected a numeric array");
    }
    if (array.ndim() != 1) {
        throw std::runtime_error("expected a 1-D array");
    }
    return array;
}

}  // namespace

// 模块名 gpu_vector 必须和 CMake 里 pybind11_add_module 的目标名一致。
PYBIND11_MODULE(gpu_vector, m) {
    m.doc() = "GPU vector owned by a C++ class";

    py::class_<GpuVector>(m, "GpuVector")
        .def(py::init<size_t>(), py::arg("n"))
        .def("size", &GpuVector::size)

        // 这两个方法要碰 NumPy 对象，GIL 只在真正拷贝显存时放开。
        .def(
            "from_numpy",
            [](GpuVector& self, py::array input) {
                auto array = as_vector(std::move(input));
                const float* src = array.data();
                const size_t n = static_cast<size_t>(array.shape(0));
                {
                    py::gil_scoped_release release;
                    self.copy_from_host(src, n);
                }
            },
            py::arg("array"))
        .def("to_numpy", [](const GpuVector& self) {
            auto array = py::array_t<float>(self.size());
            float* dst = array.mutable_data();
            {
                py::gil_scoped_release release;
                self.copy_to_host(dst, self.size());
            }
            return array;
        })

        // 下面每个方法对应一次核函数启动，运行期间不占着 GIL。
        .def("fill", &GpuVector::fill, py::arg("value"), py::call_guard<py::gil_scoped_release>())
        .def("add", &GpuVector::add, py::arg("other"), py::call_guard<py::gil_scoped_release>())
        .def("scale", &GpuVector::scale, py::arg("alpha"), py::call_guard<py::gil_scoped_release>())
        .def("sum", &GpuVector::sum, py::call_guard<py::gil_scoped_release>())
        .def_static("add_to", &GpuVector::add_to, py::arg("a"), py::arg("b"), py::arg("out"),
                    py::call_guard<py::gil_scoped_release>());
}
