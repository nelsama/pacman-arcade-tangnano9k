--
-- Verifica la CAPTURA del framebuffer: recorre hcnt/vcnt como el core y
-- comprueba que cada pixel acaba en una direccion distinta y en el orden
-- esperado. No simula la memoria, solo calcula lo que se escribiria.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_capture is
end;

architecture sim of tb_capture is

  constant SRC_X0 : integer := 129;
  constant SRC_Y0 : integer := 248;
  constant SRC_W  : integer := 384;
  constant SRC_H  : integer := 264;
  constant PPW    : integer := 8;
  constant LINE_B : integer := SRC_W / PPW;

begin

  p : process
    variable hx, vy, a, pos : integer;
    variable n_pixels  : integer := 0;
    variable n_writes  : integer := 0;
    variable seen      : integer := 0;
    variable last_addr : integer := -1;
    variable max_addr  : integer := 0;
    variable dup       : integer := 0;
    type flags is array (0 to 12799) of boolean;
    variable done  : flags := (others => false);
  begin
    for v in 248 to 511 loop
      for hh in 0 to 511 loop
        -- solo pixeles visibles (hblank/vblank ya filtrados por el test)
        hx := hh - SRC_X0;
        vy := v - SRC_Y0;
        if (hx >= 0) and (hx < SRC_W) and (vy >= 0) and (vy < SRC_H) then
          n_pixels := n_pixels + 1;
          pos := hx mod PPW;
          a   := vy * LINE_B + hx / PPW;
          if a > max_addr then max_addr := a; end if;
          if done(a) then
            dup := dup + 1;
          else
            done(a) := true;
            seen := seen + 1;
          end if;
          if pos = PPW - 1 then
            n_writes := n_writes + 1;
          end if;
        end if;
      end loop;
    end loop;

    report "pixeles visibles : " & integer'image(n_pixels);
    report "palabras escritas: " & integer'image(n_writes);
    report "esperadas        : " & integer'image(SRC_W/PPW * SRC_H);
    report "direcciones unicas: " & integer'image(seen);
    report "direccion maxima : " & integer'image(max_addr);
    report "palabras repetidas: " & integer'image(dup);
    wait;
  end process;

end;
