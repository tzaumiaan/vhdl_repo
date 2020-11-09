library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tb_pkg is
  -- constants
  constant CLK_PERIOD: time := 8 ns;
  constant RESET_TIME: time := 101 ns;
  constant SHORT_DELAY: time := 0.8 ns;
  constant RX_DELAY: time := 33 ns;
  constant W_CNT: integer := 6;
  constant W_DATA: integer := 48;
  -- functions / procedures declaration
  procedure p_master_wr (
    signal clk, tx_done, tx_cs, tx_sck, cpol, cpha: in std_logic;
    signal data_size: in integer;
    signal data_block: in std_logic_vector(W_DATA-1 downto 0);
    signal tx_sdo: in std_logic;
    signal tx_start: out std_logic;
    signal tx_word: out std_logic_vector(W_DATA-1 downto 0);
    signal tx_result: inout std_logic_vector(W_DATA-1 downto 0) );
  procedure p_master_rd (
    signal clk, rx_done, rx_cs, rx_sck, cpol, cpha: in std_logic;
    signal data_size: in integer;
    signal data_block: in std_logic_vector(W_DATA-1 downto 0);
    signal rx_word_1, rx_word_0: in std_logic_vector(W_DATA-1 downto 0);
    signal rx_start, rx_sdi: out std_logic;
    signal rx_result: out std_logic_vector(W_DATA-1 downto 0) );
end package tb_pkg;

package body tb_pkg is
  -- functions / procedures implementation
  ---- master write mode ----
  procedure p_master_wr (
    signal clk, tx_done, tx_cs, tx_sck, cpol, cpha: in std_logic;
    signal data_size: in integer;
    signal data_block: in std_logic_vector(W_DATA-1 downto 0);
    signal tx_sdo: in std_logic;
    signal tx_start: out std_logic;
    signal tx_word: out std_logic_vector(W_DATA-1 downto 0);
    signal tx_result: inout std_logic_vector(W_DATA-1 downto 0)
  ) is
    variable idx: integer;
  begin
    if (tx_done='0') then
      wait until (tx_done='1');
    end if;
    wait until rising_edge(clk);
    wait for SHORT_DELAY;
    tx_start <= '1';
    tx_word <= data_block;
    tx_result <= (others => '0');
    wait until rising_edge(clk);
    wait for SHORT_DELAY;
    tx_start <= '0';
    wait for SHORT_DELAY;
    -- index init
    idx := W_DATA-1;
    while tx_done='0' loop
      if cpol=cpha then
        wait until rising_edge(tx_sck);
      else
        wait until falling_edge(tx_sck);
      end if;
      wait for SHORT_DELAY;
      tx_result <= tx_result(tx_result'high-1 downto 0) & tx_sdo;
      assert idx>=0 report "master writing index out of range" severity error;
      idx := idx - 1;
      exit when idx + data_size < W_DATA;
    end loop;
    wait for SHORT_DELAY;
    wait until tx_done='1';
    wait for CLK_PERIOD * 5;
    -- monitor output
    wait for SHORT_DELAY;
  end p_master_wr;
  ---- master read mode ----
  procedure p_master_rd (
    signal clk, rx_done, rx_cs, rx_sck, cpol, cpha: in std_logic;
    signal data_size: in integer;
    signal data_block: in std_logic_vector(W_DATA-1 downto 0);
    signal rx_word_1, rx_word_0: in std_logic_vector(W_DATA-1 downto 0);
    signal rx_start, rx_sdi: out std_logic;
    signal rx_result: out std_logic_vector(W_DATA-1 downto 0)
  ) is
    variable idx: integer;
  begin
    if (rx_done='0') then
      wait until (rx_done='1');
    end if;
    wait for SHORT_DELAY;
    wait until rising_edge(clk);
    wait for SHORT_DELAY;
    rx_start <= '1';
    wait until rising_edge(clk);
    wait for SHORT_DELAY;
    rx_start <= '0';
    -- index init
    idx := W_DATA-1;
    -- if cpha='0', first SDI comes when CS down, otherwise SDI unknown
    if cpha='0' then
      rx_sdi <= data_block(idx);
      idx := idx - 1;
    else
      rx_sdi <= 'U';
    end if;
    wait until rising_edge(clk);
    while rx_done='0' and idx + data_size >= W_DATA loop
      if cpol=cpha then
        wait until falling_edge(rx_sck) and rx_cs='0';
      else
        wait until rising_edge(rx_sck) and rx_cs='0';
      end if;
      wait for SHORT_DELAY;
      rx_sdi <= data_block(idx);
      assert idx>=0 report "master reading index out of range" severity error;
      idx := idx - 1;
    end loop;
    wait for SHORT_DELAY;
    -- if cpha='0', SDI goes unknown after last clock edge
    if cpha='0' then
      if cpol='0' then
        wait until falling_edge(rx_sck);
      else
        wait until rising_edge(rx_sck);
      end if;
      wait for SHORT_DELAY;
      rx_sdi <= 'U';
    end if;
    if (rx_done='0') then
      wait until (rx_done='1');
    end if;
    wait for SHORT_DELAY;
    rx_sdi <= 'Z';
    wait for SHORT_DELAY;
    -- monitor output
    rx_result <= rx_word_0 and not rx_word_1;
    wait for SHORT_DELAY;
  end p_master_rd;
  
end tb_pkg;
