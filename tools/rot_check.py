# La imagen de origen es 384 x 264 (ancho x alto).
#   fila de origen  iy : 0..263
#   columna origen  ix : 0..383
#
# Tras girar 90 grados, la pantalla es 264 de ancho x 384 de alto.
#   sx (ancho pantalla) : 0..263
#   sy (alto pantalla)  : 0..383
#
# Para que la imagen quede derecha:
#   sy recorre las COLUMNAS del origen  -> ix depende de sy   (0..383)
#   sx recorre las FILAS del origen     -> iy depende de sx   (0..263)
#
# Codigo actual:
#   ix := (SRC_W - 1) - sy;   -> 383 - (0..383) = 383..0    CORRECTO
#   iy := sx;                 -> 0..263                     CORRECTO
#
# Comprobacion de rangos:
print("ix rango:", (384 - 1) - 383, "..", (384 - 1) - 0)
print("iy rango:", 0, "..", 263)
print("direccion max:", 263 * 48 + 383 // 8)
