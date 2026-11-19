--
-- Mide la geometria REAL que produce el core Pac-Man.
--
-- Replica EXACTAMENTE los procesos p_hvcnt, p_sync y p_sync_comb de
-- src/core/pacman.vhd (mismos valores iniciales, misma logica) y cuenta:
--
--   * cuantos valores de hcnt caen fuera de hblank (pixeles por linea)
--   * en que valor de hcnt empieza y acaba la zona visible
--   * cuantas lineas visibles hay por campo (fuera de vblank)
--
-- Con eso el framebuffer puede usar la geometria correcta en vez de
-- valores supuestos.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity tb_geom is
end;

architecture sim of tb_geom is

  constant CLK_PERIOD : time := 40.67 ns;   -- 24,589 MHz

  signal clk    : std_logic := '1';
  signal ena6   : std_logic := '0';
  signal div    : std_logic_vector(1 downto 0) := "00";

  signal hcnt   : std_logic_vector(8 downto 0) := "010000000"; -- 080
  signal vcnt   : std_logic_vector(8 downto 0) := "011111000"; -- 0F8
  signal hblank : std_logic := '0';
  signal vblank : std_logic := '1';
  signal hsync  : std_logic := '0';
  signal vsync  : std_logic := '1';
  signal do_hsync : boolean := false;

  -- medidas
  signal px_in_line : integer := 0;   -- visibles en la linea actual
  signal first_h    : integer := -1;
  signal last_h     : integer := -1;
  signal lines_done : integer := 0;   -- lineas completas medidas
  signal done       : boolean := false;

  -- por campo
  signal visible_lines : integer := 0;

begin

  -- reloj y ENA_6 = 1 de cada 4
  p_clk : process
  begin
    wait for CLK_PERIOD/2;
    clk <= not clk;
  end process;

  p_div : process(clk)
  begin
    if rising_edge(clk) then
      div <= div + "1";
    end if;
  end process;

  ena6 <= div(0) and not div(1);

  -- contadores: copia literal de pacman.vhd
  p_hvcnt : process
    variable hcarry, vcarry : boolean;
  begin
    wait until rising_edge(clk);
    if (ena6 = '1') then
      hcarry := (hcnt = "111111111");
      if hcarry then
        hcnt <= "010000000";
      else
        hcnt <= hcnt + "1";
      end if;

      vcarry := (vcnt = "111111111");
      if do_hsync then
        if vcarry then
          vcnt <= "011111000";
        else
          vcnt <= vcnt + "1";
        end if;
      end if;
    end if;
  end process;

  -- p_sync_comb
  p_sync_comb : process(hcnt, vcnt)
  begin
    vsync <= not vcnt(8);
    do_hsync <= (hcnt = "010101111"); -- 0AF
  end process;

  -- p_sync: blanking
  p_sync : process
  begin
    wait until rising_edge(clk);
    if (ena6 = '1') then
      if (hcnt = "010001111") then        -- 08F
        hblank <= '1';
      elsif (hcnt = "011101111") then     -- 0EF
        hblank <= '0';
      end if;

      if do_hsync then
        hsync <= '1';
      elsif (hcnt = "011001111") then     -- 0CF
        hsync <= '0';
      end if;

      if do_hsync then
        if (vcnt = "111101111") then      -- 1EF
          vblank <= '1';
        elsif (vcnt = "100001111") then   -- 10F
          vblank <= '0';
        end if;
      end if;
    end if;
  end process;

  -- medicion
  p_meas : process
  begin
    wait until rising_edge(clk);
    if (ena6 = '1') and not done then

      if (hblank = '0') then
        px_in_line <= px_in_line + 1;
        if first_h < 0 then
          first_h <= conv_integer(hcnt);
        end if;
        last_h <= conv_integer(hcnt);
      end if;

      -- fin de linea: tras pasar por el primer valor del contador
      if (vcnt(8) = '1') and not (hcnt(8) = '1' and hcnt(7 downto 0) = x"80") then
        null;
      end if;

      -- al completar una vuelta de hcnt
      if (hcnt = "010000000") then
        report "LINEA vcnt=" & integer'image(conv_integer(vcnt)) &
               " visibles=" & integer'image(px_in_line) &
               " hcnt_ini=" & integer'image(first_h) &
               " hcnt_fin=" & integer'image(last_h) &
               " hblank=" & std_logic'image(hblank) &
               " vblank=" & std_logic'image(vblank);
        px_in_line <= 0;
        first_h <= -1;
        last_h <= -1;
        lines_done <= lines_done + 1;
        if lines_done > 300 then
          done <= true;
        end if;
      end if;

    end if;
  end process;

end;
