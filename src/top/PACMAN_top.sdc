// Restricciones de temporizacion (Gowin) - Pac-Man en Tang Nano 9K
//
//   CLOCK_27   27 MHz      reloj de entrada (pin 52), solo alimenta las rPLL
//   clk_core   23,625 MHz  rPLL clk_pacman (core; ENA_6 = /4)
//   clk_hdmi   135 MHz     rPLL clk_27x5   (TMDS serie = 27 x 5)
//   clk_pix    27 MHz      CLKDIV /5 de clk_hdmi (raster + PCLK de OSER10)
//
// El core usa enables (ENA_6 / ENA_12) sobre clk_core, no relojes
// divididos.

create_clock -name CLOCK_27 -period 37.037 -waveform {0 18.518} [get_ports {CLOCK_27}]

// clk_pacman: CLKOUTD = 27 * 35 / 5 / 8 = 23,625 MHz
//   (IDIV_SEL=4, FBDIV_SEL=34, ODIV_SEL=4 -> VCO 756 MHz, SDIV=8)
create_clock -name clk_core -period 42.328 [get_nets {core_clk25}]

// clk_27x5: 27 MHz * 5 = 135 MHz
create_clock -name clk_hdmi -period 7.407 [get_nets {clk135}]

// CLKDIV /5: 27 MHz de pixel
create_clock -name clk_pix -period 37.037 [get_nets {clk_pix}]

// --- Grupos asincronos -----------------------------------------------------
// clk_core -> clk_pix solo cruza por la BSRAM de doble reloj del
// framebuffer. clk_hdmi -> clk_pix solo dentro de los OSER10 (dedicado).
set_clock_groups -asynchronous -group [get_clocks {CLOCK_27}] -group [get_clocks {clk_core}] -group [get_clocks {clk_hdmi}] -group [get_clocks {clk_pix}]

// Entradas de usuario: sin relacion con ningun reloj (se muestrean).
set_false_path -from [get_ports {joy_up joy_down joy_left joy_right joy_fire}]
set_false_path -from [get_ports {btn_reset btn_start1 btn_credit}]

// --- CPU Z80 (T80): caminos multiciclo -------------------------------------
// Todos los registros del T80 solo cambian con cpu_ena (1 de cada 8 ciclos
// de clk_core) y todo lo que la CPU lee o escribe (RAMs, ROM de programa,
// latch de control, entradas, audio, espia de video) esta habilitado con
// ena_6 (1 de cada 4, y cpu_ena es un subconjunto de ena_6). Por tanto
// cualquier camino que sale de o llega a un registro del T80 dispone de al
// menos 4 ciclos. Sin esto, el analizador exige 1 ciclo (42 ns) a caminos de
// mas de 23 niveles y el resultado depende de la suerte de la colocacion.
// (El comodin * de Gowin no cruza niveles de jerarquia: se listan 2.)
set_multicycle_path -from [get_regs {u_core/u_cpu/* u_core/u_cpu/*/*}] -setup 4
set_multicycle_path -from [get_regs {u_core/u_cpu/* u_core/u_cpu/*/*}] -hold 3
set_multicycle_path -to [get_regs {u_core/u_cpu/* u_core/u_cpu/*/*}] -setup 4
set_multicycle_path -to [get_regs {u_core/u_cpu/* u_core/u_cpu/*/*}] -hold 3
// Banco de registros del Z80 (LUT-RAM, escrito solo con CEN = cpu_ena)
set_multicycle_path -to [get_pins {u_core/u_cpu/u0/Regs/*/*}] -setup 4
set_multicycle_path -to [get_pins {u_core/u_cpu/u0/Regs/*/*}] -hold 3
// ROM de microcodigo inferida (pROM, direccion = IR, que solo cambia con
// cpu_ena): se identifica por el pin de reloj de las celdas del T80.
set_multicycle_path -from [get_pins {u_core/u_cpu/u0/*/CLK}] -setup 4
set_multicycle_path -from [get_pins {u_core/u_cpu/u0/*/CLK}] -hold 3
