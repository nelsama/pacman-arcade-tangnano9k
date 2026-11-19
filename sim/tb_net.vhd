--
-- Simulacion del NETLIST post-PnR (impl/pnr/PACMAN_top.vho) con las
-- primitivas de Gowin. Reconstruye el flujo de bits del canal TMDS 0
-- (azul, lleva HSYNC/VSYNC en el blanking) y cuenta los tokens de control
-- y de datos para comprobar que el hardware sintetizado emite video.
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_net is
end;

architecture sim of tb_net is
  signal clk27 : std_logic := '0';
  signal c0p, c0n, c1p, c1n, c2p, c2n, ckp, ckn : std_logic;
  signal done : boolean := false;
  signal n_ck, n_c1 : integer := 0;
  constant TBIT : real := 37037.0 / 10.0;   -- ps por bit
begin
  clk27 <= not clk27 after 18518 ps;

  dut : entity work.PACMAN_top
    port map (
      CLOCK_27 => clk27,
      btn_credit => '1', btn_reset => '1', btn_start1 => '1',
      joy_down => '1', joy_fire => '1', joy_left => '1', joy_right => '1', joy_up => '1',
      hdmi_tmds_c0_n => c0n, hdmi_tmds_c0_p => c0p,
      hdmi_tmds_c1_n => c1n, hdmi_tmds_c1_p => c1p,
      hdmi_tmds_c2_n => c2n, hdmi_tmds_c2_p => c2p,
      hdmi_tmds_ck_n => ckn, hdmi_tmds_ck_p => ckp,
      audio_out_l => open, audio_out_r => open
      );

  p_trace : process
    variable l : string(1 to 120);
  begin
    wait for 150 us;
    for i in 1 to 120 loop
      wait for 925925 fs;   -- 1/4 de bit
      if c0p = '1' then l(i) := '1'; else l(i) := '0'; end if;
    end loop;
    report "c0p (4 muestras/bit): " & l;
    for i in 1 to 120 loop
      wait for 925925 fs;
      if ckp = '1' then l(i) := '1'; else l(i) := '0'; end if;
    end loop;
    report "ckp (4 muestras/bit): " & l;
    wait;
  end process;

  p_cnt : process(ckp, c1p)
  begin
    if now > 100 us then
      if ckp'event then n_ck <= n_ck + 1; end if;
      if c1p'event then n_c1 <= n_c1 + 1; end if;
    end if;
  end process;

  p_dec : process
    variable t_last : time := 0 ps;
    variable lvl    : std_logic := '0';
    variable bits   : std_logic_vector(0 to 9) := (others => '0');
    variable n, k   : integer;
    variable c_c00, c_c01, c_c10, c_c11, c_tr : integer := 0;
    variable started : boolean := false;
  begin
    wait on c0p for 1 ms;
    if now > 400 us then
      report "tokens canal0 (ventanas de 10 bits deslizantes): " &
             "ctl00=" & integer'image(c_c00) & " ctl01(hs)=" & integer'image(c_c01) &
             " ctl10(vs)=" & integer'image(c_c10) & " ctl11=" & integer'image(c_c11) &
             " transiciones=" & integer'image(c_tr) &
             " flancos ck=" & integer'image(n_ck) & " flancos c1=" & integer'image(n_c1);
      std.env.finish;
    end if;
    if c0p'event and now > 100 us then
      c_tr := c_tr + 1;
      n := integer(real((now - t_last) / 1 ps) / TBIT + 0.5);
      if not started then
        started := true; n := 0;
      end if;
      for i in 1 to n loop
        if i > 400 then exit; end if;
        bits := bits(1 to 9) & lvl;
        -- tokens TMDS se envian LSB primero: q(0) es el primer bit
        if bits = "0010101011" then c_c00 := c_c00 + 1; end if;   -- 1101010100
        if bits = "1101010100" then c_c01 := c_c01 + 1; end if;   -- 0010101011
        if bits = "0010101010" then c_c10 := c_c10 + 1; end if;   -- 0101010100
        if bits = "1101010101" then c_c11 := c_c11 + 1; end if;   -- 1010101011
      end loop;
      lvl := c0p;
      t_last := now;
    end if;
  end process;
end sim;
