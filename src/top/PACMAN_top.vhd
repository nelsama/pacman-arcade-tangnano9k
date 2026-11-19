--
-- Pac-Man en Tang Nano 9K (Gowin GW1NR-9)
--
-- Top de placa: core PACMAN de MikeJ/FPGAArcade + adaptacion de
-- perifericos al Tang Nano 9K.
--
--   CLOCK_27     pin 52, 27 MHz
--   HDMI         pines 69..75 (TMDS + reloj)
--   Audio        pines 76 (R) y 77 (L)
--   Joystick 1   pines 29/30/33/34/40 (fire/up/down/left/right)
--   Botones      pines 4 (S1 = reset), 85 (start 1), 86 (credit)
--
-- Video: el core exporta las escrituras de la CPU en la memoria de video
-- (espia O_SNP_*). pacman_render mantiene su propia copia y dibuja la
-- imagen ya girada (ROT90), con los 16 colores reales de la PROM 7F, en
-- 720x480 @ 60 Hz por HDMI. No hay framebuffer.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity PACMAN_top is
  port (
    CLOCK_27      : in  std_logic;

    joy_up        : in  std_logic;
    joy_down      : in  std_logic;
    joy_left      : in  std_logic;
    joy_right     : in  std_logic;
    joy_fire      : in  std_logic;

    btn_reset     : in  std_logic;
    btn_start1    : in  std_logic;
    btn_credit    : in  std_logic;

    hdmi_tmds_c0_p : out std_logic;
    hdmi_tmds_c0_n : out std_logic;
    hdmi_tmds_c1_p : out std_logic;
    hdmi_tmds_c1_n : out std_logic;
    hdmi_tmds_c2_p : out std_logic;
    hdmi_tmds_c2_n : out std_logic;
    hdmi_tmds_ck_p : out std_logic;
    hdmi_tmds_ck_n : out std_logic;

    audio_out_l   : out std_logic;
    audio_out_r   : out std_logic
    );
end;

architecture Behavioral of PACMAN_top is

  signal core_audio   : std_logic;
  signal core_clk25   : std_logic;
  signal core_rgb_r   : std_logic_vector(3 downto 0);
  signal core_rgb_g   : std_logic_vector(3 downto 0);
  signal core_rgb_b   : std_logic_vector(3 downto 0);
  signal core_hsync   : std_logic;
  signal core_vsync   : std_logic;


  signal snp_we       : std_logic;
  signal snp_xy       : std_logic;
  signal snp_a        : std_logic_vector(11 downto 0);
  signal snp_d        : std_logic_vector(7 downto 0);

  signal clk135       : std_logic;   -- reloj serie TMDS (27 x 5)
  signal hdmi_lock    : std_logic;
  signal clk_pix      : std_logic;   -- 27 MHz = clk135 / 5 (CLKDIV)
  signal pix_rst_sr   : std_logic_vector(3 downto 0) := (others => '1');
  signal pix_rst      : std_logic;

  component CLKDIV
    generic (
      DIV_MODE : string := "2";
      GSREN    : string := "false"
    );
    port (
      CLKOUT : out std_logic;
      HCLKIN : in  std_logic;
      RESETN : in  std_logic;
      CALIB  : in  std_logic
    );
  end component;

  signal vga_r        : std_logic_vector(7 downto 0);
  signal vga_g        : std_logic_vector(7 downto 0);
  signal vga_b        : std_logic_vector(7 downto 0);
  signal vga_hs       : std_logic;
  signal vga_vs       : std_logic;
  signal vga_de       : std_logic;

  signal i_sw         : std_logic_vector(3 downto 0);
  signal i_button     : std_logic_vector(3 downto 0);

  signal reset_n      : std_logic;
  signal reset_core   : std_logic;



