library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-----------------------------------------------------------
-- spi rx for master or slave with external clk/cs
-----------------------------------------------------------
entity spi_master_rx is
  generic (
    N_SYNCLE: integer := 2;  -- number of stages for level synchronizer
    W_DATA: integer := 48  -- number of bits of data buffer
  );
  port (
    clk_i: in std_logic;
    rst_i: in std_logic;
    rx_en_i: in std_logic;
    spi_rxcs_i: in std_logic;
    spi_rxsck_i: in std_logic;
    spi_miso_a_i: in std_logic;
    spi_miso_b_i: in std_logic;
    rx_data_a_o: out std_logic_vector(W_DATA-1 downto 0);
    rx_data_b_o: out std_logic_vector(W_DATA-1 downto 0);
    c2r_mode: in std_logic;  -- 0: rising-edge sampling, 1: falling-edge sampling
    r2c_ready: out std_logic
  );
end entity spi_master_rx;

architecture rtl of spi_master_rx is
  -- wires
  signal sync_cs, sync_sck, sync_miso_a, sync_miso_b: std_logic;
  signal is_cs_falling, is_cs_rising: std_logic;
  signal is_sck_falling, is_sck_rising: std_logic;
  signal is_sck_edge, rx_data_trig: std_logic;
  -- clock-gating signals
  signal cg_rx: std_logic;
  -- flip-flops
  signal cs_d1, sck_d1: std_logic;
  signal ready, ready_next: std_logic;
  signal rx_data_a, rx_data_a_next: std_logic_vector(W_DATA-1 downto 0);
  signal rx_data_b, rx_data_b_next: std_logic_vector(W_DATA-1 downto 0);
begin
  ---------------------------------------------------------
  -- instantiation part
  ---------------------------------------------------------
  gen_with_sync: if N_SYNCLE>0 generate
    u_syncle_cs: entity work.spi_master_syncle
    generic map (N_SYNCLE => N_SYNCLE, RST_VAL => '1')
    port map (clk_i => clk_i, rst_i => rst_i, d_i => spi_rxcs_i, d_o => sync_cs);
    u_syncle_sck: entity work.spi_master_syncle
    generic map (N_SYNCLE => N_SYNCLE, RST_VAL => '1')
    port map (clk_i => clk_i, rst_i => rst_i, d_i => spi_rxsck_i, d_o => sync_sck);
    u_syncle_miso_a: entity work.spi_master_syncle
    generic map (N_SYNCLE => N_SYNCLE, RST_VAL => '0')
    port map (clk_i => clk_i, rst_i => rst_i, d_i => spi_miso_a_i, d_o => sync_miso_a);
    u_syncle_miso_b: entity work.spi_master_syncle
    generic map (N_SYNCLE => N_SYNCLE, RST_VAL => '0')
    port map (clk_i => clk_i, rst_i => rst_i, d_i => spi_miso_b_i, d_o => sync_miso_b);
  end generate gen_with_sync;
  gen_no_sync: if N_SYNCLE<=0 generate
    sync_cs <= spi_rxcs_i;
    sync_sck <= spi_rxsck_i;
    sync_miso_a <= spi_miso_a_i;
    sync_miso_b <= spi_miso_b_i;
  end generate gen_no_sync;
  ---------------------------------------------------------
  -- combinational part
  ---------------------------------------------------------
  is_cs_falling <= '1' when (cs_d1='1' and sync_cs='0') else '0';
  is_cs_rising <= '1' when (cs_d1='0' and sync_cs='1') else '0';
  is_sck_falling <= '1' when (sck_d1='1' and sync_sck='0') else '0';
  is_sck_rising <= '1' when (sck_d1='0' and sync_sck='1') else '0';
  is_sck_edge <= is_sck_rising when (c2r_mode='0') else is_sck_falling;
  rx_data_trig <= (not sync_cs) and is_sck_edge;
  rx_data_a_next <= (others => '0') when (is_cs_falling='1') else
                    rx_data_a(W_DATA-2 downto 0) & sync_miso_a when (rx_data_trig='1') else
                    rx_data_a;
  rx_data_b_next <= (others => '0') when (is_cs_falling='1') else
                    rx_data_b(W_DATA-2 downto 0) & sync_miso_b when (rx_data_trig='1') else
                    rx_data_b;
  ready_next <= '0' when (is_cs_falling='1') else
                '1' when (is_cs_rising='1') else
                ready;
  cg_rx <= rx_en_i and (is_cs_falling or is_cs_rising or rx_data_trig);
  rx_data_a_o <= rx_data_a;
  rx_data_b_o <= rx_data_b;
  r2c_ready <= ready or not rx_en_i;
  ---------------------------------------------------------
  -- sequential part
  ---------------------------------------------------------
  process (clk_i, rst_i)
  begin
    if (rst_i='1') then
      cs_d1 <= '1';
      sck_d1 <= '1';
      ready <= '1';
      rx_data_a <= (others => '0');
      rx_data_b <= (others => '0');
    elsif rising_edge(clk_i) then
      cs_d1 <= sync_cs;
      sck_d1 <= sync_sck;
      if (cg_rx='1') then
        ready <= ready_next;
        rx_data_a <= rx_data_a_next;
        rx_data_b <= rx_data_b_next;
      end if;
    end if;
  end process;
end architecture rtl;
