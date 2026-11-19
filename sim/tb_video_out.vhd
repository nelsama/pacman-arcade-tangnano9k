--
-- Testbench de pacman_video_out: verifica geometria y rotacion.
--
-- Escribe en la imagen del juego:
--   * una FRANJA en la primera linea (imagen y=0)  -> color A
--   * una FRANJA en la primera columna (imagen x=0) -> color B
-- y despues informa en que borde de la pantalla aparece cada una.
--
-- Con eso se deduce la rotacion aplicada:
--   franja y=0 arriba en pantalla   -> sin rotar
--   franja y=0 abajo                -> 180
--   franja y=0 a la izquierda       -> 90/270

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity tb_video_out is
end;

architecture sim of tb_video_out is

  constant T_CORE : time := 40.04 ns;
  constant T_PIX  : time := 37.037 ns;

  signal clk_core : std_logic := '1';
  signal clk_pix  : std_logic := '1';
  signal ena6     : std_logic := '0';
  signal hcnt     : std_logic_vector(8 downto 0) := "010000000";
  signal vcnt     : std_logic_vector(8 downto 0) := "011111000";
  signal hblank   : std_logic := '0';
  signal vblank   : std_logic := '0';
  signal cidx     : std_logic_vector(3 downto 0) := "0000";
  signal pal_addr : std_logic_vector(3 downto 0);
  -- paleta: entrada 1 -> rojo, entrada 2 -> verde
  signal pal_data : std_logic_vector(7 downto 0);
  signal rst      : std_logic := '1';

  signal o_r, o_g, o_b : std_logic_vector(7 downto 0);
  signal o_hs, o_vs, o_de : std_logic;

  signal done : boolean := false;

  signal dbg_writes : std_logic_vector(15 downto 0);
  signal dbg_e3_de  : std_logic;
  signal dbg_e3_win : std_logic;
  signal dbg_pix    : std_logic_vector(3 downto 0);
  signal dbg_e1_win : std_logic;
  signal dbg_h      : integer;
  signal dbg_v      : integer;
  signal n_e1win    : integer := 0;
  signal n_red      : integer := 0;
  signal red_xmax, red_ymax : integer := -1;
  signal hmax, vmax : integer := 0;
  signal n_de    : integer := 0;
  signal n_pixnz : integer := 0;
  signal n_e3de  : integer := 0;
  signal n_e3win : integer := 0;
  signal n_palnz : integer := 0;
  signal n_winnz : integer := 0;
  signal n_col : integer := 0;

  -- posicion del primer pixel rojo y verde encontrados
  signal red_x, red_y     : integer := -1;
  signal green_x, green_y : integer := -1;
  signal hpos, vpos       : integer := 0;
  signal frame_ok         : boolean := false;

