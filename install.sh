#!/usr/bin/env bash
# Installs the emela binary of a GitHub release into the runner's tool cache and adds it to PATH.
set -euo pipefail

repo="emela-lang/emela"

case "$RUNNER_OS/$RUNNER_ARCH" in
  Linux/X64) target="x86_64-unknown-linux-gnu" ;;
  macOS/ARM64) target="aarch64-apple-darwin" ;;
  *)
    echo "::error::emela has no release build for $RUNNER_OS/$RUNNER_ARCH (Linux/X64 and macOS/ARM64 only)"
    exit 1
    ;;
esac

case "$INPUT_VERSION" in
  latest)
    # The redirect of /releases/latest names the tag without using the API's rate limit.
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
      "https://github.com/$repo/releases/latest" | sed -n 's#.*/releases/tag/##p')"
    if [ -z "$tag" ]; then
      echo "::error::no stable emela release found in $repo"
      exit 1
    fi
    ;;
  v*) tag="$INPUT_VERSION" ;;
  *) tag="v$INPUT_VERSION" ;;
esac
version="${tag#v}"

dir="$RUNNER_TOOL_CACHE/emela/$version/$target"
if [ ! -x "$dir/emela" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  url="https://github.com/$repo/releases/download/$tag/emela-$tag-$target.tar.gz"
  if ! curl -fsSL "$url" -o "$tmp/emela.tar.gz"; then
    echo "::error::cannot download $url (is $tag a release of $repo?)"
    exit 1
  fi
  tar -xzf "$tmp/emela.tar.gz" -C "$tmp"
  mkdir -p "$dir"
  cp "$tmp/emela" "$dir/emela"
  chmod +x "$dir/emela"
fi

reported="$("$dir/emela" --version)"
if [ "$reported" != "emela $version" ]; then
  echo "::error::emela --version printed '$reported', expected 'emela $version'"
  exit 1
fi

echo "$dir" >> "$GITHUB_PATH"
echo "version=$version" >> "$GITHUB_OUTPUT"
echo "installed $reported"
