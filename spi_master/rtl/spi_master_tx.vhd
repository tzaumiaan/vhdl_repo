library ieee;
use ieee.std_logic_1164.all;

-----------------------------------------------------------
-- spi tx for master
-----------------------------------------------------------
entity spi_master_tx is
  generic (
    W_DATA: integer := 48  -- number of bits of data buffer
  );
  port (
    clk_i: in std_logic;
    rst_i: in std_logic;
    spi_mosi_o: out std_logic;
    tx_data_i: in std_logic_vector(W_DATA-1 downto 0);
    c2t_di_trig: in std_logic;
    c2t_do_trig: in std_logic
  );
end entity spi_master_tx;

architecture rtl of spi_master_tx is
  -- clock-gating conditions
  signal cg_tx: std_logic;
  -- flip-flops
  signal tx_data, tx_data_next: std_logic_vector(W_DATA-1 downto 0);
begin
  ---------------------------------------------------------
  -- combinational part
  ---------------------------------------------------------
  cg_tx <= c2t_di_trig or c2t_do_trig;
  tx_data_next <= tx_data_i when (c2t_di_trig='1') else
                  tx_data(tx_data'high-1 downto 0) & '0' when (c2t_do_trig='1') else
                  tx_data;
  spi_mosi_o <= tx_data(tx_data'high);
  ---------------------------------------------------------
  -- sequential part
  ---------------------------------------------------------
  process (clk_i, rst_i)
  begin
    if (rst_i='1') then
      tx_data <= (others => '0');
    elsif rising_edge(clk_i) then
      if (cg_tx='1') then
        tx_data <= tx_data_next;
      end if;
    end if;
  end process;
end architecture rtl;
