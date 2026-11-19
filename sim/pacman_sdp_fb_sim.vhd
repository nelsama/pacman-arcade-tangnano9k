--
-- Modelo de simulacion del IP Gowin Pacman_SDP_FB (RAM_SDP 12288 x 16,
-- read_mode bypass: dout registrado 1 ciclo en clkb).
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity Pacman_SDP_FB is
  port (
    dout   : out std_logic_vector(15 downto 0);
    clka   : in  std_logic;
    cea    : in  std_logic;
    reseta : in  std_logic;
    clkb   : in  std_logic;
    ceb    : in  std_logic;
    resetb : in  std_logic;
    oce    : in  std_logic;
    ada    : in  std_logic_vector(13 downto 0);
    din    : in  std_logic_vector(15 downto 0);
    adb    : in  std_logic_vector(13 downto 0)
  );
end;

architecture sim of Pacman_SDP_FB is
  type mem_t is array (0 to 16383) of std_logic_vector(15 downto 0);
  shared variable mem : mem_t := (others => (others => '0'));
begin
  p_a : process(clka)
  begin
    if rising_edge(clka) then
      if cea = '1' then
        mem(to_integer(unsigned(ada))) := din;
      end if;
    end if;
  end process;

  p_b : process(clkb)
  begin
    if rising_edge(clkb) then
      if ceb = '1' then
        dout <= mem(to_integer(unsigned(adb)));
      end if;
    end if;
  end process;
end sim;
