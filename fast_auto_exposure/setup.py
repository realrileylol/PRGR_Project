"""
Setup script for fast_auto_exposure C++ extension
Ultra-fast auto-exposure controller with Python bindings
"""

from setuptools import setup, Extension
from pybind11.setup_helpers import Pybind11Extension, build_ext
import sys

# Compiler flags for optimization
extra_compile_args = [
    '-O3',              # Maximum optimization
    '-march=native',    # Optimize for current CPU (enables SIMD)
    '-mtune=native',
    '-ffast-math',      # Fast floating point math
    '-flto',            # Link-time optimization
    '-std=c++17',       # C++17 standard
]

extra_link_args = [
    '-flto',            # Link-time optimization
]

ext_modules = [
    Pybind11Extension(
        "fast_auto_exposure",
        sources=[
            "fast_auto_exposure.cpp",
            "../src/AutoExposureController.cpp"
        ],
        include_dirs=["../include"],
        extra_compile_args=extra_compile_args,
        extra_link_args=extra_link_args,
        language='c++'
    ),
]

setup(
    name="fast_auto_exposure",
    version="1.0.0",
    author="PRGR Project",
    description="Ultra-fast auto-exposure controller for high-speed ball tracking",
    ext_modules=ext_modules,
    cmdclass={"build_ext": build_ext},
    zip_safe=False,
    python_requires=">=3.7",
)
