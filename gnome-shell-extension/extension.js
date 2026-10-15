// Batata drop down terminal.
//
// Batata started with `--dropdown` uses the application ID io.github.hugopl.Batata.Dropdown, this extension
// binds a global shortcut (F12 by default) to show/hide that window as a fullscreen Quake style terminal,
// starting Batata if it isn't running yet.
//
// Settings are stored in Batata's own schema, so they are changed in Batata preferences dialog.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const SCHEMA_ID = 'io.github.hugopl.Batata';
const DROPDOWN_APP_ID = 'io.github.hugopl.Batata.Dropdown';
const DROPDOWN_ARGV = ['batata', '--dropdown'];

const ANIMATION_TIME = 150;
// How long to wait for the window to appear after launching Batata, ignoring new shortcut presses meanwhile.
const LAUNCH_TIMEOUT_SECONDS = 10;
// How long to wait for the window to reach the target monitor geometry before showing it anyway.
const PLACE_TIMEOUT_MS = 1000;

export default class BatataExtension extends Extension {
    enable() {
        this._window = null;
        this._hiding = false;
        this._windowSignals = [];
        this._signals = [];
        this._launchTimeoutId = 0;
        this._placeTimeoutId = 0;

        try {
            this._settings = this.getSettings(SCHEMA_ID);
        } catch (e) {
            this._settings = null;
            Main.notifyError('Batata drop down terminal',
                `Batata settings schema not found, is Batata installed? (${e.message})`);
            return;
        }

        Main.wm.addKeybinding('dropdown-shortcut', this._settings,
            Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
            Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
            () => this.toggle());

        this._connect(global.window_manager, 'map', (_wm, actor) => this._onMap(actor));
        this._connect(this._settings, 'changed::dropdown-monitor', () => this._replace());
        this._connect(Main.layoutManager, 'monitors-changed', () => this._replace());

        // The extension is disabled/enabled on screen lock, adopt the drop down terminal if it's already running.
        const win = global.get_window_actors().map(actor => actor.meta_window).find(w => this._isDropdownWindow(w));
        if (win)
            this._track(win);
    }

    disable() {
        if (!this._settings)
            return;

        Main.wm.removeKeybinding('dropdown-shortcut');
        this._signals.forEach(([obj, id]) => obj.disconnect(id));
        this._signals = [];
        this._removeSources();

        if (this._window) {
            // Don't leave the window half way in an animation.
            const actor = this._window.get_compositor_private();
            if (actor) {
                actor.remove_all_transitions();
                actor.translation_y = 0;
                actor.opacity = 255;
            }
            this._untrack();
        }
        this._settings = null;
    }

    toggle() {
        const win = this._window;
        if (!win)
            this._launch();
        else if (this._hiding || win.minimized || !win.has_focus())
            this._show();
        else
            this._hide();
    }

    _connect(obj, signal, callback) {
        this._signals.push([obj, obj.connect(signal, callback)]);
    }

    _removeSources() {
        if (this._launchTimeoutId) {
            GLib.Source.remove(this._launchTimeoutId);
            this._launchTimeoutId = 0;
        }
        if (this._placeTimeoutId) {
            GLib.Source.remove(this._placeTimeoutId);
            this._placeTimeoutId = 0;
        }
    }

    // Main Batata drop down window, i.e. not the about window or other dialogs.
    _isDropdownWindow(win) {
        return win &&
            win.get_wm_class() === DROPDOWN_APP_ID &&
            win.get_window_type() === Meta.WindowType.NORMAL &&
            !win.get_transient_for();
    }

