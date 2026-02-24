{
  outputs =
    {
      self,
      ...
    }@inputs:
    let
      lib-nixpkgs = inputs.introducingbloats.lib.nixpkgs inputs;
    in
    {
      packages = lib-nixpkgs.forSystems lib-nixpkgs.linuxOnly (
        { pkgs, ... }:
        let
          mkOsu = channel: pkgs.callPackage ./package.nix { inherit channel; };
          stable = mkOsu "stable";
          tachyon = mkOsu "tachyon";
        in
        {
          default = stable;
          osu-lazer-bin-stable = stable;
          osu-lazer-bin-tachyon = tachyon;
          updateScript = pkgs.callPackage ./update.nix { };
        }
      );
    };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
    introducingbloats.url = "github:introducingbloats/core.flakes/main";
  };
}
