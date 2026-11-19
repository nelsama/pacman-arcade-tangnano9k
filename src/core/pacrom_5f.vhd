--
-- A simulation model of Pacman hardware
-- Copyright (c) MikeJ - January 2006
--
-- Port a Gowin (Tang Nano 9K).
--
-- ROM de caracteres 5F (4K x 8).
-- El contenido se declara como ARRAY CONSTANTE: es el unico patron que
-- el sintetizador de Gowin reconoce como BRAM con inicializacion. Una
-- funcion con "case" acaba implementada en LUT (2.112 LUT por ROM) y
-- deja el diseno sin recursos.
--
-- El contenido lo genera 'tools/rom2vhd.py'.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

use work.pkg_pacman.all;

entity PACROM_5F is
  port (
    CLK         : in    std_logic;
    ENA         : in    std_logic;
    ADDR        : in    std_logic_vector(11 downto 0);
    DATA        : out   std_logic_vector(7 downto 0)
    );
end;

architecture RTL of PACROM_5F is

  type rom_t is array (0 to 4095) of std_logic_vector(7 downto 0);

  -- >>> CONTENIDO ROM 5F >>>
    -- (vacio en el repositorio: lo rellena tools/rom2vhd.py desde roms/pacman/)
  -- <<< CONTENIDO ROM 5F <<<

begin
  p_rom : process(CLK)
  begin
    if rising_edge(CLK) then
      if (ENA = '1') then
        DATA <= ROM_CONTENT(to_integer(unsigned(ADDR)));
      end if;
    end if;
  end process;
end RTL;
