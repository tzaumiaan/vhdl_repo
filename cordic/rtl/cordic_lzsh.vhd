-----------------------------------------------------------
-- leading zero shifter for inputs of cordic vectoring mode
-----------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic_lzsh is
  generic (
    W_DATA: positive := 16
  );
  port (
    mode_i: in std_logic;  -- mode 0: rotation, 1: vectoring
    x_i: in signed(W_DATA-1 downto 0);
    y_i: in signed(W_DATA-1 downto 0);
    x_o: out signed(W_DATA-1 downto 0);
    y_o: out signed(W_DATA-1 downto 0)
  );
end entity cordic_lzsh;

architecture rtl of cordic_lzsh is
  signal x_ld0, x_ld1, y_ld0, y_ld1, ld: std_logic_vector(W_DATA-1 downto 0);
  signal x_sh, y_sh: signed(W_DATA-1 downto 0);
begin
  ---------------------------------------------------------
  -- combinational part
  ---------------------------------------------------------
  x_ld0(W_DATA-1) <= x_i(W_DATA-1);
  x_ld1(W_DATA-1) <= x_i(W_DATA-1);
  y_ld0(W_DATA-1) <= y_i(W_DATA-1);
  y_ld1(W_DATA-1) <= y_i(W_DATA-1);
  ld(W_DATA-1) <= '1';
  gen_ld: for i in W_DATA-2 downto 0 generate
    x_ld0(i) <= x_i(i) or x_ld0(i+1);
    x_ld1(i) <= x_i(i) and x_ld1(i+1);
    y_ld0(i) <= y_i(i) or y_ld0(i+1);
    y_ld1(i) <= y_i(i) and y_ld1(i+1);
    ld(i) <= ld(i+1) and (not x_ld0(i) or x_ld1(i)) and (not y_ld0(i) or y_ld1(i));
  end generate gen_ld;
  p_lzsh: process (x_i, y_i, ld)
  begin
    x_sh <= x_i;
    y_sh <= y_i;
    -- note: left shift so that the non-zero MSB locates
    --       at "001..." as positive or "110...." as negative
    for i in W_DATA-3 downto 1 loop
      if (ld(i) = '1' and ld(i-1) = '0') then
        x_sh <= shift_left(x_i, W_DATA-i-2);
        y_sh <= shift_left(y_i, W_DATA-i-2);
      end if;
    end loop;
  end process p_lzsh;
  x_o <= x_sh when (mode_i = '1') else x_i;
  y_o <= y_sh when (mode_i = '1') else y_i;
  ---------------------------------------------------------
  -- sequential part
  ---------------------------------------------------------
  -- n/a
end architecture rtl;
