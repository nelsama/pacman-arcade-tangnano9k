--
-- Testbench del core PACMAN: comprueba que arranca y genera imagen.
--
--  1. Reloj de 12,53 MHz con ENA_6 = 1 de cada 2 (igual que el diseno).
--  2. Suelta el reset y muestrea (hcnt, vcnt, hblank, vblank, color_idx)
--     exactamente como hace pacman_video_out.
--  3. Vuelca la imagen a un PPM y reporta cuantos pixeles no son negros.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;
  use work.tb_image_pkg.all;

entity tb_pacman is
end;

architecture sim of tb_pacman is

  constant CLK_PERIOD : time := 79.78 ns;    -- 12,53 MHz
  constant SIM_TIME   : time := 300 us;   -- suficiente para que el Z80 arranque

  constant H_IMG_START : integer := 16#0F0#;
  constant V_IMG_START : integer := 16#110#;

  signal clk27   : std_logic := '1';
  signal clk     : std_logic := '1';
  signal reset   : std_logic := '1';
  signal done    : boolean := false;

  signal video_r : std_logic_vector(3 downto 0);
  signal video_g : std_logic_vector(3 downto 0);
  signal video_b : std_logic_vector(3 downto 0);
  signal hsync   : std_logic;
  signal vsync   : std_logic;
  signal audio   : std_logic;
  signal clk25   : std_logic;

  signal color_idx : std_logic_vector(3 downto 0);
  signal hcnt      : std_logic_vector(8 downto 0);
  signal vcnt      : std_logic_vector(8 downto 0);
  signal hblank    : std_logic;
  signal vblank    : std_logic;
  signal ena6      : std_logic;

  shared variable img : image_prot_t;

  -- estadisticas
  signal n_samples : integer := 0;
  signal n_frames  : integer := 0;

begin

  clk27 <= not clk27 after 18.5 ns;
  clk   <= not clk   after CLK_PERIOD / 2;

  p_ena : process(clk)
    variable ph : std_logic := '0';
  begin
    if rising_edge(clk) then
      ph   := not ph;
      ena6 <= ph;
    end if;
  end process;

  p_done : process
  begin
    wait for SIM_TIME;
    done <= true;
    wait;
  end process;

  p_reset : process
  begin
    reset <= '1';
    wait for 100 us;
    reset <= '0';
    wait;
  end process;

  u_core : entity work.PACMAN
    port map (
      O_VIDEO_R   => video_r,
      O_VIDEO_G   => video_g,
      O_VIDEO_B   => video_b,
      O_HSYNC     => hsync,
      O_VSYNC     => vsync,
      O_AUDIO     => audio,
      I_SW        => (others => '1'),
      I_BUTTON    => (others => '1'),
      O_LED       => open,
      I_RESET     => reset,
      I_CLK_REF   => clk27,
      O_CLK_25    => clk25,
      O_COLOR_IDX => color_idx,
      O_HCNT      => hcnt,
      O_VCNT      => vcnt,
      O_HBLANK    => hblank,
      O_VBLANK    => vblank,
      O_ENA_6     => ena6
      );

  -- Muestreo identico al de pacman_video_out
  p_sample : process(clk)
    variable hx, vy : integer;
    variable v : std_logic_vector(3 downto 0);
  begin
    if rising_edge(clk) then
      if (ena6 = '1') and (hblank = '0') and (vblank = '0') then
        hx := to_integer(unsigned(hcnt)) - H_IMG_START;
        vy := to_integer(unsigned(vcnt)) - V_IMG_START;
        if (hx >= 0) and (hx < IMG_W) and (vy >= 0) and (vy < IMG_H) then
          v := color_idx;
          img.set_pix(hx, vy, to_integer(unsigned(v)));
          n_samples <= n_samples + 1;
        end if;
      end if;
    end if;
  end process;

  -- Cuenta cuadros por vsync para saber si el core genera sincronismo
  p_frames : process(vsync)
  begin
    if rising_edge(vsync) then
      n_frames <= n_frames + 1;
    end if;
  end process;

  p_dump : process
    file f : text;
    variable l : line;
    variable v : integer;
  begin
    wait until done;
    file_open(f, "sim/frame.ppm", write_mode);
    write(l, string'("P3"));
    write(l, integer'image(IMG_W) & " " & integer'image(IMG_H));
    write(l, string'("255"));
    writeline(f, l);
    for y in 0 to IMG_H - 1 loop
      for x in 0 to IMG_W - 1 loop
        v := img.get_pix(x, y);
        if v <= 0 then
          write(l, string'("0 0 0 "));
        else
          write(l, string'("255 255 ") & integer'image((v * 17) mod 256) & " ");
        end if;
      end loop;
      writeline(f, l);
    end loop;
    file_close(f);

    write(l, string'("=== RESULTADO ==="));
    writeline(output, l);
    write(l, string'("muestras:      ") & integer'image(n_samples));
    writeline(output, l);
    write(l, string'("cuadros (vsync subidas): ") & integer'image(n_frames));
    writeline(output, l);
    write(l, string'("pixeles != 0:  ")
             & integer'image(img.count_nonzero) & " / 57344");
    writeline(output, l);
    wait;
  end process;

end sim;
