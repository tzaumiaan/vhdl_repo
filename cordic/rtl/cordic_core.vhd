library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity cordic_core is
  generic (
    W_DATA: positive := 16;
    ITER: positive := 16
  );
  port (
    clk_i: in std_logic;
    rst_i: in std_logic;
    trig_i: in std_logic;
    mode_i: in std_logic;  -- mode 0: rotation, 1: vectoring
    x_i: in signed(W_DATA-1 downto 0);
    y_i: in signed(W_DATA-1 downto 0);
    theta_i: in signed(W_DATA-1 downto 0);
    ready_o: out std_logic;
    x_o: out signed(W_DATA-1 downto 0);
    y_o: out signed(W_DATA-1 downto 0);
    theta_o: out signed(W_DATA-1 downto 0)
  );
end entity cordic_core;

architecture rtl of cordic_core is
  -- fsm states --
  constant W_FSM: integer := 2;
  constant ST_IDLE: unsigned(W_FSM-1 downto 0) := to_unsigned(0, W_FSM);
  constant ST_CORE: unsigned(W_FSM-1 downto 0) := to_unsigned(1, W_FSM);
  constant ST_POST: unsigned(W_FSM-1 downto 0) := to_unsigned(2, W_FSM);
  -- atan table generation --
  constant W_LUT: positive := W_DATA + 4; -- 4 extra bits for higher resolution
  type signed_array is array (natural range <>) of signed (W_LUT-1 downto 0);
  function gen_atan_table return signed_array is
    variable tmp: real;
    variable table: signed_array(0 to ITER-1);
  begin
    for i in table'range loop
      -- table content in floating point
      tmp := arctan(2.0**(-i)) * 2.0**(W_LUT) / MATH_2_PI;
      -- truncation to integer
      table(i) := to_signed(integer(tmp), W_LUT);
    end loop;
    return table;
  end function gen_atan_table;
  constant ATAN_TABLE: signed_array(0 to ITER-1) := gen_atan_table;
  -- cordic gain generation --
  function gen_cordic_gain return signed is
    variable k_tmp: real := 1.0;
    variable k: signed (W_DATA-1 downto 0);
  begin
    for i in 0 to ITER-1 loop
      k_tmp := k_tmp * (1.0 / sqrt(1.0 + 2.0**(-2*i)));
    end loop;
    -- truncation to integer
    k := to_signed(integer(k_tmp * 2.0**(W_DATA-1)), W_DATA);
    return k;
  end function gen_cordic_gain;
  constant K: signed (W_DATA-1 downto 0) := gen_cordic_gain;
  -- constants --
  constant W_CNT: integer := integer(ceil(log2(real(ITER))));
  constant MODE_ROT: std_logic := '0';
  constant MODE_VEC: std_logic := '1';
  constant THETA_PI: signed(W_LUT-1 downto 0) := to_signed(integer(2.0**(W_LUT-1)), W_LUT);
  -- wires --
  signal busy: std_logic;
  signal cnt_p1: unsigned(W_CNT-1 downto 0);
  signal is_cnt_hit: std_logic;
  signal quad_init: std_logic;
  signal x_i_tmp, y_i_tmp: signed(W_DATA-1 downto 0);
  signal x_init, x_sh, x_new, x_end: signed(W_DATA downto 0);
  signal y_init, y_sh, y_new, y_end: signed(W_DATA downto 0);
  signal theta_i_ext: signed(W_LUT-1 downto 0);
  signal theta_init, theta_sh, theta_new, theta_end: signed(W_LUT-1 downto 0);
  signal is_neg: std_logic;
  signal kx, ky: signed(2*W_DATA downto 0);
  -- clock gating conditions --
  signal upd_cordic: std_logic;
  -- flip-flops --
  signal state, state_next: unsigned(W_FSM-1 downto 0);
  signal cnt, cnt_next: unsigned(W_CNT-1 downto 0);
  signal quad, quad_next: std_logic; -- 0: quad 1/4, 1: quad 2/3
  signal x_reg, x_reg_next: signed(W_DATA downto 0); 
  signal y_reg, y_reg_next: signed(W_DATA downto 0); 
  signal theta_reg, theta_reg_next: signed(W_LUT-1 downto 0); 
