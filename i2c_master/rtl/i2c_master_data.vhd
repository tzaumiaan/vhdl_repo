library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master_data is
  generic (
    W_ADDR: integer := 7;
    W_DATA: integer := 8;
    N_BUF: integer := 7;
    W_BUF: integer := 3 -- width of number of buffer
  );
  port (
    clk_i: in std_logic;
    rst_i: in std_logic;
    addr_i: in std_logic_vector(W_ADDR-1 downto 0);
    wr_data_i: in std_logic_vector(N_BUF*W_DATA-1 downto 0);
    rd_data_o: out std_logic_vector(N_BUF*W_DATA-1 downto 0);
    wr_bytes_i: in std_logic_vector(W_BUF-1 downto 0);
    sda_i: in std_logic;
    sda_o: out std_logic;
    c2d_buf_init: in std_logic;
    c2d_ad_mode: in std_logic; -- 0: addr, 1: data
    c2d_rw_mode: in std_logic; -- 1: read, 0: write
    c2d_data_vld: in std_logic;
    c2d_force_hi: in std_logic; -- for start/restart/stop/ack signals
    c2d_force_lo: in std_logic  -- for start/restart/stop/ack signals
  );
end entity;

architecture rtl of i2c_master_data is
  -- wires
  signal data_null: std_logic_vector(N_BUF*W_DATA-1 downto 0);
  signal data_init_a, data_init_wr: std_logic_vector(N_BUF*W_DATA-1 downto 0);
  signal upd_data_buf, upd_sda: std_logic;
  signal sda_wr, sda_wr_vld: std_logic;
  -- flip-flops
  signal data_buf, data_buf_next: std_logic_vector(N_BUF*W_DATA-1 downto 0);
  signal sda, sda_next: std_logic;
begin
  ---------------------------------------------------------
  -- combinational part
  ---------------------------------------------------------
  -- static assignments
  rd_data_o <= data_buf;
  sda_o <= sda;
  -- data buffer logic
  data_null <= (others => '0');
  -- initial addr buffer
  data_init_a <= addr_i & c2d_rw_mode & data_null(N_BUF*W_DATA-W_ADDR-2 downto 0);
  -- barrel shifter for initial write-buffer
  data_init_wr <= wr_data_i(1*W_DATA-1 downto 0) & data_null((N_BUF-1)*W_DATA-1 downto 0) when(N_BUF>0 and wr_bytes_i="001") else
                  wr_data_i(2*W_DATA-1 downto 0) & data_null((N_BUF-2)*W_DATA-1 downto 0) when(N_BUF>1 and wr_bytes_i="010") else
                  wr_data_i(3*W_DATA-1 downto 0) & data_null((N_BUF-3)*W_DATA-1 downto 0) when(N_BUF>2 and wr_bytes_i="011") else
                  wr_data_i(4*W_DATA-1 downto 0) & data_null((N_BUF-4)*W_DATA-1 downto 0) when(N_BUF>3 and wr_bytes_i="100") else
                  wr_data_i(5*W_DATA-1 downto 0) & data_null((N_BUF-5)*W_DATA-1 downto 0) when(N_BUF>4 and wr_bytes_i="101") else
                  wr_data_i(6*W_DATA-1 downto 0) & data_null((N_BUF-6)*W_DATA-1 downto 0) when(N_BUF>5 and wr_bytes_i="110") else
                  wr_data_i(7*W_DATA-1 downto 0) & data_null((N_BUF-7)*W_DATA-1 downto 0) when(N_BUF>6 and wr_bytes_i="111") else
                  data_null;
  p_data_buf: process (data_buf, c2d_buf_init, c2d_ad_mode, data_init_a, c2d_rw_mode, data_init_wr, data_null, c2d_data_vld, data_buf, sda_i)
  begin
    upd_data_buf <= '0';
    data_buf_next <= data_buf;
    if (c2d_buf_init = '1') then
      upd_data_buf <= '1';
      if (c2d_ad_mode='0') then
        data_buf_next <= data_init_a;
      elsif (c2d_rw_mode='0') then
        data_buf_next <= data_init_wr;
      else
        data_buf_next <= data_null;
      end if;
    elsif (c2d_data_vld = '1') then
      upd_data_buf <= '1';
      data_buf_next(N_BUF*W_DATA-1 downto 1) <= data_buf(N_BUF*W_DATA-2 downto 0);
      if (c2d_rw_mode='0') then
        data_buf_next(0) <= '0';
      else
        data_buf_next(0) <= sda_i;
      end if;
    end if;
  end process;

  -- sda logic
  sda_wr <= data_buf_next(N_BUF*W_DATA-1);
  sda_wr_vld <= '1' when ((c2d_buf_init='1' or c2d_data_vld='1') and
                          (c2d_ad_mode='0' or c2d_rw_mode='0')) else '0';
  sda_next <= '1' when (c2d_force_hi='1') else
              '0' when (c2d_force_lo='1') else
              sda_wr when (sda_wr_vld='1') else
              sda;
  upd_sda <= '1' when (sda /= sda_next) else '0';

  ---------------------------------------------------------
  -- sequential part
  ---------------------------------------------------------
  process (clk_i, rst_i)
  begin
    if (rst_i='1') then
      data_buf <= (others => '0');
      sda <= '1';
    elsif rising_edge(clk_i) then
      if (upd_data_buf='1') then data_buf <= data_buf_next; end if;
      if (upd_sda='1') then sda <= sda_next; end if;
    end if;
  end process;
end architecture rtl;
