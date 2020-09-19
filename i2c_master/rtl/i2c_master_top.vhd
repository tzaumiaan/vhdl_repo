library ieee;
use ieee.std_logic_1164.all;

entity i2c_master_top is
  generic (
    W_ADDR: integer := 7;
    W_DATA: integer := 8
  );
  port (
    clk_i: in std_logic;
    rstb_i: in std_logic;
    scl_o: out std_logic; 
    sda_i: in std_logic;
    sda_o: out std_logic;
    swr_o: out std_logic;
    trig_i: in std_logic;
    busy_o: out std_logic;
    waddr_i: in std_logic_vector(W_ADDR-1 downto 0);
    wdata_i: in std_logic_vector(W_DATA-1 downto 0);
    rdata_o: out std_logic_vector(W_DATA-1 downto 0)
  );
end entity;

architecture rtl of i2c_master_top is
begin
  scl_o <= '0';
  sda_o <= '0';
  swr_o <= '0';
  busy_o <= '1';
  rdata_o <= (others => '0');
end rtl;

