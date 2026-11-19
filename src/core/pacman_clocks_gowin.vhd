--
-- A simulation model of Pacman hardware
-- Copyright (c) MikeJ - January 2006
--
-- Port a Gowin (Tang Nano 9K) del generador de relojes.
--
-- IMPORTANTE: el core NECESITA 25 MHz reales con ENA_6 a 6,25 MHz.
-- No se puede bajar el reloj base aunque el T80 fuese mas lento: el bus
-- de video alterna CPU/VRAM con hcnt(1), y ese margen de 4 ciclos es lo
-- que permite que ambos compartan la memoria. Con un reparto distinto
-- la CPU y el video se pisan y la pantalla queda en negro.
--
--   reloj base = 25,00 MHz  (rPLL 27 * 25 / 27, VCO 400 MHz)
--   ENA_6      = 1 de cada 4 ciclos  -> 6,25 MHz
--   ENA_12     = 1 de cada 2 ciclos  -> 12,5 MHz
--
-- Es identico al pacman_clocks del original (DCM 25 MHz + div_cnt).

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

use work.pkg_pacman.all;

entity PACMAN_CLOCKS is
  port (
    I_CLK_REF         : in    std_logic;
    I_RESET_L         : in    std_logic;
    --
    O_CLK_REF         : out   std_logic;
    --
    O_ENA_12          : out   std_logic;
    O_ENA_6           : out   std_logic;
    O_CLK             : out   std_logic;
    O_RESET           : out   std_logic
    );
end;

architecture RTL of PACMAN_CLOCKS is

  signal clk            : std_logic;
  signal pll_lock       : std_logic;
  signal delay_count    : std_logic_vector(7 downto 0);
  signal div_cnt        : std_logic_vector(1 downto 0);

begin

  u_pll : entity work.clk_pacman
    port map (
      clkin  => I_CLK_REF,
      clkout => clk,
      lock   => pll_lock
      );

  O_CLK     <= clk;
  O_CLK_REF <= clk;

  -- Reset diferido (256 ciclos), sujeto al lock de la PLL.
  p_delay : process
  begin
    wait until rising_edge(clk);
    if (I_RESET_L = '0') or (pll_lock = '0') then
      delay_count <= x"00";
      O_RESET     <= '1';
    elsif (delay_count = x"FF") then
      O_RESET     <= '0';
    else
      delay_count <= delay_count + "1";
      O_RESET     <= '1';
    end if;
  end process;

  p_clk_div : process
  begin
    wait until rising_edge(clk);
    if (I_RESET_L = '0') or (pll_lock = '0') then
      div_cnt <= (others => '0');
    else
      div_cnt <= div_cnt + "1";
    end if;
  end process;

  -- Igual que el original: ENA_12 = div(0), ENA_6 = div(0) and not div(1)
  O_ENA_12 <= div_cnt(0);
  O_ENA_6  <= div_cnt(0) and not div_cnt(1);

end RTL;
