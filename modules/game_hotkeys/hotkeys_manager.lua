-- Text-only hotkeys (chat text and spell words). Item use (runes, potions,
-- fluids) is intentionally unsupported: the editor offers no object
-- selection and stored item bindings are ignored on load.
HotkeyColors = {
  text = '#888888',
  textAutoSend = '#FFFFFF',
}

hotkeysManagerLoaded = false
hotkeysWindow = nil
hotkeysButton = nil
currentHotkeyLabel = nil
addHotkeyButton = nil
removeHotkeyButton = nil
hotkeyText = nil
hotKeyTextLabel = nil
sendAutomatically = nil
defaultComboKeys = nil
perServer = true
perCharacter = true
currentHotkeys = nil
boundCombosCallback = {}
hotkeysList = {}
lastHotkeyTime = g_clock.millis()

-- public functions
function init()
  hotkeysButton = modules.client_topmenu.addLeftGameButton('hotkeysButton', tr('Hotkeys') .. ' (Ctrl+K)', '/images/topbuttons/hotkeys', toggle)
  g_keyboard.bindKeyDown('Ctrl+K', toggle)
  hotkeysWindow = g_ui.displayUI('hotkeys_manager')
  hotkeysWindow:setVisible(false)

  currentHotkeys = hotkeysWindow:getChildById('currentHotkeys')
  addHotkeyButton = hotkeysWindow:getChildById('addHotkeyButton')
  removeHotkeyButton = hotkeysWindow:getChildById('removeHotkeyButton')
  hotkeyText = hotkeysWindow:getChildById('hotkeyText')
  hotKeyTextLabel = hotkeysWindow:getChildById('hotKeyTextLabel')
  sendAutomatically = hotkeysWindow:getChildById('sendAutomatically')

  currentHotkeys.onChildFocusChange = function(self, hotkeyLabel) onSelectHotkeyLabel(hotkeyLabel) end
  g_keyboard.bindKeyPress('Down', function() currentHotkeys:focusNextChild(KeyboardFocusReason) end, hotkeysWindow)
  g_keyboard.bindKeyPress('Up', function() currentHotkeys:focusPreviousChild(KeyboardFocusReason) end, hotkeysWindow)

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })

  load()
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })

  g_keyboard.unbindKeyDown('Ctrl+K')

  unload()

  hotkeysWindow:destroy()
  hotkeysButton:destroy()
end

function configure(savePerServer, savePerCharacter)
  perServer = savePerServer
  perCharacter = savePerCharacter
  reload()
end

function online()
  reload()
  hide()
end

function offline()
  unload()
  hide()
end

function show()
  if not g_game.isOnline() then
    return
  end
  hotkeysWindow:show()
  hotkeysWindow:raise()
  hotkeysWindow:focus()
end

function hide()
  hotkeysWindow:hide()
end

function toggle()
  if not hotkeysWindow:isVisible() then
    show()
  else
    hide()
  end
end

function ok()
  save()
  hide()
end

function cancel()
  reload()
  hide()
end

function load(forceDefaults)
  hotkeysManagerLoaded = false

  local hotkeySettings = g_settings.getNode('game_hotkeys')
  local hotkeys = {}

  if not table.empty(hotkeySettings) then hotkeys = hotkeySettings end
  if perServer and not table.empty(hotkeys) then hotkeys = hotkeys[G.host] end
  if perCharacter and not table.empty(hotkeys) then hotkeys = hotkeys[g_game.getCharacterName()] end

  hotkeyList = {}
  if not forceDefaults then
    if not table.empty(hotkeys) then
      for keyCombo, setting in pairs(hotkeys) do
        keyCombo = tostring(keyCombo)
        addKeyCombo(keyCombo, setting)
        hotkeyList[keyCombo] = setting
      end
    end
  end

  if currentHotkeys:getChildCount() == 0 then
    loadDefautComboKeys()
  end

  hotkeysManagerLoaded = true
end

function unload()
  for keyCombo,callback in pairs(boundCombosCallback) do
    g_keyboard.unbindKeyPress(keyCombo, callback)
  end
  boundCombosCallback = {}
  currentHotkeys:destroyChildren()
  currentHotkeyLabel = nil
  updateHotkeyForm(true)
  hotkeyList = {}
end

function reset()
  unload()
  load(true)
end

function reload()
  unload()
  load()
end

function save()
  local hotkeySettings = g_settings.getNode('game_hotkeys') or {}
  local hotkeys = hotkeySettings

  if perServer then
    if not hotkeys[G.host] then
      hotkeys[G.host] = {}
    end
    hotkeys = hotkeys[G.host]
  end

  if perCharacter then
    local char = g_game.getCharacterName()
    if not hotkeys[char] then
      hotkeys[char] = {}
    end
    hotkeys = hotkeys[char]
  end

  table.clear(hotkeys)

  for _,child in pairs(currentHotkeys:getChildren()) do
    hotkeys[child.keyCombo] = {
      autoSend = child.autoSend,
      value = child.value
    }
  end

  hotkeyList = hotkeys
  g_settings.setNode('game_hotkeys', hotkeySettings)
  g_settings.save()
end

function loadDefautComboKeys()
  if not defaultComboKeys then
    for i=1,12 do
      addKeyCombo('F' .. i)
    end
    for i=1,4 do
      addKeyCombo('Shift+F' .. i)
    end
  else
    for keyCombo, keySettings in pairs(defaultComboKeys) do
      addKeyCombo(keyCombo, keySettings)
    end
  end
end

function setDefaultComboKeys(combo)
  defaultComboKeys = combo
end

