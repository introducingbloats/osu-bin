{
  lib,
  writeShellApplication,
  jq,
  coreutils,
  curl,
}:
writeShellApplication {
  name = "osu-bin-update";
  runtimeInputs = [
    jq
    coreutils
    curl
  ];
    text = ''
    set -euo pipefail

    CURL_OPTS=()
    if [[ -n "''${GITHUB_TOKEN:-}" ]]; then
      CURL_OPTS=( -H "Authorization: Bearer ''${GITHUB_TOKEN}" )
    fi

    github_curl() {
      local url=$1
      local tmp
      local status

      tmp="$(mktemp)"
      status="$(curl -sS -L "''${CURL_OPTS[@]}" -o "$tmp" -w "%{http_code}" "$url" || echo "__CURL_FAILED__")"

      if [ "$status" = "__CURL_FAILED__" ]; then
        echo "Error: failed to execute curl request: $url" >&2
        rm -f "$tmp"
        exit 1
      fi

      if [ "$status" != "200" ]; then
        echo "Error: GitHub API returned HTTP $status for $url" >&2
        echo "Response body:" >&2
        cat "$tmp" >&2 || true
        rm -f "$tmp"
        exit 1
      fi

      cat "$tmp"
      rm -f "$tmp"
    }

    update_channel() {
      local CHANNEL="$1"
      local TAG_SUFFIX="$2"
      local PRERELEASE="$3"

      echo "=== Updating $CHANNEL channel (tag suffix: $TAG_SUFFIX) ==="

      if [ "$PRERELEASE" = "true" ]; then
        RELEASE=$(github_curl "https://api.github.com/repos/ppy/osu/releases" | \
          jq -re "[.[] | select(.prerelease == true and (.tag_name | endswith(\"$TAG_SUFFIX\")))[0]]")
      else
        RELEASE=$(github_curl "https://api.github.com/repos/ppy/osu/releases" | \
          jq -re "[.[] | select(.prerelease == false and (.tag_name | endswith(\"$TAG_SUFFIX\")))[0]]")
      fi

      TAG=$(echo "$RELEASE" | jq -re '.tag_name')
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
      X64_HASH=$(nix store prefetch-file --json "$APPIMAGE_URL" | jq -r '.hash')
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
