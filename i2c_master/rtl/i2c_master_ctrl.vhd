library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master_ctrl is
  generic (
    W_CNT: integer := 3; -- log2(W_DATA)
    W_BUF: integer := 3; -- width of number of buffer
    W_CKDIV: integer := 16 -- max: 125MHz clk_i over 100kHz scl_o
  );
  port (
    clk_i: in std_logic;
    rst_i: in std_logic;
    trig_i: in std_logic;
    busy_o: out std_logic;
    ckdiv_i: in std_logic_vector(W_CKDIV-1 downto 0);
    wr_bytes_i: in std_logic_vector(W_BUF-1 downto 0);
    rd_bytes_i: in std_logic_vector(W_BUF-1 downto 0);
    scl_i: in std_logic; 
    scl_o: out std_logic; 
    scl_oen: out std_logic;
    sda_oen: out std_logic;
    c2d_buf_init: out std_logic;
    c2d_ad_mode: out std_logic; -- 0: addr, 1: data
    c2d_rw_mode: out std_logic; -- 1: read, 0: write
    c2d_data_vld: out std_logic;
    c2d_force_hi: out std_logic; -- for start/restart/stop/ack signals
    c2d_force_lo: out std_logic  -- for start/restart/stop/ack signals
  );
end entity;

architecture rtl of i2c_master_ctrl is
  -- states of FSM
  constant W_FSM : integer := 4;
  -- state coding idea:
  constant ST_IDLE    : std_logic_vector(W_FSM-1 downto 0) := x"0";
  constant ST_START   : std_logic_vector(W_FSM-1 downto 0) := x"1";
  constant ST_ADDR_W  : std_logic_vector(W_FSM-1 downto 0) := x"4";
  constant ST_AACK_W  : std_logic_vector(W_FSM-1 downto 0) := x"5";
  constant ST_DATA_W  : std_logic_vector(W_FSM-1 downto 0) := x"6";
  constant ST_DACK_W  : std_logic_vector(W_FSM-1 downto 0) := x"7";
  constant ST_RESTART : std_logic_vector(W_FSM-1 downto 0) := x"2";
  constant ST_ADDR_R  : std_logic_vector(W_FSM-1 downto 0) := x"c";
  constant ST_AACK_R  : std_logic_vector(W_FSM-1 downto 0) := x"d";
  constant ST_DATA_R  : std_logic_vector(W_FSM-1 downto 0) := x"e";
  constant ST_DACK_R  : std_logic_vector(W_FSM-1 downto 0) := x"f";
  constant ST_STOP    : std_logic_vector(W_FSM-1 downto 0) := x"3";
  -- wires
  signal is_busy: std_logic;
  signal upd_state, upd_phase, upd_cnt_bit, upd_cnt_byte, upd_cnt_ckdiv: std_logic;
  signal upd_doen, upd_scl: std_logic;
  signal cnt_ckdiv_p1 : unsigned(W_CKDIV-1 downto 0);
  signal is_ckdiv_vld, is_ckdiv_full_hit, is_ckdiv_half_hit: std_logic;
  signal is_phase_01, is_phase_12, is_phase_23, is_phase_30: std_logic;
  signal phase_p1: unsigned(1 downto 0);
  signal wr_en, rd_en, is_nop, is_trig: std_logic;
  signal cnt_bit_p1: unsigned(W_CNT-1 downto 0);
  signal is_last_bit, is_last_byte: std_logic;
  signal cnt_byte_p1, cnt_byte_max: unsigned(W_BUF-1 downto 0);
  -- flip-flops
  signal state, state_next: std_logic_vector(W_FSM-1 downto 0);
  signal phase, phase_next: unsigned(1 downto 0);
  signal cnt_ckdiv, cnt_ckdiv_next: unsigned(W_CKDIV-1 downto 0);
  signal cnt_bit, cnt_bit_next: unsigned(W_CNT-1 downto 0);
  signal cnt_byte, cnt_byte_next: unsigned(W_BUF-1 downto 0);
  signal scl, scl_next: std_logic;
  signal doen, doen_next: std_logic;
