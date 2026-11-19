--
-- A simulation model of Pacman hardware
-- Copyright (c) MikeJ - January 2006
--
-- Port a Gowin (Tang Nano 9K).
--
-- Las cuatro ROMs de programa (6E, 6F, 6H, 6J) forman una unica memoria
-- de 16K x 8: los chips originales usan A11..A0 con CS segun A13..A12,
-- asi que la ROM completa se direcciona simplemente con A13..A0.
--
-- El contenido se genera con 'tools/rom2vhd.py' a partir de roms/*.bin y
-- se coloca en este mismo fichero (funcion pacman_rom_data). El script
-- sustituye este fichero completo, manteniendo el mismo interfaz.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

use work.pkg_pacman.all;

entity PACMAN_PROGRAM_ROM is
  port (
    I_ADDR            : in    std_logic_vector(13 downto 0);
    O_DATA            : out   std_logic_vector( 7 downto 0);
    ENA_6             : in    std_logic;
    CLK               : in    std_logic
    );
end;

architecture RTL of PACMAN_PROGRAM_ROM is

  -- >>> CONTENIDO ROM PROG >>>
    -- (vacio en el repositorio: lo rellena tools/rom2vhd.py desde roms/pacman/)
  -- <<< CONTENIDO ROM PROG <<<

begin
  p_rom : process
  begin
    wait until rising_edge(CLK);
    if (ENA_6 = '1') then
      O_DATA <= pacman_rom_data(I_ADDR);
    end if;
  end process;
end RTL;
