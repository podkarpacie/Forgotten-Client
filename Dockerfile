# ForgottenClient Linux compile gate (CI) — Ubuntu 24.04 (noble).
# A green `docker build` proves the source compiles clean on a current toolchain.
#
# Notes:
# - System PhysFS (libphysfs-dev, 3.x) replaces the old Mercurial-source build;
#   the icculus hg host is decommissioned and plain-HTTP clones fail.
# - Crypto++ (libcrypto++-dev) is REQUIRED by src/framework/CMakeLists.txt
#   (find_package(cryptopp CONFIG)); the old image never installed it.
# - LuaJIT (LUAJIT=ON) matches the shipped build; luainterface.cpp requires
#   <luajit/lua.hpp>, so stock Lua 5.1 headers are insufficient.
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
        libluajit-5.1-dev \
        libopenal-dev \
        libphysfs-dev \
        libssl-dev \
        libvorbis-dev \
        pkg-config \
        zlib1g-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /otclient
COPY CMakeLists.txt ./
COPY src/ ./src/

# LuaJIT headers live in luajit-2.1/; the tree includes them as <luajit/...> and the
# bundled FindLuaJIT.cmake searches a luajit-2.0 suffix — bridge both names.
RUN ln -s luajit-2.1 /usr/include/luajit && ln -s luajit-2.1 /usr/include/luajit-2.0

RUN cmake -B build -DCMAKE_BUILD_TYPE=Release -DLUAJIT=ON -DUSE_STATIC_LIBS=OFF . && \
    cmake --build build -j"$(nproc)"

# Content so the image carries a complete client tree; the CI gate only needs the build above.
COPY data/ ./data/
COPY mods/ ./mods/
COPY modules/ ./modules/
COPY init.lua ./

CMD ["./build/ForgottenClient"]
