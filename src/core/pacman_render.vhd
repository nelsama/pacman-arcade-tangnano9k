--
-- Pac-Man en Tang Nano 9K: renderizador de video en el dominio HDMI.
--
-- Sustituye al framebuffer. En vez de guardar la imagen que genera el
-- core (que no cabe a 4 bpp en la BSRAM), se dibuja directamente ya
-- girada, a 27 MHz, a partir de una copia propia de la memoria de video:
--
--   * El core exporta cada escritura de la CPU (espia O_SNP_*). Aqui se
--     pasan al dominio de pixel (toggle + dato retenido; las escrituras
--     de la CPU distan >= 1 us) y se aplican a:
--        vram  1024 x 8   codigos de tile        (0x4000-0x43FF)
--        cram  1024 x 8   color de tile          (0x4400-0x47FF)
--        attr    16 x 8   codigo/flip/color spr  (0x4FF0-0x4FFF)
--        xy      16 x 8   posicion de sprites    (0x5060-0x506F)
--   * Tiles: se calculan pixel a pixel (VRAM -> ROM 5E -> PROM 4A).
--   * Sprites: durante cada linea HDMI se prepara un buffer de COLUMNA
--     (la linea HDMI siguiente = una columna nativa del core) con los
--     sprites 1..6 (ROM 5F -> PROM 4A); el de numero menor queda encima.
--   * Color final: PROM 7F con las resistencias del original -> RGB 24 bit.
--
-- Coordenadas
--   nativas (las del core): x = pixel en la linea 0..287, y = linea 0..223
--   pantalla 720x480, ROT90:  x = sy - Y_OFF,  y = 223 - (sx - X_OFF)
--
-- La referencia de todas las formulas es tools/render_model.py, que se
-- valida contra la imagen real del core (sim/tb_golden.vhd).
--
-- El bit FLIP (pantalla invertida del modo cocktail) no se aplica: el
-- mueble vertical nunca lo activa.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity pacman_render is
  generic (
    -- Posicion de sprites, medida sobre el core original (tools/spr_fit.py):
    --   x nativa = SXC - X
    --   y nativa = Y - SYC       (sprites 3..6)
    --   y nativa = Y - SYC + 1   (sprites 1 y 2, leidos antes de que avance
    --                             el contador de lineas)
    --   visibles solo en x = SXC-256 .. SXC-1 (buffer de linea de 256)
    --   los sprites 0 y 7 no se dibujan (el hardware solo tiene 6 ranuras)
    SXC    : integer := 273;
    SYC    : integer := 31
  );
  port (
    -- dominio del core
    clk_core : in  std_logic;
    snp_we   : in  std_logic;
    snp_xy   : in  std_logic;
    snp_a    : in  std_logic_vector(11 downto 0);
    snp_d    : in  std_logic_vector(7 downto 0);
    -- dominio de pixel (27 MHz)
    clk_pix  : in  std_logic;
    out_r    : out std_logic_vector(7 downto 0);
    out_g    : out std_logic_vector(7 downto 0);
    out_b    : out std_logic_vector(7 downto 0);
    out_hs   : out std_logic;
    out_vs   : out std_logic;
    out_de   : out std_logic
  );
end;

