"""在 step3 目录运行: python3 main.py"""

import numpy as np
from build import gpu_vector


def main():
    n = 1_000_000
    a_np = np.arange(n, dtype=np.float32)
    b_np = np.full(n, 0.5, dtype=np.float32)

    a = gpu_vector.GpuVector(n)
    b = gpu_vector.GpuVector(n)
    out = gpu_vector.GpuVector(n)
    a.from_numpy(a_np)
    b.from_numpy(b_np)

    gpu_vector.GpuVector.add_to(a, b, out)
    if not np.allclose(out.to_numpy(), a_np + b_np):
        raise SystemExit("add_to mismatch")

    a.add(b)
    if not np.allclose(a.to_numpy(), a_np + b_np):
        raise SystemExit("in-place add mismatch")

    a.scale(2.0)
    if not np.allclose(a.to_numpy(), 2.0 * (a_np + b_np)):
        raise SystemExit("scale mismatch")

    a.fill(1.0)
    total = a.sum()
    if abs(total - n) > 1e-3:
        raise SystemExit(f"sum mismatch: {total}")

    print("ok")
    print("size:", a.size())
    print("sum of ones:", total)
    print("add_to first 4:", out.to_numpy()[:4])


if __name__ == "__main__":
    main()
