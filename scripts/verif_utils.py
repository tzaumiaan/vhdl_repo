import os
import sys
from math import ceil
from typing import Any, Union, Callable
import os_utils
import module_utils

fail_string = "FAIL @__@"
pass_string = "PASS ^__^"


def ascii_colorize(x: str, color: str, bold: bool = False) -> str:
    c_table = {
        "grey": 90,
        "red": 91,
        "green": 92,
        "yellow": 93,
        "blue": 94,
        "violet": 95,
        "beige": 96,
        "white": 97,
    }
    assert color in c_table
    msg = "\33[{}m{}\33[0m".format(c_table[color], x)
    if bold:
        msg = "\33[1m" + msg
    return msg


# print with emphasis
def emph_print(x: Any, deco: str = "*", color: str = "", bold: bool = False) -> None:
    tmp1 = "{0} {1} {0}".format(deco, str(x))
    tmp2 = deco * len(tmp1)
    msg = "{1}\n{0}\n{1}".format(tmp1, tmp2)
    if color != "":
        msg = ascii_colorize(msg, color, bold)
    print(msg)


def check_log(filename: str) -> None:
    kw_list = ["error", "fatal_error"]
    cnt_err = 0
    for kw in kw_list:
        cnt_err += os_utils.count_keyword(filename, kw)
    print("Checking {}: {} errors".format(filename, cnt_err))
    if cnt_err != 0:
        emph_print(fail_string, color="red", bold=True)
        sys.exit("Aborted")


def line_diff(golden: str, dump: str, line_id: int) -> int:
    if golden != dump:
        print(
            ascii_colorize(
                "Mismatch at line {}: expected {} != result {}".format(
                    line_id, golden, dump
                ),
                color="red",
            )
        )
        return 1
    return 0


# default pattern checking method
def check_pat_diff(
    golden: str, dump: str, f_diff: Callable[[str, str, int], int] = line_diff
) -> int:
    assert os.path.exists(golden), "Error: No pattern {}".format(golden)
    assert os.path.exists(dump), "Error: No DUT dump {}".format(dump)
    cnt_err, cnt = 0, 0
    line_g, line_d = list(), list()
    with open(golden) as f_g, open(dump) as f_d:
        line_g = [l.strip().lower() for l in f_g]
        line_d = [l.strip().lower() for l in f_d]
    for lg, ld in zip(line_g, line_d):
        cnt += 1
        cnt_err += f_diff(lg, ld, cnt)
    if len(line_g) != len(line_d):
        print(
            ascii_colorize(
                "Mismatch at end: lines of expected {} != result {}".format(
                    len(line_g), len(line_d)
                ),
                color="red",
            )
        )
        cnt_err += abs(len(line_g) - len(line_d))
    print("Checking {}: {} errors".format(dump, cnt_err))
    if cnt_err != 0:
        emph_print(fail_string, color="red", bold=True)
    return cnt_err


def check_sim_summary(sim_summary: dict) -> None:
    emph_print("SIMULATION SUMMARY")
    is_pass = True
    for k, v in sim_summary.items():
        is_pass = is_pass and v == 0
        result = (
            ascii_colorize("Pass", "green") if v == 0 else ascii_colorize("Fail", "red")
        )
        print("Case [{}]: {} ({} errors)".format(k, result, v))
    if is_pass:
        emph_print(pass_string, color="green", bold=True)
    else:
        emph_print(fail_string, color="red", bold=True)
        sys.exit("Simulation finished with errors!")  # throw error


def signed_hex2int(hexstr: str, width: int) -> int:
    value = int(hexstr, width)
    if value & (1 << (width - 1)):
        value -= 1 << width
    return value


def int2hex(intval: int, width: int) -> str:
    tmp = intval
    if intval < 0:
        tmp += 1 << width
    mask = (1 << width) - 1
    tmp &= mask
    fmt = "{{:0{}x}}".format(ceil(width / 4))
    return fmt.format(tmp)


class pattern_comparator:
    def __init__(self, golden: Union[list, str], dump: Union[list, str]) -> None:
        self.pattern_list = []
        msg = "Error: Invalid pattern settings"
        if isinstance(golden, str) and isinstance(dump, str):
            self.pattern_list.append((golden, dump))
        elif isinstance(golden, list) and isinstance(dump, list):
            assert len(golden) == len(dump), msg
            self.pattern_list = zip(golden, dump)
        else:
            raise TypeError(msg)

    # call entry
    def run(self) -> int:
        cnt_err = 0
        for p_, d_ in self.pattern_list:
            cnt_err += check_pat_diff(p_, d_)
        return cnt_err


class pattern_generator:
    def __init__(self, pat_cfg: dict) -> None:
        self.pat_cfg = pat_cfg
        if "timeout" not in self.pat_cfg:
            self.pat_cfg["timeout"] = "1 ms"  # default timeout
        module_utils.create_sim_tcl(".", self.pat_cfg["timeout"])

    # call entry
    def run(self) -> None:
        pass
