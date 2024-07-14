.PHONY: all build configure test debug install post-install uninstall
PREFIX ?= /usr
CR_FLAGS ?= -Dstrict_multi_assign -Duse_pcre2 -Dpreview_overload_order

all: .WAIT configure build

build:
	crystal build --release --debug $(CR_FLAGS) -s --link-flags='-Wl,--as-needed' src/main.cr -o bin/batata

configure:
	shards install
	./bin/gi-crystal

test:
	# Some tests need en_US locale to pass on string to float convertions: "1.23" vs "1,23".
	@if [ "$$(uname -s)" == "Darwin" ]; then\
	  LC_ALL=en_US.UTF8 crystal spec $(CR_FLAGS);\
	else\
	  LC_ALL=en_US.UTF8 xvfb-run crystal spec $(CR_FLAGS);\
	fi

debug:
	shards build --debug $(CR_FLAGS) -s --error-trace

install:
	install -D -m 0755 bin/batata $(DESTDIR)$(PREFIX)/bin/batata
	install -D -m 0644 data/batata.desktop $(DESTDIR)$(PREFIX)/share/applications/io.github.hugopl.Batata.desktop
	install -D -m 0644 data/batata.svg $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/io.github.hugopl.Batata.svg
	# Settings schema
	install -D -m644 data/gschema.xml $(DESTDIR)$(PREFIX)/share/glib-2.0/schemas/io.github.hugopl.Batata.gschema.xml
	# Schemes
	install -d $(DESTDIR)$(PREFIX)/share/batata/themes
	install -D -m644 data/themes/*.json $(DESTDIR)$(PREFIX)/share/batata/themes

	# License
	install -D -m0644 LICENSE $(DESTDIR)$(PREFIX)/share/licenses/batata/LICENSE
	# Changelog
	install -D -m0644 CHANGELOG.md $(DESTDIR)$(PREFIX)/share/doc/batata/CHANGELOG.md
	gzip -9fn $(DESTDIR)$(PREFIX)/share/doc/batata/CHANGELOG.md

post-install:
	gtk4-update-icon-cache --ignore-theme-index $(DESTDIR)$(PREFIX)/share/icons/hicolor
	glib-compile-schemas $(DESTDIR)$(PREFIX)/share/glib-2.0/schemas

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/batata
	rm -f $(DESTDIR)$(PREFIX)/share/applications/io.github.hugopl.Batata.desktop
	rm -f $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/io.github.hugopl.Batata.svg
	rm -f $(DESTDIR)$(PREFIX)/share/glib-2.0/schemas/io.github.hugopl.Batata.gschema.xml
	rm -rf $(DESTDIR)$(PREFIX)/share/licenses/batata
	rm -rf $(DESTDIR)$(PREFIX)/share/doc/batata
	rm -rf $(DESTDIR)$(PREFIX)/share/batata

flatpak:
	./bin/create-flatpack-file.cr data/io.github.hugopl.Batata.in.yml > data/io.github.hugopl.Batata.yml
	flatpak-builder --force-clean ./build data/io.github.hugopl.Batata.yml --user --install