begin

  clk_core <= not clk_core after T_CORE / 2;
  clk_pix  <= not clk_pix  after T_PIX / 2;

  p_ena : process(clk_core)
    variable ph : std_logic := '0';
  begin
    if rising_edge(clk_core) then
      ph := not ph;
      ena6 <= ph;
    end if;
  end process;

  p_reset : process
  begin
    rst <= '1';
    wait for 10 us;
    rst <= '0';
    wait;
  end process;

  -- paleta: 1 -> R, 2 -> G
  -- entrada 1: R=7 G=0 B=0   (bits 2:0 = R, 5:3 = G, 7:6 = B)
  -- entrada 2: R=0 G=7 B=0
  -- paleta de prueba: cualquier indice distinto de 0 da color.
  -- mantiene R y G separados para poder distinguir las franjas.
  pal_data <= "00000111" when pal_addr(0) = '1' else
              "00111000" when pal_addr /= "0000" else
              "00000000";

  -- Patron de origen, escrito con el mismo metodo que el diseno real.
  p_src : process(clk_core)
    variable hx, vy : integer;
  begin
    if rising_edge(clk_core) then
      if ena6 = '1' then
        if hcnt = "111111111" then
          hcnt <= "010000000";
          if vcnt = "111111111" then
            vcnt <= "011111000";
          else
            vcnt <= vcnt + 1;
          end if;
        else
          hcnt <= hcnt + 1;
        end if;

        if hcnt = "010001111" then
          hblank <= '1';
        elsif hcnt = "011101111" then
          hblank <= '0';
        end if;

        if hcnt = "010101111" then
          if vcnt = "111101111" then
            vblank <= '1';
          elsif vcnt = "100001111" then
            vblank <= '0';
          end if;
        end if;

        hx := to_integer(unsigned(hcnt)) - 16#0F0#;
        vy := to_integer(unsigned(vcnt)) - 16#110#;

        if (hx >= 0) and (hx < 224) and (vy >= 0) and (vy < 224) then
          if (vy < 3) then
            cidx <= "0001";              -- primera LINEA (y=0)  -> rojo
          elsif (hx < 3) then
            cidx <= "0010";              -- primera COLUMNA (x=0) -> verde
          else
            cidx <= "0000";
          end if;
        else
          cidx <= "0000";
        end if;
      end if;
    end if;
  end process;

  u_dut : entity work.pacman_video_out
    port map (
      clk_core  => clk_core,
      ena_6     => ena6,
      hcnt      => hcnt,
      vcnt      => vcnt,
      hblank    => hblank,
      vblank    => vblank,
      color_idx => cidx,
      pal_addr  => pal_addr,
      pal_data  => pal_data,
      clk_pix   => clk_pix,
      rst       => rst,
      out_r     => o_r,
      out_g     => o_g,
      out_b     => o_b,
      out_hs    => o_hs,
      out_vs    => o_vs,
      out_de    => o_de,
      dbg_writes => dbg_writes,
      dbg_e3_de  => dbg_e3_de,
      dbg_e3_win => dbg_e3_win,
      dbg_pix    => dbg_pix,
      dbg_e1_win => dbg_e1_win,
      dbg_h      => dbg_h,
      dbg_v      => dbg_v
      );

  -- Seguimiento del raster de pantalla.
  -- El modulo genera 720x480 con DE activo en la parte visible.
  p_scan : process(clk_pix)
    variable hp : integer := 0;
    variable vp : integer := 0;
    variable started : boolean := false;
  begin
    if rising_edge(clk_pix) then
      if o_de = '1' then
        if (o_r /= x"00") and (red_x < 0) then
          red_x <= hp;
          red_y <= vp;
        end if;
        if (o_g /= x"00") and (green_x < 0) then
          green_x <= hp;
          green_y <= vp;
        end if;

        if hp = 719 then
          hp := 0;
          if vp = 479 then
            vp := 0;
          else
            vp := vp + 1;
          end if;
        else
          hp := hp + 1;
        end if;
      else
        -- fin de linea visible: al salir de DE
        if hp /= 0 then
          hp := 0;
          vp := vp + 1;
        end if;
      end if;
    end if;
  end process;

  p_trace : process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      if (o_de = '1') and (o_r /= x"00") then
        n_red <= n_red + 1;
      end if;
      if dbg_e1_win = '1' then
        n_e1win <= n_e1win + 1;
      end if;
      if dbg_h > hmax then hmax <= dbg_h; end if;
      if dbg_v > vmax then vmax <= dbg_v; end if;
      if (dbg_e3_de = '1') then
        n_e3de <= n_e3de + 1;
      end if;
      if (dbg_e3_win = '1') then
        n_e3win <= n_e3win + 1;
      end if;
      if (pal_addr /= "0000") then
        n_pixnz <= n_pixnz + 1;
      end if;
      if (pal_data /= x"00") then
        n_palnz <= n_palnz + 1;
      end if;
      if o_de = '1' then
        n_de <= n_de + 1;
        if (o_r /= x"00") or (o_g /= x"00") then
          n_col <= n_col + 1;
        end if;
      end if;
    end if;
  end process;

  p_report : process
  begin
    wait for 19 ms;
    report "=== GEOMETRIA ===";
    report "primera LINEA de imagen (rojo)  -> pantalla x=" &
           integer'image(red_x) & " y=" & integer'image(red_y);
    report "primera COLUMNA de imagen (verde) -> pantalla x=" &
           integer'image(green_x) & " y=" & integer'image(green_y);
    report "eventos de escritura en fb: " &
           integer'image(to_integer(unsigned(dbg_writes)));
    report "pixeles rojos totales: " & integer'image(n_red);
    report "e1_win=1: " & integer'image(n_e1win) &
           "  h max " & integer'image(hmax) &
           "  v max " & integer'image(vmax);
    report "e3_de=1: " & integer'image(n_e3de) &
           "  e3_win=1: " & integer'image(n_e3win);
    report "pal_addr != 0: " & integer'image(n_pixnz) &
           "   pal_data != 0: " & integer'image(n_palnz);
    report "ciclos con DE: " & integer'image(n_de) &
           "   con color: " & integer'image(n_col);
    report "pantalla: 0..719 x 0..479";
    wait;
  end process;


end sim;
