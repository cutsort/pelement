SRC = sorttable.js pelement.css
IMAGES = left_arrow_old.png left_arrow.png.xpm right_arrow.png \
	 zoom_huge.png zoom_in_old.png zoom_in.png.xpm zoom_out.png \
	 left_arrow.png right_arrow_old.png right_arrow.png.xpm zoom_huge.png.xpm \
	 zoom_in.png zoom_out_old.png zoom_out.png.xpm


install: $(SRC)
	for I in $(SRC); do ( cp $$I $(INSTALLDIR) ); done
	for I in $(IMAGES); do ( cp $$I $(INSTALLDIR)/images ); done
