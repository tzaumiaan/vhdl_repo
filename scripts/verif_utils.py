import os
import sys
import os_utils

# print with emphasis
def emph_print(x, deco='*'):
    tmp1 = '{0} {1} {0}'.format(deco, str(x))
    tmp2 = deco * len(tmp1)
    print('{1}\n{0}\n{1}'.format(tmp1, tmp2))

def check_log(filename):
    kw_list = ['error', 'fatal_error']
    cnt_err = 0
    for kw in kw_list:
        cnt_err += os_utils.count_keyword(filename, kw)
    print('Checking {}: {} errors'.format(filename, cnt_err))
    if cnt_err!=0:
        emph_print('FAIL @__@')
        sys.exit('Aborted')

def check_sim_result(cfg):
    msg = 'Error: Invalid pattern settings'
    if isinstance(cfg['sim']['pat_out'], str):
        assert isinstance(cfg['sim']['dut_out'], str), msg
        cfg['sim']['pat_out'] = [cfg['sim']['pat_out']]
        cfg['sim']['dut_out'] = [cfg['sim']['dut_out']]
    if isinstance(cfg['sim']['pat_out'], list):
        assert isinstance(cfg['sim']['dut_out'], list), msg
        assert len(cfg['sim']['dut_out']) == len(cfg['sim']['dut_out']) > 0, msg
        cnt_err = 0
        for p_, d_ in zip(cfg['sim']['pat_out'], cfg['sim']['dut_out']):
            cnt_err += check_pat_diff(p_, d_)
    else:
        raise AssertionError(msg)
    return cnt_err

def check_pat_diff(golden, dump):
    assert os.path.exists(golden), 'Error: No pattern {}'.format(golden)
    assert os.path.exists(dump), 'Error: No DUT dump {}'.format(dump)
    cnt_err, cnt = 0, 0
    with open(golden) as f_g, open(dump) as f_d:
        line_g = [l.strip().lower() for l in f_g]
        line_d = [l.strip().lower() for l in f_d]
        for lg, ld in zip(line_g, line_d):
            cnt += 1
            if lg != ld:
                print('Mismatch at line {}: expected {} != result {}'.format(cnt, lg, ld))
                cnt_err += 1
        if len(line_g) != len(line_d):
            print('Mismatch at end: lines of expected {} != result {}'.format(len(line_g), len(line_d)))
            cnt_err += abs(len(line_g) - len(line_d))
    print('Checking {}: {} errors'.format(dump, cnt_err))
    if cnt_err!=0:
        emph_print('FAIL @__@')
    return cnt_err
