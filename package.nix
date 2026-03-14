{
  lib,
  appimageTools,
  fetchurl,
  icu,
  copyDesktopItems,
  makeDesktopItem,
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
      # Install icons from the AppImage
      if [ -d "${appimageContents}/usr/share/icons" ]; then
        mkdir -p $out/share
        cp -r ${appimageContents}/usr/share/icons $out/share/icons
      fi

      # Install a proper desktop file with correct Exec path
      mkdir -p $out/share/applications
      cat > $out/share/applications/osu-lazer.desktop <<EOF
      [Desktop Entry]
      Name=osu!
      Comment=A free-to-win rhythm game
      Exec=$out/bin/${pname} %U
      Icon=osu!
      Type=Application
      Categories=Game;
      StartupWMClass=osu!
      MimeType=application/x-osu-beatmap;application/x-osu-skin;application/x-osu-replay;x-scheme-handler/osu;
      EOF
      sed -i 's/^      //' $out/share/applications/osu-lazer.desktop
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
