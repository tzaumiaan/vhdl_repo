library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-----------------------------------------------------------
-- spi master controller
-----------------------------------------------------------
entity spi_master_ctrl is
  generic (
    W_CNT: integer := 6  -- number of bits of bit counter
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
    spi_cs_o: out std_logic; 
    spi_sck_o: out std_logic; 
    c2r_mode: out std_logic;  -- 0: rising-edge sampling, 1: falling-edge sampling
    r2c_ready: in std_logic;
    c2t_di_trig: out std_logic;
    c2t_do_trig: out std_logic
  );
end entity spi_master_ctrl;

architecture rtl of spi_master_ctrl is
  -- wires
  signal ready, spi_trig: std_logic;
  signal cnt_ckdiv_p1: unsigned(15 downto 0);
  signal is_cnt_ckdiv_hit: std_logic;
  signal cnt_bitpha_p1: unsigned(W_CNT downto 0);
  signal is_cnt_bitpha_hit: std_logic;
  -- clock-gating signals
  signal cg_ctrl, cg_sck: std_logic;
  -- flip-flops
  signal mst_ready, mst_ready_next: std_logic;
  signal cnt_ckdiv, cnt_ckdiv_next: unsigned(15 downto 0);
  signal cnt_bitpha, cnt_bitpha_next: unsigned(W_CNT downto 0);
  signal sck, sck_next: std_logic;
begin
  ---------------------------------------------------------
  -- combinational part
  ---------------------------------------------------------
  -- counter control system
  spi_trig <= trig_i and ready;
  ready <= mst_ready and r2c_ready;
  mst_ready_next <= '0' when (spi_trig='1') else
                    '1' when (is_cnt_ckdiv_hit='1' and is_cnt_bitpha_hit='1') else
                    mst_ready;
  cnt_ckdiv_p1 <= cnt_ckdiv + 1;
  is_cnt_ckdiv_hit <= '1' when (cnt_ckdiv_p1 = unsigned(ckdiv_i)) else '0';
  cnt_ckdiv_next <= (others => '0') when (spi_trig='1') else
                    (others => '0') when (is_cnt_ckdiv_hit='1') else
                    cnt_ckdiv_p1 when (mst_ready='0') else
                    cnt_ckdiv;
  cnt_bitpha_p1 <= cnt_bitpha + 1;
  is_cnt_bitpha_hit <= '1' when (cnt_bitpha_p1(W_CNT downto 1) = unsigned(nbits_i)) else '0';
  cnt_bitpha_next <= (others => '0') when (spi_trig='1') else
                     cnt_bitpha_p1 when (mst_ready='0' and is_cnt_ckdiv_hit='1') else
                     cnt_bitpha;
  cg_ctrl <= spi_trig or not mst_ready;
  -- sck part
  sck_next <= (cpol_i xor cpha_i) when (spi_trig='1') else -- init
              cpol_i when (mst_ready_next='1') else  -- finish
              (not sck) when (mst_ready='0' and is_cnt_ckdiv_hit='1') else
              cpol_i when (mst_ready='1' and sck /= cpol_i) else  -- follow cpol_i when idle
              sck;
  cg_sck <= '1' when (sck/=sck_next) else '0';
  -- output assignment
  ready_o <= ready;
  spi_cs_o <= mst_ready;
  spi_sck_o <= sck;
  c2r_mode <= cpol_i xor cpha_i;
  c2t_di_trig <= spi_trig;
  c2t_do_trig <= '1' when (cnt_bitpha(0)='1' and cnt_bitpha_next(0)='0') else '0';
  ---------------------------------------------------------
  -- sequential part
  ---------------------------------------------------------
  process (clk_i, rst_i)
  begin
    if (rst_i='1') then
      mst_ready <= '1';
      cnt_ckdiv <= (others => '0');
      cnt_bitpha <= (others => '0');
      sck <= '1';
    elsif rising_edge(clk_i) then
      if (cg_ctrl='1') then
        mst_ready <= mst_ready_next;
        cnt_ckdiv <= cnt_ckdiv_next;
        cnt_bitpha <= cnt_bitpha_next;
      end if;
      if (cg_sck='1') then
        sck <= sck_next;
      end if;
    end if;
  end process;
end architecture rtl;
