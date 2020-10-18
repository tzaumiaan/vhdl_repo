import verif_utils

w_data = 16
thr_err = 8


class pattern_comparator(verif_utils.pattern_comparator):
    def run(self) -> int:
        cnt_err = 0
        for p_, d_ in self.pattern_list:
            cnt_err += verif_utils.check_pat_diff(p_, d_, f_diff=line_comp_cordic)
        return cnt_err


def line_comp_cordic(golden: str, dump: str, line_id: int) -> int:
    line_decode = lambda x: [
        verif_utils.signed_hex2int(v, w_data) for v in x.split(" ")
    ]
    err_msg = ""
    for v, g, d in zip(["x", "y", "theta"], line_decode(golden), line_decode(dump)):
        if abs(g - d) > thr_err:
            # exception for theta if one is close to 0x7fff and anotehr is close to 0x8000
            if abs(abs(g - d) - (1 << w_data)) < thr_err:
                continue  # not counted as error
            err_msg += "\n  {}: expected({}) differ from result({}) too much!".format(
                v, verif_utils.int2hex(g, w_data), verif_utils.int2hex(d, w_data)
            )
    if err_msg != "":
        print(
            verif_utils.ascii_colorize(
                "Mismatch at line {}:{}".format(line_id, err_msg), color="red"
            )
        )
        return 1
    return 0
