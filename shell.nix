{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  packages = [
    (import ./default.nix { inherit pkgs; })
    pkgs.direnv
  ];
}