begin
  ---------------------------------------------------------
  -- combinational part
  ---------------------------------------------------------
  -- tied outputs
  scl_oen <= '1';
  -- static assignments
  busy_o <= is_busy;
  scl_o <= scl;
  sda_oen <= doen;
  -- clock dividor
  is_ckdiv_vld <= '1' when (unsigned(ckdiv_i) > to_unsigned(1, W_CKDIV)) else '0';
  is_ckdiv_full_hit <= '1' when (cnt_ckdiv_p1 = unsigned(ckdiv_i)) else '0';
  is_ckdiv_half_hit <= '1' when (cnt_ckdiv_p1 = shift_right(unsigned(ckdiv_i), 1)) else '0';
  cnt_ckdiv_p1 <= cnt_ckdiv + 1;
  cnt_ckdiv_next <= (others => '0') when (is_trig='1' or is_ckdiv_full_hit='1') else
                    cnt_ckdiv_p1 when (is_busy='1') else
                    cnt_ckdiv;
  upd_cnt_ckdiv <= is_trig or is_ckdiv_full_hit or is_busy;
  -- phase
  upd_phase <= is_ckdiv_half_hit or is_ckdiv_full_hit;
  phase_p1 <= phase + 1;
  phase_next <= "00" when is_trig='1' else
                phase_p1 when upd_phase='1' else
                phase;
  is_phase_01 <= '1' when (phase="00" and upd_phase='1') else '0';
  is_phase_12 <= '1' when (phase="01" and upd_phase='1') else '0';
  is_phase_23 <= '1' when (phase="10" and upd_phase='1') else '0';
  is_phase_30 <= '1' when (phase="11" and upd_phase='1') else '0';

  -- fsm
  is_busy <= '0' when (state = ST_IDLE) else '1';
  wr_en <= '1' when (unsigned(wr_bytes_i) /= to_unsigned(0, W_BUF)) else '0';
  rd_en <= '1' when (unsigned(rd_bytes_i) /= to_unsigned(0, W_BUF)) else '0';
  is_nop <= '1' when (wr_en='0' and rd_en='0') else '0';
  is_trig <= '1' when (is_busy='0' and is_ckdiv_vld='1' and trig_i='1' and is_nop='0') else '0';
  p_fsm: process (state, is_trig, upd_cnt_bit, wr_en, rd_en, is_last_bit, is_last_byte)
  begin
    upd_state <= '0';
    state_next <= state;
    case state is
      when ST_IDLE =>
        if (is_trig='1') then upd_state <= '1'; state_next <= ST_START; end if;
      when ST_START =>
        if (upd_cnt_bit='1' and wr_en='1') then upd_state <= '1'; state_next <= ST_ADDR_W;
        elsif (upd_cnt_bit='1' and rd_en='1') then upd_state <= '1'; state_next <= ST_ADDR_R;
        end if;
      when ST_ADDR_W =>
        if (is_last_bit='1') then upd_state <= '1'; state_next <= ST_AACK_W; end if;
      when ST_AACK_W =>
        if (upd_cnt_bit='1') then upd_state <= '1'; state_next <= ST_DATA_W; end if;
      when ST_DATA_W =>
        if (is_last_bit='1') then upd_state <= '1'; state_next <= ST_DACK_W; end if;
      when ST_DACK_W =>
        if (is_last_byte='1' and rd_en='1') then upd_state <= '1'; state_next <= ST_RESTART;
        elsif (is_last_byte='1') then upd_state <= '1'; state_next <= ST_STOP;
        elsif (upd_cnt_bit='1') then upd_state <= '1'; state_next <= ST_DATA_W;
        end if;
      when ST_RESTART =>
        if (upd_cnt_bit='1') then upd_state <= '1'; state_next <= ST_ADDR_R; end if;
      when ST_ADDR_R =>
        if (is_last_bit='1') then upd_state <= '1'; state_next <= ST_AACK_R; end if;
      when ST_AACK_R =>
        if (upd_cnt_bit='1') then upd_state <= '1'; state_next <= ST_DATA_R; end if;
      when ST_DATA_R =>
        if (is_last_bit='1') then upd_state <= '1'; state_next <= ST_DACK_R; end if;
      when ST_DACK_R =>
        if (is_last_byte='1') then upd_state <= '1'; state_next <= ST_STOP;
        elsif (upd_cnt_bit='1') then upd_state <= '1'; state_next <= ST_DATA_R;
        end if;
      when ST_STOP =>
        if (upd_cnt_bit='1') then upd_state <= '1'; state_next <= ST_IDLE; end if;
      when others =>
        upd_state <= '1';
        state_next <= ST_IDLE;
    end case;
  end process p_fsm;

  -- bit counter
  upd_cnt_bit <= is_phase_30;
  cnt_bit_p1 <= cnt_bit + 1;
  is_last_bit <= '1' when (cnt_bit=to_unsigned(2**W_CNT-1, W_CNT) and upd_cnt_bit='1') else '0';
  p_cnt_bit: process (state, is_last_bit, upd_cnt_bit, cnt_bit_p1, cnt_bit)
  begin
    case state is
      when ST_ADDR_W | ST_DATA_W | ST_ADDR_R | ST_DATA_R =>
        if (is_last_bit='1') then
          cnt_bit_next <= (others => '0');
        elsif (upd_cnt_bit='1') then
          cnt_bit_next <= cnt_bit_p1;
        else
          cnt_bit_next <= cnt_bit;
        end if;
      when others =>
        cnt_bit_next <= (others => '0');
    end case;
  end process p_cnt_bit;

  -- byte counter
  cnt_byte_p1 <= cnt_byte + 1;
  cnt_byte_max <= unsigned(wr_bytes_i) when (state=ST_DATA_W or state=ST_DACK_W) else
        	  unsigned(rd_bytes_i) when (state=ST_DATA_R or state=ST_DACK_R) else
        	  to_unsigned(0, W_BUF);
  upd_cnt_byte <= '1' when ((state=ST_DACK_W or state=ST_DACK_R) and upd_cnt_bit='1') else '0';
  is_last_byte <= '1' when (cnt_byte_p1=cnt_byte_max and upd_cnt_byte='1') else '0';
  p_cnt_byte: process (state, is_last_byte, upd_cnt_byte, cnt_byte_p1, cnt_byte)
  begin
    case state is
      when ST_DACK_W | ST_DACK_R =>
        if (is_last_byte='1') then
          cnt_byte_next <= (others => '0');
        elsif (upd_cnt_byte='1') then
          cnt_byte_next <= cnt_byte_p1;
        else
          cnt_byte_next <= cnt_byte;
        end if;
      when others =>
        cnt_byte_next <= (others => '0');
    end case;
  end process p_cnt_byte;

  -- scl logic
  upd_scl <= '1' when (scl /= scl_next) else '0';
  scl_next <= '1' when (state=ST_IDLE) else
              '0' when (state=ST_START and is_phase_23='1') else
              '1' when (state=ST_STOP and is_phase_01='1') else
              '1' when (state/=ST_START and is_phase_01='1') else
              '0' when (state/=ST_STOP and is_phase_23='1') else
              scl;

  -- doen logic
  upd_doen <= '1' when (doen /= doen_next) else '0';
  doen_next <= '0' when (state_next=ST_AACK_W or state_next=ST_DACK_W or
                         state_next=ST_AACK_R or state_next=ST_DATA_R ) else '1';

  -- data control
  c2d_buf_init <= '1' when (state=ST_START and state_next=ST_ADDR_W) else
                  '1' when (state=ST_AACK_W and state_next=ST_DATA_W) else
                  '1' when ((state=ST_START or state=ST_RESTART) and state_next=ST_ADDR_R) else
                  '1' when (state=ST_AACK_R and state_next=ST_DATA_R) else
                  '0';
  c2d_ad_mode <= '0' when (state_next=ST_ADDR_W or state_next=ST_ADDR_R or
                           state_next=ST_AACK_W or state_next=ST_AACK_R ) else '1';
  c2d_rw_mode <= '1' when (state_next=ST_ADDR_R or state_next=ST_AACK_R or
                           state_next=ST_DATA_R or state_next=ST_DACK_R ) else '0';
  c2d_data_vld <= '1' when ((upd_cnt_bit='1') and (state=ST_ADDR_W or state=ST_DATA_W or state=ST_ADDR_R)) else
                  '1' when (state=ST_DATA_R and is_phase_12='1') else
                  '0';
  c2d_force_hi <= '1' when (state/=ST_START and state_next=ST_START) else -- start init state
                  '1' when (state/=ST_RESTART and state_next=ST_RESTART) else -- restart init state
                  '1' when (state=ST_STOP and is_phase_12='1') else -- stop rising edge
                  '1' when (state/=ST_DACK_R and state_next=ST_DACK_R and cnt_byte_p1=cnt_byte_max) else -- final r-ack
                  '0';
  c2d_force_lo <= '1' when (state=ST_START and is_phase_12='1') else -- start falling edge
                  '1' when (state=ST_RESTART and is_phase_12='1') else -- restart falling edge
                  '1' when (state/=ST_STOP and state_next=ST_STOP) else -- stop init state
                  '1' when (state/=ST_DACK_R and state_next=ST_DACK_R and cnt_byte_p1/=cnt_byte_max) else -- other r-ack
                  '0';

  ---------------------------------------------------------
  -- sequential part
  ---------------------------------------------------------
  process (clk_i, rst_i)
  begin
    if (rst_i='1') then
      state <= ST_IDLE;
      phase <= "00";
      cnt_ckdiv <= (others => '0');
      cnt_bit <= (others => '0');
      cnt_byte <= (others => '0');
      scl <= '1';
      doen <= '1';
    elsif rising_edge(clk_i) then
      if (upd_state='1') then state <= state_next; end if;
      if (upd_phase='1') then phase <= phase_next; end if;
      if (upd_cnt_ckdiv='1') then cnt_ckdiv <= cnt_ckdiv_next; end if;
      if (upd_cnt_bit='1') then cnt_bit <= cnt_bit_next; end if;
      if (upd_cnt_byte='1') then cnt_byte <= cnt_byte_next; end if;
      if (upd_scl='1') then scl <= scl_next; end if;
      if (upd_doen='1') then doen <= doen_next; end if;
    end if;
  end process;
end architecture rtl;
