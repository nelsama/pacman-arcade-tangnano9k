pal = {0:0x00,1:0x07,2:0x66,3:0xEF,4:0x00,5:0xF8,6:0xEA,7:0x6F,
       8:0x00,9:0x3F,10:0x00,11:0xC9,12:0x38,13:0xAA,14:0xAF,15:0xF6}
names = {0:'negro',1:'azul medio',2:'rosa',3:'amarillo',4:'negro',
         5:'amarillo brillante',6:'naranja/salmon',7:'gris',8:'negro',
         9:'cian',10:'negro',11:'rojo',12:'verde',13:'rosa',14:'rosa claro',15:'beige'}
for k in sorted(pal):
    print('idx %2d  0x%02X  %s' % (k, pal[k], names[k]))
