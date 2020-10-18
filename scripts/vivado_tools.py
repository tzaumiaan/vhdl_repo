import os
import subprocess
from fnmatch import fnmatch
import importlib
from ruamel import yaml
import os_utils
import verif_utils
import module_utils

# vivado settings
vivado_ver = "2019.1"
vivado_path = {
    "win_local": r"C:\Xilinx\Vivado\{}\bin".format(vivado_ver),
    "linux_local": r"/tools/Xilinx/Vivado/{}/bin".format(vivado_ver),
    "linux_ci": r"/opt/Xilinx/Vivado/{}/bin".format(vivado_ver),
}
vivado_comp_opt = " -v 0"  # use -2008 only in simulation, not linting
vivado_elab_opt = " -debug typical -v 0 -mt off -stat"
vivado_sim_opt = ""
vivado_comp = "xvhdl"
vivado_elab = "xelab"
vivado_sim = "xsim"
work_dir_prefix = "work"

vivado_cmd = lambda path, cmd, opt: os.path.join(path, cmd) + opt


def parse_module_config(config_name=module_utils.config_name):
    assert os.path.exists(config_name)
    cfg = dict()
    with open(config_name) as f:
        cfg = yaml.load(f, Loader=yaml.Loader)
    # process file list into string
    cfg["__module_root__"] = os.path.realpath(os.getcwd())
    cfg_src = cfg["src_list"]
    for _s in cfg_src:
        if cfg_src[_s] is None:
            cfg_src[_s] = []
        elif isinstance(cfg_src[_s], str):
            if "*" in cfg_src[_s]:  # wildcard match
                cfg_src[_s] = [_f for _f in os.listdir(_s) if fnmatch(_f, cfg_src[_s])]
            else:
                cfg_src[_s] = cfg_src[_s].split()
        assert isinstance(cfg_src[_s], list), "Error: invalid {}: {}".format(
            _s, cfg_src[_s]
        )
        _tmp = [os.path.join(cfg["__module_root__"], _s, _f) for _f in cfg_src[_s]]
        cfg_src[_s] = " ".join(_tmp)
    # print(cfg_src) # for debugging only
    return cfg


def create_vivado_dir(cfg, vivado_mode="win_local", gen_work_dir=True):
    # vivado path
    cfg["__vivado_path__"] = vivado_path[vivado_mode]
    # create working directory
    if gen_work_dir:
        cfg["__work_dir__"] = os_utils.mkdir_w_datetime(
            cfg["__module_root__"], work_dir_prefix
        )
    else:
        cfg["__work_dir__"] = os_utils.get_latest_dir(
            cfg["__module_root__"], work_dir_prefix
        )


def parse_rtl_hier(cfg, submodule_list, src_list):
    cur_module = os_utils.get_cur_dir()
    if cfg["submodules"] is not None:
        for m_ in cfg["submodules"]:
            if m_ in submodule_list:
                continue  # already parsed
            # go to that module and parse it
            print("--> parsing submodule: {}".format(m_))
            m_dir = os.path.realpath(os.path.join(cfg["__module_root__"], "..", m_))
            os.chdir(m_dir)
            m_cfg = parse_module_config()
            src_list = parse_rtl_hier(m_cfg, submodule_list, src_list)
            submodule_list.append(m_)
            os.chdir(cfg["__module_root__"])
    if cur_module not in submodule_list:
        src_list += " " + cfg["src_list"]["rtl"]
    return src_list


def module_compile(cfg, w_tb=True):
    verif_utils.emph_print("COMPILE")
    submodule_list = list()
    src_list = parse_rtl_hier(cfg, submodule_list, "")
    src_list += " " + cfg["src_list"]["rtl"]
    comp_opt = vivado_comp_opt
    if w_tb:
        src_list += " " + cfg["src_list"]["tb"]
        comp_opt += " -2008"
    cmd = vivado_cmd(cfg["__vivado_path__"], vivado_comp, comp_opt)
    cmd = r"{} {}".format(cmd, src_list)
    os.chdir(cfg["__work_dir__"])
    subprocess.call(cmd, shell=True)
    verif_utils.check_log("xvhdl.log")
    verif_utils.emph_print(
        "COMPILE: " + verif_utils.pass_string, color="green", bold=True
    )
    os.chdir(cfg["__module_root__"])


