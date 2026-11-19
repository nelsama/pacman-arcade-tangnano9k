--
-- Modelo de simulacion de la PLL de Gowin (clk_pacman).
--
-- En hardware es un rPLL; para GHDL se genera una replica funcional:
--   CLKOUT = CLKIN * (FBDIV+1) / (IDIV+1) / ODIV
--   CLKOUTD = CLKOUT / DYN_SDIV_SEL
--
-- Configuracion del proyecto: IDIV=6, FBDIV=12, ODIV=16, SDIV=4
--   CLKOUT  = 27 * 13 / 7 / 16  = 50,14 MHz
--   CLKOUTD = 50,14 / 4         = 12,53 MHz

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;

entity clk_pacman is
  port (
    clkin  : in  std_logic;
    clkout : out std_logic;
    lock   : out std_logic
  );
end;

architecture sim of clk_pacman is

  constant T_IN   : time := 37.037 ns;   -- 27 MHz
  constant T_OUT  : time := 79.78 ns;    -- 12,53 MHz (CLKOUTD)

  signal clk_int  : std_logic := '0';
  signal locked   : std_logic := '0';

begin

  clk_int <= not clk_int after T_OUT / 2;
  clkout  <= clk_int;

  -- La PLL tarda unas decenas de microsegundos en enganchar
  p_lock : process
  begin
    locked <= '0';
    wait for 50 us;
    locked <= '1';
    wait;
  end process;

  lock <= locked;

end sim;
