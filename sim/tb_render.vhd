--
-- Testbench de pacman_render contra el golden del core.
--
--   1. Lee sim/golden/<DUMP> (memoria espiada + imagen real del core).
--   2. Inyecta toda la memoria por la interfaz espia en el dominio core
--      (una escritura cada ~1,1 us, como la CPU), pasando por el CDC.
--   3. Compara un cuadro HDMI completo pixel a pixel con la imagen del
--      core girada (ROT90) y pasada por la paleta 7F.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity tb_render is
  generic (
    DUMP   : string  := "sim/golden/f0030.txt";
    SXC    : integer := 273;
    SYC    : integer := 31;
    SC_NUM : integer := 6;
    SC_DEN : integer := 5
  );
end;

architecture sim of tb_render is

  constant T_CORE : time := 42.328 ns;
  constant T_PIX  : time := 37.037 ns;

  signal clk_core : std_logic := '1';
  signal clk_pix  : std_logic := '1';

  signal snp_we, snp_xy : std_logic := '0';
  signal snp_a : std_logic_vector(11 downto 0) := (others => '0');
  signal snp_d : std_logic_vector(7 downto 0)  := (others => '0');

  signal o_r, o_g, o_b    : std_logic_vector(7 downto 0);
  signal o_hs, o_vs, o_de : std_logic;

  signal loaded : boolean := false;

  -- referencia independiente del escalado (division exacta)
  constant DW : integer := (224 * SC_NUM + SC_DEN - 1) / SC_DEN;
  constant DH : integer := (288 * SC_NUM + SC_DEN - 1) / SC_DEN;
  constant XO : integer := (720 - DW) / 2;
  constant YO : integer := (480 - DH) / 2;

  type mem_t is array (natural range <>) of std_logic_vector(7 downto 0);
  type img_t is array (0 to 223, 0 to 287) of integer range 0 to 15;
  shared variable img : img_t;

  function hexv (c : character) return integer is
  begin
    case c is
      when '0' to '9' => return character'pos(c) - character'pos('0');
      when 'A' to 'F' => return character'pos(c) - character'pos('A') + 10;
      when 'a' to 'f' => return character'pos(c) - character'pos('a') + 10;
      when others     => return 0;
    end case;
  end function;

  -- paleta 7F real de Pac-Man ya convertida a RGB (resistencias)
  type pal_t is array (0 to 15) of std_logic_vector(23 downto 0);
  constant PAL7F : std_logic_vector(127 downto 0) :=
    x"F6AFAA38C9003F00" & x"6FEAF800EF660700";   -- idx 15..0

  function rgb (i : integer) return std_logic_vector is
    variable c : std_logic_vector(7 downto 0);
    variable r, g, b : integer := 0;
  begin
    c := PAL7F(i * 8 + 7 downto i * 8);
    if c(0) = '1' then r := r + 16#21#; end if;
    if c(1) = '1' then r := r + 16#47#; end if;
    if c(2) = '1' then r := r + 16#97#; end if;
    if c(3) = '1' then g := g + 16#21#; end if;
    if c(4) = '1' then g := g + 16#47#; end if;
    if c(5) = '1' then g := g + 16#97#; end if;
    if c(6) = '1' then b := b + 16#51#; end if;
    if c(7) = '1' then b := b + 16#AE#; end if;
    return std_logic_vector(to_unsigned(r, 8)) & std_logic_vector(to_unsigned(g, 8)) &
           std_logic_vector(to_unsigned(b, 8));
  end function;

