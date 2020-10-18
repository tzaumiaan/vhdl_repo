library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tb_pkg is
  -- constants
  constant CLK_PERIOD : time := 10 ns;
  constant RESET_TIME : time := 101 ns;
  constant SHORT_DELAY : time := 1.5 ns;
  -- design paramters
  constant W_ADDR: integer := 7;
  constant W_DATA: integer := 8;
  constant W_CNT: integer := 3; -- log2(W_DATA)
  constant N_BUF: integer := 7;
  constant W_BUF: integer := 3; -- width of number of buffer
  constant W_CKDIV: integer := 16; -- max: 125MHz clk_i over 100kHz scl_o
  -- functions / procedures declaration
  procedure p_transfer (
    signal clk, busy, scl_mst, sda_mst, sig_start, sig_stop: in std_logic;
    signal trig, sda_slv : out std_logic;
    signal wr_bytes, rd_bytes : in std_logic_vector(W_BUF-1 downto 0);
    signal rd_data_feed : in std_logic_vector(N_BUF*W_DATA-1 downto 0);
    signal addr_dump : out std_logic_vector(W_ADDR-1 downto 0);
    signal wr_data_dump : out std_logic_vector(N_BUF*W_DATA-1 downto 0) );
end package tb_pkg;

package body tb_pkg is
  -- functions / procedures implementation
  procedure p_transfer (
    signal clk, busy, scl_mst, sda_mst, sig_start, sig_stop: in std_logic;
    signal trig, sda_slv : out std_logic;
    signal wr_bytes, rd_bytes : in std_logic_vector(W_BUF-1 downto 0);
    signal rd_data_feed : in std_logic_vector(N_BUF*W_DATA-1 downto 0);
    signal addr_dump : out std_logic_vector(W_ADDR-1 downto 0);
    signal wr_data_dump : out std_logic_vector(N_BUF*W_DATA-1 downto 0)
  ) is
    variable cnt_bit, cnt_byte, idx: integer;
    variable addr_buf: std_logic_vector(W_ADDR-1 downto 0);
    variable data_buf: std_logic_vector(N_BUF*W_DATA-1 downto 0);
    variable is_last_byte: std_logic;
  begin
    if busy='1' then
      wait until busy='0';
    end if;
    wait until rising_edge(clk);
    wait for SHORT_DELAY;
    trig <= '1';
    wait until rising_edge(clk);
    wait for SHORT_DELAY;
    trig <= '0';
    addr_dump <= (others => '0');
    wr_data_dump <= (others => '0');
    -- write part
    if to_integer(unsigned(wr_bytes)) > 0 then
      addr_buf := (others => 'X');
      wait until rising_edge(sig_start);
      -- address
      cnt_bit := 0;
      while cnt_bit < W_ADDR loop
        wait until rising_edge(scl_mst);
        wait for SHORT_DELAY;
        addr_buf := addr_buf(W_ADDR-2 downto 0) & sda_mst;
        wait for SHORT_DELAY;
        cnt_bit := cnt_bit + 1;
      end loop;
      wait until rising_edge(scl_mst); -- read/write mode
      wait for SHORT_DELAY;
      assert sda_mst='0' report "ERROR: mode is not as expected (write)!" severity failure;
      if (scl_mst='1') then
        wait until scl_mst='0';
      end if;
      wait for SHORT_DELAY;
      sda_slv <= '0';
      wait until rising_edge(scl_mst);
      wait until falling_edge(scl_mst);
      wait for SHORT_DELAY;
      sda_slv <= 'Z';
      -- data
      data_buf := (others => '0');
      cnt_byte := 0;
      while cnt_byte < to_integer(unsigned(wr_bytes)) loop
        cnt_bit := 0;
        while cnt_bit < W_DATA loop
          wait until rising_edge(scl_mst);
          wait for SHORT_DELAY;
          data_buf := data_buf(N_BUF*W_DATA-2 downto 0) & sda_mst;
          wait for SHORT_DELAY;
          cnt_bit := cnt_bit + 1;
        end loop;
        if (scl_mst='1') then
          wait until scl_mst='0';
        end if;
        wait for SHORT_DELAY;
        sda_slv <= '0';
        wait until rising_edge(scl_mst);
        wait until falling_edge(scl_mst);
        wait for SHORT_DELAY;
        sda_slv <= 'Z';
        cnt_byte := cnt_byte + 1;
      end loop;
      wait for SHORT_DELAY;
      addr_dump <= addr_buf;
      wr_data_dump <= data_buf;
      wait for SHORT_DELAY;
    end if;
    -- read part
    if to_integer(unsigned(rd_bytes)) > 0 then
      addr_buf := (others => 'X');
      wait until rising_edge(sig_start);
      -- address
      cnt_bit := 0;
      while cnt_bit < W_ADDR loop
        wait until rising_edge(scl_mst);
        wait for SHORT_DELAY;
        addr_buf := addr_buf(W_ADDR-2 downto 0) & sda_mst;
        wait for SHORT_DELAY;
        cnt_bit := cnt_bit + 1;
      end loop;
      wait until rising_edge(scl_mst); -- read/write mode
      wait for SHORT_DELAY;
      assert sda_mst='1' report "ERROR: mode is not as expected (read)!" severity failure;
      if (scl_mst='1') then
        wait until scl_mst='0';
      end if;
      wait for SHORT_DELAY;
      sda_slv <= '0';
      wait until rising_edge(scl_mst);
      wait until falling_edge(scl_mst);
      wait for SHORT_DELAY;
      sda_slv <= 'Z';
      -- data
      data_buf := (others => '0');
      cnt_byte := 0;
      while cnt_byte < to_integer(unsigned(rd_bytes)) loop
        cnt_bit := 0;
        while cnt_bit < W_DATA loop
          idx := (to_integer(unsigned(rd_bytes))-cnt_byte-1)*W_DATA + (W_DATA-1-cnt_bit);
          sda_slv <= rd_data_feed(idx);
          wait until rising_edge(scl_mst);
          wait until falling_edge(scl_mst);
          wait for SHORT_DELAY;
          cnt_bit := cnt_bit  + 1;
        end loop;
        sda_slv <= 'Z';
        wait until rising_edge(scl_mst);
        wait for SHORT_DELAY;
        is_last_byte := '0';
        if (cnt_byte + 1 = to_integer(unsigned(rd_bytes))) then
          is_last_byte := '1';
        end if;
        assert sda_mst=is_last_byte report "ERROR: ack is not as expected "& std_logic'image(is_last_byte) &"!" severity failure;
        wait until falling_edge(scl_mst);
        wait for SHORT_DELAY;
        sda_slv <= 'Z';
        cnt_byte := cnt_byte + 1;
      end loop;
      wait for SHORT_DELAY;
      addr_dump <= addr_buf;
      wait for SHORT_DELAY;
    end if;
    wait until rising_edge(sig_stop);
    wait for SHORT_DELAY;
    if busy='1' then
      wait until busy='0';
    end if;
    wait for SHORT_DELAY;
  end p_transfer;
end tb_pkg;
