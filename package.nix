{
  lib,

  writeScriptBin,
  ffmpeg,
  jq,
  makeWrapper,
  ffmpegFromRuntimePath ? false,
}:
assert (!ffmpegFromRuntimePath) -> (ffmpeg != null);
let
  wrapperFlags = [
    "--set-default" "FCS_CONFIG_TEMPLATE_PATH" ./config-template.sh
    "--set-default" "FCS_JQ_PATH" (lib.getExe jq)
  ] ++ (lib.optionals (!ffmpegFromRuntimePath) [
    "--set-default" "FCS_FFMPEG_PATH"  (lib.getExe' ffmpeg "ffmpeg")
    "--set-default" "FCS_FFPROBE_PATH" (lib.getExe' ffmpeg "ffprobe")
  ]);
in
(
  writeScriptBin
  "ffmpeg-chapter-split"
  (builtins.readFile ./ffmpeg-chapter-split.sh)
).overrideAttrs (prev: {
  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    makeWrapper $out/bin/ffmpeg-chapter-split ${lib.escapeShellArgs wrapperFlags}
  '';
})
