library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master_top is
  generic (
    WITH_RX: boolean := true;
    WITH_EXT_CLK: boolean := true;
    W_CNT: integer := 6;  -- number of bits of bit counter
    W_DATA: integer := 48  -- number of bits of data buffer
  );
  port (
    clk_i: in std_logic;
    rst_i: in std_logic;
    trig_i: in std_logic;
    ready_o: out std_logic;
    ckdiv_i: in std_logic_vector(15 downto 0);
    nbits_i: in std_logic_vector(W_CNT-1 downto 0);
    cpol_i: in std_logic;
    cpha_i: in std_logic;
    rx_en_i: in std_logic;
    spi_cs_o: out std_logic; 
    spi_sck_o: out std_logic; 
    spi_mosi_o: out std_logic;
    spi_miso_a_i: in std_logic;
    spi_miso_b_i: in std_logic;
    spi_rxcs_i: in std_logic;
    spi_rxsck_i: in std_logic;
    tx_data_i: in std_logic_vector(W_DATA-1 downto 0);
    rx_data_a_o: out std_logic_vector(W_DATA-1 downto 0);
    rx_data_b_o: out std_logic_vector(W_DATA-1 downto 0)
  );
end entity spi_master_top;

architecture rtl of spi_master_top is
  signal r2c_ready: std_logic;
  signal c2r_mode: std_logic;
  signal c2t_di_trig: std_logic;
  signal c2t_do_trig: std_logic;
  signal spi_cs: std_logic;
  signal spi_sck: std_logic;
begin
  ---------------------------------------------------------
  -- instantiation
  ---------------------------------------------------------
  u_ctrl: entity work.spi_master_ctrl
  generic map (
    W_CNT => W_CNT
  )
  port map (
    clk_i => clk_i,
    rst_i => rst_i,
    trig_i => trig_i,
    ready_o => ready_o,
    ckdiv_i => ckdiv_i,
    nbits_i => nbits_i,
    cpol_i => cpol_i,
    cpha_i => cpha_i,
    spi_cs_o => spi_cs,
    spi_sck_o => spi_sck,
    c2r_mode => c2r_mode,
    r2c_ready => r2c_ready,
    c2t_di_trig => c2t_di_trig,
    c2t_do_trig => c2t_do_trig
  );
  u_tx: entity work.spi_master_tx
  generic map (
    W_DATA => W_DATA
  )
  port map (
    clk_i => clk_i,
    rst_i => rst_i,
    spi_mosi_o => spi_mosi_o,
    tx_data_i => tx_data_i,
    c2t_di_trig => c2t_di_trig,
    c2t_do_trig => c2t_do_trig
  );
  gen_rx_slv: if (WITH_RX=true and WITH_EXT_CLK=true) generate
    u_rx: entity work.spi_master_rx
    generic map (
      N_SYNCLE => 2,
      W_DATA => W_DATA
    )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,
      rx_en_i => rx_en_i,
      spi_rxcs_i => spi_rxcs_i,
      spi_rxsck_i => spi_rxsck_i,
      spi_miso_a_i => spi_miso_a_i,
      spi_miso_b_i => spi_miso_b_i,
      rx_data_a_o => rx_data_a_o,
      rx_data_b_o => rx_data_b_o,
      c2r_mode => c2r_mode,
      r2c_ready => r2c_ready
    );
  end generate gen_rx_slv;
  gen_rx_mst: if (WITH_RX=true and WITH_EXT_CLK=false) generate
    u_rx: entity work.spi_master_rx
    generic map (
      N_SYNCLE => 0,
      W_DATA => W_DATA
    )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,
      rx_en_i => rx_en_i,
      spi_rxcs_i => spi_cs,
      spi_rxsck_i => spi_sck,
      spi_miso_a_i => spi_miso_a_i,
      spi_miso_b_i => spi_miso_b_i,
      rx_data_a_o => rx_data_a_o,
      rx_data_b_o => rx_data_b_o,
      c2r_mode => c2r_mode,
      r2c_ready => r2c_ready
    );
  end generate gen_rx_mst;
  gen_no_rx: if WITH_RX=false generate
    rx_data_a_o <= (others => '0');
    rx_data_b_o <= (others => '0');
    r2c_ready <= '1';
  end generate gen_no_rx;
  ---------------------------------------------------------
  -- combinational part
  ---------------------------------------------------------
  spi_cs_o <= spi_cs;
  spi_sck_o <= spi_sck;
end architecture rtl;
