# Forgotten Client 7.4

A clean 7.4-focused Tibia client built for [Forgotten Engine](https://github.com/podkarpacie/Forgotten-Engine).

Forgotten Client is a modernized fork of **Midgard** ([sp4wna1/Midgard-Client](https://github.com/sp4wna1/Midgard-Client)), itself a fork of edubart's **OTClient**. It keeps OTClient's Lua-modular architecture and classic protocol foundations, rebranded and retargeted for genuine Tibia **7.4** worlds.

## Why this client

- **Native 740 protocol support** — version list starts at 740 (`game.lua`), with dedicated `<= 740` code paths for movement pacing and message rendering.
- **Chat works at 740** — text messages route through the classic message path below 760, unlike OTClientV8 whose mode map is empty below 760.
- **Lua-modular** — every interface module is a separate Lua module (gameserver, creature, mapview, etc.); add mods without touching the engine.
- **MIT licensed** — full rebrand and modification rights (copyright notices retained).

## Compatibility

Forgotten Client talks the classic **740** wire protocol. It pairs with Forgotten Engine's native 740 profile:

- Operator-supplied `Tibia.spr` / `Tibia.dat` go in `data/things/740/` (no redistributed client assets — bring your own lawful files).
- Point the login server at your FE native 740 endpoint (default localhost :7172).
- The legacy login RSA modulus in `modules/gamelib/const.lua` (`FE_RSA`) must match your server's generated private key (`generate-key`).

## Building (Windows)

Prerequisites: Visual Studio 2022 (v143 toolset, Windows SDK 10.0.19041+), and [vcpkg](https://vcpkg.io) with the `x64-windows` triplet installed.

Dependencies (via vcpkg):

```
vcpkg install cryptopp luajit physfs openal-soft openssl zlib glew libogg libvorbis `
  boost-thread boost-chrono boost-date-time boost-filesystem boost-asio boost-system boost-uuid `
  --triplet x64-windows
```

Then open `vc14/forgotten.sln` in Visual Studio and build the `otclient` project (Release / x64). The binary is produced as `ForgottenClient.exe`.

The project was modernized for the current toolchain: Boost 1.92's Asio (`io_context`, `steady_timer`, `results_type`), C++17 (`std::shuffle`, no removed `unary_function`), and OpenSSL 3.

## Running

```
ForgottenClient.exe
```

The client discovers `init.lua` and its modules from the working directory. Default login: `127.0.0.1:7172` protocol 740.

## Credits

- **edubart** — OTClient (MIT)
- **sp4wna1** — Midgard (MIT)
- **Forgotten Engine** — companion 7.4 server

See `LICENSE`, `AUTHORS`, and `BUGS`.