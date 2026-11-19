--
-- Mide la ventana VISIBLE real del core Pac-Man tal como la recibe la
-- placa (O_HBLANK / O_VBLANK = blanking que de verdad apaga el pixel,
-- alineado con O_COLOR_IDX y O_PIX_VALID).
--
-- Comprueba: 288 pixeles visibles por linea, 224 lineas por campo, y
-- reporta en que O_HCNT / O_VCNT empiezan y acaban.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_win is
end;

architecture sim of tb_win is

  signal clk27   : std_logic := '1';
  signal reset   : std_logic := '1';
  signal clk     : std_logic;

  signal r, g, b : std_logic_vector(3 downto 0);
  signal hs, vs, au : std_logic;

  signal hcnt, vcnt  : std_logic_vector(8 downto 0);
  signal hbl, vbl, pv : std_logic;

begin

  clk27 <= not clk27 after 18.5 ns;

  p_reset : process
  begin
    reset <= '1';
    wait for 60 us;
    reset <= '0';
    wait;
  end process;

  u_core : entity work.PACMAN
    port map (
      O_VIDEO_R => r, O_VIDEO_G => g, O_VIDEO_B => b,
      O_HSYNC => hs, O_VSYNC => vs, O_AUDIO => au,
      I_SW => (others => '1'), I_BUTTON => (others => '1'),
      O_LED => open, I_RESET => reset, I_CLK_REF => clk27,
      O_CLK_25 => clk,
      O_COLOR_IDX => open, O_RGB => open, O_PIX_VALID => pv,
      O_HCNT => hcnt, O_VCNT => vcnt, O_HBLANK => hbl,
      O_VBLANK => vbl, O_ENA_6 => open
      );

  p_meas : process
    variable h, v          : integer;
    variable n_px          : integer := 0;
    variable first_h, last_h : integer := -1;
    variable in_line       : boolean := false;
    variable n_lines       : integer := 0;
    variable first_v, last_v : integer := -1;
    variable seen_vblank   : boolean := false;
    variable bad           : integer := 0;
  begin
    wait until rising_edge(clk);
    if pv = '1' then
      h := to_integer(unsigned(hcnt));
      v := to_integer(unsigned(vcnt));
      if vbl = '1' then
        if seen_vblank and n_lines > 0 then
          report "CAMPO: lineas visibles = " & integer'image(n_lines) &
                 "  O_VCNT " & integer'image(first_v) & " .. " & integer'image(last_v) &
                 "  lineas con /= 288 px: " & integer'image(bad);
          std.env.finish;
        end if;
        seen_vblank := true;
        n_lines := 0;
      elsif seen_vblank then
        if hbl = '0' then
          if not in_line then
            in_line := true;
            n_px    := 0;
            first_h := h;
            if n_lines = 0 then first_v := v; end if;
          end if;
          n_px   := n_px + 1;
          last_h := h;
          last_v := v;
        elsif in_line then
          in_line := false;
          n_lines := n_lines + 1;
          if n_px /= 288 then bad := bad + 1; end if;
          if n_lines <= 2 or n_lines = 224 then
            report "linea " & integer'image(n_lines) & ": " & integer'image(n_px) &
                   " px, O_HCNT " & integer'image(first_h) & " .. " & integer'image(last_h) &
                   ", O_VCNT " & integer'image(v);
          end if;
        end if;
      end if;
    end if;
  end process;

end sim;
