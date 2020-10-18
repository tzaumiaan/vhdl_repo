library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic_top is
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
end entity cordic_top;

architecture rtl of cordic_top is
  signal x_sh, y_sh: signed(W_DATA-1 downto 0); 
begin
  ---------------------------------------------------------
  -- instantiation
  ---------------------------------------------------------
  u_core: entity work.cordic_core
  generic map (
    W_DATA => W_DATA,
    ITER => ITER
  )
  port map (
    clk_i => clk_i,
    rst_i => rst_i,
    trig_i => trig_i,
    mode_i => mode_i,
    x_i => x_sh,
    y_i => y_sh,
    theta_i => theta_i,
    ready_o => ready_o,
    x_o => x_o,
    y_o => y_o,
    theta_o => theta_o
  );
  u_lzsh: entity work.cordic_lzsh
  generic map (
    W_DATA => W_DATA
  )
  port map (
    mode_i => mode_i,
    x_i => x_i,
    y_i => y_i,
    x_o => x_sh,
    y_o => y_sh
  );
end architecture rtl;
