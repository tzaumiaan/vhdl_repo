library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
library std;
use std.textio.all;

use work.tb_pkg.all; -- constants and subroutines

entity tb is
end entity tb;

architecture rtl of tb is
  -- dut i/o signals --
  signal clk_i: std_logic := '0';
  signal rst_i: std_logic := '0';
  signal trig_i: std_logic;
  signal mode_i: std_logic;  -- mode 0: rotation, 1: vectoring
  signal x_i: signed(W_DATA-1 downto 0);
  signal y_i: signed(W_DATA-1 downto 0);
  signal theta_i: signed(W_DATA-1 downto 0);
  signal ready_o: std_logic;
  signal x_o: signed(W_DATA-1 downto 0);
  signal y_o: signed(W_DATA-1 downto 0);
  signal theta_o: signed(W_DATA-1 downto 0);
begin
  ---------------------------------------------------------
  -- instantiation
  ---------------------------------------------------------
  u_cordic: entity work.cordic_top
  generic map (
    W_DATA => W_DATA,
    ITER => ITER
  )
  port map (
    clk_i => clk_i,
    rst_i => rst_i,
    trig_i => trig_i,
    mode_i => mode_i,
    x_i => x_i,
    y_i => y_i,
    theta_i => theta_i,
    ready_o => ready_o,
    x_o => x_o,
    y_o => y_o,
    theta_o => theta_o
  );
  ---------------------------------------------------------
  -- clock/reset
  ---------------------------------------------------------
  clk_i <= not clk_i after (CLK_PERIOD/2);
  rst_i <= '1' after SHORT_DELAY, '0' after RESET_TIME;
  ---------------------------------------------------------
  -- main simulation
  ---------------------------------------------------------
  p_sim: process
    file f_feed: text open read_mode is "pat_in.txt";
    file f_dump: text open write_mode is "dut_out.txt";
    variable l_feed, l_dump: line;
    variable din, dout: std_logic_vector(W_DATA-1 downto 0);
  begin
    -- init_values
    trig_i <= '0';
    -- wait for reset done
    wait until falling_edge(rst_i);
    wait for SHORT_DELAY;
    -- sim body
    report "cordic simulation starts";
    while not endfile(f_feed) loop
      readline(f_feed, l_feed);
      next when l_feed(1)='#'; -- skip comment in files
      -- make sure the dut is idle
      if (ready_o = '0') then
        wait until (ready_o = '1');
      end if;
      wait for SHORT_DELAY;
      -- parse and apply inputs
      wait until rising_edge(clk_i);
      wait for SHORT_DELAY;
      hread(l_feed, din(0 downto 0)); mode_i <= din(0);
      hread(l_feed, din(W_DATA-1 downto 0)); x_i <= signed(din(W_DATA-1 downto 0));
      hread(l_feed, din(W_DATA-1 downto 0)); y_i <= signed(din(W_DATA-1 downto 0));
      hread(l_feed, din(W_DATA-1 downto 0)); theta_i <= signed(din(W_DATA-1 downto 0));
      trig_i <= '1';
      wait until rising_edge(clk_i);
      wait for SHORT_DELAY;
      trig_i <= '0';
      -- apply inputs
      wait until (ready_o = '1');
      wait until rising_edge(clk_i);
      wait for SHORT_DELAY;
      dout(x_o'length-1 downto 0) := std_logic_vector(x_o);
      hwrite(l_dump, dout(x_o'length-1 downto 0), right, x_o'length/4+1);
      dout(y_o'length-1 downto 0) := std_logic_vector(y_o);
      hwrite(l_dump, dout(y_o'length-1 downto 0), right, y_o'length/4+1);
      dout(theta_o'length-1 downto 0) := std_logic_vector(theta_o);
      hwrite(l_dump, dout(theta_o'length-1 downto 0), right, theta_o'length/4+1);
      writeline(f_dump, l_dump);
      wait for SHORT_DELAY;
    end loop;
    -- sim done
    report "cordic simulation ends";
    wait;
  end process p_sim;
end architecture rtl;
