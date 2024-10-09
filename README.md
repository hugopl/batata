<p align="center">
  <img src="./data/batata.svg" width=252 alt="Batata logo" /><br>
</p>

# Batata 🥔

Batata is a Gnome/GTK4 opinionated terminal emulator for people that
need to have several terminals open at the same time and want to easily
navigate between them. Something similar to [Tilix](https://github.com/gnunn1/tilix)/[tmux]()/[Terminator](https://github.com/gnome-terminator/terminator)
but flavored to my taste.

## Demo

Here's an ugly demo where a forget to showcase that it support tabs too!!

[![Batata Terminal demo](https://img.youtube.com/vi/SdpsOAt3JpI/0.jpg)](https://www.youtube.com/watch?v=SdpsOAt3JpI)

# Shortcuts YOU NEED TO KNOW

| Action           | Shorcut                                |
|------------------|----------------------------------------|
| Ctrl+Shift+N     | Spawn a new terminal in current stack. |
| Alt+Shift+Arrows | Move terminal to that direction.       |
| Alt+Arrows       | Focus the terminal that direction.     |
| Ctrl+Shift+X     | Maximize/restore current terminal.     |
| Ctrl+Shift+T     | Spawns a new terminal in a new tab.    |
| Alt+Numbers      | Show tabs 0-9.                         |

# Why this name?

[Lucas Schulze](https://github.com/lucschulze) uses the word "potato" and/or "batata" as values for things when debugging stuff, everyone likes batatas.

# Current Status

As a _eat your own dog food_ enthusiast I currently using it every day, however it still
may eat your terminals.

- [ ] Fix Desktop::Widget known issues.
- [ ] Fancy widget to choose themes.
- [ ] Move widget from one tab to another when move(:left/:right) returns false.
- [ ] Show terminals from all tabs in `Desktop::Switcher` in different columns.

## Things that can be done after a first release

- [ ] Add support for translations.
- [ ] Finish safe-signals patch on GI-Crystal to avoid memory leaks here.

## Installation

### ArchLinux

It's available on AUR.

```
yay -S batata
batata
```

### Flatpak

Not yet on flathub, but you can build and install it doing:

```
make flatpak
flatpak run io.github.hugopl.Batata
```

### From Source

You need the development packages for libadwaita version >= 1.6 and vte4 >= 0.78.

```
make && sudo make install && sudo make post-install
batata
```

## Contributors

- [Hugo Parente Lima](https://github.com/hugopl) - creator and maintainer
