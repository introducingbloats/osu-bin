{
  lib,
  nix-prefetch-scripts,
  writeShellApplication,
  jq,
  coreutils,
  curl,
}:
writeShellApplication {
  name = "osu-bin-update";
  runtimeInputs = [
    jq
    nix-prefetch-scripts
    coreutils
    curl
  ];
  text = ''
    set -euo pipefail

    update_channel() {
      local CHANNEL="$1"
      local TAG_SUFFIX="$2"
      local PRERELEASE="$3"

      echo "=== Updating $CHANNEL channel (tag suffix: $TAG_SUFFIX) ==="

      if [ "$PRERELEASE" = "true" ]; then
        RELEASE=$(curl -sL "https://api.github.com/repos/ppy/osu/releases" | \
          jq -r "[.[] | select(.prerelease == true and (.tag_name | endswith(\"$TAG_SUFFIX\")))][0]")
      else
        RELEASE=$(curl -sL "https://api.github.com/repos/ppy/osu/releases" | \
          jq -r "[.[] | select(.prerelease == false and (.tag_name | endswith(\"$TAG_SUFFIX\")))][0]")
      fi

      TAG=$(echo "$RELEASE" | jq -r '.tag_name')
      VERSION="''${TAG%-"$TAG_SUFFIX"}"
      echo "Latest $CHANNEL version: $VERSION (tag: $TAG)"

      CURRENT_VERSION=$(jq -r ".$CHANNEL.version" version.json)
      echo "Flake $CHANNEL version: $CURRENT_VERSION"
      if [ "$VERSION" = "$CURRENT_VERSION" ]; then
        echo "$CHANNEL version matches, skipping"
        return 0
      fi

      echo "Fetching AppImage and calculating hash"
      APPIMAGE_URL="https://github.com/ppy/osu/releases/download/$TAG/osu.AppImage"
      X64_SHA256=$(nix-prefetch-url "$APPIMAGE_URL")
      X64_HASH=$(nix-hash --to-sri --type sha256 "$X64_SHA256")
      echo "$CHANNEL x86_64-linux hash: $X64_HASH"

      jq --arg channel "$CHANNEL" \
         --arg version "$VERSION" \
         --arg tag "$TAG" \
         --arg hash_linux_x64 "$X64_HASH" \
         '.[$channel].version = $version |
          .[$channel].tag = $tag |
          .[$channel]."hash-linux-x64" = $hash_linux_x64' \
         version.json > version.json.tmp
      mv version.json.tmp version.json
      echo "done updating $CHANNEL"
    }

    update_channel "stable" "lazer" "false"
    update_channel "tachyon" "tachyon" "true"

    echo "All channels updated"
  '';
}
