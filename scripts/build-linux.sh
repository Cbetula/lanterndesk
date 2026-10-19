#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cache_dir=${LANTERNDESK_BUILD_CACHE:-"${XDG_CACHE_HOME:-$HOME/.cache}/lanterndesk-build"}
image=lanterndesk-builder:ubuntu24.04-flutter3.24.5-rust1.75

if [[ $(uname -m) != x86_64 ]]; then
  printf 'This build currently supports Linux x86_64 only.\n' >&2
  exit 1
fi
command -v docker >/dev/null || { printf 'Install Docker Engine first.\n' >&2; exit 1; }
docker info >/dev/null
git -C "$repo_dir" submodule update --init --recursive
mkdir -p "$cache_dir/cargo" "$cache_dir/pub" "$cache_dir/home"

docker build --network host --tag "$image" \
  --build-arg HTTP_PROXY --build-arg HTTPS_PROXY --build-arg ALL_PROXY --build-arg NO_PROXY \
  --build-arg http_proxy --build-arg https_proxy --build-arg all_proxy --build-arg no_proxy \
  --build-arg RUST_DIST_SERVER="${RUST_DIST_SERVER:-https://static.rust-lang.org}" \
  --build-arg FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.googleapis.com}" \
  "$repo_dir/packaging/linux"
docker run --rm --network host --user "$(id -u):$(id -g)" \
  --env HOME=/cache/home --env CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-8}" \
  --env HTTP_PROXY --env HTTPS_PROXY --env ALL_PROXY --env NO_PROXY \
  --env http_proxy --env https_proxy --env all_proxy --env no_proxy \
  --env FLUTTER_STORAGE_BASE_URL --env PUB_HOSTED_URL \
  --volume "$repo_dir:/workspace" --volume "$cache_dir:/cache" \
  --volume "$repo_dir/packaging/linux/pubspec.lock:/workspace/flutter/pubspec.lock:ro" \
  "$image" bash scripts/build-linux-container.sh
