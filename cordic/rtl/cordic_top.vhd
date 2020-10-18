library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic_top is
  port (
    clk_i: in std_logic;
    rst_i: in std_logic;
    data_o: out std_logic_vector(15 downto 0)
  );
end entity cordic_top;

architecture rtl of cordic_top is
begin
  data_o <= (others => '0');
end architecture rtl;
