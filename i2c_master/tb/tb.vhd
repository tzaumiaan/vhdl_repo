-- testbench for i2c_master_top

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
  signal rst_i: std_logic := '1';
  signal trig_i: std_logic;
  signal busy_o: std_logic;
  signal ckdiv_i: std_logic_vector(W_CKDIV-1 downto 0);
  signal addr_i: std_logic_vector(W_ADDR-1 downto 0);
  signal wr_data_i: std_logic_vector(N_BUF*W_DATA-1 downto 0);
  signal rd_data_o: std_logic_vector(N_BUF*W_DATA-1 downto 0);
  signal wr_bytes_i: std_logic_vector(W_BUF-1 downto 0);
  signal rd_bytes_i: std_logic_vector(W_BUF-1 downto 0);
  signal scl_i: std_logic; 
  signal scl_o: std_logic; 
  signal scl_oen: std_logic;
  signal sda_i: std_logic;
  signal sda_o: std_logic;
  signal sda_oen: std_logic;
  -- simulation signals
  signal sig_start: std_logic := '0';
  signal sig_stop: std_logic := '0';
  signal scl_slv: std_logic := 'Z';
  signal sda_slv: std_logic := 'Z';
  signal rd_data_feed: std_logic_vector(N_BUF*W_DATA-1 downto 0) := (others => 'X');
  signal wr_data_dump: std_logic_vector(N_BUF*W_DATA-1 downto 0) := (others => 'X');
  signal addr_dump: std_logic_vector(W_ADDR-1 downto 0) := (others => 'X');
  -- functions / procedures
  -- n/a
begin
  -- instantiation
  u_i2c_master: entity work.i2c_master_top
  generic map (
    W_ADDR => W_ADDR,
    W_DATA => W_DATA,
    W_CNT => W_CNT,
    N_BUF => N_BUF,
    W_BUF => W_BUF,
    W_CKDIV => W_CKDIV
  )
  port map (
    clk_i => clk_i,
    rst_i => rst_i,
    trig_i => trig_i,
    busy_o => busy_o,
    ckdiv_i => ckdiv_i,
    addr_i => addr_i,
    wr_data_i => wr_data_i,
    rd_data_o => rd_data_o,
    wr_bytes_i => wr_bytes_i,
    rd_bytes_i => rd_bytes_i,
    scl_i => scl_i,
    scl_o => scl_o,
    scl_oen => scl_oen,
    sda_i => sda_i,
    sda_o => sda_o,
    sda_oen => sda_oen
  );
  -- clock behavior
  clk_i <= not clk_i after (CLK_PERIOD/2);
  -- static settings
  scl_i <= scl_o when (scl_oen='1') else scl_slv;
  sda_i <= sda_o when (sda_oen='1') else sda_slv;
  -- subroutines
  p_sig: process (sda_i)
  begin
    if falling_edge(sda_i) and scl_i='1' then
      sig_start <= '1', '0' after SHORT_DELAY;
    elsif rising_edge(sda_i) and scl_i='1' then
      sig_stop <= '1', '0' after SHORT_DELAY;
    end if;
  end process;
  -- main simulation process
  p_sim: process
    file f_feed : text open read_mode is "pat_in.txt";
    file f_dump : text open write_mode is "dut_out.txt";
    variable l_feed, l_dump : line;
    variable din, dout : std_logic_vector(63 downto 0);
  begin
    -- hold reset for RESET_TIME
    rst_i <= '1';
    wait for RESET_TIME;
    rst_i <= '0';
    trig_i <= '0';
    wait for SHORT_DELAY;
    -- sim body
    report "Simulation starts after reset released" severity note;
    while not endfile(f_feed) loop
      readline(f_feed, l_feed);
      next when l_feed(1)='#'; -- skip comment in files
      exit; -- got the line
    end loop;
    hread(l_feed, din(W_CKDIV-1 downto 0)); ckdiv_i <= din(W_CKDIV-1 downto 0);
    wait for SHORT_DELAY;
    while not endfile(f_feed) loop
      readline(f_feed, l_feed);
      next when l_feed.all(1)='#'; -- skip comment in files
      hread(l_feed, din(W_ADDR-1 downto 0)); addr_i <= din(W_ADDR-1 downto 0);
      hread(l_feed, din(W_BUF-1 downto 0)); wr_bytes_i <= din(W_BUF-1 downto 0);
      hread(l_feed, din(N_BUF*W_DATA-1 downto 0)); wr_data_i <= din(N_BUF*W_DATA-1 downto 0);
      hread(l_feed, din(W_BUF-1 downto 0)); rd_bytes_i <= din(W_BUF-1 downto 0);
      hread(l_feed, din(N_BUF*W_DATA-1 downto 0)); rd_data_feed <= din(N_BUF*W_DATA-1 downto 0);
      wait for SHORT_DELAY;
      p_transfer (
        clk => clk_i,
        trig => trig_i,
        busy => busy_o,
        sig_start => sig_start,
        sig_stop => sig_stop,
        scl_mst => scl_i,
        sda_mst => sda_i,
        sda_slv => sda_slv,
        wr_bytes => wr_bytes_i,
        rd_bytes => rd_bytes_i,
        rd_data_feed => rd_data_feed,
        wr_data_dump => wr_data_dump,
        addr_dump => addr_dump);
      report "Finish one trasaction" severity note;
      dout(W_ADDR-1 downto 0) := addr_dump;
      hwrite(l_dump, dout(W_ADDR-1 downto 0));
      dout(N_BUF*W_DATA-1 downto 0) := wr_data_dump;
      hwrite(l_dump, dout(N_BUF*W_DATA-1 downto 0), right, (N_BUF*W_DATA/4 + 1));
      dout(N_BUF*W_DATA-1 downto 0) := rd_data_o;
      hwrite(l_dump, dout(N_BUF*W_DATA-1 downto 0), right, (N_BUF*W_DATA/4 + 1));
      writeline(f_dump, l_dump);
    end loop;
    -- sim done
    assert false report "Simulation done" severity note;
    wait;
  end process;
end rtl;
