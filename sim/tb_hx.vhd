--
-- Muestra los valores reales de hcnt para una linea visible y comprueba
-- que hx mod 8 recorre 0..7 de forma consecutiva.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_hx is
end;

architecture sim of tb_hx is

  constant SRC_X0 : integer := 129;

begin

  p : process
    variable hx : integer;
    variable n  : integer := 0;
    variable s  : string(1 to 200);
    variable k  : integer := 1;
  begin
    for hh in 0 to 511 loop
      hx := hh - SRC_X0;
      if (hx >= 0) and (hx < 384) then
        if n < 24 then
          report "hcnt=" & integer'image(hh) &
                 " hx=" & integer'image(hx) &
                 " pos=" & integer'image(hx mod 8);
        end if;
        n := n + 1;
      end if;
    end loop;
    report "total visibles por linea: " & integer'image(n);
    wait;
  end process;

end;
