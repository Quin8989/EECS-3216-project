-- VHDL wrapper for nullobject/sdram-fpga controller.
-- Hardcodes generics for DE10-Lite IS42S16320D @ 50 MHz.
-- 10-bit column addressing (full 64 MB).
-- Converts unsigned ports to std_logic_vector for mixed-language use.
--
-- Upstream: https://github.com/nullobject/sdram-fpga (MIT licence)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_ctrl is
  port (
    reset       : in    std_logic;
    clk         : in    std_logic;
    -- CPU-side interface (32-bit words, 24-bit word address -> 64 MB)
    addr        : in    std_logic_vector(23 downto 0);
    data        : in    std_logic_vector(31 downto 0);
    we          : in    std_logic;
    req         : in    std_logic;
    ack         : out   std_logic;
    valid       : out   std_logic;
    q           : out   std_logic_vector(31 downto 0);
    -- SDRAM chip interface (directly to IS42S16320D pins)
    sdram_a     : out   std_logic_vector(12 downto 0);
    sdram_ba    : out   std_logic_vector(1 downto 0);
    sdram_dq_i  : in    std_logic_vector(15 downto 0);
    sdram_dq_o  : out   std_logic_vector(15 downto 0);
    sdram_dq_oe : out   std_logic;
    sdram_cke   : out   std_logic;
    sdram_cs_n  : out   std_logic;
    sdram_ras_n : out   std_logic;
    sdram_cas_n : out   std_logic;
    sdram_we_n  : out   std_logic;
    sdram_dqml  : out   std_logic;
    sdram_dqmh  : out   std_logic
  );
end entity sdram_ctrl;

architecture rtl of sdram_ctrl is
  signal sdram_a_u  : unsigned(12 downto 0);
  signal sdram_ba_u : unsigned(1 downto 0);
begin
  sdram_a  <= std_logic_vector(sdram_a_u);
  sdram_ba <= std_logic_vector(sdram_ba_u);

  u_sdram : entity work.sdram
    generic map (
      CLK_FREQ         => 25.0,
      ADDR_WIDTH       => 24,
      DATA_WIDTH       => 32,
      SDRAM_ADDR_WIDTH => 13,
      SDRAM_DATA_WIDTH => 16,
      SDRAM_COL_WIDTH  => 10,
      SDRAM_ROW_WIDTH  => 13,
      SDRAM_BANK_WIDTH => 2,
      CAS_LATENCY      => 2,
      BURST_LENGTH     => 2
    )
    port map (
      reset       => reset,
      clk         => clk,
      addr        => unsigned(addr),
      data        => data,
      we          => we,
      req         => req,
      ack         => ack,
      valid       => valid,
      q           => q,
      sdram_a     => sdram_a_u,
      sdram_ba    => sdram_ba_u,
      sdram_dq_i  => sdram_dq_i,
      sdram_dq_o  => sdram_dq_o,
      sdram_dq_oe => sdram_dq_oe,
      sdram_cke   => sdram_cke,
      sdram_cs_n  => sdram_cs_n,
      sdram_ras_n => sdram_ras_n,
      sdram_cas_n => sdram_cas_n,
      sdram_we_n  => sdram_we_n,
      sdram_dqml  => sdram_dqml,
      sdram_dqmh  => sdram_dqmh
    );
end architecture rtl;
