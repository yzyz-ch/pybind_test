import time
import numpy as np
from build import toy_matrix
from pymatrix import PyMatrix

Matrix = toy_matrix.Matrix

def NPArrayFromMatrix(A):
    N = A.Rows()
    M = A.Cols()
    return np.array([[A.Get(i, j) for j in range(M)] for i in range(N)])

def PyMatrixFromMatrix(A):
    N = A.Rows()
    M = A.Cols()
    result = PyMatrix(N, M, random_fill=False)
    for i in range(N):
        for j in range(M):
            result.Set(i, j, A.Get(i, j))
    
    return result

def CompareResult(A, B):
    # 对A*B，比较不同实现的精度和速度

    # 转换为Numpy矩阵
    A_NP = NPArrayFromMatrix(A)
    B_NP = NPArrayFromMatrix(B)

    # 转换为Python矩阵
    A_Py = PyMatrixFromMatrix(A)
    B_Py = PyMatrixFromMatrix(B)

    # Numpy矩阵乘法
    np_start = time.time()
    C_NP = A_NP.dot(B_NP)
    np_end = time.time()

    # Python调用C++实现
    C = Matrix(A.Rows(), B.Cols())
    cpp_start = time.time()
    Matrix.Dot(A, B, C)
    cpp_end = time.time()
    C_CPP = NPArrayFromMatrix(C)

    # Python原生实现
    C_Py = PyMatrix(A.Rows(), B.Cols(), random_fill=False)
    py_start = time.time()
    PyMatrix.Dot(A_Py, B_Py, C_Py)
    py_end = time.time()
    C_Py_NP = np.array([[C_Py.Get(i, j) for j in range(C_Py.cols)] for i in range(C_Py.rows)])

    if not np.allclose(C_NP, C_CPP, atol=1e-6):
        print("Results do not match")
        
        ERR = C_NP - C_CPP
        print("Error: ", np.max(np.abs(ERR)))
    elif not np.allclose(C_NP, C_Py_NP, atol=1e-6):
        print("Results do not match")
        
        ERR = C_NP - C_Py_NP
        print("Error: ", np.max(np.abs(ERR)))
    else:
        print("Results match")

    np_report = f"Numpy matrix multiplication: size: {A.Rows()}, time: {(np_end - np_start) * 1000} ms"
    cpp_report = f"C++ matrix multiplication: size: {A.Rows()}, time: {(cpp_end - cpp_start) * 1000} ms"
    py_report = f"Python matrix multiplication: size: {A.Rows()}, time: {(py_end - py_start) * 1000} ms"
    
    print(np_report)
    print(cpp_report)
    print(py_report)

def Compare(N=1000):
    A = Matrix(N, N)
    B = Matrix(N, N)
    # C = Matrix(N, N)
    A.FillRandom()
    B.FillRandom()

    CompareResult(A, B)

def TestNumpy(N):
    # create a NxN matrix
    A = np.random.rand(N, N)
    B = np.random.rand(N, N)
    C = np.random.rand(N, N)

    # measure the time to multiply two numpy matrices
    start = time.time()
    np.dot(A, B, out=C)
    end = time.time()

    print(f"Numpy matrix multiplication: size: {N}, time: {(end - start) * 1000} ms")

if __name__ == "__main__":
    import sys
    N = int(sys.argv[1])

    Compare(N)
    # TestNumpy(N)