begin

  clk_core <= not clk_core after T_CORE / 2;
  clk_pix  <= not clk_pix  after T_PIX / 2;

  dut : entity work.pacman_render
    generic map (SXC => SXC, SYC => SYC, SC_NUM => SC_NUM, SC_DEN => SC_DEN)
    port map (
      clk_core => clk_core, snp_we => snp_we, snp_xy => snp_xy,
      snp_a => snp_a, snp_d => snp_d,
      clk_pix => clk_pix,
      out_r => o_r, out_g => o_g, out_b => o_b,
      out_hs => o_hs, out_vs => o_vs, out_de => o_de
      );

  -- carga del volcado + inyeccion por el espia
  p_load : process
    file f      : text;
    variable l  : line;
    variable c  : character;
    variable tag : character;
    variable y  : integer := 0;
    variable vb : mem_t(0 to 2047);   -- V y C
    variable ab : mem_t(0 to 15);
    variable xb : mem_t(0 to 15);
    variable n  : integer;

    procedure rd_bytes (m : inout mem_t; off : integer; cnt : integer) is
      variable c1, c2 : character;
    begin
      for i in 0 to cnt - 1 loop
        read(l, c1); read(l, c2);
        m(off + i) := std_logic_vector(to_unsigned(hexv(c1) * 16 + hexv(c2), 8));
      end loop;
    end procedure;

    procedure wr (xyf : std_logic; a : integer; d : std_logic_vector(7 downto 0)) is
    begin
      wait until rising_edge(clk_core);
      snp_we <= '1'; snp_xy <= xyf;
      snp_a  <= std_logic_vector(to_unsigned(a, 12));
      snp_d  <= d;
      wait until rising_edge(clk_core);
      snp_we <= '0';
      for k in 1 to 24 loop          -- ~1,1 us entre escrituras
        wait until rising_edge(clk_core);
      end loop;
    end procedure;
  begin
    file_open(f, DUMP, read_mode);
    while not endfile(f) loop
      readline(f, l);
      read(l, tag); read(l, c);
      case tag is
        when 'V' => rd_bytes(vb, 0, 1024);
        when 'C' => rd_bytes(vb, 1024, 1024);
        when 'A' => rd_bytes(ab, 0, 16);
        when 'X' => rd_bytes(xb, 0, 16);
        when 'I' =>
          for x in 0 to 287 loop
            read(l, c);
            img(y, x) := hexv(c);
          end loop;
          y := y + 1;
        when others => null;
      end case;
    end loop;
    file_close(f);

    for i in 0 to 1023 loop
      wr('0', i, vb(i));
      wr('0', 16#400# + i, vb(1024 + i));
    end loop;
    for i in 0 to 15 loop
      wr('0', 16#FF0# + i, ab(i));
      wr('1', i, xb(i));
    end loop;
    report "memoria cargada por el espia";
    loaded <= true;
    wait;
  end process;

  -- comprobacion de un cuadro HDMI completo tras la carga
  p_chk : process
    variable sx, sy   : integer := 0;
    variable prev_de  : std_logic := '0';
    variable prev_vs  : std_logic := '1';
    variable checking : boolean := false;
    variable errs, n_ok : integer := 0;
    variable exp, got : std_logic_vector(23 downto 0);
    variable x, y     : integer;
  begin
    wait until rising_edge(clk_pix);
    if prev_vs = '1' and o_vs = '0' then
      if checking then
        report "RESULTADO " & DUMP & ": correctos = " & integer'image(n_ok) &
               ", errores = " & integer'image(errs);
        std.env.finish;
      end if;
      if loaded then checking := true; end if;
      sy := 0;
    end if;
    prev_vs := o_vs;

    if o_de = '1' then
      if checking then
        got := o_r & o_g & o_b;
        if (sx >= XO) and (sx < XO + DW) and (sy >= YO) and (sy < YO + DH) then
          x   := ((sy - YO) * SC_DEN) / SC_NUM;
          y   := 223 - ((sx - XO) * SC_DEN) / SC_NUM;
          exp := rgb(img(y, x));
        else
          exp := x"000000";
        end if;
        if got = exp then
          n_ok := n_ok + 1;
        else
          if errs < 12 then
            report "ERROR pantalla(" & integer'image(sx) & "," & integer'image(sy) &
                   ") ventana(" & integer'image(sx - XO) & "," & integer'image(sy - YO) & ")" &
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
