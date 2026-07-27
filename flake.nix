{
  description = "displays — GUI output manager for Hyprland (Wails)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        displays = pkgs.callPackage ./package.nix { };
        default = self.packages.${pkgs.system}.displays;
      });

      # `nix flake check` is the release gate: the package builds (buildGoModule
      # runs the Go tests in its checkPhase) and the UI passes the browser e2e
      # suite. Nothing reaches origin/main without both — see Taskfile.yml.
      checks = forAllSystems (pkgs: {
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.displays;
        e2e = pkgs.callPackage ./tests/e2e.nix {
          inherit (self.packages.${pkgs.stdenv.hostPlatform.system}.displays) frontend;
        };
      });

      # Reuse the existing dev/build environment (nix-shell + wails build).
      devShells = forAllSystems (pkgs: {
        default = import ./shell.nix { inherit pkgs; };
      });
    };
}
