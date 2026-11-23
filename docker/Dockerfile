# Toolchain image for superapp: Flutter + Rust + codegen tools, pinned to the
# versions CI uses. Build and run it through scripts/dev.sh.
FROM ubuntu:24.04

# Keep equal to FLUTTER_VERSION in .github/workflows/ci.yml.
ARG FLUTTER_VERSION=3.41.2
# Keep equal to rust/rust-toolchain.toml and the dtolnay/rust-toolchain pin in CI.
ARG RUST_VERSION=1.99.0
ARG CARGO_EXPAND_VERSION=1.0.110
ARG FRB_VERSION=2.13.0

ENV DEBIAN_FRONTEND=noninteractive
# protobuf-compiler on ubuntu-24.04 is 3.21.12, the version scripts/gen_chat_proto.sh pins.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip build-essential pkg-config \
      libssl-dev clang cmake ninja-build protobuf-compiler \
      libglu1-mesa libgtk-3-dev \
    && rm -rf /var/lib/apt/lists/*

# Everything lives under /opt and is world-writable, so the container can run
# as the host user (see scripts/dev.sh) and still write caches.
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/cargo-home \
    PUB_CACHE=/pub-cache \
    FLUTTER_ROOT=/opt/flutter \
    PATH=/pub-cache/bin:/opt/tools/bin:/opt/rustup-bin:/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH

RUN curl -fsSL https://sh.rustup.rs | CARGO_HOME=/opt/rustup-home sh -s -- -y --no-modify-path \
      --profile minimal --default-toolchain ${RUST_VERSION} -c rustfmt \
      -t aarch64-linux-android -t x86_64-linux-android \
    && mkdir -p /opt/rustup-bin && cp /opt/rustup-home/bin/* /opt/rustup-bin/ \
    && cargo install --root /opt/tools --locked cargo-expand --version ${CARGO_EXPAND_VERSION} \
    && cargo install --root /opt/tools --locked flutter_rust_bridge_codegen --version ${FRB_VERSION} \
    && rm -rf /cargo-home /opt/rustup-home

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter \
    && git config --system --add safe.directory '*' \
    && flutter config --no-analytics --no-cli-animations \
    && flutter precache --universal \
    && mkdir -p /cargo-home /pub-cache \
    && chmod -R a+rwX /opt/flutter /opt/rustup /opt/tools /cargo-home /pub-cache

ENV HOME=/tmp/home
WORKDIR /work
