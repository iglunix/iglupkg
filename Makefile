.POSIX:

PREFIX=/usr
DESTDIR=

.PHONY: all install

.DEFAULT: all

ARCH=x86_64

install:
	install -Dm755 ./iglu.sh $(DESTDIR)$(PREFIX)/sbin/iglu
	install -Dm755 ./iglupkg.sh $(DESTDIR)$(PREFIX)/bin/iglupkg
	install -Dm644 ./mirror.list $(DESTDIR)/etc/mirror.list
