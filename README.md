# DISPLAYS

GUI output manager for Hyprland — enable/disable, arrange (drag with forced
edge-to-edge adjacency), and set resolution / refresh rate / scale per monitor.
A Wails (Go + system WebKit) app: lightweight native binary, the UI is plain
HTML/CSS/JS.

![Displays output manager](docs/screenshot.png)

## How it works

- **Read** — `hyprctl monitors all -j` (includes disabled outputs).
- **Arrange** — dragging is free, but on drop the output snaps to the nearest
  gap-free spot: active outputs always form one connected, non-overlapping
  cluster (GNOME model). Geometry uses logical sizes (`pixels / scale`), so
  layouts stay flush for scaled outputs too.
- **Apply (live)** — for each output `hyprctl eval 'hl.monitor({...})'`.
  Takes effect instantly, no reload.
- **Confirm or revert** — an applied layout stays *pending* for 15 seconds:
  a dialog offers Keep / Revert, and if it isn't confirmed (timeout, Esc, or
  closing the window) the previous configuration is restored automatically —
  a layout that blanks the displays can't survive.
- **Persist** — confirming rewrites `~/.config/hypr/monitors.lua`, which
  `hyprland.lua` sources via `dofile()`, so the layout survives reload/reboot.
  Until confirmed, nothing touches disk.

The frontend re-reads state after Apply, so any value Hyprland adjusts
(e.g. an invalid scale snapped to a valid one) is reflected back.

## Build

Nix flake only — the build tags (`desktop`, `production`, `webkit2_41`) and the
WebKitGTK 4.1 / GTK3 runtime are baked into the package.

```sh
nix build --no-link --print-out-paths
```

Binary: `<store-path>/bin/displays`.

## Install (Nix flake)

The repo is a flake exposing `packages.default`. The tags `desktop`,
`production`, `webkit2_41` are baked in — a plain `go build` would drop the
GTK/WebKit backend and yield a headless stub.

Run without installing:

```sh
nix run github:ovitente/displays
```

Imperative install into your profile:

```sh
nix profile install github:ovitente/displays
```

Declarative (NixOS flake): add the input, expose it via an overlay, then install
`pkgs.displays`.

```nix
# flake.nix
inputs.displays = {
  url = "github:ovitente/displays";
  inputs.nixpkgs.follows = "nixpkgs";
};

# overlay
(final: prev: { displays = inputs.displays.packages.${prev.stdenv.hostPlatform.system}.default; })

# module
environment.systemPackages = [ pkgs.displays ];
```

The binary lands on `PATH` as `displays`, so the Hyprland bind is just
`exec, displays` (see below).

## Dev

Rebuild and run the packaged binary after a change:

```sh
nix run .
```

`wails dev` is deliberately not used: it bypasses the packaged build and the
baked-in tags, so what it shows isn't what ships.

## Launch

Bound to `SUPER+SHIFT+D` in the Hyprland config. `Esc` and `Ctrl+Q` close the
window; an unconfirmed layout is reverted first. SIGINT/SIGTERM do the same.
The window is frameless; drag it by the title bar.

UI size: the stylesheet is written in `rem` off a 16px root, and XWayland always
reports `devicePixelRatio = 1`, so the app starts with the root at 1.25× — a
real layout at a larger size, which keeps text crisp and native `<select>`
popups anchored (a CSS zoom does neither). Override with `DISPLAYS_SCALING`
(0.5–3, anything else falls back to the default):

```sh
DISPLAYS_SCALING=1.6 displays
```

## Hyprland integration

The window is frameless and meant to float. Add these rules so it always opens
floating and centered (lua config; XWayland WM_CLASS is `Displays`):

```lua
hl.window_rule({ match = { class = "(?i)displays" }, float = true })
hl.window_rule({ match = { class = "(?i)displays" }, center = true })
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("displays"))
```

Classic `.conf` equivalent:

```conf
windowrule = float, class:(?i)displays
windowrule = center, class:(?i)displays
bind = SUPER SHIFT, D, exec, displays
```

(`displays` on `PATH` assumes the flake install above; otherwise point the bind
at the store path from `nix build`.)

## Notes / gotchas

- **XWayland is forced** (`GDK_BACKEND=x11`, set in `main.go`). Under the native
  Wayland backend, WebKitGTK on wlroots reports `devicePixelRatio = 1/96`, which
  shrinks the entire UI ~96×. XWayland reports the correct DPR.
- **Lua Hyprland (0.55):** `hyprctl keyword` is rejected ("can't work with
  non-legacy parsers"). Live changes use `hyprctl eval 'hl.monitor({...})'`.

## Tests

The package is distributed through the flake, so the gate is a flake check —
nothing gets pushed (and therefore installed) without it:

```sh
task check        # == nix flake check
```

- `checks.package` — builds the package; `buildGoModule` runs `go test` in its
  `checkPhase`, so a red backend test fails the build.
- `checks.e2e` — the suite below in nixpkgs' chromium, sandboxed and hermetic
  (`tests/e2e.nix`). Screenshots land in the derivation output.

`task push` runs the same gate, then pushes `main`; `task nix` bumps the flake
input in the NixOS configuration and rebuilds the host. What no check covers:
the real GTK/WebKit window against a live Hyprland — that stays a manual
`nix run` (and `visual.sh` below).

The individual suites, for iterating locally:

- `node tests/run.mjs` — headless e2e (puppeteer + system Chrome): stubs the Go
  backend, drives the real UI (toggle, mode change, Apply payload, drag with
  snap-on-drop adjacency, confirm/revert countdown, canvas containment),
  screenshots each step to `tests/screenshots/`, checks for console/asset errors.
- `go test ./...` — backend: availableModes parsing, scale formatting, the
  apply/confirm/revert state machine (faked hyprctl, temp $HOME), and a live
  `GetMonitors` against the running Hyprland (skipped without a session).
- `visual.sh` (lives in dotfiles: `.config/hypr/scripts/visual.sh`) — launches the
  built binary in the live Hyprland session and captures the actual WebKit render
  with grim. Run: `visual.sh -o /tmp/shot.png`. This catches WebKit-only bugs the
  headless tests can't (e.g. the devicePixelRatio issue above).