architecture RTL of pacman_render is

  -- 720x480 @ 60 Hz (CEA-861 formato 2/3)
  constant H_VIS   : integer := 720;
  constant H_FP    : integer := 16;
  constant H_SYNC  : integer := 62;
  constant H_TOTAL : integer := 858;
  constant V_VIS   : integer := 480;
  constant V_FP    : integer := 9;
  constant V_SYNC  : integer := 6;
  constant V_TOTAL : integer := 525;

  constant DST_W   : integer := 224;
  constant DST_H   : integer := 288;
  constant X_OFF   : integer := (H_VIS - DST_W) / 2;   -- 248
  constant Y_OFF   : integer := (V_VIS - DST_H) / 2;   -- 96

  -- ------------------------------------------------------------------
  -- CDC de escrituras
  -- ------------------------------------------------------------------
  signal c_hold   : std_logic_vector(20 downto 0) := (others => '0');  -- xy & a & d
  signal c_tog    : std_logic := '0';
  signal p_tog    : std_logic_vector(2 downto 0) := (others => '0');
  signal ev_we    : std_logic := '0';
  signal ev_xy    : std_logic := '0';
  signal ev_a     : std_logic_vector(11 downto 0) := (others => '0');
  signal ev_d     : std_logic_vector(7 downto 0) := (others => '0');

  attribute syn_preserve : boolean;
  attribute syn_preserve of p_tog : signal is true;

  -- ------------------------------------------------------------------
  -- Memoria de video propia
  -- ------------------------------------------------------------------
  type ram1k_t is array (0 to 1023) of std_logic_vector(7 downto 0);
  type reg16_t is array (0 to 15)   of std_logic_vector(7 downto 0);
  signal vram  : ram1k_t;
  signal cram  : ram1k_t;
  signal attr  : reg16_t := (others => (others => '0'));
  signal xy    : reg16_t := (others => (others => '0'));

  -- ------------------------------------------------------------------
  -- Raster
  -- ------------------------------------------------------------------
  signal h    : integer range 0 to H_TOTAL - 1 := 0;
  signal v    : integer range 0 to V_TOTAL - 1 := 0;

  -- ------------------------------------------------------------------
  -- Tuberia de tiles
  -- ------------------------------------------------------------------
  signal t1_addr : unsigned(9 downto 0) := (others => '0');
  signal t1_xx   : unsigned(2 downto 0) := (others => '0');
  signal t1_yy   : unsigned(2 downto 0) := (others => '0');
  signal t1_y    : unsigned(7 downto 0) := (others => '0');
  signal t1_win, t1_de, t1_hs, t1_vs : std_logic := '0';

  signal vram_q, cram_q : std_logic_vector(7 downto 0) := (others => '0');

  signal t2_xx   : unsigned(2 downto 0) := (others => '0');
  signal t2_yy   : unsigned(2 downto 0) := (others => '0');
  signal t2_y    : unsigned(7 downto 0) := (others => '0');
  signal t2_win, t2_de, t2_hs, t2_vs : std_logic := '0';

  signal rom5e_a : std_logic_vector(11 downto 0);
  signal rom5e_q : std_logic_vector(7 downto 0);

  signal t3_xx   : unsigned(1 downto 0) := (others => '0');
  signal t3_col  : std_logic_vector(4 downto 0) := (others => '0');
  signal t3_win, t3_de, t3_hs, t3_vs : std_logic := '0';

  signal t3_pix  : std_logic_vector(1 downto 0);
  signal lut_t_a : std_logic_vector(7 downto 0);
  signal lut_t_q : std_logic_vector(7 downto 0);

  signal t4_idx  : std_logic_vector(3 downto 0) := (others => '0');
  signal t4_win, t4_de, t4_hs, t4_vs : std_logic := '0';
  signal pal_q   : std_logic_vector(7 downto 0);

  -- ------------------------------------------------------------------
  -- Buffer de columna de sprites: 2 bancos x 256 x 4
  -- ------------------------------------------------------------------
  type sbuf_t is array (0 to 511) of std_logic_vector(3 downto 0);
  signal sbuf     : sbuf_t;
  signal sb_we    : std_logic := '0';
  signal sb_wa    : unsigned(8 downto 0) := (others => '0');
  signal sb_wd    : std_logic_vector(3 downto 0) := (others => '0');
  signal sb_ra    : unsigned(8 downto 0) := (others => '0');
  signal sb_q     : std_logic_vector(3 downto 0) := (others => '0');

  -- constructor de columna
  type bstate_t is (B_IDLE, B_CLEAR, B_SPR);
  signal bst      : bstate_t := B_IDLE;
  signal b_bank   : std_logic := '0';
  signal b_x      : integer range -1024 to 1023 := 0;   -- x nativa a construir
  signal b_cnt    : unsigned(7 downto 0) := (others => '0');
  signal b_s      : integer range 0 to 7 := 7;
  signal b_ly     : integer range 0 to 15 := 0;
  -- etapa de lectura de ROM
  signal b2_val   : std_logic := '0';
  signal b2_y     : unsigned(7 downto 0) := (others => '0');
  signal b2_xx    : unsigned(1 downto 0) := (others => '0');
  signal b2_col   : std_logic_vector(4 downto 0) := (others => '0');
  signal b2_bank  : std_logic := '0';
  signal rom5f_a  : std_logic_vector(11 downto 0) := (others => '0');
  -- etapa 3: alineada con rom5f_q (rom5f_a es registro y la ROM registra
  -- otra vez: el dato llega 2 ciclos despues de B_SPR)
  signal b3_val   : std_logic := '0';
  signal b3_y     : unsigned(7 downto 0) := (others => '0');
  signal b3_xx    : unsigned(1 downto 0) := (others => '0');
  signal b3_col   : std_logic_vector(4 downto 0) := (others => '0');
  signal b3_bank  : std_logic := '0';
  signal rom5f_q  : std_logic_vector(7 downto 0);
  signal lut_s_a  : std_logic_vector(7 downto 0);
  signal lut_s_q  : std_logic_vector(7 downto 0);

  -- ------------------------------------------------------------------
  function pix2 (b : std_logic_vector(7 downto 0); xx : unsigned(1 downto 0))
    return std_logic_vector is
    variable k : integer;
  begin
    k := 3 - to_integer(xx);
    return b(4 + k) & b(k);
  end function;

  -- resistencias del original: 1K / 470 / 220 ohm (rojo, verde) y 470/220 (azul)
  function pal_rgb (c : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable r, g, b : integer;
  begin
    r := 0; g := 0; b := 0;
    if c(0) = '1' then r := r + 16#21#; end if;
    if c(1) = '1' then r := r + 16#47#; end if;
    if c(2) = '1' then r := r + 16#97#; end if;
    if c(3) = '1' then g := g + 16#21#; end if;
    if c(4) = '1' then g := g + 16#47#; end if;
    if c(5) = '1' then g := g + 16#97#; end if;
    if c(6) = '1' then b := b + 16#51#; end if;
    if c(7) = '1' then b := b + 16#AE#; end if;
    return std_logic_vector(to_unsigned(r, 8)) &
           std_logic_vector(to_unsigned(g, 8)) &
           std_logic_vector(to_unsigned(b, 8));
  end function;

begin

  -- ##################################################################
  -- CDC: dominio core
  -- ##################################################################
  -- Solo se reenvian las escrituras que importan al video, y solo si
  -- cambian (un mismo ciclo de escritura de la CPU genera varios pulsos
  -- identicos). Entre dos escrituras distintas pasa >= 1 us, de sobra
  -- para que el dominio de pixel recoja c_hold, que no cambia mientras.
  p_cdc_core : process(clk_core)
    variable nv : std_logic_vector(20 downto 0);
    variable a  : integer;
  begin
    if rising_edge(clk_core) then
      if snp_we = '1' then
        nv := snp_xy & snp_a & snp_d;
        a  := to_integer(unsigned(snp_a));
        if (snp_xy = '1') or (a < 16#800#) or (a >= 16#FF0#) then
          if nv /= c_hold then
            c_hold <= nv;
            c_tog  <= not c_tog;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ##################################################################
  -- CDC: dominio pixel + escritura de la memoria propia
  -- ##################################################################
  p_cdc_pix : process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      p_tog <= p_tog(1 downto 0) & c_tog;
      ev_we <= '0';
      if p_tog(2) /= p_tog(1) then
        ev_we <= '1';
        ev_xy <= c_hold(20);
        ev_a  <= c_hold(19 downto 8);
        ev_d  <= c_hold(7 downto 0);
      end if;
    end if;
  end process;

  p_vram : process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      if (ev_we = '1') and (ev_xy = '0') and (ev_a(11 downto 10) = "00") then
        vram(to_integer(unsigned(ev_a(9 downto 0)))) <= ev_d;
      end if;
      vram_q <= vram(to_integer(t1_addr));
    end if;
  end process;

  p_cram : process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      if (ev_we = '1') and (ev_xy = '0') and (ev_a(11 downto 10) = "01") then
        cram(to_integer(unsigned(ev_a(9 downto 0)))) <= ev_d;
      end if;
      cram_q <= cram(to_integer(t1_addr));
    end if;
  end process;

  p_regs : process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      if ev_we = '1' then
        if ev_xy = '1' then
          xy(to_integer(unsigned(ev_a(3 downto 0)))) <= ev_d;
        elsif ev_a(11 downto 4) = x"FF" then
          attr(to_integer(unsigned(ev_a(3 downto 0)))) <= ev_d;
        end if;
      end if;
    end if;
  end process;

  -- ##################################################################
  -- RASTER
  -- ##################################################################
  p_raster : process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      if h = H_TOTAL - 1 then
        h <= 0;
        if v = V_TOTAL - 1 then
          v <= 0;
        else
          v <= v + 1;
        end if;
      else
        h <= h + 1;
      end if;
    end if;
  end process;

  -- ##################################################################
  -- TILES
  -- ##################################################################
  -- T1: geometria y direccion de VRAM/CRAM (la RAM la registra en el
  --     flanco siguiente y entrega codigo/color durante T2)
  p_t1 : process(clk_pix)
    variable sx, sy, x, y, tc, vr : integer;
    variable de, hs, vs : std_logic;
  begin
    if rising_edge(clk_pix) then
      de := '0'; hs := '1'; vs := '1';
      if (h < H_VIS) and (v < V_VIS) then de := '1'; end if;
      if (h >= H_VIS + H_FP) and (h < H_VIS + H_FP + H_SYNC) then hs := '0'; end if;
      if (v >= V_VIS + V_FP) and (v < V_VIS + V_FP + V_SYNC) then vs := '0'; end if;

      sx := h - X_OFF;
      sy := v - Y_OFF;
      if (sx >= 0) and (sx < DST_W) and (sy >= 0) and (sy < DST_H) then
        x  := sy;
        y  := (DST_W - 1) - sx;
        tc := x / 8;
        vr := y / 8 + 2;
        if tc < 2 then
          t1_addr <= to_unsigned(16#3C0# + tc * 32 + vr, 10);
        elsif tc >= 34 then
          t1_addr <= to_unsigned((tc - 34) * 32 + vr, 10);
        else
          t1_addr <= to_unsigned(vr * 32 + (tc - 2), 10);
        end if;
        t1_xx  <= to_unsigned(x mod 8, 3);
        t1_yy  <= to_unsigned(y mod 8, 3);
        t1_y   <= to_unsigned(y, 8);
        t1_win <= '1';
      else
        t1_win <= '0';
        t1_y   <= (others => '0');
      end if;
      t1_de <= de; t1_hs <= hs; t1_vs <= vs;
    end if;
  end process;

  -- buffer de sprites: la direccion se presenta en T2 (y de T2) y la RAM
  -- entrega el dato registrado durante T3, junto al pixel de tile.
  sb_ra <= (not b_bank) & t2_y;   -- banco que NO se esta construyendo

  -- T2: codigo de tile -> direccion de ROM 5E (dato durante T3)
  rom5e_a <= vram_q & std_logic_vector(not t2_xx(2) & t2_yy);

  u_rom5e : entity work.PACROM_5E
    port map (CLK => clk_pix, ENA => '1', ADDR => rom5e_a, DATA => rom5e_q);

  p_t2 : process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      t2_xx  <= t1_xx;  t2_yy <= t1_yy; t2_y <= t1_y;
      t2_win <= t1_win; t2_de <= t1_de; t2_hs <= t1_hs; t2_vs <= t1_vs;

      t3_xx  <= t2_xx(1 downto 0);
      t3_col <= cram_q(4 downto 0);
      t3_win <= t2_win; t3_de <= t2_de; t3_hs <= t2_hs; t3_vs <= t2_vs;
    end if;
  end process;

  -- T3: pixel de tile + PROM 4A, mezcla con sprite
  t3_pix  <= pix2(rom5e_q, t3_xx);
  lut_t_a <= '0' & t3_col & t3_pix;

  u_lut_t : entity work.PACROM_4A_DST
    port map (ADDR => lut_t_a, DATA => lut_t_q);

  p_t3 : process(clk_pix)
    variable spr : std_logic_vector(3 downto 0);
  begin
    if rising_edge(clk_pix) then
      spr := sb_q;
      if spr /= "0000" then
        t4_idx <= spr;
      else
        t4_idx <= lut_t_q(3 downto 0);
      end if;
      t4_win <= t3_win; t4_de <= t3_de; t4_hs <= t3_hs; t4_vs <= t3_vs;
    end if;
  end process;

  -- T4: paleta y salida
  u_pal : entity work.PACROM_7F_DST
    port map (ADDR => t4_idx, DATA => pal_q);

  p_out : process(clk_pix)
    variable rgb : std_logic_vector(23 downto 0);
  begin
    if rising_edge(clk_pix) then
      rgb := pal_rgb(pal_q);
      out_de <= t4_de;
      out_hs <= t4_hs;
      out_vs <= t4_vs;
      if (t4_de = '1') and (t4_win = '1') then
        out_r <= rgb(23 downto 16);
        out_g <= rgb(15 downto 8);
        out_b <= rgb(7 downto 0);
      else
        out_r <= (others => '0');
        out_g <= (others => '0');
        out_b <= (others => '0');
      end if;
    end if;
  end process;

  -- ##################################################################
  -- BUFFER DE SPRITES
  -- ##################################################################
  p_sbuf : process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      if sb_we = '1' then
        sbuf(to_integer(sb_wa)) <= sb_wd;
      end if;
      sb_q <= sbuf(to_integer(sb_ra));
    end if;
  end process;

  -- ##################################################################
  -- CONSTRUCTOR DE COLUMNA DE SPRITES
  -- ##################################################################
  -- Al empezar cada linea HDMI v se construye la columna de la linea v+1
  -- (x nativa = v + 1 - Y_OFF) en el banco que no se muestra:
  --   B_CLEAR  256 ciclos: banco a 0
  --   B_SPR    sprites 6..1 x 16 filas (el 1 queda encima; 0 y 7 no se
  --            ven en el hardware original);
  --            un pixel por ciclo; 2 ciclos de latencia hasta la escritura.
  p_build : process(clk_pix)
    variable X, Y, lx, ly, ys, sxs : integer;
    variable a0     : std_logic_vector(7 downto 0);
    variable fx, fy : boolean;
    variable lxf, lyf, xb, yb : integer;
    variable hit    : boolean;
  begin
    if rising_edge(clk_pix) then
      sb_we  <= '0';
      b2_val <= '0';

      case bst is
        when B_IDLE =>
          if h = 0 then
            b_bank <= not b_bank;      -- el banco recien construido pasa a mostrarse
            b_x    <= v + 1 - Y_OFF;
            b_cnt  <= (others => '0');
            bst    <= B_CLEAR;
          end if;

        when B_CLEAR =>
          sb_we <= '1';
          sb_wa <= b_bank & b_cnt;
          sb_wd <= "0000";
          b_cnt <= b_cnt + 1;
          if b_cnt = 255 then
            b_s  <= 6;
            b_ly <= 0;
            bst  <= B_SPR;
          end if;

        when B_SPR =>
          X  := to_integer(unsigned(xy(2 * b_s + 1)));
          Y  := to_integer(unsigned(xy(2 * b_s)));
          a0 := attr(2 * b_s);
          fx := a0(0) = '1';
          fy := a0(1) = '1';
          sxs := SXC - X;
          lx := b_x - sxs;
          if (lx < 0) or (lx > 15) then
            lx := lx + 256;            -- copia desplazada 256 (vuelta)
          end if;
          ly := b_ly;
          ys := Y - SYC + ly;
          if b_s <= 2 then
            ys := ys + 1;
          end if;
          hit := (b_x >= SXC - 256) and (b_x < SXC) and (lx >= 0) and (lx <= 15) and
                 (ys >= 0) and (ys < 224);
          if fx then lxf := 15 - lx; else lxf := lx; end if;
          if fy then lyf := 15 - ly; else lyf := ly; end if;
          if hit then
            case lxf / 4 is
              when 0      => xb := 8;
              when 1      => xb := 16;
              when 2      => xb := 24;
              when others => xb := 0;
            end case;
            if lyf < 8 then yb := lyf; else yb := lyf + 24; end if;
            rom5f_a <= a0(7 downto 2) & std_logic_vector(to_unsigned(xb + yb, 6));
            b2_val  <= '1';
            b2_y    <= to_unsigned(ys, 8);
            b2_xx   <= to_unsigned(lxf mod 4, 2);
            b2_col  <= attr(2 * b_s + 1)(4 downto 0);
            b2_bank <= b_bank;
          end if;

          if b_ly = 15 then
            b_ly <= 0;
            if b_s = 1 then
              bst <= B_IDLE;
            else
              b_s <= b_s - 1;
            end if;
          else
            b_ly <= b_ly + 1;
          end if;
      end case;

      -- etapa 2: la ROM 5F registra rom5f_a; las etiquetas esperan un ciclo
      b3_val  <= b2_val;
      b3_y    <= b2_y;
      b3_xx   <= b2_xx;
      b3_col  <= b2_col;
      b3_bank <= b2_bank;

      -- etapa 3: dato de ROM 5F -> PROM 4A -> escritura si no es transparente
      if (b3_val = '1') and (lut_s_q(3 downto 0) /= "0000") then
        sb_we <= '1';
        sb_wa <= b3_bank & b3_y;
        sb_wd <= lut_s_q(3 downto 0);
      end if;
    end if;
  end process;

  u_rom5f : entity work.PACROM_5F
    port map (CLK => clk_pix, ENA => '1', ADDR => rom5f_a, DATA => rom5f_q);

  lut_s_a <= '0' & b3_col & pix2(rom5f_q, b3_xx);

  u_lut_s : entity work.PACROM_4A_DST
    port map (ADDR => lut_s_a, DATA => lut_s_q);

end RTL;
