--
-- Testbench minimo del CPU: solo T80sed + ROM de programa.
--
-- Verifica que el Z80 arranca y ejecuta codigo de Pac-Man:
--   * tras el reset, MREQ/RD deben activarse (pide la ROM),
--   * el PC (bus A) debe avanzar y recorrer direcciones de la ROM,
--   * se cuentan los accesos a ROM y las escrituras a RAM.
--
-- Es muy ligero: no incluye video, audio ni el SoC completo.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity tb_cpu is
end;

architecture sim of tb_cpu is

  constant CLK_PERIOD : time := 79.78 ns;

  signal clk     : std_logic := '1';
  signal reset_n : std_logic := '0';

  signal m1_n    : std_logic;
  signal mreq_n  : std_logic;
  signal iorq_n  : std_logic;
  signal rd_n    : std_logic;
  signal wr_n    : std_logic;
  signal rfsh_n  : std_logic;
  signal halt_n  : std_logic;
  signal busak_n : std_logic;
  signal a       : std_logic_vector(15 downto 0);
  signal di      : std_logic_vector(7 downto 0);
  signal do      : std_logic_vector(7 downto 0);

  signal rom_d   : std_logic_vector(7 downto 0);

  signal n_rom    : integer := 0;
  signal n_wr     : integer := 0;
  signal pc_min   : integer := 65535;
  signal pc_max   : integer := 0;
  signal n_clken  : integer := 0;
  signal cpu_ena  : std_logic := '0';

  constant SIM_TIME : time := 2 ms;

begin

  clk <= not clk after CLK_PERIOD / 2;

  p_reset : process
  begin
    reset_n <= '0';
    wait for 2 us;
    reset_n <= '1';
    wait;
  end process;

  -- CLKEN: 1 de cada 2 ciclos, como el diseno real (cpu_ena)
  p_ena : process(clk)
    variable ph : std_logic := '0';
  begin
    if rising_edge(clk) then
      ph      := not ph;
      cpu_ena <= ph;
      if ph = '1' then
        n_clken <= n_clken + 1;
      end if;
    end if;
  end process;

  u_rom : entity work.PACMAN_PROGRAM_ROM
    port map (
      I_ADDR => a(13 downto 0),
      O_DATA => rom_d,
      ENA_6  => '1',
      CLK    => clk
      );

  -- RAM simplificada: el CPU lee la ROM por debajo de 0x4000 y ceros arriba
  di <= rom_d when (a(14) = '0') else (others => '0');

  u_dut : entity work.T80sed
    port map (
      RESET_n => reset_n,
      CLK_n   => clk,
      CLKEN   => cpu_ena,
      WAIT_n  => '1',
      INT_n   => '1',
      NMI_n   => '1',
      BUSRQ_n => '1',
      M1_n    => m1_n,
      MREQ_n  => mreq_n,
      IORQ_n  => iorq_n,
      RD_n    => rd_n,
      WR_n    => wr_n,
      RFSH_n  => rfsh_n,
      HALT_n  => halt_n,
      BUSAK_n => busak_n,
      A       => a,
      DI      => di,
      DO      => do
      );

  p_stat : process(clk)
  begin
    if rising_edge(clk) then
      if (mreq_n = '0') and (rd_n = '0') and (a(14) = '0') then
        n_rom <= n_rom + 1;
      end if;
      if (wr_n = '0') then
        n_wr <= n_wr + 1;
      end if;
      if to_integer(unsigned(a)) < pc_min then
        pc_min <= to_integer(unsigned(a));
      end if;
      if to_integer(unsigned(a)) > pc_max then
        pc_max <= to_integer(unsigned(a));
      end if;
    end if;
  end process;

  p_report : process
  begin
    wait for SIM_TIME;
    report "=== CPU ===";
    report "ciclos con CLKEN          : " & integer'image(n_clken);
    report "accesos a ROM (MREQ+RD)   : " & integer'image(n_rom);
    report "escrituras (WR)           : " & integer'image(n_wr);
    report "direccion minima vista    : 0x" & integer'image(pc_min);
    report "direccion maxima vista    : 0x" & integer'image(pc_max);
    report "HALT_n                    : " & std_logic'image(halt_n);
    wait;
  end process;

end sim;
