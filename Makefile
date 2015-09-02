all:	tests

DOWNLOAD=curl -O http://www.zimmers.net/anonftp/pub/cbm/firmware/computers/b/

kernal: cbm-ii-kernal.asm
	bsa -D$(VERSION) $<

verify: kernal
	hexdump -C kernal-by-bsa.bin > kernal-by-bsa.bin.hexdump
	hexdump -C $(ORIG) > $(ORIG).hexdump
	diff kernal-by-bsa.bin.hexdump $(ORIG).hexdump | head -n 20
#	diff kernal-by-bsa.bin.hexdump $(ORIG).hexdump
	rm *.hexdump

k1:	b500-kernal.901244-01.bin
	$(MAKE) VERSION=MAKE_K1    ORIG=$< verify

k3b:	kernal.901244-03b.bin
	$(MAKE) VERSION=MAKE_K3B   ORIG=$< verify

k4a:	kernal.901244-04a.bin
	$(MAKE) VERSION=MAKE_K4A   ORIG=$< verify

k4ao:	kernal.901244-04a.official.bin
	$(MAKE) VERSION=MAKE_K4AO  ORIG=$< verify

k4bo:	kernal.901244-04b.official.bin
	$(MAKE) VERSION=MAKE_K4BO  ORIG=$< verify

tests:	k3b k4a k4ao k4bo
#tests:	k3b k4a k4ao k4bo k1


# Fetch original ROM images
b500-kernal.901244-01.bin:
	$(DOWNLOAD)$@

kernal.901244-03b.bin:
	$(DOWNLOAD)$@

kernal.901244-04a.bin:
	$(DOWNLOAD)$@

kernal.901244-04a.official.bin:
	$(DOWNLOAD)$@

kernal.901244-04b.official.bin:
	$(DOWNLOAD)$@

clean:
	rm -f cbm-ii-kernal.lst bsa.info *.hexdump

# Do not run multiple builds at the same time since this doesn't work
# and wouldn't make any sense if it would.
.NOTPARALLEL:
