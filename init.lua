-- Production init.lua: standard boot with GC restarted after module loading
g_logger.setLogFile(g_resources.getWorkDir() .. g_app.getCompactName() .. ".log")
g_logger.info(os.date("== application started at %b %d %Y %X"))
g_logger.info(g_app.getName() .. " " .. g_app.getVersion() .. " rev " .. g_app.getBuildRevision() .. " (" .. g_app.getBuildCommit() .. ") built on " .. g_app.getBuildDate() .. " for arch " .. g_app.getBuildArch())

if not g_resources.addSearchPath(g_resources.getWorkDir() .. "data", true) then
  g_logger.fatal("Unable to add data directory to the search path.")
end
if not g_resources.addSearchPath(g_resources.getWorkDir() .. "modules", true) then
  g_logger.fatal("Unable to add modules directory to the search path.")
end
g_resources.addSearchPath(g_resources.getWorkDir() .. "mods", true)
g_resources.setupUserWriteDir(("%s/"):format(g_app.getCompactName()))
g_resources.searchAndAddPackages("/", ".otpkg", true)
g_configs.loadSettings("/config.otml")
g_modules.discoverModules()

g_modules.autoLoadModules(99)
g_modules.ensureModuleLoaded("corelib")
g_modules.ensureModuleLoaded("gamelib")

g_modules.autoLoadModules(499)
g_modules.ensureModuleLoaded("client")

g_modules.autoLoadModules(999)
g_modules.ensureModuleLoaded("game_interface")

g_modules.autoLoadModules(9999)

-- GC was suspended at state creation; restart it now that all modules are loaded
collectgarbage("restart")

local script = "/" .. g_app.getCompactName() .. "rc.lua"
if g_resources.fileExists(script) then
  dofile(script)
end