begin
  ---------------------------------------------------------
  -- combinational part
  ---------------------------------------------------------
  -- state --
  state_next <= ST_CORE when (state = ST_IDLE and trig_i = '1') else
                ST_POST when (state = ST_CORE and is_cnt_hit = '1') else
                ST_IDLE when (state = ST_POST) else
                state;
  busy <= '1' when (state /= ST_IDLE) else '0';
  ready_o <= not busy;
  upd_cordic <= trig_i or busy;
  -- counter --
  cnt_p1 <= cnt + 1;
  is_cnt_hit <= '1' when (cnt_p1 = to_unsigned(ITER, cnt_p1'length)) else '0';
  cnt_next <= (others => '0') when (trig_i = '1') else
              (others => '0') when (is_cnt_hit = '1') else
              cnt_p1 when (state = ST_CORE) else
              cnt;
  -- cordic core --
  quad_next <= quad_init when (state = ST_IDLE and trig_i = '1') else
               quad;
  x_reg_next <=  x_init when (state = ST_IDLE and trig_i = '1') else
                 x_new when (state = ST_CORE) else
                 x_end when (state = ST_POST) else
                 x_reg;
  y_reg_next <=  y_init when (state = ST_IDLE and trig_i = '1') else
                 y_new when (state = ST_CORE) else
                 y_end when (state = ST_POST) else
                 y_reg;
  theta_reg_next <= theta_init when (state = ST_IDLE and trig_i = '1') else
                    theta_new when (state = ST_CORE) else
                    theta_end when (state = ST_POST) else
                    theta_reg;
  quad_init <= x_i(x_i'high) when (mode_i = MODE_VEC) else
               theta_i(theta_i'high) xor theta_i(theta_i'high - 1);
  x_i_tmp <= (- x_i) when (mode_i = MODE_ROT and quad_init = '1') else
             (- x_i) when (mode_i = MODE_VEC and quad_init = '1') else
             x_i;
  x_init <= x_i_tmp(x_i_tmp'high) & x_i_tmp;
  y_i_tmp <= (- y_i) when (mode_i = MODE_ROT and quad_init = '1') else
             y_i;
  y_init <= y_i_tmp(y_i_tmp'high) & y_i_tmp;
  theta_i_ext(theta_i_ext'high downto theta_i_ext'high-theta_i'length+1) <= theta_i;
  theta_i_ext(theta_i_ext'high-theta_i'length downto 0) <= (others => '0');
  theta_init <= (theta_i_ext - THETA_PI) when (mode_i = MODE_ROT and quad_init = '1') else
                theta_i_ext when (mode_i = MODE_ROT and quad_init = '0') else
                (others => '0');  -- vectoring mode does not take theta_i
  is_neg <= theta_reg(theta_reg'high) when (mode_i = MODE_ROT) else
            (not y_reg(y_reg'high));
  x_sh <= shift_right(x_reg, to_integer(cnt));
  y_sh <= shift_right(y_reg, to_integer(cnt));
  x_new <= (x_reg + y_sh) when (is_neg = '1') else
           (x_reg - y_sh);
  y_new <= (y_reg - x_sh) when (is_neg = '1') else
           (y_reg + x_sh);
  theta_new <= (theta_reg + ATAN_TABLE(to_integer(cnt))) when (is_neg = '1') else
               (theta_reg - ATAN_TABLE(to_integer(cnt)));

  -- gain adjustment and post processing --
  kx <= K * x_reg;
  ky <= K * y_reg;
  x_end <= kx(kx'high-1 downto kx'high-1-W_DATA);
  y_end <= ky(ky'high-1 downto ky'high-1-W_DATA);
  theta_end <= (THETA_PI - theta_reg) when (mode_i = MODE_VEC and quad = '1') else
               theta_reg;

  -- output --
  x_o <= x_reg(x_reg'high-1 downto 0);
  y_o <= y_reg(y_reg'high-1 downto 0);
  theta_o <= theta_reg(theta_reg'high downto theta_reg'high-theta_o'length+1);

  ---------------------------------------------------------
  -- sequential part
  ---------------------------------------------------------
  process (clk_i, rst_i)
  begin
    if (rst_i = '1') then
      state <= ST_IDLE;
      cnt <= (others => '0');
      quad <= '0';
      x_reg <= (others => '0');
      y_reg <= (others => '0');
      theta_reg <= (others => '0');
    elsif rising_edge(clk_i) then
      if (upd_cordic = '1') then
        state <= state_next;
        cnt <= cnt_next;
        quad <= quad_next;
        x_reg <= x_reg_next;
        y_reg <= y_reg_next;
        theta_reg <= theta_reg_next;
      end if;
    end if;
  end process;
end architecture rtl;
