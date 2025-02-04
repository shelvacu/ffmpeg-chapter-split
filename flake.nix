{
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system: 
    let
      pkgs = import nixpkgs { inherit system; };
      inherit (pkgs) lib;
    in
    {
      packages.ffmpeg-split-script = pkgs.resholve.writeScriptBin "ffmpeg-split-script" {
        interpreter = lib.getExe pkgs.bash;
        inputs = [
          pkgs.ffmpeg
          pkgs.jq
        ];
      } (builtins.readFile ./ffmpeg-chapter-split.sh);
      checks.shellcheck = pkgs.runCommandLocal "do-shellcheck" {} ''
        ${lib.getExe pkgs.shellcheck} \
          --norc \
          --enable=add-default-case,avoid-nullary-conditions,check-extra-masked-returns,check-set-e-suppressed,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets \
          --shell=bash \
          ${./ffmpeg-chapter-split.sh}
        touch $out
      '';
    }
  );
}
