-- Copyright (C)2014-2023 Gowin Semiconductor Corporation.
--
-- PLL del nucleo Pac-Man (Tang Nano 9K)
--
-- Frecuencias segun Gowin:
--   PFD  = FCLKIN / (IDIV_SEL+1)                              -> 3..400 MHz
--   VCO  = FCLKIN * (FBDIV_SEL+1) * ODIV_SEL / (IDIV_SEL+1)   -> 400..1200 MHz
--   CLKOUT  = VCO / ODIV_SEL
--   CLKOUTD = CLKOUT / DYN_SDIV_SEL
--
-- Configuracion:
--   IDIV_SEL     = 4   -> PFD 5,400 MHz
--   FBDIV_SEL    = 36  -> x37
--   ODIV_SEL     = 4   -> VCO 799,2 MHz, CLKOUT 199,8 MHz
--   DYN_SDIV_SEL = 8   -> CLKOUTD 24,975 MHz
--
-- 24,975 MHz es -0,1 % respecto a los 25 MHz del hardware original, de
-- modo que ENA_6 = 1 de cada 4 da 6,244 MHz (el original: 6,25).
-- Se usa CLKOUTD porque 25 MHz exactos desde 27 MHz exigiria un PFD de
-- 1 MHz, por debajo del minimo de 3 MHz que impone Gowin.

library IEEE;
  use IEEE.STD_LOGIC_1164.all;

entity clk_pacman is
  port (
    clkin  : in  std_logic;
    clkout : out std_logic;
    lock   : out std_logic
  );
end;

architecture Behavioral of clk_pacman is

  signal gw_gnd : std_logic;
  signal FBDSEL_i : std_logic_vector(5 downto 0);
  signal IDSEL_i  : std_logic_vector(5 downto 0);
  signal ODSEL_i  : std_logic_vector(5 downto 0);
  signal PSDA_i   : std_logic_vector(3 downto 0);
  signal DUTYDA_i : std_logic_vector(3 downto 0);
  signal FDLY_i   : std_logic_vector(3 downto 0);

  component rPLL
    generic (
      FCLKIN          : in string  := "100.0";
      DEVICE          : in string  := "GW1N-4";
      DYN_IDIV_SEL    : in string  := "false";
      IDIV_SEL        : in integer := 0;
      DYN_FBDIV_SEL   : in string  := "false";
      FBDIV_SEL       : in integer := 0;
      DYN_ODIV_SEL    : in string  := "false";
      ODIV_SEL        : in integer := 8;
      PSDA_SEL        : in string  := "0000";
      DYN_DA_EN       : in string  := "false";
      DUTYDA_SEL      : in string  := "1000";
      CLKOUT_FT_DIR   : in bit     := '1';
      CLKOUTP_FT_DIR  : in bit     := '1';
      CLKOUT_DLY_STEP : in integer := 0;
      CLKOUTP_DLY_STEP: in integer := 0;
      CLKOUTD3_SRC    : in string  := "CLKOUT";
      CLKFB_SEL       : in string  := "internal";
      CLKOUT_BYPASS   : in string  := "false";
      CLKOUTP_BYPASS  : in string  := "false";
      CLKOUTD_BYPASS  : in string  := "false";
      CLKOUTD_SRC     : in string  := "CLKOUT";
      DYN_SDIV_SEL    : in integer := 2
    );
    port (
      CLKOUT  : out std_logic;
      LOCK    : out std_logic;
      CLKOUTP : out std_logic;
      CLKOUTD : out std_logic;
      CLKOUTD3: out std_logic;
      RESET   : in  std_logic;
      RESET_P : in  std_logic;
      CLKIN   : in  std_logic;
      CLKFB   : in  std_logic;
      FBDSEL  : in  std_logic_vector(5 downto 0);
      IDSEL   : in  std_logic_vector(5 downto 0);
      ODSEL   : in  std_logic_vector(5 downto 0);
      PSDA    : in  std_logic_vector(3 downto 0);
      DUTYDA  : in  std_logic_vector(3 downto 0);
      FDLY    : in  std_logic_vector(3 downto 0)
    );
  end component;

begin
  gw_gnd  <= '0';
  FBDSEL_i <= (others => '0');
  IDSEL_i  <= (others => '0');
  ODSEL_i  <= (others => '0');
  PSDA_i   <= (others => '0');
  DUTYDA_i <= (others => '0');
  FDLY_i   <= "1111";

  rpll_inst : rPLL
    generic map (
      FCLKIN           => "27",
      DEVICE           => "GW1NR-9C",
      DYN_IDIV_SEL     => "false",
      IDIV_SEL         => 4,    -- /5
      DYN_FBDIV_SEL    => "false",
      FBDIV_SEL        => 34,   -- x35
      DYN_ODIV_SEL     => "false",
      ODIV_SEL         => 4,
      PSDA_SEL         => "0000",
      DYN_DA_EN        => "false",
      DUTYDA_SEL       => "1000",
      CLKOUT_FT_DIR    => '1',
      CLKOUTP_FT_DIR   => '1',
      CLKOUT_DLY_STEP  => 0,
      CLKOUTP_DLY_STEP => 0,
      CLKFB_SEL        => "internal",
      CLKOUT_BYPASS    => "false",
      CLKOUTP_BYPASS   => "false",
      CLKOUTD_BYPASS   => "false",
      DYN_SDIV_SEL     => 8,    -- CLKOUTD = CLKOUT/8
      CLKOUTD_SRC      => "CLKOUT",
      CLKOUTD3_SRC     => "CLKOUT"
    )
    port map (
      CLKOUT   => open,
      LOCK     => lock,
      CLKOUTP  => open,
      CLKOUTD  => clkout,
      CLKOUTD3 => open,
      RESET    => gw_gnd,
      RESET_P  => gw_gnd,
      CLKIN    => clkin,
      CLKFB    => gw_gnd,
      FBDSEL   => FBDSEL_i,
      IDSEL    => IDSEL_i,
      ODSEL    => ODSEL_i,
      PSDA     => PSDA_i,
      DUTYDA   => DUTYDA_i,
      FDLY     => FDLY_i
    );

end Behavioral;
