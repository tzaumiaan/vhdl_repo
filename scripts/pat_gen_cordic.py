import numpy as np
import verif_utils

w_data = 16


class pattern_generator(verif_utils.pattern_generator):
    def run(self):
        # generate variable arrays
        var_dict = dict()
        for k in ["ampl", "theta_init"]:
            if k in self.pat_cfg:
                if self.pat_cfg[k]["mode"] == "random":
                    seed = 0
                    if "seed" in self.pat_cfg[k]:
                        seed = self.pat_cfg[k]["seed"]
                    np.random.seed(seed)
                    v = np.random.randint(
                        self.pat_cfg[k]["range"][0],
                        self.pat_cfg[k]["range"][1],
                        self.pat_cfg["n_pat"],
                    ).astype(int)
                else:
                    v = np.ones(self.pat_cfg["n_pat"]).astype(int) * int(
                        self.pat_cfg[k]["value"]
                    )
            else:
                v = np.zeros(self.pat_cfg["n_pat"]).astype(int)
            var_dict[k] = v
        var_dict["theta"] = np.linspace(
            0, ((1 << w_data) - 1), num=self.pat_cfg["n_pat"], dtype=int
        )
        with open("pat_in.txt", "w") as f_in, open("pat_out.txt", "w") as f_out:
            f_in.write("# mode, x, y, theta\n")
            for i in range(self.pat_cfg["n_pat"]):
                mode = 1 if self.pat_cfg["cordic_mode"] == "vector" else 0
                phase_i = (
                    var_dict["theta"][i] if mode == 1 else var_dict["theta_init"][i]
                )
                phase_o = (
                    0
                    if mode == 1
                    else (
                        (var_dict["theta"][i] + var_dict["theta_init"][i])
                        & ((1 << w_data) - 1)
                    )
                )
                x_i = int(
                    float(var_dict["ampl"][i])
                    * np.cos(2 * np.pi * float(phase_i) / (2 ** w_data))
                )
                y_i = int(
                    float(var_dict["ampl"][i])
                    * np.sin(2 * np.pi * float(phase_i) / (2 ** w_data))
                )
                theta_i = 0 if mode == 1 else var_dict["theta"][i]
                theta_o = var_dict["theta"][i] if mode == 1 else 0
                f_in.write(
                    "{} {} {} {}\n".format(
                        mode,
                        verif_utils.int2hex(x_i, w_data),
                        verif_utils.int2hex(y_i, w_data),
                        verif_utils.int2hex(theta_i, w_data),
                    )
                )
                # to simulate the leading zero/one shifter in RTL codes
                lsh = 0
                if mode == 1:
                    op_hi = int(1 << (w_data - 3)) - 1
                    op_lo = -int(1 << (w_data - 3))
                    while (op_lo <= x_i <= op_hi) and (op_lo <= y_i <= op_hi):
                        x_i *= 2
                        y_i *= 2
                        lsh += 1
                x_o = int(
                    float(var_dict["ampl"][i] << lsh)
                    * np.cos(2 * np.pi * float(phase_o) / (2 ** w_data))
                )
                y_o = int(
                    float(var_dict["ampl"][i] << lsh)
                    * np.sin(2 * np.pi * float(phase_o) / (2 ** w_data))
                )
                f_out.write(
                    "{} {} {}\n".format(
                        verif_utils.int2hex(x_o, w_data),
                        verif_utils.int2hex(y_o, w_data),
                        verif_utils.int2hex(theta_o, w_data),
                    )
                )
            f_in.close()
            f_out.close()
