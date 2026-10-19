#!/usr/bin/env bash
set -euo pipefail
cd /workspace

printf '%s\n' 'fc50782895f49a1d25bf9439bbc59af116d9ba44f916fcf1d485e8a4873190a2  packaging/linux/bridge-53996e3c.zip' | sha256sum -c -
unzip -oq packaging/linux/bridge-53996e3c.zip
sed -i 's/ffi.NativeFunction<ffi.Bool Function(DartPort/ffi.NativeFunction<ffi.Uint8 Function(DartPort/g' flutter/lib/generated_bridge.dart

flutter config --no-analytics --enable-linux-desktop
git -C /opt/flutter apply /workspace/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff
(cd flutter && flutter pub get --enforce-lockfile)

cargo build --locked --lib --release --features flutter,linux-pkg-config,unix-file-copy-paste
(cd flutter && flutter build linux --release --no-pub)

bundle=dist/lanterndesk-linux-x86_64
mkdir -p dist
rm -rf "$bundle"
cp -a flutter/build/linux/x64/release/bundle "$bundle"

# The system-codec build needs these small libraries beside the Rust library.
for lib in libaom.so.3 libvpx.so.9 libyuv.so.0 libopus.so.0 libxdo.so.3; do
  lib_path=$(ldconfig -p | awk -v name="$lib" '$1 == name && !found { print $NF; found = 1 }')
  [[ -n "$lib_path" ]] || { printf 'Missing runtime library: %s\n' "$lib" >&2; exit 1; }
  cp -L "$lib_path" "$bundle/lib/$lib"
done
patchelf --set-rpath '$ORIGIN' "$bundle/lib/librustdesk.so"
cp LICENCE "$bundle/LICENSE"
mkdir -p "$bundle/licenses"
for package in libaom3 libvpx9 libyuv0 libopus0 libxdo3; do
  cp "/usr/share/doc/$package/copyright" "$bundle/licenses/$package-copyright"
done
printf '%s\n' 'LanternDesk — Ubuntu 24.04+ / Linux x86_64' \
  'Run ./lanterndesk from this directory. Keep the data/ and lib/ folders beside it.' \
  'Runtime packages: libgtk-3-0t64 libasound2t64 libpulse0 libgstreamer-plugins-base1.0-0 libayatana-appindicator3-1' \
  'Wayland screen sharing additionally needs a working xdg-desktop-portal and gstreamer1.0-pipewire.' \
  'Built with software codecs; hardware video acceleration is not enabled in this build.' \
  > "$bundle/README.txt"
if ldd "$bundle/lanterndesk" "$bundle/lib/librustdesk.so" | grep -q 'not found'; then
  printf 'The output has unresolved runtime libraries.\n' >&2
  exit 1
fi
tar -C dist -czf dist/lanterndesk-linux-x86_64.tar.gz lanterndesk-linux-x86_64
(cd dist && sha256sum lanterndesk-linux-x86_64.tar.gz > lanterndesk-linux-x86_64.tar.gz.sha256)
printf 'Built %s\n' /workspace/dist/lanterndesk-linux-x86_64.tar.gz
