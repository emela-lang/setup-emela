#!/usr/bin/env bash
# Installs the emela binary of a GitHub release into the runner's tool cache and adds it to PATH.
# With INPUT_PLAYGROUND=true, also puts the compiler for the browser of the same release
# (emela_playground.js and emela_playground_bg.wasm) into the tool cache.
set -euo pipefail

repo="emela-lang/emela"

case "$RUNNER_OS/$RUNNER_ARCH" in
  Linux/X64) target="x86_64-unknown-linux-gnu" ;;
  macOS/ARM64) target="aarch64-apple-darwin" ;;
  Windows/X64) target="x86_64-pc-windows-msvc" ;;
  *)
    echo "::error::emela has no release build for $RUNNER_OS/$RUNNER_ARCH (Linux/X64, macOS/ARM64 and Windows/X64 only)"
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

# Windows releases (0.28.0 and later) are a zip of emela.exe; the others a tarball of emela.
if [ "$RUNNER_OS" = Windows ]; then
  exe="emela.exe"
  archive="emela-$tag-$target.zip"
else
  exe="emela"
  archive="emela-$tag-$target.tar.gz"
fi

dir="$RUNNER_TOOL_CACHE/emela/$version/$target"
if [ ! -x "$dir/$exe" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  url="https://github.com/$repo/releases/download/$tag/$archive"
  if ! curl -fsSL "$url" -o "$tmp/$archive"; then
    if [ "$RUNNER_OS" = Windows ]; then
      echo "::error::cannot download $url (releases before 0.28.0 have no Windows build)"
    else
      echo "::error::cannot download $url (is $tag a release of $repo?)"
    fi
    exit 1
  fi
  case "$archive" in
    *.zip) unzip -q "$tmp/$archive" -d "$tmp" ;;
    *) tar -xzf "$tmp/$archive" -C "$tmp" ;;
  esac
  mkdir -p "$dir"
  cp "$tmp/$exe" "$dir/$exe"
  chmod +x "$dir/$exe"
fi

# A release may add `+<commit>` after the version.
reported="$("$dir/$exe" --version | tr -d '\r')"
if [ "${reported%%+*}" != "emela $version" ]; then
  echo "::error::emela --version printed '$reported', expected 'emela $version' (with an optional +<commit>)"
  exit 1
fi

# GITHUB_PATH takes a path of the runner's OS (C:\... on Windows).
if command -v cygpath >/dev/null; then
  cygpath -w "$dir" >> "$GITHUB_PATH"
else
  echo "$dir" >> "$GITHUB_PATH"
fi
echo "version=$version" >> "$GITHUB_OUTPUT"
echo "installed $reported"

if [ "${INPUT_PLAYGROUND:-false}" = true ]; then
  # The same files on every runner, so they are cached by version only.
  playground="$RUNNER_TOOL_CACHE/emela/$version/playground"
  if [ ! -f "$playground/emela_playground_bg.wasm" ]; then
    ptmp="$(mktemp -d)"
    trap 'rm -rf "${tmp:-}" "$ptmp"' EXIT
    url="https://github.com/$repo/releases/download/$tag/emela-playground-$tag.tar.gz"
    if ! curl -fsSL "$url" -o "$ptmp/playground.tar.gz"; then
      echo "::error::cannot download $url (releases before 0.28.0 have no playground compiler)"
      exit 1
    fi
    tar -xzf "$ptmp/playground.tar.gz" -C "$ptmp"
    mkdir -p "$playground"
    cp "$ptmp/emela_playground.js" "$ptmp/emela_playground_bg.wasm" "$playground/"
  fi
  echo "playground=$playground" >> "$GITHUB_OUTPUT"
  echo "installed the playground compiler in $playground"
fi
