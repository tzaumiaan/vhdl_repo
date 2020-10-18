library ieee;
use ieee.std_logic_1164.all;

entity i2c_master_top is
  generic (
    W_ADDR: integer := 7;
    W_DATA: integer := 8;
    W_CNT: integer := 3; -- log2(W_DATA)
    N_BUF: integer := 7;
    W_BUF: integer := 3; -- width of number of buffer
    W_CKDIV: integer := 16 -- max: 125MHz clk_i over 100kHz scl_o
  );
  port (
    clk_i: in std_logic;
    rst_i: in std_logic;
    trig_i: in std_logic;
    busy_o: out std_logic;
    ckdiv_i: in std_logic_vector(W_CKDIV-1 downto 0);
    addr_i: in std_logic_vector(W_ADDR-1 downto 0);
    wr_data_i: in std_logic_vector(N_BUF*W_DATA-1 downto 0);
    rd_data_o: out std_logic_vector(N_BUF*W_DATA-1 downto 0);
    wr_bytes_i: in std_logic_vector(W_BUF-1 downto 0);
    rd_bytes_i: in std_logic_vector(W_BUF-1 downto 0);
    scl_i: in std_logic; 
    scl_o: out std_logic; 
    scl_oen: out std_logic;
    sda_i: in std_logic;
    sda_o: out std_logic;
    sda_oen: out std_logic
  );
end entity;

architecture rtl of i2c_master_top is
  -- wires
  signal c2d_buf_init: std_logic;
  signal c2d_ad_mode: std_logic; -- 0: addr, 1: data
  signal c2d_rw_mode: std_logic; -- 0: read, 1: write
  signal c2d_data_vld: std_logic;
  signal c2d_force_hi: std_logic; -- for start/restart/stop/ack signals
  signal c2d_force_lo: std_logic; -- for start/restart/stop/ack signals
begin
  -- instantiation
  u_ctrl: entity work.i2c_master_ctrl
  generic map (
    W_CNT => W_CNT,
    W_BUF => W_BUF,
    W_CKDIV => W_CKDIV
  )
  port map (
    clk_i => clk_i,
    rst_i => rst_i,
    trig_i => trig_i,
    busy_o => busy_o,
    ckdiv_i => ckdiv_i,
    wr_bytes_i => wr_bytes_i,
    rd_bytes_i => rd_bytes_i,
    scl_i => scl_i,
    scl_o => scl_o,
    scl_oen => scl_oen,
    sda_oen => sda_oen,
    c2d_buf_init => c2d_buf_init,
    c2d_ad_mode => c2d_ad_mode,
    c2d_rw_mode => c2d_rw_mode,
    c2d_data_vld => c2d_data_vld,
    c2d_force_hi => c2d_force_hi,
    c2d_force_lo => c2d_force_lo
  );

  u_data: entity work.i2c_master_data
  generic map (
    W_ADDR => W_ADDR,
    W_DATA => W_DATA,
    N_BUF => N_BUF,
    W_BUF => W_BUF
  )
  port map (
    clk_i => clk_i,
    rst_i => rst_i,
    addr_i => addr_i,
    wr_data_i => wr_data_i,
    rd_data_o => rd_data_o,
    wr_bytes_i => wr_bytes_i,
    sda_i => sda_i,
    sda_o => sda_o,
    c2d_buf_init => c2d_buf_init,
    c2d_ad_mode => c2d_ad_mode,
    c2d_rw_mode => c2d_rw_mode,
    c2d_data_vld => c2d_data_vld,
    c2d_force_hi => c2d_force_hi,
    c2d_force_lo => c2d_force_lo
  );
end rtl;
