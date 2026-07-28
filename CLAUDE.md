# displays

GUI output manager for Hyprland (Wails: Go + WebKitGTK). Packaged as a Nix flake.

## Install & Test Policy (strict)

- **Nix flake only.** This app is installed exclusively as a Nix package on a Nix
  system: via this repo's flake (`nix build` / `nix run`) or as the `displays`
  flake input of the NixOS configuration (dotfiles `nixos/flake.nix`).
- **Testing uses the flake-built package.** Run the artifact produced by
  `nix build` / `nix run` — never test through `wails dev`, `go run`, manually
  built binaries, copied artifacts, or any other workaround.
- **No `result` symlinks.** Build with `nix build --no-link --print-out-paths`.

## Release Flow

`task check` (== `nix flake check`) → commit → `task push` (re-checks, pushes
main) → `task nix` (bumps the `displays` flake input in dotfiles, rebuilds the
host). The NixOS config pins a revision of `github:ovitente/displays`, so an
unpushed commit is invisible to the rebuild — `task nix` refuses to run on a
dirty tree or a HEAD that is not `origin/main`.

## Commands

- Full gate: `task check` — package build + Go tests + frontend e2e in chromium
- Build: `nix build --no-link --print-out-paths`
- Run (flake): `nix run .`
- Go tests: `nix-shell --run "go test ./..."`
- Frontend build: `nix-shell --run "npm --prefix frontend run build"`
- E2E: `node tests/run.mjs` (needs frontend/dist built first; Chrome is taken
  from PATH, override with `CHROME=`)

## Notes

- Hyprland 0.55 with Lua config: live changes go through
  `hyprctl eval 'hl.monitor({...})'`, `hyprctl keyword` is rejected.
- `GDK_BACKEND=x11` is forced in `main.go` (WebKitGTK DPR bug on wlroots Wayland).
- Layout geometry is logical pixels (`pixels / scale`) — see adjacency solver
  in `frontend/src/main.js`.
