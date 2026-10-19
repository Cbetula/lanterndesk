#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == --help ]]; then
  printf '%s\n' 'Build LanternDesk for this Mac (Apple Silicon or Intel).' \
    'Requires full Xcode, rustup, and Homebrew packages: cmake pkg-config cocoapods autoconf automake libtool.' \
    'Usage: ./scripts/build-macos.sh' \
    'Output: dist/lanterndesk-macos-<arm64|x86_64>.dmg and .sha256' \
    'Optional: LANTERNDESK_MACOS_CACHE, FLUTTER_STORAGE_BASE_URL, CARGO_BUILD_JOBS.'
  exit 0
fi
[[ $# == 0 ]] || { printf 'Unknown argument; see --help.\n' >&2; exit 1; }
[[ $(uname -s) == Darwin ]] || { printf 'macOS with full Xcode is required; Linux cannot run this build.\n' >&2; exit 1; }

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cache_dir=${LANTERNDESK_MACOS_CACHE:-"$HOME/Library/Caches/lanterndesk-macos"}
case $(uname -m) in
  arm64)
    arch=arm64; triplet=arm64-osx
    flutter_archive=flutter_macos_arm64_3.24.5-stable.zip
    flutter_sha=ca9624a6de7a1a8962f2f0a3e2a57b16434ca34f1137b8d9dc68c5ca1f187133
    ;;
  x86_64)
    arch=x86_64; triplet=x64-osx
    flutter_archive=flutter_macos_3.24.5-stable.zip
    flutter_sha=30f337aeb2f7a0d324cfae9a3718c1caa8a5abcb19eff933b337332465f9cfe8
    ;;
  *) printf 'Unsupported Mac architecture.\n' >&2; exit 1 ;;
esac
for tool in xcodebuild rustup cmake pkg-config pod autoconf automake libtool rsync; do
  command -v "$tool" >/dev/null || { printf 'Missing prerequisite: %s (see packaging/macos/README.md)\n' "$tool" >&2; exit 1; }
done
xcodebuild -version
export LIBCLANG_PATH="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib"
[[ -f $LIBCLANG_PATH/libclang.dylib ]] || { printf 'Select a full Xcode installation with xcode-select.\n' >&2; exit 1; }
export MACOSX_DEPLOYMENT_TARGET=13.0
export CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS:-3}
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export COCOAPODS_DISABLE_STATS=true
export VCPKG_MAX_CONCURRENCY=$CARGO_BUILD_JOBS

mkdir -p "$cache_dir/downloads" "$cache_dir/sdk-$arch"
if [[ ! -x $cache_dir/sdk-$arch/flutter/bin/flutter ]]; then
  curl -fL --retry 3 "${FLUTTER_STORAGE_BASE_URL:-https://storage.googleapis.com}/flutter_infra_release/releases/stable/macos/$flutter_archive" -o "$cache_dir/downloads/$flutter_archive"
  printf '%s  %s\n' "$flutter_sha" "$cache_dir/downloads/$flutter_archive" | shasum -a 256 -c -
  unzip -q "$cache_dir/downloads/$flutter_archive" -d "$cache_dir/sdk-$arch"
  rm "$cache_dir/downloads/$flutter_archive"
fi
export PATH="$cache_dir/sdk-$arch/flutter/bin:$PATH"
flutter_root="$cache_dir/sdk-$arch/flutter"
if git -C "$flutter_root" apply --check "$repo_dir/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"; then
  git -C "$flutter_root" apply "$repo_dir/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"
else
  git -C "$flutter_root" apply --reverse --check "$repo_dir/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"
fi
# Same macOS frame-scheduling workaround as the upstream Flutter workflow.
perl -pi -e 's/^([ \t]*)_setFramesEnabledState\(false\);/$1\/\/_setFramesEnabledState(false);/' "$flutter_root/packages/flutter/lib/src/scheduler/binding.dart"
flutter config --no-analytics --enable-macos-desktop
rustup toolchain install 1.81.0 --profile minimal

# The upstream AOM port requires NASM even on arm64; build it natively to avoid Rosetta.
if [[ ! -x $cache_dir/nasm-2.16.03/nasm ]]; then
  curl -fL --retry 3 https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/nasm-2.16.03.tar.xz -o "$cache_dir/downloads/nasm.tar.xz"
  printf '%s  %s\n' 1412a1c760bbd05db026b6c0d1657affd6631cd0a63cddb6f73cc6d4aa616148 "$cache_dir/downloads/nasm.tar.xz" | shasum -a 256 -c -
  tar -xJf "$cache_dir/downloads/nasm.tar.xz" -C "$cache_dir"
  (cd "$cache_dir/nasm-2.16.03" && ./configure && make -j "$CARGO_BUILD_JOBS")