begin

  reset_n <= btn_reset;   -- S1 activo en bajo: pulsado = '0'

  -- Reset del core sincronizado y prolongado: la PLL tarda en enganchar
  -- y la RAM de video necesita unos ciclos antes de la primera lectura.
  p_reset : process(core_clk25)
    variable cnt : std_logic_vector(7 downto 0) := (others => '0');
  begin
    if rising_edge(core_clk25) then
      if (reset_n = '0') or (cnt /= x"FF") then
        if (cnt /= x"FF") then
          cnt := cnt + 1;
        end if;
        reset_core <= '1';
      else
        reset_core <= '0';
      end if;
    end if;
  end process;

  -- ------------------------------------------------------------------
  -- Relojes HDMI
  --   rPLL  27 MHz -> 135 MHz (serie, FCLK de los OSER10)
  --   CLKDIV 135 / 5 -> 27 MHz (pixel, PCLK de los OSER10)
  -- PCLK y FCLK tienen que venir de la misma fuente con fase fija; por
  -- eso el pixel clock sale del CLKDIV y no del pin CLOCK_27.
  -- ------------------------------------------------------------------
  u_clk_hdmi : entity work.clk_27x5
    port map (
      clkin  => CLOCK_27,
      clkout => clk135,
      lock   => hdmi_lock
      );

  u_clkdiv : CLKDIV
    generic map (
      DIV_MODE => "5",
      GSREN    => "false"
      )
    port map (
      CLKOUT => clk_pix,
      HCLKIN => clk135,
      RESETN => hdmi_lock,
      CALIB  => '0'
      );

  -- Reset de los serializadores: activo hasta unos ciclos despues del lock.
  p_pix_rst : process(clk_pix, hdmi_lock)
  begin
    if hdmi_lock = '0' then
      pix_rst_sr <= (others => '1');
    elsif rising_edge(clk_pix) then
      pix_rst_sr <= pix_rst_sr(2 downto 0) & '0';
    end if;
  end process;
  pix_rst <= pix_rst_sr(3);

  -- ------------------------------------------------------------------
  -- Entradas
  -- ------------------------------------------------------------------
  -- I_SW del core (activo en alto):
  --   3 = moneda 1 (credito)   2 = start 2 jugadores
  --   1 = start 1 jugador      0 = sin uso
  -- Los botones de la placa son activos en bajo (pull-up).
  i_sw <= (3 => not btn_credit,
           2 => '0',
           1 => not btn_start1,
           0 => '0');

  i_button <= (3 => not joy_right,
               2 => not joy_left,
               1 => not joy_down,
               0 => not joy_up);

  -- ------------------------------------------------------------------
  -- Core Pac-Man
  -- ------------------------------------------------------------------
  u_core : entity work.PACMAN
    port map (
      O_VIDEO_R  => core_rgb_r,
      O_VIDEO_G  => core_rgb_g,
      O_VIDEO_B  => core_rgb_b,
      O_HSYNC    => core_hsync,
      O_VSYNC    => core_vsync,
      O_AUDIO    => core_audio,
      I_SW       => i_sw,
      I_BUTTON   => i_button,
      O_LED      => open,
      I_RESET    => reset_core,
      I_CLK_REF  => CLOCK_27,
      O_CLK_25   => core_clk25,
      -- El video original del core no se usa: al quedar sus salidas
      -- abiertas, la sintesis elimina PACMAN_VIDEO y sus ROMs.
      O_COLOR_IDX => open,
      O_HCNT      => open,
      O_VCNT      => open,
      O_HBLANK    => open,
      O_VBLANK    => open,
      O_ENA_6     => open,
      O_RGB       => open,
      O_PIX_VALID => open,
      O_SNP_WE    => snp_we,
      O_SNP_XY    => snp_xy,
      O_SNP_A     => snp_a,
      O_SNP_D     => snp_d,
      O_FLIP      => open
      );

  -- ------------------------------------------------------------------
  -- Video: renderizador propio a 27 MHz (ROT90, 720x480, color 7F real)
  -- ------------------------------------------------------------------
  u_video : entity work.pacman_render
    port map (
      clk_core => core_clk25,
      snp_we   => snp_we,
      snp_xy   => snp_xy,
      snp_a    => snp_a,
      snp_d    => snp_d,
      clk_pix  => clk_pix,
      out_r    => vga_r,
      out_g    => vga_g,
      out_b    => vga_b,
      out_hs   => vga_hs,
      out_vs   => vga_vs,
      out_de   => vga_de
      );

  -- ------------------------------------------------------------------
  -- HDMI
  -- ------------------------------------------------------------------
  u_hdmi : entity work.hdmi_module
    port map (
      vga_clk_x5      => clk135,
      vga_clk         => clk_pix,
      rst             => pix_rst,
      vga_red_in      => vga_r,
      vga_green_in    => vga_g,
      vga_blue_in     => vga_b,
      vga_hsync_in    => vga_hs,
      vga_vsync_in    => vga_vs,
      vga_disp_ena_in => vga_de,
      tmds_c0_p_out   => hdmi_tmds_c0_p,
      tmds_c0_n_out   => hdmi_tmds_c0_n,
      tmds_c1_p_out   => hdmi_tmds_c1_p,
      tmds_c1_n_out   => hdmi_tmds_c1_n,
      tmds_c2_p_out   => hdmi_tmds_c2_p,
      tmds_c2_n_out   => hdmi_tmds_c2_n,
      tmds_ck_p_out   => hdmi_tmds_ck_p,
      tmds_ck_n_out   => hdmi_tmds_ck_n
      );

  -- ------------------------------------------------------------------
  -- Audio
  -- ------------------------------------------------------------------
  audio_out_l <= core_audio;
  audio_out_r <= core_audio;

end Behavioral;
