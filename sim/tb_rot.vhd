--
-- Verificacion de la rotacion sin ambiguedades.
--
-- Cada pixel de la imagen lleva un color que codifica su fila (y).
-- Asi, mirando una columna de la pantalla se sabe que fila de origen
-- corresponde a cada posicion, y se puede deducir la rotacion exacta.
--
--   color = 1 + (y mod 15)
--
-- Se imprime el mapa de transicion: para cada fila de pantalla, que
-- valor de y aparece en la primera columna visible.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity tb_rot is
end;

architecture sim of tb_rot is

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
  signal pal_data : std_logic_vector(7 downto 0);
  signal rst      : std_logic := '1';

  signal o_r, o_g, o_b : std_logic_vector(7 downto 0);
  signal o_hs, o_vs, o_de : std_logic;
  signal dbg_writes : std_logic_vector(15 downto 0);
  signal dbg_e3_de, dbg_e3_win : std_logic;
  signal dbg_pix : std_logic_vector(3 downto 0);
  signal dbg_e1_win : std_logic;
  signal dbg_h, dbg_v : integer;

  -- mapa: fila de pantalla -> color visto en la primera columna de ventana
  type rowmap_t is array (0 to 479) of integer;
  signal rowmap : rowmap_t := (others => -1);

  signal capturing : boolean := false;

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

  -- paleta identidad: indice -> R = indice (para leer el valor directo)
  pal_data <= std_logic_vector(resize(unsigned(pal_addr(2 downto 0)), 3))
              & "00000";

  -- origen: color = fila
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
          cidx <= std_logic_vector(to_unsigned((vy / 8) mod 8, 4));
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

  -- Registra, en el primer pixel de cada fila visible, el color leido.
  p_cap : process(clk_pix)
    variable hp, vp : integer := 0;
    variable seen_row : integer := -1;
  begin
    if rising_edge(clk_pix) then
      if o_de = '1' then
        if (hp = 0) then
          seen_row := vp;
        end if;
        -- primera columna de la ventana (X_OFF = 216)
        if (hp = 217) and (vp <= 479) then
          rowmap(vp) <= to_integer(unsigned(o_r(7 downto 5)));
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
      end if;
    end if;
  end process;

  p_report : process
  begin
    wait for 19 ms;
    report "=== MAPA DE ROTACION (fila pantalla -> color/fila origen) ===";
    for yy in 120 to 360 loop
      if (yy mod 10) = 0 then
        report "pantalla y=" & integer'image(yy) &
               "  color(origen)=" & integer'image(rowmap(yy));
      end if;
    end loop;
    wait;
  end process;

end sim;