    _launch() {
        if (this._launchTimeoutId)
            return;

        // Launch it using the desktop file when available, so Batata runs on its own systemd scope and not
        // inside GNOME Shell's one.
        const app = Shell.AppSystem.get_default().lookup_app(`${DROPDOWN_APP_ID}.desktop`);
        try {
            if (app) {
                app.launch(0, -1, Shell.AppLaunchGpu.APP_PREF);
            } else {
                const proc = Gio.Subprocess.new(DROPDOWN_ARGV, Gio.SubprocessFlags.NONE);
                proc.wait_check_async(null, (p, res) => {
                    try {
                        p.wait_check_finish(res);
                    } catch (e) {
                        console.warn(`Batata drop down terminal exited with error: ${e.message}`);
                    }
                });
            }
        } catch (e) {
            Main.notifyError('Batata drop down terminal', `Failed to launch Batata: ${e.message}`);
            return;
        }

        this._launchTimeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, LAUNCH_TIMEOUT_SECONDS, () => {
            this._launchTimeoutId = 0;
            return GLib.SOURCE_REMOVE;
        });
    }

    _onMap(actor) {
        const win = actor.meta_window;
        if (this._window || !this._isDropdownWindow(win))
            return;

        if (this._launchTimeoutId) {
            GLib.Source.remove(this._launchTimeoutId);
            this._launchTimeoutId = 0;
        }

        // Replace the default map animation by ours, after the window is in the right place.
        global.window_manager.emit('kill-window-effects', actor);
        actor.opacity = 0;
        this._track(win);
        this._show();
    }

    _track(win) {
        this._window = win;
        this._windowSignals = [
            win.connect('unmanaged', () => this._untrack()),
        ];
    }

    _untrack() {
        if (this._placeTimeoutId) {
            GLib.Source.remove(this._placeTimeoutId);
            this._placeTimeoutId = 0;
        }
        this._windowSignals.forEach(id => this._window.disconnect(id));
        this._windowSignals = [];
        this._window = null;
        this._hiding = false;
    }

    _targetMonitor() {
        const display = global.display;
        const monitor = this._settings.get_string('dropdown-monitor');
        if (monitor === 'pointer')
            return display.get_current_monitor();

        if (monitor !== 'primary') {
            const index = global.backend.get_monitor_manager().get_monitor_for_connector(monitor);
            if (index >= 0)
                return index;
        }
        return display.get_primary_monitor();
    }

    _place() {
        const win = this._window;
        const monitor = this._targetMonitor();

        if (!win.is_on_all_workspaces())
            win.stick();
        if (!win.is_above())
            win.make_above();
        if (win.get_monitor() !== monitor)
            win.move_to_monitor(monitor);
        if (!win.is_fullscreen())
            win.make_fullscreen();

        return global.display.get_monitor_geometry(monitor);
    }

    // Monitor setup or settings changed while the window is visible.
    _replace() {
        if (this._window && !this._window.minimized)
            this._place();
    }

    _show() {
        const win = this._window;
        const actor = win.get_compositor_private();
        if (!actor)
            return;

        if (Main.overview.visible)
            Main.overview.hide();

        // Hidden means minimized or just mapped (opacity set to 0 in _onMap).
        const animate = this._hiding || win.minimized || actor.opacity === 0;
        this._hiding = false;
        actor.remove_all_transitions();
        if (win.minimized) {
            actor.opacity = 0;
            Main.wm.skipNextEffect(actor);
            win.unminimize();
        }

        const target = this._place();
        if (!animate) {
            // Visible but without focus.
            Main.activateWindow(win);
            return;
        }
        // On Wayland moving the window to another monitor may require the client to resize it, so wait for that
        // before sliding it in, otherwise the animation would show the old window geometry.
        this._whenPlaced(target, () => this._slideIn());
    }

    _whenPlaced(target, callback) {
        const win = this._window;
        const isPlaced = () => target.equal(win.get_frame_rect());
        if (isPlaced()) {
            callback();
            return;
        }

        const ids = [];
        const done = () => {
            ids.forEach(id => win.disconnect(id));
            ids.length = 0;
            if (this._placeTimeoutId) {
                GLib.Source.remove(this._placeTimeoutId);
                this._placeTimeoutId = 0;
            }
            if (this._window === win)
                callback();
        };
        const check = () => {
            if (isPlaced())
                done();
        };
        ids.push(win.connect('position-changed', check));
        ids.push(win.connect('size-changed', check));
        ids.push(win.connect('unmanaged', () => {
            ids.forEach(id => win.disconnect(id));
            ids.length = 0;
        }));

        if (this._placeTimeoutId)
            GLib.Source.remove(this._placeTimeoutId);
        this._placeTimeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, PLACE_TIMEOUT_MS, () => {
            this._placeTimeoutId = 0;
            done();
            return GLib.SOURCE_REMOVE;
        });
    }

    _slideIn() {
        const win = this._window;
        const actor = win.get_compositor_private();
        if (!actor)
            return;

        actor.remove_all_transitions();
        actor.get_parent()?.set_child_above_sibling(actor, null);
        // If a hide animation was interrupted, slide in from where it stopped.
        if (actor.opacity === 0)
            actor.translation_y = -actor.height;
        actor.opacity = 255;
        Main.activateWindow(win);

        actor.ease({
            translation_y: 0,
            duration: ANIMATION_TIME,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });
    }

    _hide() {
        const win = this._window;
        const actor = win.get_compositor_private();
        if (!actor)
            return;

        this._hiding = true;
        actor.remove_all_transitions();
        actor.ease({
            translation_y: -actor.height,
            duration: ANIMATION_TIME,
            mode: Clutter.AnimationMode.EASE_IN_QUAD,
            onComplete: () => {
                this._hiding = false;
                Main.wm.skipNextEffect(actor);
                win.minimize();
                actor.translation_y = 0;
            },
        });
    }
}
