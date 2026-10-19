FROM ubuntu:24.04@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates clang cmake curl git libaom-dev \
    libasound2-dev libayatana-appindicator3-dev libclang-dev libdbus-1-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgtk-3-dev \
    liblzma-dev libopus-dev libpulse-dev libssl-dev libvpx-dev \
    libxcb-randr0-dev libxcb-shape0-dev libxcb-xfixes0-dev libxdo-dev \
    libxfixes-dev libxtst-dev libyuv-dev nasm ninja-build patchelf \
    pkg-config unzip xz-utils && rm -rf /var/lib/apt/lists/*

# Ubuntu's libyuv development package does not provide a pkg-config file.
RUN printf '%s\n' 'prefix=/usr' 'libdir=${prefix}/lib/x86_64-linux-gnu' \
    'includedir=${prefix}/include' 'Name: libyuv' 'Description: YUV conversion' \
    'Version: 0.0' 'Libs: -L${libdir} -lyuv' 'Cflags: -I${includedir}' \
    > /usr/lib/x86_64-linux-gnu/pkgconfig/libyuv.pc

ARG RUST_DIST_SERVER=https://static.rust-lang.org
RUN curl -fsSL --retry 3 ${RUST_DIST_SERVER}/dist/rust-1.75.0-x86_64-unknown-linux-gnu.tar.xz -o /tmp/rust.tar.xz \
    && echo '6bf166ddcad545aa26aa2d12a186454d7697133b52b7fbbd271ce3ee1ecfedc6  /tmp/rust.tar.xz' | sha256sum -c - \
    && tar -xJf /tmp/rust.tar.xz -C /tmp \
    && /tmp/rust-1.75.0-x86_64-unknown-linux-gnu/install.sh --prefix=/opt/rust --without=rust-docs \
    && rm -rf /tmp/rust*

ARG FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
RUN curl -fsSL --retry 3 ${FLUTTER_STORAGE_BASE_URL}/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz -o /tmp/flutter.tar.xz \
    && echo 'a7c82f551a9eae018e078f6bb186171e5a77920d35a3d75a61d9a593d0a9e4ae  /tmp/flutter.tar.xz' | sha256sum -c - \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --system --add safe.directory /opt/flutter \
    && chmod -R a+rwX /opt/flutter

ENV PATH=/opt/rust/bin:/opt/flutter/bin:$PATH \
    CARGO_HOME=/cache/cargo PUB_CACHE=/cache/pub \
    CARGO_INCREMENTAL=0 CARGO_NET_GIT_FETCH_WITH_CLI=true
WORKDIR /workspace
