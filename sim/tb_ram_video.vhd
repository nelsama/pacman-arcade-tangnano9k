--
-- Testbench conjunto de PACMAN_RAMS + PACMAN_VIDEO.
--
-- Escribe patrones en la VRAM como haria el CPU (AB < 0x800) y comprueba
-- que PACMAN_VIDEO recupera esos datos por I_DB y produce color.
--
-- Este es el eslabon que falta entre la CPU (que ya se verifico) y el
-- framebuffer de placa.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity tb_ram_video is
end;

architecture sim of tb_ram_video is

  constant CLK_PERIOD : time := 79.78 ns;

  signal clk     : std_logic := '1';
  signal ena6    : std_logic := '0';
  signal hcnt    : std_logic_vector(8 downto 0) := "010000000";
  signal vcnt    : std_logic_vector(8 downto 0) := "011111000";
  signal hblank  : std_logic := '0';
  signal vblank  : std_logic := '0';
  signal flip    : std_logic := '0';

  signal ab      : std_logic_vector(11 downto 0) := (others => '0');
  signal db_wr   : std_logic_vector(7 downto 0) := (others => '0');
  signal db_rd   : std_logic_vector(7 downto 0);
  signal r_w_l   : std_logic := '1';
  signal vram_l  : std_logic := '1';
  signal wr2_l   : std_logic := '1';

  signal o_red   : std_logic_vector(2 downto 0);
  signal o_green : std_logic_vector(2 downto 0);
  signal o_blue  : std_logic_vector(1 downto 0);
  signal o_idx   : std_logic_vector(3 downto 0);

  signal nz     : integer := 0;
  signal hist   : integer := 0;
  signal phase  : integer := 0;

begin

  clk  <= not clk after CLK_PERIOD / 2;
  ena6 <= not ena6 after CLK_PERIOD;

  p_hv : process(clk)
  begin
    if rising_edge(clk) then
      if ena6 = '1' then
        if hcnt = "111111111" then
          hcnt <= "010000000";
        else
          hcnt <= hcnt + 1;
        end if;
        if hcnt = "010101111" then
          if vcnt = "111111111" then
            vcnt <= "011111000";
          else
            vcnt <= vcnt + 1;
          end if;
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
      end if;
    end if;
  end process;

  -- FASE 0 (0..300us): el "CPU" llena la VRAM con un patron de color.
  -- FASE 1: se deja de escribir y solo se lee, como en el juego real.
  p_wr : process(clk)
    variable addr : integer;
  begin
    if rising_edge(clk) then
      if ena6 = '1' then
        if now < 300 us then
          -- escribe 0x040..0x3FF de la VRAM (color register + caracter)
          addr := 64 + (to_integer(unsigned(hcnt)) mod 960);
          ab     <= std_logic_vector(to_unsigned(addr, 12));
          db_wr  <= "001" & "01111";     -- caracter 0x20 y color 0x0F
          r_w_l  <= '0';
          vram_l <= '0';
          phase  <= 0;
        else
          r_w_l  <= '1';
          vram_l <= '1';
          phase  <= 1;
        end if;
      end if;
    end if;
  end process;

  -- El mux de AB como en pacman.vhd: en la fase de video lo controla el
  -- contador de VRAM; aqui se simplifica usando hcnt.
  p_ab : process(clk)
  begin
    if rising_edge(clk) then
      if (now > 350 us) and (hcnt(1) = '1') then
        ab <= "000" & hcnt(8 downto 1) & "0";
      end if;
    end if;
  end process;

  u_rams : entity work.PACMAN_RAMS
    port map (
      I_AB     => ab,
      I_DATA   => db_wr,
      O_DATA   => db_rd,
      I_R_W_L  => r_w_l,
      I_VRAM_L => vram_l,
      ENA_6    => ena6,
      CLK      => clk
      );

  u_video : entity work.PACMAN_VIDEO
    port map (
      I_HCNT      => hcnt,
      I_VCNT      => vcnt,
      I_AB        => ab,
      I_DB        => db_rd,
      I_HBLANK    => hblank,
      I_VBLANK    => vblank,
      I_FLIP      => flip,
      I_WR2_L     => wr2_l,
      O_RED       => o_red,
      O_GREEN     => o_green,
      O_BLUE      => o_blue,
      O_COLOR_IDX => o_idx,
      ENA_6       => ena6,
      CLK         => clk
      );

  p_stat : process(clk)
    variable seen : std_logic_vector(15 downto 0) := (others => '0');
    variable v : integer;
  begin
    if rising_edge(clk) then
      if phase = 1 then
        v := to_integer(unsigned(o_idx));
        if seen(v) = '0' then
          seen(v) := '1';
          hist <= hist + 1;
        end if;
        if v /= 0 then
          nz <= nz + 1;
        end if;
      end if;
    end if;
  end process;

  p_report : process
  begin
    wait for 1 ms;
    report "=== RAM + VIDEO ===";
    report "valores distintos de color : " & integer'image(hist);
    report "ciclos con color != 0      : " & integer'image(nz);
    report "ultimo db_rd               : 0x" & to_hstring(db_rd);
    wait;
  end process;

end sim;
