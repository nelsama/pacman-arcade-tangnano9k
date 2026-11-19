-- CPU inerte para la prueba de sprites: no hace ningun acceso al bus,
-- asi la memoria de video precargada no cambia.
library ieee;
  use ieee.std_logic_1164.all;
entity T80sed is
  port(
    RESET_n : in  std_logic; CLK_n : in std_logic; CLKEN : in std_logic;
    WAIT_n  : in  std_logic; INT_n : in std_logic; NMI_n : in std_logic;
    BUSRQ_n : in  std_logic;
    M1_n, MREQ_n, IORQ_n, RD_n, WR_n, RFSH_n, HALT_n, BUSAK_n : out std_logic;
    A  : out std_logic_vector(15 downto 0);
    DI : in  std_logic_vector(7 downto 0);
    DO : out std_logic_vector(7 downto 0));
end;
architecture stub of T80sed is
begin
  M1_n <= '1'; MREQ_n <= '1'; IORQ_n <= '1'; RD_n <= '1'; WR_n <= '1';
  RFSH_n <= '1'; HALT_n <= '1'; BUSAK_n <= '1';
  A <= (others => '0'); DO <= (others => '0');
end;
