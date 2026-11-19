--
-- Testbench de pacman_video_out (escritura + rotacion + raster).
--
-- Genera una fuente con la temporizacion medida del core (288 px
-- visibles + 96 de blanking por linea, 224 lineas + 40 de vblank) con
-- un patron conocido c(x, y) de 4 clases, y comprueba PIXEL A PIXEL que
-- la pantalla 720x480 muestra:
--   pantalla(sx, sy) = c(x = sy - 96, y = 223 - (sx - 248))  dentro de la ventana
--   negro                                                    fuera
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_fbrot is
end;

architecture sim of tb_fbrot is

  constant T_CORE : time := 42.328 ns;   -- 23,625 MHz
  constant T_PIX  : time := 37.037 ns;   -- 27 MHz

  signal clk_core : std_logic := '1';
  signal clk_pix  : std_logic := '1';
  signal pv       : std_logic := '0';
  signal hbl, vbl : std_logic := '1';
  signal cidx     : std_logic_vector(3 downto 0) := "0000";

  signal o_r, o_g, o_b    : std_logic_vector(7 downto 0);
  signal o_hs, o_vs, o_de : std_logic;

  signal frames_src : integer := 0;

  -- clase del patron en la imagen del core
  function cls (x, y : integer) return integer is
  begin
    return ((x / 3) + (y / 5) + (x * y) / 97) mod 4;
  end function;

  function idx_of (c : integer) return std_logic_vector is
  begin
    case c is
      when 0      => return "0000";   -- negro
      when 1      => return "1011";   -- 11 azul
      when 2      => return "1001";   -- 9 amarillo
      when others => return "0001";   -- 1 rojo
    end case;
  end function;

  function rgb_of (c : integer) return std_logic_vector is
  begin
    case c is
      when 0      => return x"000000";
      when 1      => return x"2121FF";
      when 2      => return x"FFFF00";
      when others => return x"FF0000";
    end case;
  end function;

begin

  clk_core <= not clk_core after T_CORE / 2;
  clk_pix  <= not clk_pix  after T_PIX / 2;

  -- Fuente: 1 pixel cada 4 ciclos (ENA_6), linea de 384, campo de 264.
  p_src : process
    variable x, y : integer;
  begin
    for f in 0 to 2 loop
      for ln in 0 to 263 loop
        for px in 0 to 383 loop
          wait until rising_edge(clk_core);
          wait until rising_edge(clk_core);
          wait until rising_edge(clk_core);
          vbl <= '1' when ln >= 224 else '0';
          hbl <= '1' when px >= 288 else '0';
          if (ln < 224) and (px < 288) then
            cidx <= idx_of(cls(px, ln));
          else
            cidx <= "0000";
          end if;
          pv <= '1';
          wait until rising_edge(clk_core);
          pv <= '0';
        end loop;
      end loop;
      frames_src <= f + 1;
    end loop;
    wait;
  end process;

  dut : entity work.pacman_video_out
    port map (
      clk_core => clk_core, ena_6 => '0',
      hcnt => (others => '0'), vcnt => (others => '0'),
      hblank => hbl, vblank => vbl, pix_valid => pv, color_idx => cidx,
      clk_pix => clk_pix, rst => '0',
      out_r => o_r, out_g => o_g, out_b => o_b,
      out_hs => o_hs, out_vs => o_vs, out_de => o_de
      );

  -- Comprobacion de un cuadro HDMI completo cuando la fuente ya ha
  -- escrito 2 campos.
  p_chk : process
    variable sx, sy   : integer := 0;
    variable prev_de  : std_logic := '0';
    variable prev_vs  : std_logic := '1';
    variable armed    : boolean := false;
    variable checking : boolean := false;
    variable errs, n_ok, n_win : integer := 0;
    variable exp      : std_logic_vector(23 downto 0);
    variable got      : std_logic_vector(23 downto 0);
    variable ix, iy   : integer;
  begin
    wait until rising_edge(clk_pix);
    if frames_src >= 2 then armed := true; end if;

    -- inicio de cuadro: flanco de bajada de vsync
    if prev_vs = '1' and o_vs = '0' then
      if checking then
        report "RESULTADO: pixeles en ventana = " & integer'image(n_win) &
               ", correctos = " & integer'image(n_ok) &
               ", errores = " & integer'image(errs) &
               ", lineas DE = " & integer'image(sy);
        std.env.finish;
      end if;
      if armed then checking := true; end if;
      sy := 0;
    end if;
    prev_vs := o_vs;

    if o_de = '1' then
      if checking then
        got := o_r & o_g & o_b;
        if (sx >= 248) and (sx < 248 + 224) and (sy >= 96) and (sy < 96 + 288) then
          ix  := sy - 96;
          iy  := 223 - (sx - 248);
          exp := rgb_of(cls(ix, iy));
          n_win := n_win + 1;
        else
          exp := x"000000";
        end if;
        if got = exp then
          n_ok := n_ok + 1;
        else
          if errs < 10 then
            report "ERROR en (" & integer'image(sx) & "," & integer'image(sy) &
                   ") esperado " & to_hstring(exp) & " leido " & to_hstring(got);
          end if;
          errs := errs + 1;
        end if;
      end if;
      sx := sx + 1;
    elsif prev_de = '1' then
      sx := 0;
      sy := sy + 1;
    end if;
    prev_de := o_de;
  end process;

end sim;
