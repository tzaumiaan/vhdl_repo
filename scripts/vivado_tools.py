import os
import subprocess
from fnmatch import fnmatch
from ruamel import yaml
import os_utils
import verif_utils

# vivado settings
vivado_ver = '2019.1'
#vivado_path = r'C:\Xilinx\Vivado\{}\bin'.format(vivado_ver) # windows
vivado_path = r'/tools/Xilinx/Vivado/{}/bin'.format(vivado_ver) # windows
vivado_comp_opt = ' --2008'
vivado_elab_opt = ' --debug typical -v 1 --mt off --stat'
vivado_sim_opt = ''
vivado_comp = os.path.join(vivado_path, 'xvhdl') + vivado_comp_opt
vivado_elab = os.path.join(vivado_path, 'xelab') + vivado_elab_opt
vivado_sim = os.path.join(vivado_path, 'xsim') + vivado_sim_opt
work_dir_prefix = 'work'

def parse_module_config(filename='config.yml', gen_work_dir=True):
    assert os.path.exists(filename)
    cfg = dict()
    with open(filename) as f:
        cfg = yaml.load(f, Loader=yaml.Loader)
    # process file list into string
    cfg['__module_root__'] = os.path.realpath(os.getcwd())
    if gen_work_dir:
        cfg['__work_dir__'] = os_utils.mkdir_w_datetime(cfg['__module_root__'], work_dir_prefix)
    else:
        cfg['__work_dir__'] = os_utils.get_latest_dir(cfg['__module_root__'], work_dir_prefix)
    cfg_src = cfg['src_list']
    for _s in cfg_src:
        if cfg_src[_s] is None:
            cfg_src[_s] = []
        elif isinstance(cfg_src[_s], str):
            if '*' in cfg_src[_s]: # wildcard match
                cfg_src[_s] = [_f for _f in os.listdir(_s) if fnmatch(_f, cfg_src[_s])]
            else:
                cfg_src[_s] = cfg_src[_s].split()
        assert isinstance(cfg_src[_s], list), 'Error: invalid {}: {}'.format(_s, cfg_src[_s])
        _tmp = [os.path.join(cfg['__module_root__'], _s, _f) for _f in cfg_src[_s]]
        cfg_src[_s] = ' '.join(_tmp)
    #print(cfg_src) # for debugging only
    return cfg

def module_compile(cfg, w_tb=True):
    verif_utils.emph_print('COMPILE')
    src_list = cfg['src_list']['rtl']
    if w_tb:
        src_list += ' ' + cfg['src_list']['tb']
    if cfg['submodules'] is not None:
        pass # TODO: to handle submodule list
    cmd = r'{} {}'.format(vivado_comp, src_list)
    os.chdir(cfg['__work_dir__'])
    subprocess.call(cmd, shell=True)
    verif_utils.check_log('xvhdl.log')
    verif_utils.emph_print('COMPILE: PASS ^__^')
    os.chdir(cfg['__module_root__'])

def module_elaborate(cfg):
    verif_utils.emph_print('ELABORATE')
    cmd = r'{0} {1} -s {1}_sim'.format(vivado_elab, cfg['sim']['top_name'])
    os.chdir(cfg['__work_dir__'])
    subprocess.call(cmd, shell=True)
    verif_utils.check_log('xelab.log')
    verif_utils.emph_print('ELABORATE: PASS ^__^')
    os.chdir(cfg['__module_root__'])

def module_simulate(cfg):
    verif_utils.emph_print('SIMULATE')
    os.chdir(cfg['__work_dir__'])
    pat_shared_path = os.path.join(cfg['__module_root__'], 'sim')
    sim_summary = dict()
    # fixed patterns
    for sim_case in cfg['sim']['fixed_cases']:
        case_dir = os_utils.mkdir('.', sim_case)
        os.chdir(case_dir)
        verif_utils.emph_print('SIM CASE: {}'.format(sim_case))
        # link necessay files here
        pat_case_path = os.path.join(pat_shared_path, sim_case)
        # 1. sim.tcl: search for case folder first, then use the shared one
        tcl_name = 'sim.tcl'
        for _p in [pat_case_path, pat_shared_path]:
            _src = os.path.join(_p, tcl_name)
            if os.path.exists(_src):
                os_utils.symlink(_src, tcl_name)
                break
        assert os.path.exists(tcl_name), 'Error: tcl file not found!'
        # 2. pattern input and output
        for _f in os.listdir(pat_case_path):
            if _f.endswith('.txt'):
                os_utils.symlink(os.path.join(pat_case_path, _f), _f)
        # link the xsim snapshot
        os_utils.symlink(os.path.join(cfg['__work_dir__'], 'xsim.dir'), 'xsim.dir')
        # simulate
        cmd = r'{0} {1}_sim -t {2}'.format(vivado_sim, cfg['sim']['top_name'], tcl_name)
        subprocess.call(cmd, shell=True)
        verif_utils.check_log('xsim.log')
        cnt_err = verif_utils.check_sim_result(cfg)
        sim_summary[sim_case] = cnt_err
        os.chdir(cfg['__work_dir__'])
    # TODO: random patterns
    # summary
    verif_utils.emph_print('SIMULATION SUMMARY')
    is_pass = True
    for k, v in sim_summary.items():
        is_pass = is_pass and v==0
        print('Case [{}]: {} ({} errors)'.format(k, 'Pass' if v==0 else 'Fail', v))
    if is_pass:
        verif_utils.emph_print('PASS ^__^')
    else:
        verif_utils.emph_print('FAIL @__@')
    os.chdir(cfg['__module_root__'])

def view_latest_result(cfg, sim_dir):
    verif_utils.emph_print('VIEW WAVEFORM: CASE {}'.format(sim_dir))
    sim_path = os.path.join(cfg['__work_dir__'], sim_dir)
    assert os.path.exists(sim_path)
    os.chdir(sim_path)
    # link waveform config if exists
    pat_shared_path = os.path.join(cfg['__module_root__'], 'sim')
    wcfg_flags = ''
    for _f in os.listdir(pat_shared_path):
        if _f.endswith('.wcfg'):
            if not os.path.exists(_f):
                os_utils.symlink(os.path.join(pat_shared_path, _f), _f)
            wcfg_flags += ' -view {}'.format(_f)
    cmd = r'{0} {1}_sim.wdb {2} -gui'.format(vivado_sim, cfg['sim']['top_name'], wcfg_flags)
    subprocess.call(cmd, shell=True)
    os.chdir(cfg['__module_root__'])
