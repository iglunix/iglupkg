.POSIX:

PREFIX=/usr
DESTDIR=

.PHONY: all install

.DEFAULT: all

install:
	install -Dm755 ./iglu.sh $(DESTDIR)$(PREFIX)/sbin/iglu
	install -Dm755 ./iglupkg.sh $(DESTDIR)$(PREFIX)/bin/iglupkg