def module_elaborate(cfg):
    verif_utils.emph_print("ELABORATE")
    cmd = vivado_cmd(cfg["__vivado_path__"], vivado_elab, vivado_elab_opt)
    cmd = r"{0} {1} -s {1}_sim".format(cmd, cfg["sim"]["top_name"])
    os.chdir(cfg["__work_dir__"])
    subprocess.call(cmd, shell=True)
    verif_utils.check_log("xelab.log")
    verif_utils.emph_print(
        "ELABORATE: " + verif_utils.pass_string, color="green", bold=True
    )
    os.chdir(cfg["__module_root__"])


def module_simulate(cfg):
    verif_utils.emph_print("SIMULATE")
    os.chdir(cfg["__work_dir__"])
    pat_shared_path = os.path.join(cfg["__module_root__"], "sim")
    sim_summary = dict()
    case_dir_list = list()
    # fixed patterns
    for sim_case in cfg["sim"]["fixed_cases"]:
        case_dir = os_utils.mkdir(".", sim_case)
        os.chdir(case_dir)
        print("Preparing fixed case [{}] ...".format(sim_case))
        # link necessay files here
        pat_case_path = os.path.join(pat_shared_path, sim_case)
        # 1. sim.tcl: search for case folder first, then use the shared one
        for _p in [pat_case_path, pat_shared_path]:
            _src = os.path.join(_p, module_utils.sim_tcl_name)
            if os.path.exists(_src):
                os_utils.symlink(_src, module_utils.sim_tcl_name)
                break
        assert os.path.exists(module_utils.sim_tcl_name), "Error: tcl file not found!"
        # 2. pattern input and output
        for _f in os.listdir(pat_case_path):
            if _f.endswith(".txt"):
                os_utils.symlink(os.path.join(pat_case_path, _f), _f)
        os.chdir(cfg["__work_dir__"])
        case_dir_list.append(case_dir)
    # generated patterns
    if cfg["sim"]["generated_cases"] is not None:
        assert (
            cfg["sim"]["pat_gen_script"] is not None
        ), "Error: pattern generator not defined!"
        pg_root = importlib.import_module(cfg["sim"]["pat_gen_script"])
        for sim_case, pat_cfg in cfg["sim"]["generated_cases"].items():
            case_dir = os_utils.mkdir(".", sim_case)
            os.chdir(case_dir)
            print("Preparing generated case [{}] ...".format(sim_case))
            pg_root.pattern_generator(pat_cfg).run()
            os.chdir(cfg["__work_dir__"])
            case_dir_list.append(case_dir)
    # simulate
    for case_dir in case_dir_list:
        os.chdir(case_dir)
        sim_case = os_utils.get_cur_dir()
        verif_utils.emph_print("SIM CASE: {}".format(sim_case))
        # link the xsim snapshot
        os_utils.symlink(os.path.join(cfg["__work_dir__"], "xsim.dir"), "xsim.dir")
        # simulate
        cmd = vivado_cmd(cfg["__vivado_path__"], vivado_sim, vivado_sim_opt)
        cmd = r"{0} {1}_sim -t {2}".format(
            cmd, cfg["sim"]["top_name"], module_utils.sim_tcl_name
        )
        subprocess.call(cmd, shell=True)
        verif_utils.check_log("xsim.log")
        pc_root = verif_utils
        if cfg["sim"]["pat_comp_script"] is not None:
            pc_root = importlib.import_module(cfg["sim"]["pat_comp_script"])
        pc = pc_root.pattern_comparator(cfg["sim"]["pat_out"], cfg["sim"]["dut_out"])
        sim_summary[sim_case] = pc.run()
        os.chdir(cfg["__work_dir__"])
    os.chdir(cfg["__module_root__"])
    # check simulation summary
    verif_utils.check_sim_summary(sim_summary)


def view_latest_result(cfg, sim_dir):
    verif_utils.emph_print("VIEW WAVEFORM: CASE {}".format(sim_dir))
    sim_path = os.path.join(cfg["__work_dir__"], sim_dir)
    assert os.path.exists(sim_path)
    os.chdir(sim_path)
    # link waveform config if exists
    pat_shared_path = os.path.join(cfg["__module_root__"], "sim")
    wcfg_flags = ""
    for _f in os.listdir(pat_shared_path):
        if _f.endswith(".wcfg"):
            if not os.path.exists(_f):
                os_utils.symlink(os.path.join(pat_shared_path, _f), _f)
            wcfg_flags += " -view {}".format(_f)
    cmd = vivado_cmd(cfg["__vivado_path__"], vivado_sim, vivado_sim_opt)
    cmd = r"{0} {1}_sim.wdb {2} -gui".format(cmd, cfg["sim"]["top_name"], wcfg_flags)
    subprocess.call(cmd, shell=True)
    os.chdir(cfg["__module_root__"])
