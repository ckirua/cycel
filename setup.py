import numpy as np
import pyarrow
import pybind11
from picobuild import Extension, cythonize, find_packages, get_cython_build_dir, setup

# Extensions:
#
# -   arrow       ->    Cython      º
# -   databases   ->    Python      *
# -   files       ->    Cython      º
# -   logging     ->    Python      *
# -   net         ->    Cython      º
# -   zip         ->    PyBind11    +


# C extensions
########################################################
c_extensions = [
    Extension(
        "cycel.clock.clock",
        ["src/cycel/clock/clock.c"],
        extra_compile_args=[
            "-O3",
            "-march=native",
            "-Wno-unused-function",
            "-Wno-unused-variable",
        ],
        language="c",
    ),
    Extension(
        "cycel.clock.iterators",
        ["src/cycel/clock/iterators.c"],
        extra_compile_args=[
            "-O3",
            "-march=native",
            "-Wno-unused-function",
            "-Wno-unused-variable",
        ],
        language="c",
    ),
    Extension(
        "cycel.clock.ranges",
        ["src/cycel/clock/ranges.c"],
        extra_compile_args=[
            "-O3",
            "-march=native",
            "-Wno-unused-function",
            "-Wno-unused-variable",
        ],
        language="c",
    ),
]


# Cython extensions
########################################################
cythonized_extensions = cythonize(
    [
        # Arrow
        Extension(
            "cycel.arrow.*",
            ["src/cycel/arrow/**/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            libraries=pyarrow.get_libraries(),
            library_dirs=pyarrow.get_library_dirs(),
            runtime_library_dirs=pyarrow.get_library_dirs(),
            include_dirs=[pyarrow.get_include()] + [np.get_include()],
            language="c++",
        ),
        Extension(
            "cycel.clock.*",
            ["src/cycel/clock/**/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            language="c",
        ),
        Extension(
            "cycel.files.*",
            ["src/cycel/files/**/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            language="c",
        ),
        Extension(
            "cycel.net.*",
            ["src/cycel/net/**/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            language="c",
        ),
        Extension(
            "cycel.zmq.*",
            ["src/cycel/zmq/**/*.pyx"],
            libraries=["zmq"],
            library_dirs=["/usr/lib", "/usr/local/lib"],
            include_dirs=["/usr/include"],  # where zmq.h lives
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            language="c",
        ),
        Extension(
            "cycel.crypto.*",
            ["src/cycel/crypto/**/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            libraries=["crypto"],
            language="c",
        ),
    ],
    build_dir=get_cython_build_dir(),
)


# PyBind11 extensions
########################################################
pybind_extensions = [
    Extension(
        "cycel.zip.zip",
        sources=["src/cycel/zip/zip.cpp"],
        include_dirs=[pybind11.get_include()],
        libraries=["zip"],  # This is libzip, libzip.h not libzip.hpp
        language="c++",
        extra_compile_args=[
            "-O3",
            "-march=native",
            "-Wno-unused-function",
            "-Wno-unused-variable",
        ],
    )
]


if __name__ == "__main__":
    setup(
        packages=find_packages(where="src"),
        package_dir={"": "src"},
        package_data={"cycel": ["**/*.pxd", "**/*.pxi"]},
        ext_modules=c_extensions + cythonized_extensions + pybind_extensions,
    )
