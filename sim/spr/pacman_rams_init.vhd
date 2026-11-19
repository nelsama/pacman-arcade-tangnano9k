--
-- A simulation model of Pacman hardware
-- Copyright (c) MikeJ - January 2006
--
-- Port a Gowin (Tang Nano 9K): las primitivas Xilinx RAMB16_S9 se
-- sustituyen por memoria inferida con enable. El sintetizador de Gowin
-- coloca cada 1Kx8 en un SDP (la memoria tiene un solo puerto de lectura
-- y uno de escritura compartido, igual que el RAMB16_S9 original).
--
-- Se mantiene la latencia del original: 1 ciclo de reloj desde la
-- direccion hasta O_DATA, con la lectura habilitada solo cuando ENA_6='1'.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

use work.pkg_pacman.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity PACMAN_RAMS is
  port (
    I_AB              : in    std_logic_vector(11 downto 0);
    I_DATA            : in    std_logic_vector( 7 downto 0);
    O_DATA            : out   std_logic_vector( 7 downto 0);
    I_R_W_L           : in    std_logic;
    I_VRAM_L          : in    std_logic;
    ENA_6             : in    std_logic;
    CLK               : in    std_logic
    );
end;

architecture RTL of PACMAN_RAMS is

  type ram_array is array (0 to 1023) of std_logic_vector(7 downto 0);

  impure function load (base : integer) return ram_array is
    file f : text open read_mode is "sim/spr/mem.hex";
    variable l : line;
    variable r : ram_array;
    variable v : std_logic_vector(7 downto 0);
  begin
    for i in 0 to 4095 loop
      readline(f, l);
      hread(l, v);
      if (i >= base) and (i < base + 1024) then
        r(i - base) := v;
      end if;
    end loop;
    return r;
  end function;

  signal ram_v   : ram_array := load(0);
  signal ram_c   : ram_array := load(1024);
  signal ram_w   : ram_array := load(3072);

  signal ram_addr : std_logic_vector(9 downto 0);
  signal dout_v   : std_logic_vector(7 downto 0);
  signal dout_c   : std_logic_vector(7 downto 0);
  signal dout_w   : std_logic_vector(7 downto 0);
  signal cs       : std_logic_vector(3 downto 0);
  signal we_v     : std_logic;
  signal we_c     : std_logic;
  signal we_w     : std_logic;

begin
  ram_addr <= I_AB(9 downto 0);

  -- chip selects: vram / cram / (sin uso) / wram
  p_cs_comb  : process(I_AB, I_VRAM_L)
  begin
    cs <= "1111";
    if (I_VRAM_L = '0') then
      case I_AB(11 downto 10) is
        when "00" => cs <= "1110";
        when "01" => cs <= "1101";
        when "10" => cs <= "1011";
        when "11" => cs <= "0111";
        when others => null;
      end case;
    end if;
  end process;

  p_we_comb  : process(I_R_W_L, cs)
  begin
    we_v <= not cs(0) and not I_R_W_L;
    we_c <= not cs(1) and not I_R_W_L;
    we_w <= not cs(3) and not I_R_W_L;
  end process;

  -- Lectura SIEMPRE registrada: una RAM real entrega el dato de la
  -- direccion presente en cada flanco, no solo cuando llega ENA_6.
  p_ram_v : process
  begin
    wait until rising_edge(CLK);
    if (ENA_6 = '1') then
      if (we_v = '1') then
        ram_v(to_integer(unsigned(ram_addr))) <= I_DATA;
      end if;
      dout_v <= ram_v(to_integer(unsigned(ram_addr)));
    end if;
  end process;

  p_ram_c : process
  begin
    wait until rising_edge(CLK);
    if (ENA_6 = '1') then
      if (we_c = '1') then
        ram_c(to_integer(unsigned(ram_addr))) <= I_DATA;
      end if;
      dout_c <= ram_c(to_integer(unsigned(ram_addr)));
    end if;
  end process;

  p_ram_w : process
  begin
    wait until rising_edge(CLK);
    if (ENA_6 = '1') then
      if (we_w = '1') then
        ram_w(to_integer(unsigned(ram_addr))) <= I_DATA;
      end if;
      dout_w <= ram_w(to_integer(unsigned(ram_addr)));
    end if;
  end process;

  p_mux_comb : process(I_AB, dout_v, dout_c, dout_w)
  begin
    O_DATA <= (others => '0');
    case I_AB(11 downto 10) is
      when "00" => O_DATA <= dout_v;
      when "01" => O_DATA <= dout_c;
      when "10" => O_DATA <= (others => '0');
      when "11" => O_DATA <= dout_w;
      when others => null;
    end case;
  end process;

end architecture RTL;
