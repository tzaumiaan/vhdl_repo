-- testbench for spi_top

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;

use work.tb_pkg.all; -- constants and subroutines

entity tb is
end tb;

architecture rtl of tb is
  -- dut i/o signals
  signal clk_i: std_logic := '0';
  signal rst_i: std_logic := '0';
  signal trig_i: std_logic := '0'; 
  signal rx_en_i: std_logic := '0';
  signal cpol_i: std_logic := '0';
  signal cpha_i: std_logic := '0';
  signal nbits_i: std_logic_vector(W_CNT-1 downto 0) := (others => '0');
  signal ckdiv_i: std_logic_vector(15 downto 0) := (others => '0');
  signal tx_word_i: std_logic_vector(W_DATA-1 downto 0) := (others => '0');
  signal rxcs_i: std_logic := '1'; 
  signal rxsck_i: std_logic := 'U'; 
  signal sdi_i: std_logic := 'U'; 
  signal rx_data_a_o: std_logic_vector(W_DATA-1 downto 0);
  signal rx_data_b_o: std_logic_vector(W_DATA-1 downto 0);
  signal cs_o: std_logic; 
  signal sck_o: std_logic; 
  signal sdo_o: std_logic; 
  signal ready_o: std_logic;
  -- simulation signals
  signal data_block: std_logic_vector(W_DATA-1 downto 0);
  signal data_size: integer;
  signal wr_en: std_logic;
  signal data_dump: std_logic_vector(W_DATA-1 downto 0);
  -- functions / procedures
  -- n/a
begin
  -- instantiation
  u_spi_master_top: entity work.spi_master_top
  generic map (
    WITH_RX => true,
    WITH_EXT_CLK => true,
    W_CNT => W_CNT,
    W_DATA => W_DATA
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
    rx_en_i => rx_en_i,
    spi_cs_o => cs_o,
    spi_sck_o => sck_o,
    spi_mosi_o => sdo_o,
    spi_miso_a_i => sdi_i,
    spi_miso_b_i => (not sdi_i),
    spi_rxcs_i => rxcs_i,
    spi_rxsck_i => rxsck_i,
    tx_data_i => tx_word_i,
    rx_data_a_o => rx_data_a_o,
    rx_data_b_o => rx_data_b_o
  );
  -- clock behavior
  clk_i <= not clk_i after (CLK_PERIOD/2);
  -- static settings
  data_size <= to_integer(unsigned(nbits_i));
  rx_en_i <= not wr_en;
  -- cs and sck return path delay
  rxcs_i <= transport cs_o after RX_DELAY;
  rxsck_i <= transport sck_o after RX_DELAY;
  -- main simulation process
  p_sim: process
    file f_feed: text open read_mode is "pat_in.txt";
    file f_dump: text open write_mode is "dut_out.txt";
    variable l_feed, l_dump: line;
    variable din, dout: std_logic_vector(W_DATA-1 downto 0);
  begin
    -- hold reset for RESET_TIME
    rst_i <= '1';
    trig_i <= '0';
    wait for RESET_TIME;
    rst_i <= '0';
    wait for SHORT_DELAY;
    -- sim body
    report "Simulation starts after reset released" severity note;
    --   apply configuration
    while not endfile(f_feed) loop
      readline(f_feed, l_feed);
      next when l_feed(1)='#'; -- skip comment in files
      exit; -- got the line
    end loop;
    hread(l_feed, din( 0 downto 0)); cpol_i <= din(0);
    hread(l_feed, din( 0 downto 0)); cpha_i <= din(0);
    wait for SHORT_DELAY;
    while not endfile(f_feed) loop
      readline(f_feed, l_feed);
      next when l_feed.all(1)='#'; -- skip comment in files
      hread(l_feed, din(15 downto 0)); ckdiv_i <= din(15 downto 0);
      hread(l_feed, din(W_CNT-1 downto 0)); nbits_i <= din(W_CNT-1 downto 0);
      hread(l_feed, din); data_block <= din;
      hread(l_feed, din(0 downto 0)); wr_en <= din(0);
      wait for SHORT_DELAY;
      tx_word_i <= (others => '0');
      sdi_i <= 'Z';
      if wr_en='1' then
        p_master_wr (
          clk => clk_i,
          tx_start => trig_i,
          tx_done => ready_o,
          data_size => data_size, 
          data_block => data_block, 
          tx_cs => cs_o,
          tx_sck => sck_o,
          tx_sdo => sdo_o,
          cpol => cpol_i,
          cpha => cpha_i,
          tx_word => tx_word_i,
          tx_result => data_dump);
      elsif wr_en='0' then
        p_master_rd (
          clk => clk_i,
          rx_start => trig_i,
          rx_done => ready_o,
          data_size => data_size, 
          data_block => data_block, 
          rx_cs => rxcs_i,
          rx_sck => rxsck_i,
          rx_sdi => sdi_i,
          cpol => cpol_i,
          cpha => cpha_i,
          rx_word_1 => rx_data_b_o,
          rx_word_0 => rx_data_a_o,
          rx_result => data_dump);
      end if;
      dout := data_dump;
      hwrite(l_dump, dout);
      dout(0) := wr_en;
      hwrite(l_dump, dout(0 downto 0), right, 2);
      writeline(f_dump, l_dump);
    end loop;
    -- sim done
    assert false report "Simulation done" severity note;
    wait;
  end process;
end rtl;
