#include "gpu_vector.h"

#include <cuda_runtime.h>

#include <limits>
#include <sstream>
#include <stdexcept>
#include <utility>
#include <vector>

namespace {

constexpr int kThreads = 256;

void check_cuda(cudaError_t err, const char* what) {
    if (err == cudaSuccess) {
        return;
    }
    std::ostringstream message;
    message << what << ": " << cudaGetErrorString(err);
    throw std::runtime_error(message.str());
}

int as_int(size_t n) {
    if (n > static_cast<size_t>(std::numeric_limits<int>::max())) {
        throw std::invalid_argument("vector length does not fit in int");
    }
    return static_cast<int>(n);
}

int block_count(int n) {
    return (n + kThreads - 1) / kThreads;
}

void same_size(const GpuVector& a, const GpuVector& b) {
    if (a.size() != b.size()) {
        throw std::invalid_argument("vectors must have the same length");
    }
}

__global__ void fill_kernel(float* data, int n, float value) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        data[i] = value;
    }
}

__global__ void add_kernel(const float* a, const float* b, float* c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}

__global__ void scale_kernel(float* data, int n, float alpha) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        data[i] *= alpha;
    }
}

// 每个 block 把自己负责的元素加到 partial[blockIdx.x]。
__global__ void reduce_sum_kernel(const float* data, float* partial, int n) {
    __shared__ float buf[kThreads];
    const int tid = threadIdx.x;
    const int i = blockIdx.x * blockDim.x + tid;
    buf[tid] = (i < n) ? data[i] : 0.f;
    __syncthreads();

    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            buf[tid] += buf[tid + stride];
        }
        __syncthreads();
    }

    if (tid == 0) {
        partial[blockIdx.x] = buf[0];
    }
}

}  // namespace

GpuVector::GpuVector(size_t n) : data_(nullptr), n_(0) {
    if (n == 0) {
        return;
    }
    as_int(n);
    check_cuda(cudaMalloc(&data_, n * sizeof(float)), "cudaMalloc");
    cudaError_t err = cudaMemset(data_, 0, n * sizeof(float));
    if (err != cudaSuccess) {
        cudaFree(data_);
        data_ = nullptr;
        check_cuda(err, "cudaMemset");
    }
    n_ = n;
}

GpuVector::~GpuVector() {
    cudaFree(data_);
}

GpuVector::GpuVector(GpuVector&& other) noexcept : data_(other.data_), n_(other.n_) {
    other.data_ = nullptr;
    other.n_ = 0;
}

GpuVector& GpuVector::operator=(GpuVector&& other) noexcept {
    if (this != &other) {
        cudaFree(data_);
        data_ = other.data_;
        n_ = other.n_;
        other.data_ = nullptr;
        other.n_ = 0;
    }
    return *this;
}

size_t GpuVector::size() const {
    return n_;
}

void GpuVector::copy_from_host(const float* host, size_t n) {
    if (n != n_) {
        throw std::invalid_argument("host array length does not match GpuVector");
    }
    if (n_ == 0) {
        return;
    }
    check_cuda(cudaMemcpy(data_, host, n_ * sizeof(float), cudaMemcpyHostToDevice), "copy to device");
}

void GpuVector::copy_to_host(float* host, size_t n) const {
    if (n != n_) {
        throw std::invalid_argument("host array length does not match GpuVector");
    }
    if (n_ == 0) {
        return;
    }
    check_cuda(cudaMemcpy(host, data_, n_ * sizeof(float), cudaMemcpyDeviceToHost), "copy to host");
}

void GpuVector::fill(float value) {
    if (n_ == 0) {
        return;
    }
    const int n = as_int(n_);
    fill_kernel<<<block_count(n), kThreads>>>(data_, n, value);
    check_cuda(cudaGetLastError(), "launch fill_kernel");
    check_cuda(cudaDeviceSynchronize(), "synchronize fill_kernel");
}

void GpuVector::add(const GpuVector& other) {
    same_size(*this, other);
    if (n_ == 0) {
        return;
    }
    const int n = as_int(n_);
    // 读完 a[i]、b[i] 再写回 a[i]，同一个线程内没有别的线程写这个下标。
    add_kernel<<<block_count(n), kThreads>>>(data_, other.data_, data_, n);
    check_cuda(cudaGetLastError(), "launch add_kernel");
    check_cuda(cudaDeviceSynchronize(), "synchronize add_kernel");
}

void GpuVector::scale(float alpha) {
    if (n_ == 0) {
        return;
    }
    const int n = as_int(n_);
    scale_kernel<<<block_count(n), kThreads>>>(data_, n, alpha);
    check_cuda(cudaGetLastError(), "launch scale_kernel");
    check_cuda(cudaDeviceSynchronize(), "synchronize scale_kernel");
}

float GpuVector::sum() const {
    if (n_ == 0) {
        return 0.f;
    }
    const int n = as_int(n_);
    const int blocks = block_count(n);
    float* partial = nullptr;
    check_cuda(cudaMalloc(&partial, static_cast<size_t>(blocks) * sizeof(float)), "cudaMalloc partial");
    try {
        reduce_sum_kernel<<<blocks, kThreads>>>(data_, partial, n);
        check_cuda(cudaGetLastError(), "launch reduce_sum_kernel");
        check_cuda(cudaDeviceSynchronize(), "synchronize reduce_sum_kernel");

        std::vector<float> host_partial(static_cast<size_t>(blocks));
        check_cuda(cudaMemcpy(host_partial.data(), partial, host_partial.size() * sizeof(float),
                              cudaMemcpyDeviceToHost),
                   "copy partial sums");
        cudaFree(partial);
        partial = nullptr;

        float total = 0.f;
        for (float value : host_partial) {
            total += value;
        }
        return total;
    } catch (...) {
        cudaFree(partial);
        throw;
    }
}

void GpuVector::add_to(const GpuVector& a, const GpuVector& b, GpuVector& out) {
    same_size(a, b);
    same_size(a, out);
    if (a.size() == 0) {
        return;
    }
    const int n = as_int(a.size());
    add_kernel<<<block_count(n), kThreads>>>(a.data_, b.data_, out.data_, n);
    check_cuda(cudaGetLastError(), "launch add_kernel");
    check_cuda(cudaDeviceSynchronize(), "synchronize add_kernel");
}
