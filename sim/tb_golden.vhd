--
-- Golden del video: ejecuta el core completo (CPU + video original) y,
-- cada DUMP_EVERY cuadros, vuelca a sim/golden/fNNNN.txt:
--
--   * la memoria de video RECONSTRUIDA SOLO CON EL ESPIA (O_SNP_*), tal
--     como estaba al empezar el cuadro visible:
--       V  <1024 bytes VRAM>      C <1024 bytes color RAM>
--       A  <16 bytes 0x4FF0..>   X <16 bytes 0x5060..>   F <flip>
--   * N <n>: escrituras durante el cuadro visible (si n>0 la imagen puede
--     no corresponder del todo a la instantanea)
--   * I: la imagen nativa 288 x 224 (indice 4A/7F por pixel, 1 hex)
--
-- tools/render_model.py reproduce la imagen desde la instantanea y la
-- compara con I.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity tb_golden is
  generic (
    DUMP_FIRST : integer := 30;
    DUMP_EVERY : integer := 15
  );
end;

architecture sim of tb_golden is

  signal clk27   : std_logic := '1';
  signal reset   : std_logic := '1';
  signal clk     : std_logic;

  signal r, g, b : std_logic_vector(3 downto 0);
  signal hs, vs, au : std_logic;

  signal hcnt, vcnt   : std_logic_vector(8 downto 0);
  signal hbl, vbl, pv : std_logic;
  signal cidx         : std_logic_vector(3 downto 0);

  signal snp_we, snp_xy, flip : std_logic;
  signal snp_a : std_logic_vector(11 downto 0);
  signal snp_d : std_logic_vector(7 downto 0);

  type mem_t is array (natural range <>) of std_logic_vector(7 downto 0);
  type img_t is array (0 to 223, 0 to 287) of std_logic_vector(3 downto 0);

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
      I_SW => (others => '0'), I_BUTTON => (others => '0'),
      O_LED => open, I_RESET => reset, I_CLK_REF => clk27,
      O_CLK_25 => clk,
      O_COLOR_IDX => cidx, O_RGB => open, O_PIX_VALID => pv,
      O_HCNT => hcnt, O_VCNT => vcnt, O_HBLANK => hbl,
      O_VBLANK => vbl, O_ENA_6 => open,
      O_SNP_WE => snp_we, O_SNP_XY => snp_xy, O_SNP_A => snp_a,
      O_SNP_D => snp_d, O_FLIP => flip
      );

  p_run : process
    variable vram, cram, vram0, cram0 : mem_t(0 to 1023) := (others => x"00");
    variable attr, xy, attr0, xy0     : mem_t(0 to 15) := (others => x"00");
    variable flip0    : std_logic := '0';
    variable img      : img_t;
    variable x, y     : integer := 0;
    variable in_line  : boolean := false;
    variable in_frame : boolean := false;
    variable nwr      : integer := 0;
    variable frame    : integer := 0;
    variable a        : integer;
    file f            : text;
    variable l        : line;
    variable fname    : line;

    procedure put_mem (tag : string; m : mem_t) is
    begin
      write(l, tag);
      for i in m'range loop
        write(l, to_hstring(m(i)));
      end loop;
      writeline(f, l);
    end procedure;
  begin
    wait until rising_edge(clk);

    -- espia -> memoria reconstruida
    if snp_we = '1' then
      a := to_integer(unsigned(snp_a));
      if snp_xy = '1' then
        xy(a mod 16) := snp_d;
      elsif a < 16#400# then
        vram(a) := snp_d;
      elsif a < 16#800# then
        cram(a - 16#400#) := snp_d;
      elsif a >= 16#FF0# then
        attr(a - 16#FF0#) := snp_d;
      end if;
      if in_frame then
        nwr := nwr + 1;
      end if;
    end if;

    if pv = '1' then
      if vbl = '1' then
        if in_frame then
          -- fin del cuadro visible
          in_frame := false;
          frame := frame + 1;
          if (frame >= DUMP_FIRST) and ((frame - DUMP_FIRST) mod DUMP_EVERY = 0) then
            deallocate(fname);
            write(fname, string'("sim/golden/f"));
            write(fname, integer'image(10000 + frame)(2 to 5));
            write(fname, string'(".txt"));
            file_open(f, fname.all, write_mode);
            put_mem("V ", vram0);
            put_mem("C ", cram0);
            put_mem("A ", attr0);
            put_mem("X ", xy0);
            write(l, string'("F ") & std_logic'image(flip0)(2));
            writeline(f, l);
            write(l, string'("N ") & integer'image(nwr));
            writeline(f, l);
            for yy in 0 to 223 loop
              write(l, string'("I "));
              for xx in 0 to 287 loop
                write(l, to_hstring(img(yy, xx)));
              end loop;
              writeline(f, l);
            end loop;
            file_close(f);
            report "volcado cuadro " & integer'image(frame) &
                   " (escrituras en el cuadro: " & integer'image(nwr) & ")";
          end if;
        end if;
        x := 0; y := 0; in_line := false;
      elsif hbl = '1' then
        if in_line then
          in_line := false;
          y := y + 1;
          x := 0;
        end if;
      else
        if not in_frame then
          -- primer pixel visible del cuadro: instantanea
          in_frame := true;
          vram0 := vram; cram0 := cram; attr0 := attr; xy0 := xy;
          flip0 := flip;
          nwr := 0;
        end if;
        in_line := true;
        if (x < 288) and (y < 224) then
          img(y, x) := cidx;
        end if;
        x := x + 1;
      end if;
    end if;
  end process;

end sim;
