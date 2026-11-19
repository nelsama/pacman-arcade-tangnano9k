--
-- A simulation model of Pacman hardware
-- Copyright (c) MikeJ - January 2006
--
-- Port a Gowin (Tang Nano 9K).
--
-- Paleta final 7F (16 x 8). Como en el hardware original es una RAM de
-- latches con lectura asincrona, se implementa como tabla combinacional.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

use work.pkg_pacman.all;

entity PACROM_7F_DST is
  port (
    ADDR        : in    std_logic_vector(3 downto 0);
    DATA        : out   std_logic_vector(7 downto 0)
    );
end;

architecture RTL of PACROM_7F_DST is

  -- >>> CONTENIDO ROM 7F >>>
    -- (vacio en el repositorio: lo rellena tools/rom2vhd.py desde roms/pacman/)
  -- <<< CONTENIDO ROM 7F <<<

begin
  DATA <= rom_data(ADDR);
end RTL;
