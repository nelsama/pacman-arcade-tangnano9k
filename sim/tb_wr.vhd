--
-- Reproduce la logica de escritura de pacman_video_out y comprueba cuantas
-- palabras se escriben realmente por linea.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_wr is
end;

architecture sim of tb_wr is

  constant SRC_X0 : integer := 129;
  constant SRC_Y0 : integer := 248;
  constant SRC_W  : integer := 383;
  constant SRC_H  : integer := 264;
  constant PPW    : integer := 8;
  constant LINE_B : integer := 384 / PPW;   -- 48

begin

  p : process
    variable hx, vy, a, pos : integer;
    variable writes_per_line : integer;
    variable total : integer := 0;
    variable holes : integer := 0;
    type flags is array (0 to 12799) of boolean;
    variable done : flags := (others => false);
  begin
    for v in 248 to 511 loop
      writes_per_line := 0;
      for hh in 0 to 511 loop
        hx := hh - SRC_X0;
        vy := v - SRC_Y0;
        if (hx >= 0) and (hx < SRC_W) and (vy >= 0) and (vy < SRC_H) then
          pos := hx mod PPW;
          a   := vy * LINE_B + hx / PPW;
          if (pos = PPW - 1) or (hx = SRC_W - 1) then
            writes_per_line := writes_per_line + 1;
            total := total + 1;
            done(a) := true;
          end if;
        end if;
      end loop;
      if v = 248 or v = 300 or v = 511 then
        report "vcnt=" & integer'image(v) &
               " vy=" & integer'image(v - SRC_Y0) &
               " escrituras=" & integer'image(writes_per_line);
      end if;
    end loop;

    for i in 0 to 12671 loop
      if not done(i) then holes := holes + 1; end if;
    end loop;

    report "escrituras totales: " & integer'image(total);
    report "esperadas         : " & integer'image(48 * 264);
    report "huecos sin escribir: " & integer'image(holes);
    wait;
  end process;

end;
