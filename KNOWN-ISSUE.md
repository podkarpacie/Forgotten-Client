# KNOWN ISSUE: startup crash (v7.4.0 build) — FOR AI ANALYSIS

## Symptom
Tibia.exe (built from this exact source with VS2022 v143) aborts during startup:
- Exit code `0xC0000409` (fail-fast / abort) in `ucrtbase.dll`
- Happens **after** graphics init (GPU/OpenGL logger line prints) and **after**
  `g_resources.discoverWorkDir("init.lua")` succeeds, **inside or before the first
  C++ function called from Lua** (`g_logger.info(...)` at the top of `init.lua`)
- No logger output beyond the GPU line; crash kills buffered output
- Even a minimal `init.lua` containing only `g_logger.info("A")` crashes

## Ruled out
| Hypothesis | Evidence |
|---|---|
| LuaJIT rolling-2026 incompatibility | Replaced headers + import lib + dll with a fresh **LuaJIT 2.0** build (`v2.0` branch, `msvcbuild.bat dll`) — identical crash |
| JIT compiler frames | `luaJIT_setmode(L, 0, LUAJIT_MODE_ENGINE | LUAJIT_MODE_OFF)` at state creation — identical crash |
| Link-time code generation miscompile | Disabled WholeProgramOptimization + LTCG — identical crash |
| Release asserts | `NDEBUG` defined; earlier Debug-style assert was `assert(funcPtr)` in `luainterface.cpp` `luaCppFunctionCallback` |

## What we observed with instrumentation
- A diagnostic in `luaCppFunctionCallback` (`src/framework/luaengine/luainterface.cpp`)
  once logged a **null `funcPtr`** (upvalue userdata NULL) — i.e. the C closure was
  invoked **without its upvalue userdata** — when called from `g_logger.info`.
- After making the callback null-tolerant (return 0), the crash **moved**: still
  `0xC0000409`, but the null branch is not reached — suggesting a second corruption
  site, or corruption occurring before the call (e.g., during binding registration
  or GC).
- Debugging breadcrumb `nullfuncptr.log` / `[startup]` lines in
  `main.cpp` + `modulemanager.cpp` are intentionally left in the source.

## Key code paths
- `src/framework/luaengine/luainterface.cpp` — `pushCppFunction`: placement-`new`
  `LuaCppFunctionPtr` into `lua_newuserdata`, attaches `__gc` metatable table, then
  `lua_pushcclosure(L, luaCppFunctionCallback, 1)` with the userdata as upvalue.
- `src/framework/luaengine/luabinder.h` — std::function binding templates.
- Suspicion: under MSVC v143 / C++17, something in the closure-upvalue lifecycle
  (userdata + `__gc` metatable attach order, or `std::function` copy in the
  placement-new) breaks, yielding NULL upvalue userdata on call.

## Environment where it reproduces
- Windows 11 x64, VS2022 17.x (v143, MSVC 14.44), Windows SDK 10.0.19041
- vcpkg deps (see README): luajit 2.0 (**headers/lib/dll all matched, still crashes**),
  cryptopp, physfs, openal-soft, openssl 3, zlib, glew, libogg/vorbis, boost 1.92
- Build: Release, x64, `/std:c++17`, `NOMINMAX`, `/FS`, `MaxSpeed`, LTCG disabled
- Also crashed identically with: the rolling 2026 luajit headers/lib/dll, and with
  LTCG enabled

## Questions for analysis
1. Does `pushCppFunction`'s stack discipline hold under C++17/v143
   (`newUserdata` → `newTable` → `pushCFunction` → `setField` → `setMetatable` →
   `pushCFunction(callback, 1)`)?
2. Could `/Zc:__cplusplus` + C++17 change `luabinder.h` SFINAE/overload resolution
   so that some binds push a closure with **0 upvalues**?
3. Is the `__gc` (`luaCollectCppFunction`) running too early and freeing the
   `LuaCppFunction` while the closure is still registered on a class table?
