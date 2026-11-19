--
-- A simulation model of Pacman hardware
-- Copyright (c) MikeJ - January 2006
--
-- Port a Gowin (Tang Nano 9K).
--
-- Paleta de color 4A (256 x 8). En el hardware original es una RAM de
-- latches con lectura asincrona, asi que se implementa como tabla
-- combinacional (LUT). Su contenido lo genera 'tools/rom2vhd.py' en la
-- version "funcion + case"; aqui queda escrita a mano porque el numero
-- de entradas es pequeno.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

use work.pkg_pacman.all;

entity PACROM_4A_DST is
  port (
    ADDR        : in    std_logic_vector(7 downto 0);
    DATA        : out   std_logic_vector(7 downto 0)
    );
end;

architecture RTL of PACROM_4A_DST is

  -- >>> CONTENIDO ROM 4A >>>
    -- (vacio en el repositorio: lo rellena tools/rom2vhd.py desde roms/pacman/)
  -- <<< CONTENIDO ROM 4A <<<

begin
  DATA <= rom_data(ADDR);
end RTL;
