library ieee;
use ieee.std_logic_1164.all;

-----------------------------------------------------------
-- level synchronizer
-----------------------------------------------------------
entity spi_master_syncle is
  generic (
    N_SYNCLE: integer := 2;  -- number of level used for synchronizer DFF
    RST_VAL: std_logic := '0'  -- default value after reset
  );
  port (
    clk_i: in std_logic;
    rst_i: in std_logic;
    d_i: in std_logic;
    d_o: out std_logic
  );
end entity spi_master_syncle;

architecture rtl of spi_master_syncle is
  signal d_buf, d_buf_next: std_logic_vector(N_SYNCLE-1 downto 0);
begin
  ---------------------------------------------------------
  -- combinational part
  ---------------------------------------------------------
  d_buf_next <= d_i & d_buf(N_SYNCLE-1 downto 1);
  d_o <= d_buf(0);
  ---------------------------------------------------------
  -- sequential part
  ---------------------------------------------------------
  process (clk_i, rst_i)
  begin
    if (rst_i='1') then
      d_buf <= (others => RST_VAL);
    elsif rising_edge(clk_i) then
      d_buf <= d_buf_next;
    end if;
  end process;
end architecture rtl;