function addHotkey()
  local assignWindow = g_ui.createWidget('HotkeyAssignWindow', rootWidget)
  assignWindow:grabKeyboard()

  local comboLabel = assignWindow:getChildById('comboPreview')
  comboLabel.keyCombo = ''
  assignWindow.onKeyDown = hotkeyCapture
end

function addKeyCombo(keyCombo, keySettings, focus)
  if keyCombo == nil or #keyCombo == 0 then return end
  if not keyCombo then return end
  local hotkeyLabel = currentHotkeys:getChildById(keyCombo)
  if not hotkeyLabel then
    hotkeyLabel = g_ui.createWidget('HotkeyListLabel')
    hotkeyLabel:setId(keyCombo)

    local children = currentHotkeys:getChildren()
    children[#children+1] = hotkeyLabel
    table.sort(children, function(a,b)
      if a:getId():len() < b:getId():len() then
        return true
      elseif a:getId():len() == b:getId():len() then
        return a:getId() < b:getId()
      else
        return false
      end
    end)
    for i=1,#children do
      if children[i] == hotkeyLabel then
        currentHotkeys:insertChild(i, hotkeyLabel)
        break
      end
    end

    if keySettings then
      currentHotkeyLabel = hotkeyLabel
      hotkeyLabel.keyCombo = keyCombo
      hotkeyLabel.autoSend = toboolean(keySettings.autoSend)
      -- Stored item bindings predate text-only hotkeys and are dropped.
      if keySettings.value then hotkeyLabel.value = tostring(keySettings.value) end
    else
      hotkeyLabel.keyCombo = keyCombo
      hotkeyLabel.autoSend = false
      hotkeyLabel.value = ''
    end

    updateHotkeyLabel(hotkeyLabel)

    boundCombosCallback[keyCombo] = function() doKeyCombo(keyCombo) end
    g_keyboard.bindKeyPress(keyCombo, boundCombosCallback[keyCombo])
  end

  if focus then
    currentHotkeys:focusChild(hotkeyLabel)
    currentHotkeys:ensureChildVisible(hotkeyLabel)
    updateHotkeyForm(true)
  end
end

function doKeyCombo(keyCombo)
  if not g_game.isOnline() then return end
  local hotKey = hotkeyList[keyCombo]
  if not hotKey then return end

  if g_clock.millis() - lastHotkeyTime < modules.client_options.getOption('hotkeyDelay') then
    return
  end
  lastHotkeyTime = g_clock.millis()

  -- Text-only: say the text immediately, or drop it into the console input.
  if not hotKey.value or #hotKey.value == 0 then return end
  if hotKey.autoSend then
    modules.game_console.sendMessage(hotKey.value)
  else
    modules.game_console.setTextEditText(hotKey.value)
  end
end

function updateHotkeyLabel(hotkeyLabel)
  if not hotkeyLabel then return end
  local text = hotkeyLabel.keyCombo .. ': '
  if hotkeyLabel.value then
    text = text .. hotkeyLabel.value
  end
  hotkeyLabel:setText(text)
  if hotkeyLabel.autoSend then
    hotkeyLabel:setColor(HotkeyColors.textAutoSend)
  else
    hotkeyLabel:setColor(HotkeyColors.text)
  end
end

function updateHotkeyForm(reset)
  if currentHotkeyLabel then
    removeHotkeyButton:enable()
    hotkeyText:enable()
    hotkeyText:focus()
    hotKeyTextLabel:enable()
    if reset then
      hotkeyText:setCursorPos(-1)
    end
    hotkeyText:setText(currentHotkeyLabel.value)
    sendAutomatically:setChecked(currentHotkeyLabel.autoSend)
    sendAutomatically:setEnabled(currentHotkeyLabel.value and #currentHotkeyLabel.value > 0)
  else
    removeHotkeyButton:disable()
    hotkeyText:disable()
    sendAutomatically:disable()
    hotkeyText:clearText()
    sendAutomatically:setChecked(false)
  end
end

function removeHotkey()
  if currentHotkeyLabel == nil then return end
  g_keyboard.unbindKeyPress(currentHotkeyLabel.keyCombo, boundCombosCallback[currentHotkeyLabel.keyCombo])
  boundCombosCallback[currentHotkeyLabel.keyCombo] = nil
  currentHotkeyLabel:destroy()
  currentHotkeyLabel = nil
end

function onHotkeyTextChange(value)
  if not hotkeysManagerLoaded then return end
  if currentHotkeyLabel == nil then return end
  currentHotkeyLabel.value = value
  if value == '' then
    currentHotkeyLabel.autoSend = false
  end
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm()
end

function onSendAutomaticallyChange(autoSend)
  if not hotkeysManagerLoaded then return end
  if currentHotkeyLabel == nil then return end
  if not currentHotkeyLabel.value or #currentHotkeyLabel.value == 0 then return end
  currentHotkeyLabel.autoSend = autoSend
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm()
end

function onSelectHotkeyLabel(hotkeyLabel)
  currentHotkeyLabel = hotkeyLabel
  updateHotkeyForm(true)
end

function hotkeyCapture(assignWindow, keyCode, keyboardModifiers)
  local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers)
  local comboPreview = assignWindow:getChildById('comboPreview')
  comboPreview:setText(tr('Current hotkey to add: %s', keyCombo))
  comboPreview.keyCombo = keyCombo
  comboPreview:resizeToText()
  assignWindow:getChildById('addButton'):enable()
  return true
end

function hotkeyCaptureOk(assignWindow, keyCombo)
  addKeyCombo(keyCombo, nil, true)
  assignWindow:destroy()
end
