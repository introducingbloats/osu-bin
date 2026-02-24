{
  lib,
  appimageTools,
  fetchurl,
  icu,
  channel ? "stable",
}:
let
  versions = lib.importJSON ./version.json;
  currentVersion = versions.${channel};
  pname = "osu-lazer-bin-${channel}";
in
appimageTools.wrapType2 {
  inherit pname;
  version = currentVersion.version;

  src = fetchurl {
    url = "https://github.com/ppy/osu/releases/download/${currentVersion.tag}/osu.AppImage";
    hash = currentVersion."hash-linux-x64";
  };

  extraPkgs = pkgs: [
    pkgs.icu
  ];

  extraInstallCommands =
    let
      appimageContents = appimageTools.extractType2 {
        inherit (currentVersion) version;
        inherit pname;
        src = fetchurl {
          url = "https://github.com/ppy/osu/releases/download/${currentVersion.tag}/osu.AppImage";
          hash = currentVersion."hash-linux-x64";
        };
      };
    in
    ''
      # Install desktop file and icon if available
      if [ -d "${appimageContents}/usr/share" ]; then
        cp -r ${appimageContents}/usr/share $out/share
      fi
    '';

  meta = {
    description = "A free-to-win rhythm game (AppImage)";
    homepage = "https://osu.ppy.sh";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "osu-lazer-bin-${channel}";
  };
}
