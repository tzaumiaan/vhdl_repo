import argparse
import vivado_tools as vt

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='VHDL toolchain main entry')
    parser.add_argument('op_type', type=str, help='operation type')
    parser.add_argument('-s', '--sim_dir', type=str, help='simulation directory')
    args = parser.parse_args()
    if args.op_type == 'lint':
        cfg = vt.parse_module_config()
        vt.module_compile(cfg, w_tb=False)
    elif args.op_type == 'sim':
        cfg = vt.parse_module_config()
        vt.module_compile(cfg, w_tb=True)
        vt.module_elaborate(cfg)
        vt.module_simulate(cfg)
    elif args.op_type == 'view':
        cfg = vt.parse_module_config(gen_work_dir=False)
        assert args.sim_dir is not None
        vt.view_latest_result(cfg, args.sim_dir)
    else:
        print('Unknown operation type')
        parser.print_help()
