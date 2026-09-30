#pragma once

#include <cstddef>

// 一块在显存里的 float 向量。
// 这个头文件不包含 CUDA 头，bind.cpp 只用普通 C++ 编译。
class GpuVector {
public:
    explicit GpuVector(size_t n);
    ~GpuVector();

    GpuVector(const GpuVector&) = delete;
    GpuVector& operator=(const GpuVector&) = delete;
    GpuVector(GpuVector&& other) noexcept;
    GpuVector& operator=(GpuVector&& other) noexcept;

    size_t size() const;

    void copy_from_host(const float* host, size_t n);
    void copy_to_host(float* host, size_t n) const;

    void fill(float value);                 // fill_kernel
    void add(const GpuVector& other);       // add_kernel，结果写回自己
    void scale(float alpha);                // scale_kernel
    float sum() const;                      // reduce_sum_kernel

    // add_kernel，结果写入第三个向量，不改 a、b
    static void add_to(const GpuVector& a, const GpuVector& b, GpuVector& out);

private:
    float* data_;
    size_t n_;
};
