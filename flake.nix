{
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system: 
    let
      pkgs = import nixpkgs { inherit system; };
      inherit (pkgs) lib;
    in
    {
      packages = rec {
        ffmpeg-chapter-split = pkgs.callPackage ./package.nix {};
        default = ffmpeg-chapter-split;
      };
      checks.shellcheck = pkgs.runCommandLocal "do-shellcheck" {} ''
        cd ${./.}
        ${lib.getExe pkgs.shellcheck} \
          --norc \
          --enable=all \
          --shell=bash \
          --exclude=SC2250 \
          ffmpeg-chapter-split.sh config-template.sh
        touch $out
      '';
    }
  );
}
