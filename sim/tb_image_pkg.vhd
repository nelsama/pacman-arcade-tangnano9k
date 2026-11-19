--
-- Paquete con el almacen de imagen para el testbench.
-- Las variables compartidas necesitan un tipo protegido.

library ieee;
  use ieee.std_logic_1164.all;

package tb_image_pkg is

  constant IMG_W : integer := 256;
  constant IMG_H : integer := 224;

  type image_prot_t is protected
    procedure clear;
    procedure set_pix (x, y : integer; c : integer);
    impure function get_pix (x, y : integer) return integer;
    impure function count_nonzero return integer;
  end protected image_prot_t;

end package;

package body tb_image_pkg is

  type image_prot_t is protected body
    type img_array_t is array (0 to IMG_H * IMG_W - 1) of integer;
    variable img : img_array_t := (others => -1);

    procedure clear is
    begin
      img := (others => -1);
    end procedure;

    procedure set_pix (x, y : integer; c : integer) is
    begin
      if (x >= 0) and (x < IMG_W) and (y >= 0) and (y < IMG_H) then
        img(y * IMG_W + x) := c;
      end if;
    end procedure;

    impure function get_pix (x, y : integer) return integer is
    begin
      if (x >= 0) and (x < IMG_W) and (y >= 0) and (y < IMG_H) then
        return img(y * IMG_W + x);
      end if;
      return -1;
    end function;

    impure function count_nonzero return integer is
      variable n : integer := 0;
    begin
      for i in img'range loop
        if img(i) > 0 then
          n := n + 1;
        end if;
      end loop;
      return n;
    end function;
  end protected body image_prot_t;

end package body;
