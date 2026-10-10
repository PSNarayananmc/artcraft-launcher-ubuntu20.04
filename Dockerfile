# Dockerfile -- Rebuild ArtCraft Launcher 0.1.2 on a real ubuntu:20.04 image (glibc 2.31),
# verify the glibc floor, and package the AppImage.
#
#   docker build -t ac-launcher-2004 .
#   docker run --rm -v "$PWD/out:/out" ac-launcher-2004
#
# Output: /out/artcraft-launcher-0.1.2-ubuntu20.04-x86_64.AppImage (+ .zsync)
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# Build deps from the 20.04 apt repos. The crate is all-pure-Rust (rustls, no openssl),
# but we install libssl-dev and the X11/Wayland/xkb stacks anyway in case features change;
# xvfb + mesa are for the headless smoke test.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential pkg-config curl ca-certificates git file xz-utils libssl-dev \
      libxkbcommon-dev libwayland-dev libx11-dev libxcb1-dev \
      xvfb xauth \
      libgl1-mesa-dri libglx-mesa0 libegl-mesa0 libgl1 libegl1 \
      libx11-6 libxcursor1 libxrandr2 libxi6 libxkbcommon-x11-0 libxkbcommon0 \
      libxcb-render0 libxcb-shape0 libxcb-xfixes0 \
      binutils zsync \
    && rm -rf /var/lib/apt/lists/*

# Rust stable via rustup (rust-version = 1.90, edition 2024)
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH=/root/.cargo/bin:$PATH

WORKDIR /src
# Put the source at /src (git clone in CI, or COPY . . for a vendored tree)
RUN git clone https://github.com/storytold/craft-launcher.git . \
    && git fetch --depth 1 origin tag v0.1.2 && git checkout v0.1.2

# Build exactly what the release CI builds -- but on 20.04, so the glibc floor is 2.31
RUN cargo build --release --locked -p artcraft-launcher

# Verify: newest referenced glibc symbol version must be <= 2.31
RUN echo "== max GLIBC symbol ==" \
    && objdump -T target/release/artcraft-launcher | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1 \
    && ldd target/release/artcraft-launcher | tee /tmp/ldd.txt \
    && ! grep -q "not found" /tmp/ldd.txt

# Headless smoke test: the app must start and keep its event loop alive
# (timeout kills it after 15 s -> exit 124 means "was running")
RUN timeout 15 xvfb-run -a -s "-screen 0 1280x800x24" \
      ./target/release/artcraft-launcher > /tmp/launch.log 2>&1; \
    code=$?; echo "smoke test exit=$code (124 == was alive)"; test "$code" -eq 124

# Package with the repo's own packaging script (downloads appimagetool,
# runs it with APPIMAGE_EXTRACT_AND_RUN=1, writes the .zsync too)
RUN bash packaging/linux/package.sh --formats appimage \
    && cp dist/release/artcraft-launcher-0.1.2-linux-x86_64.AppImage \
          /out/artcraft-launcher-0.1.2-ubuntu20.04-x86_64.AppImage \
    && cp dist/release/artcraft-launcher-0.1.2-linux-x86_64.AppImage.zsync \
          /out/ 2>/dev/null || true \
    && chmod 644 /out/* || true
