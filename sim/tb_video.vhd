--
-- Testbench de PACMAN_VIDEO.
--
-- Objetivo: saber si O_COLOR_IDX produce algo distinto de cero cuando
-- el bus I_DB lleva un color valido. Esto aisla el problema del resto
-- del sistema (CPU, VRAM) en segundos.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity tb_video is
end;

architecture sim of tb_video is

  constant CLK_PERIOD : time := 79.78 ns;

  signal clk     : std_logic := '1';
  signal ena6    : std_logic := '0';
  signal hcnt    : std_logic_vector(8 downto 0) := "010000000";
  signal vcnt    : std_logic_vector(8 downto 0) := "011111000";
  signal hblank  : std_logic := '0';
  signal vblank  : std_logic := '0';
  signal ab      : std_logic_vector(11 downto 0) := (others => '0');
  signal db      : std_logic_vector(7 downto 0) := (others => '0');
  signal wr2_l   : std_logic := '1';
  signal flip    : std_logic := '0';

  signal o_red   : std_logic_vector(2 downto 0);
  signal o_green : std_logic_vector(2 downto 0);
  signal o_blue  : std_logic_vector(1 downto 0);
  signal o_idx   : std_logic_vector(3 downto 0);

  signal hist    : integer := 0;
  signal nz_cnt  : integer := 0;

begin

  clk  <= not clk after CLK_PERIOD / 2;
  ena6 <= not ena6 after CLK_PERIOD;

  -- hcnt 0x080..0x1FF, vcnt 0x0F8..0x1FF, como pacman.vhd
  p_hv : process(clk)
  begin
    if rising_edge(clk) then
      if ena6 = '1' then
        if hcnt = "111111111" then
          hcnt <= "010000000";
        else
          hcnt <= hcnt + 1;
        end if;

        if hcnt = "010101111" then            -- 0x0AF
          if vcnt = "111111111" then
            vcnt <= "011111000";              -- 0x0F8
          else
            vcnt <= vcnt + 1;
          end if;
        end if;

        if hcnt = "010001111" then            -- 0x08F
          hblank <= '1';
        elsif hcnt = "011101111" then         -- 0x0EF
          hblank <= '0';
        end if;

        if hcnt = "010101111" then
          if vcnt = "111101111" then          -- 0x1EF
            vblank <= '1';
          elsif vcnt = "100001111" then     -- 0x10F
            vblank <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Bus de datos: durante toda la linea llevamos un valor con el color
  -- register puesto (vout_db se muestrea en hcnt(2:0)="111").
  --   bits 4:0 = color register (0x0F = amarillo)
  --   bits 7:5 = parte del caracter
  p_db : process(clk)
  begin
    if rising_edge(clk) then
      db <= "001" & "01111";     -- 0x2F: color 0x0F
    end if;
  end process;

  u_dut : entity work.PACMAN_VIDEO
    port map (
      I_HCNT      => hcnt,
      I_VCNT      => vcnt,
      I_AB        => ab,
      I_DB        => db,
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
      v := to_integer(unsigned(o_idx));
      if seen(v) = '0' then
        seen(v) := '1';
        hist <= hist + 1;
      end if;
      if (v /= 0) then
        nz_cnt <= nz_cnt + 1;
      end if;
    end if;
  end process;

  p_report : process
  begin
    wait for 600 us;
    report "=== PACMAN_VIDEO ===";
    report "valores distintos de O_COLOR_IDX : " & integer'image(hist);
    report "ciclos con O_COLOR_IDX != 0       : " & integer'image(nz_cnt);
    wait;
  end process;

end sim;
