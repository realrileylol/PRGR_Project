"""
Setup script for fast_detection C++ module
Build with: pip install -e .
"""

import os
import sys
import subprocess
from pathlib import Path

from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext


class CMakeExtension(Extension):
    def __init__(self, name):
        super().__init__(name, sources=[])


class CMakeBuild(build_ext):
    def run(self):
        # Check if CMake is available
        try:
            subprocess.check_output(['cmake', '--version'])
        except OSError:
            raise RuntimeError("CMake must be installed to build the following extensions: " +
                             ", ".join(e.name for e in self.extensions))

        for ext in self.extensions:
            self.build_extension(ext)

    def build_extension(self, ext):
        extdir = os.path.abspath(os.path.dirname(self.get_ext_fullpath(ext.name)))
        cmake_args = [
            f'-DCMAKE_LIBRARY_OUTPUT_DIRECTORY={extdir}',
            f'-DPYTHON_EXECUTABLE={sys.executable}',
            '-DCMAKE_BUILD_TYPE=Release'
        ]

        build_args = ['--config', 'Release']

        # Build directory
        build_temp = Path(self.build_temp)
        build_temp.mkdir(parents=True, exist_ok=True)

        # Configure
        subprocess.check_call(['cmake', str(Path().absolute())] + cmake_args, cwd=build_temp)

        # Build
        subprocess.check_call(['cmake', '--build', '.'] + build_args, cwd=build_temp)


setup(
    name='fast_detection',
    version='1.0.0',
    author='PRGR Project',
    description='Fast C++ ball detection for golf launch monitor',
    long_description='Optimized C++ ball detection with pybind11 bindings for 100 FPS golf ball tracking',
    ext_modules=[CMakeExtension('fast_detection')],
    cmdclass={'build_ext': CMakeBuild},
    zip_safe=False,
    python_requires='>=3.7',
)
