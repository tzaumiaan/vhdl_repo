import os
import os_utils

dir_list = ["rtl", "tb", "sim"]
config_name = "config.yml"
design_ports = [("clk_i", "in", 1), ("rst_i", "in", 1), ("data_o", "out", 16)]
design_libs = ["ieee.std_logic_1164", "ieee.numeric_std"]
tb_libs = design_libs + ["ieee.std_logic_textio", "std.textio"]
sim_tcl_name = "sim.tcl"


def module_init():
    module_name = os_utils.get_cur_dir()
    create_module_structure()
    create_empty_vhdl("rtl", "{}_top".format(module_name), design_libs, design_ports)
    create_empty_vhdl("tb", "tb", tb_libs, None)
    create_config(module_name)


def create_module_structure():
    for d in dir_list:
        os_utils.mkdir(".", d)


def create_config(module_name):
    if os.path.exists(config_name):
        return
    with open(config_name, "w") as f:
        f.write("src_list:\n")
        f.write("  rtl:\n")
        f.write("    - {}_top.vhd\n".format(module_name))
        f.write("  tb:\n")
        f.write("    - tb.vhd\n")
        f.write("submodules: null\n")
        f.write("sim:\n")
        f.write("  top_name: tb\n")
        f.write("  pat_in: pat_in.txt\n")
        f.write("  pat_out: pat_out.txt\n")
        f.write("  dut_out: dut_out.txt\n")
        f.write("  pat_gen_script: null\n")
        f.write("  pat_comp_script: null\n")
        f.write("  fixed_cases: null\n")
        f.write("  generated_cases: null\n")
        f.close()


def create_empty_vhdl(dir_name, module_name, libs, ports):
    file_name = os.path.join(dir_name, "{}.vhd".format(module_name))
    if os.path.exists(file_name):
        return
    with open(file_name, "w") as f:
        # library part
        lib_list = []
        for l_ in libs:
            lib_name = l_.split(".")[0]
            if lib_name not in lib_list:
                f.write("library {};\n".format(lib_name))
                lib_list.append(lib_name)
            f.write("use {}.all;\n".format(l_))
        f.write("\n")
        # entity part
        f.write("entity {} is\n".format(module_name))
        if ports is not None:
            f.write("  port (\n")
            for i, p_ in enumerate(ports):
                d_type = "std_logic"
                if p_[2] > 1:
                    d_type += "_vector({} downto 0)".format(p_[2] - 1)
                f.write("    {}: {} {}".format(p_[0], p_[1], d_type))
                if i + 1 < len(ports):
                    f.write(";")
                f.write("\n")
            f.write("  );\n")
        f.write("end entity {};\n\n".format(module_name))
        # architecture part
        f.write("architecture rtl of {} is\nbegin\n".format(module_name))
        if ports is not None:
            for p_ in ports:
                if p_[1] != "out":
                    continue
                o_val = "(others => '0')" if p_[2] > 1 else "'0'"
                f.write("  {} <= {};\n".format(p_[0], o_val))
        f.write("end architecture rtl;\n")
        f.close()


def create_sim_tcl(dir_name: str, sim_timeout: str) -> None:
    assert os.path.exists(dir_name)
    file_name = os.path.join(dir_name, sim_tcl_name)
    if os.path.exists(file_name):
        return
    with open(file_name, "w") as f:
        f.write("log_wave -r -v /\n")
        f.write("run {}\n".format(sim_timeout))
        f.write("quit\n")
        f.close()
