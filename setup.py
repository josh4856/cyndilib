import os
import sys
import shutil
import json
from pathlib import Path
from setuptools import setup, find_packages
from distutils.extension import Extension
from distutils.sysconfig import get_python_inc
from distutils.errors import CCompilerError

USE_CYTHON = True#'--use-cython' in sys.argv
if USE_CYTHON:
    # sys.argv.remove('--use-cython')
    from Cython.Build import cythonize
    from Cython.Compiler import Options
    from annotate_index import AnnotateIndex
    Options.fast_fail = True

    USE_PROFILE = '--use-profile' in sys.argv
    if USE_PROFILE:
        sys.argv.remove('--use-profile')
else:
    USE_PROFILE = False

PROJECT_PATH = Path(__file__).parent
WIN32 = sys.platform == 'win32'
MACOS = sys.platform == 'darwin'
IS_BUILD = True
LIB_DIRS = []
INCLUDE_PATH = [get_python_inc()]

def get_ndi_include():
    if MACOS:
        p = Path('/Library/NDI SDK for Apple/include')
        if p.exists():
            INCLUDE_PATH.append(str(p))
    elif WIN32:
        # p = Path(os.environ.get('PROGRAMFILES'))
        # p = p / 'NDI' / 'NDI 5 SDK' / 'Include'
        p = PROJECT_PATH / 'src' / 'cyndilib' / 'wrapper' / 'include'
        if p.exists():
            INCLUDE_PATH.append(str(p))

def get_ndi_libdir():
    if WIN32:
        # p = Path(os.environ.get('PROGRAMFILES'))
        # p = p / 'NDI' / 'NDI 5 SDK' / 'Lib' / 'x64'
        # p = PROJECT_PATH / 'src' / 'cyndilib' / 'wrapper' / 'lib'
        sdk_dir = PROJECT_PATH / 'NDI SDK for Windows'
        lib_dir = sdk_dir / 'Lib' / 'x64'
        src_p = sdk_dir / 'Bin' / 'x64'
        dest_p = PROJECT_PATH / 'src' / 'cyndilib'
        for fn in src_p.iterdir():
            if not fn.is_file():
                continue
            dest_fn = dest_p / fn.name
            if dest_fn.exists():
                continue
            shutil.copy2(fn, dest_fn)
        LIB_DIRS.append(str(lib_dir))

def get_ndi_libname():
    if WIN32:
        return 'Processing.NDI.Lib.x64'
    return 'ndi'

if IS_BUILD:
    get_ndi_include()
    get_ndi_libdir()

try:
    import numpy
except ImportError:
    numpy = None
if numpy is not None:
    INCLUDE_PATH.append(numpy.get_include())

class CyBuildError(CCompilerError):
    def __init__(self, msg):
        self.msg = msg
    def __str__(self):
        return '{}  (try building with "--use-cython")'.format(self.msg)


def get_cython_metadata(src_file):
    """Read the distutils metadata embedded in cythonized sources

    The JSON-formatted "Cython Metadata" contains all of the necessary compiler
    and linker options discovered by "cythonize()" to be passed as kwargs to
    recreate Extension objects without Cython installed

    ::
        /* BEGIN: Cython Metadata
            {
                "distutils": {
                    "depends": ["..."],
                    "extra_compile_args": ["..."],
                    "include_dirs": ["..."],
                    "language": "c/c++",
                    "name": "...",
                    "sources": ["..."]
                }
            }
        END: Cython Metadata */

    """
    if not isinstance(src_file, Path):
        src_file = Path(src_file)
    if src_file.suffix not in ['.c', '.cpp']:
        return None
    start_found = False
    end_found = False
    meta_lines = []
    i = -1
    with src_file.open('rt') as f:
        for line in f:
            i += 1
            if not start_found:
                if 'BEGIN: Cython Metadata' in line:
                    start_found = True
                elif i > 100:
                    return None
            else:
                if 'END: Cython Metadata' in line:
                    end_found = True
                    break
                meta_lines.append(line)
    if not end_found or not len(meta_lines):
        return None
    s = '\n'.join(meta_lines)
    return json.loads(s)

def build_extensions(pkg_dir, search_pattern='**/*.pyx'):
    """Create Extension objects from ".c" and ".cpp" sources built by Cython

    Searches for ".pyx" files in ``pkg_dir`` and their corresponding ".c" or ".cpp"
    files. ``get_cython_metadata()`` is then used to initialize the Extension

    """
    if not isinstance(pkg_dir, Path):
        pkg_dir = Path(pkg_dir)
    extensions = []
    names = set()
    for pyx_file in pkg_dir.glob(search_pattern):
        src_file = None
        for suffix in ['.c', '.cpp']:
            src_file = pyx_file.with_suffix(suffix)
            if src_file.exists():
                break
            else:
                src_file = None
        if src_file is None:
            raise CyBuildError('Could not find valid source for "{}"'.format(pyx_file))
        meta = get_cython_metadata(src_file)
        print(meta)
        if meta is None:
            raise CyBuildError('Could not read metadata from source "{}"'.format(src_file))
        ext_name = meta['module_name']
        assert ext_name not in names
        names.add(ext_name)
        extensions.append(Extension(**meta['distutils']))
    return extensions

if USE_CYTHON:
    compiler_directives = {'embedsignature':True}
    if USE_PROFILE:
        ext_macros = [('CYTHON_TRACE', 1), ('CYTHON_TRACE_NOGIL', 1)]
        compiler_directives.update({'profile':True, 'linetrace':True})
    else:
        ext_macros = None
    extra_compile_args = []
    if WIN32:
        extra_compile_args.append('/Zc:strictStrings')
    else:
        extra_compile_args.append('-fpermissive')
    if not len(LIB_DIRS):
        LIB_DIRS = None

    ext_modules = [
        Extension(
            '*', ['src/**/*.pyx'],
            include_dirs=INCLUDE_PATH,
            extra_compile_args=extra_compile_args,
            libraries=[get_ndi_libname()],
            library_dirs=LIB_DIRS,
            define_macros=ext_macros,
            # define_macros=[('CYTHON_TRACE', 1), ('CYTHON_TRACE_NOGIL', 1)]
        ),
    ]
    ext_modules = cythonize(
        ext_modules,
        annotate=True,
        compiler_directives=compiler_directives,
        # compiler_directives={
        #     'embedsignature':True,
        #     # 'profile':True,
        #     # 'linetrace':True,
        # },
    )
    def build_annotate_index(extensions):
        root = AnnotateIndex('', root_dir=PROJECT_PATH / 'src')
        for ext in extensions:
            pkg_dir = Path(ext.sources[0]).parent
            pkg = root.add_module(ext.name)
        for c in root.walk():
            print('{} -> {}'.format(c, c.to_path('index.html')))
            c.write_html()
    build_annotate_index(ext_modules)
else:
    ext_modules = build_extensions(PROJECT_PATH / 'src' / 'cyndilib')

setup(
    ext_modules=ext_modules,
    include_package_data=True,
)
