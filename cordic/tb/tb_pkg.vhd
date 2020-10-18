library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tb_pkg is
  -- constants
  constant CLK_PERIOD : time := 10 ns;
  constant RESET_TIME : time := 101 ns;
  constant SHORT_DELAY : time := 1.5 ns;
  -- design paramters
  constant W_DATA: integer := 16;
  constant ITER: integer := 16;
  -- functions / procedures declaration
end package tb_pkg;

