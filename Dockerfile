# ForgottenClient Linux compile gate (CI) — Ubuntu 24.04 (noble).
# A green `docker build` proves the source compiles clean on a current toolchain.
#
# Notes:
# - System PhysFS (libphysfs-dev, 3.x) replaces the old Mercurial-source build;
#   the icculus hg host is decommissioned and plain-HTTP clones fail.
# - Crypto++ (libcrypto++-dev) is REQUIRED by src/framework/CMakeLists.txt
#   (find_package(cryptopp CONFIG)); the old image never installed it.
# - Stock Lua 5.1 (LUAJIT=OFF default); luaengine ifdefs its LuaJIT-only calls.
# - Boost components required by CMake: system, thread, filesystem.
# - Built binary is /otclient/build/ForgottenClient (CMake project name).

FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        libboost-filesystem-dev \
        libboost-system-dev \
        libboost-thread-dev \
        libcrypto++-dev \
        libglew-dev \
        liblua5.1-dev \
        libopenal-dev \
        libphysfs-dev \
        libssl-dev \
        libvorbis-dev \
        zlib1g-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /otclient
COPY CMakeLists.txt ./
COPY src/ ./src/

RUN cmake -B build -DCMAKE_BUILD_TYPE=Release . && \
    cmake --build build -j"$(nproc)"

# Content so the image carries a complete client tree; the CI gate only needs the build above.
COPY data/ ./data/
COPY mods/ ./mods/
COPY modules/ ./modules/
COPY init.lua ./

CMD ["./build/ForgottenClient"]
