.PHONY: all build configure test debug install install-extension post-install uninstall
PREFIX ?= /usr
EXTENSION_UUID = batata@hugopl.github.io
EXTENSION_FILES = gnome-shell-extension/metadata.json gnome-shell-extension/extension.js
USER_EXTENSION_DIR = $(HOME)/.local/share/gnome-shell/extensions/$(EXTENSION_UUID)
CR_FLAGS ?= -Dstrict_multi_assign -Duse_pcre2 -Dpreview_overload_order

all: .WAIT configure .WAIT build

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
	install -D -m 0644 data/batata-dropdown.desktop $(DESTDIR)$(PREFIX)/share/applications/io.github.hugopl.Batata.Dropdown.desktop
	install -D -m 0644 data/batata.svg $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/io.github.hugopl.Batata.svg
	# Settings schema
	install -D -m644 data/gschema.xml $(DESTDIR)$(PREFIX)/share/glib-2.0/schemas/io.github.hugopl.Batata.gschema.xml
	# Schemes
	install -d $(DESTDIR)$(PREFIX)/share/batata/themes
	install -D -m644 data/themes/*.json $(DESTDIR)$(PREFIX)/share/batata/themes
	# GNOME Shell extension for the drop down terminal
	install -d $(DESTDIR)$(PREFIX)/share/gnome-shell/extensions/$(EXTENSION_UUID)
	install -m644 $(EXTENSION_FILES) $(DESTDIR)$(PREFIX)/share/gnome-shell/extensions/$(EXTENSION_UUID)

	# License
	install -D -m0644 LICENSE $(DESTDIR)$(PREFIX)/share/licenses/batata/LICENSE
	# Changelog
	install -D -m0644 CHANGELOG.md $(DESTDIR)$(PREFIX)/share/doc/batata/CHANGELOG.md
	gzip -9fn $(DESTDIR)$(PREFIX)/share/doc/batata/CHANGELOG.md

# Install the GNOME Shell extension just for the current user, useful during development.
install-extension:
	install -d $(USER_EXTENSION_DIR)/schemas
	install -m644 $(EXTENSION_FILES) $(USER_EXTENSION_DIR)
	install -m644 data/gschema.xml $(USER_EXTENSION_DIR)/schemas/io.github.hugopl.Batata.gschema.xml
	glib-compile-schemas $(USER_EXTENSION_DIR)/schemas

post-install:
	gtk4-update-icon-cache --ignore-theme-index $(DESTDIR)$(PREFIX)/share/icons/hicolor
	glib-compile-schemas $(DESTDIR)$(PREFIX)/share/glib-2.0/schemas

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/batata
	rm -f $(DESTDIR)$(PREFIX)/share/applications/io.github.hugopl.Batata.desktop
	rm -f $(DESTDIR)$(PREFIX)/share/applications/io.github.hugopl.Batata.Dropdown.desktop
	rm -rf $(DESTDIR)$(PREFIX)/share/gnome-shell/extensions/$(EXTENSION_UUID)
	rm -f $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/io.github.hugopl.Batata.svg
	rm -f $(DESTDIR)$(PREFIX)/share/glib-2.0/schemas/io.github.hugopl.Batata.gschema.xml
	rm -rf $(DESTDIR)$(PREFIX)/share/licenses/batata
	rm -rf $(DESTDIR)$(PREFIX)/share/doc/batata
	rm -rf $(DESTDIR)$(PREFIX)/share/batata

flatpak:
	./bin/create-flatpack-file.cr data/io.github.hugopl.Batata.in.yml > data/io.github.hugopl.Batata.yml
	flatpak install flathub org.gnome.Sdk//47
	flatpak-builder --force-clean ./build data/io.github.hugopl.Batata.yml --user --install

