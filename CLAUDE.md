# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Batata is a GNOME tiled terminal emulator written in Crystal, using GTK4 and libadwaita (>= 1.6.0) for the UI and VTE (>= 0.78) for terminal emulation. It supports tiling terminals within tabs, keyboard-driven navigation, and theme integration.

## Build Commands

```sh
make configure   # Install shards + generate GObject bindings (run once after clone)
make build       # Release build
make debug       # Debug build with error tracing
make test        # Run tests (uses xvfb-run on Linux for headless display)
make install     # Install system-wide (desktop file, icons, schemas)
make post-install # Update icon cache and GLib schemas
```

To run a single spec file:
```sh
LC_ALL=en_US.UTF8 xvfb-run crystal spec spec/path/to/file_spec.cr
```

Formatting check (run by CI):
```sh
crystal tool format --check
```

Linter::
```sh
ameba
```

Crystal >= 1.13.3 is required.

## Architecture

The layout engine uses a **binary tree** of nodes to represent the tiled terminal arrangement within each tab:

- `src/desktop/node.cr` / `leaf_node.cr` — tree node types; leaf nodes hold terminals, inner nodes split horizontally or vertically
- `src/desktop/widget.cr` — the main tiling container widget; handles all keyboard actions, node insertion/deletion, and focus management
- `src/desktop/layout.cr` — computes pixel geometry for each node given the container size
- `src/desktop/tab_view.cr` — manages multiple tabs, each containing its own node tree
- `src/desktop/item.cr` — wraps a `Terminal` for use as a tree leaf
- `src/desktop/switcher.cr` — the visual terminal switcher overlay

Application layer:
- `src/main.cr` — `Adw::Application` entry point, registers actions
- `src/application_window.cr` — main `Adw::ApplicationWindow`; wires menus, tabs, and global shortcuts
- `src/terminal.cr` — thin `Vte::Terminal` subclass with Batata-specific configuration
- `src/theme.cr` / `theme_provider.cr` — reads the active GTK theme's colors and applies them to terminals
- `src/settings.cr` — wraps GSettings (`io.github.hugopl.Batata` schema)
- `src/preferences_dialog.cr` — preferences UI

GObject bindings for libadwaita and VTE are auto-generated into `lib/` by `./bin/gi-crystal` and are not edited by hand.

## Key Conventions

- Crystal's built-in `spec` framework is used for tests; specs live in `spec/`.
- `LC_ALL=en_US.UTF8` is required when running specs so string↔float conversions work correctly.
- Ameba is the linter; config is in `.ameba.yml`.
- Application ID: `io.github.hugopl.Batata`
