import os
import re
import shutil
import ctypes
from datetime import datetime

# file copy
copyfile = shutil.copyfile

# create symbolic link
def symlink(src, dst):
    os_symlink = getattr(os, "symlink", None)
    if callable(os_symlink):
        os_symlink(src, dst)
    else:
        csl = ctypes.windll.kernel32.CreateSymbolicLinkW
        csl.argtypes = (ctypes.c_wchar_p, ctypes.c_wchar_p, ctypes.c_uint32)
        csl.restype = ctypes.c_ubyte
        flags = 1 if os.path.isdir(src) else 0
        if csl(dst, src, flags) == 0:
            raise ctypes.WinError()


# safely create directory
def mkdir(dir_base, dir_name):
    if not os.path.exists(dir_base):
        os.mkdir(dir_base)
    dir_path = os.path.join(dir_base, dir_name)
    if not os.path.exists(dir_path):
        os.mkdir(dir_path)
    return dir_path  # return for further reference


# create directory with unique datetime
def mkdir_w_datetime(dir_base, dir_name):
    if not os.path.exists(dir_base):
        os.mkdir(dir_base)
    tmp = "{}_{}".format(dir_name, int(datetime.now().strftime("%Y%m%d%H%M%S")))
    dir_w_datetime = os.path.join(dir_base, tmp)
    if not os.path.exists(dir_w_datetime):
        os.mkdir(dir_w_datetime)
    return dir_w_datetime  # return for further reference


# get current directory name
def get_cur_dir():
    return os.path.basename(os.getcwd())


# get latest directory name
def get_latest_dir(dir_base, dir_name):
    tmp = sorted(
        [d for d in os.listdir(dir_base) if d.startswith(dir_name)], reverse=True
    )[0]
    return os.path.join(dir_base, tmp)


# count a keyword from a file
def count_keyword(filename, keyword):
    assert os.path.exists(filename)
    re_pat = r"\b{}\b".format(keyword)
    cnt_err = -1
    with open(filename) as f:
        _d = f.read()
        cnt_err = sum(1 for match in re.finditer(re_pat, _d, flags=re.IGNORECASE))
    return cnt_err