fi
export PATH="$cache_dir/nasm-2.16.03:$PATH"

export VCPKG_ROOT="$cache_dir/vcpkg"
vcpkg_commit=9e593bb18ea69cc5095e012465dcd675a822ed0d
if [[ ! -d $VCPKG_ROOT/.git ]]; then
  git init "$VCPKG_ROOT"
  git -C "$VCPKG_ROOT" remote add origin https://github.com/microsoft/vcpkg.git
  git -C "$VCPKG_ROOT" fetch --depth 1 origin "$vcpkg_commit"
  git -C "$VCPKG_ROOT" checkout --detach FETCH_HEAD
fi
[[ $(git -C "$VCPKG_ROOT" rev-parse HEAD) == "$vcpkg_commit" ]] || { printf 'Unexpected vcpkg checkout in cache.\n' >&2; exit 1; }
if [[ ! -x $VCPKG_ROOT/vcpkg ]]; then "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics; fi
"$VCPKG_ROOT/vcpkg" install --classic --clean-after-build --triplet "$triplet" \
  --overlay-ports="$repo_dir/res/vcpkg" libvpx libyuv opus aom libjpeg-turbo

git -C "$repo_dir" submodule update --init --recursive
work_dir="$cache_dir/work-$arch"
mkdir -p "$work_dir"
# Build a private copy so neither the source locks nor the user's Flutter SDK change.
rsync -a --delete --exclude=.git --exclude=/target --exclude=/dist \
  --exclude=/flutter/build --exclude=/flutter/.dart_tool --exclude=/flutter/.pub-cache \
  --exclude=/flutter/macos/Flutter/ephemeral --exclude=/flutter/macos/Pods \
  "$repo_dir/" "$work_dir/"
cd "$work_dir"
printf '%s\n' 'fc50782895f49a1d25bf9439bbc59af116d9ba44f916fcf1d485e8a4873190a2  packaging/linux/bridge-53996e3c.zip' | shasum -a 256 -c -
unzip -oq packaging/linux/bridge-53996e3c.zip
perl -pi -e 's/ffi.NativeFunction<ffi.Bool Function\(DartPort/ffi.NativeFunction<ffi.Uint8 Function(DartPort/g' flutter/lib/generated_bridge.dart
cp packaging/linux/pubspec.lock flutter/pubspec.lock
(cd flutter && flutter pub get --enforce-lockfile)
rustup run 1.81.0 cargo build --locked --release --lib --bin service --features flutter,unix-file-copy-paste,screencapturekit
cp target/release/liblibrustdesk.dylib target/release/librustdesk.dylib
(cd flutter && FLUTTER_XCODE_ARCHS="$arch" FLUTTER_XCODE_ONLY_ACTIVE_ARCH=YES flutter build macos --release --no-pub)

app="$work_dir/flutter/build/macos/Build/Products/Release/LanternDesk.app"
cp target/release/service "$app/Contents/MacOS/service"
cp LICENCE "$app/Contents/Resources/LICENSE"
mkdir -p "$app/Contents/Resources/licenses"
for package in aom libvpx libyuv opus libjpeg-turbo; do
  cp "$VCPKG_ROOT/installed/$triplet/share/$package/copyright" "$app/Contents/Resources/licenses/$package-copyright"
done
bash .github/scripts/sign-macos-app.sh "$app" - flutter/macos/Runner/Release.entitlements
[[ $(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist") == io.github.cbetula.lanterndesk ]]
[[ $("$app/Contents/MacOS/LanternDesk" --version) == 1.5.1 ]]
lipo "$app/Contents/MacOS/LanternDesk" -verify_arch "$arch"
lipo "$app/Contents/MacOS/service" -verify_arch "$arch"

mkdir -p "$repo_dir/dist"
stage_dir=$(mktemp -d "$cache_dir/dmg-$arch.XXXXXX")
ditto "$app" "$stage_dir/LanternDesk.app"
ln -s /Applications "$stage_dir/Applications"
cp packaging/macos/INSTALL_ZH.txt "$stage_dir/安装说明.txt"
dmg="lanterndesk-macos-$arch.dmg"
hdiutil create -ov -volname LanternDesk -srcfolder "$stage_dir" -format UDZO "$repo_dir/dist/$dmg"
hdiutil verify "$repo_dir/dist/$dmg"
(cd "$repo_dir/dist" && shasum -a 256 "$dmg" > "$dmg.sha256")
printf '\nBuilt %s\n' "$repo_dir/dist/$dmg"
