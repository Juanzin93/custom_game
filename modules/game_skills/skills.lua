skillsWindow = nil
skillsButton = nil
skillsSettings = nil
local ExpRating = {}

-- cached last-known values from server
local lastCondHpGain, lastCondHpTicks = 0, 0
local lastCondMpGain, lastCondMpTicks = 0, 0
local lastItemHpGain, lastItemHpTicks = 0, 0
local lastItemMpGain, lastItemMpTicks = 0, 0
local lastCritChance = 0

----------------------------------------------------------------
-- small helpers for formatting / ui update
----------------------------------------------------------------

local function fmtRegen(gain, ticksMs)
  if gain == 0 or ticksMs == 0 then
    return "0"
  end
  local seconds = ticksMs / 1000
  if seconds == math.floor(seconds) then
    return string.format("%d /%ds", gain, seconds)
  else
    return string.format("%d /%.2fs", gain, seconds)
  end
end

local function setSkillValue(id, value)
  local skill = skillsWindow:recursiveGetChildById(id)
  if not skill then return end
  local widget = skill:getChildById('value')
  if not widget then return end

  -- keep original percent formatting behavior for some skillId rows
  if id == "skillId7" or id == "skillId8" or id == "skillId9" or
     id == "skillId11" or id == "skillId13" or id == "skillId14" or
     id == "skillId15" or id == "skillId16" then
    local v = value
    if g_game.getFeature(GameEnterGameShowAppearance) then
      v = v / 100
    end
    widget:setText(v .. "%")
  else
    widget:setText(value)
  end
end

local function setSkillColor(id, color)
  local skill = skillsWindow:recursiveGetChildById(id)
  if not skill then return end
  local widget = skill:getChildById('value')
  if not widget then return end
  widget:setColor(color)
end

local function resetSkillColor(id)
  local skill = skillsWindow:recursiveGetChildById(id)
  if not skill then return end
  local widget = skill:getChildById('value')
  if not widget then return end
  widget:setColor('#bbbbbb')
end

local function toggleSkill(id, state)
  local skill = skillsWindow:recursiveGetChildById(id)
  if skill then
    skill:setVisible(state)
  end
end

local function setSkillTooltip(id, text)
  local skill = skillsWindow:recursiveGetChildById(id)
  if not skill then return end
  local widget = skill:getChildById('value')
  if not widget then return end
  if text and text ~= '' then
    widget:setTooltip(text)
  else
    widget:removeTooltip()
  end
end

local function setSkillPercent(id, percent, tooltip, color)
  local skill = skillsWindow:recursiveGetChildById(id)
  if not skill then return end
  local widget = skill:getChildById('percent')
  if not widget then return end

  widget:setPercent(math.floor(percent))

  if tooltip then
    widget:setTooltip(tooltip)
  end
  if color then
    widget:setBackgroundColor(color)
  end
end

local function setSkillBase(id, value, baseValue)
  if baseValue <= 0 or value < 0 then return end

  local skill = skillsWindow:recursiveGetChildById(id)
  if not skill then return end
  local widget = skill:getChildById('value')
  if not widget then return end

  if value > baseValue then
    widget:setColor('#008b00') -- green
    skill:setTooltip(baseValue .. ' +' .. (value - baseValue))
  elseif value < baseValue then
    widget:setColor('#b22222') -- red
    skill:setTooltip(baseValue .. ' ' .. (value - baseValue))
  else
    widget:setColor('#bbbbbb') -- default
    skill:removeTooltip()
  end
end

local function checkAlert(id, value, maxValue, threshold, greaterThan)
  if greaterThan == nil then
    greaterThan = false
  end
  local alert = false

  -- boolean mode
  if type(maxValue) == 'boolean' then
    if maxValue then
      return
    end
    if greaterThan then
      if value > threshold then alert = true end
    else
      if value < threshold then alert = true end
    end

  -- numeric mode
  elseif type(maxValue) == 'number' then
    if maxValue < 0 then
      return
    end
    local percent = math.floor((value / maxValue) * 100)
    if greaterThan then
      if percent > threshold then alert = true end
    else
      if percent < threshold then alert = true end
    end
  end

  if alert then
    setSkillColor(id, '#b22222')
  else
    resetSkillColor(id)
  end
end

-- draw regen + crit rows based on cached values
local function updateRegenDisplay()
  setSkillValue('regenHP',      fmtRegen(lastCondHpGain,  lastCondHpTicks))
  setSkillValue('regenMP',      fmtRegen(lastCondMpGain,  lastCondMpTicks))
  setSkillValue('bonusRegenHP', fmtRegen(lastItemHpGain,  lastItemHpTicks))
  setSkillValue('bonusRegenMP', fmtRegen(lastItemMpGain,  lastItemMpTicks))

  -- crit is whole-perc from server (20 => 20.00%)
  local critText = (lastCritChance and lastCritChance > 0)
                   and string.format("%.2f%%", lastCritChance)
                   or "0%"
  setSkillValue('critChance', critText)

  setSkillTooltip('regenHP',      "Base/condition regen")
  setSkillTooltip('regenMP',      "Base/condition mana regen")
  setSkillTooltip('bonusRegenHP', "Item bonus regen")
  setSkillTooltip('bonusRegenMP', "Item bonus mana regen")
  setSkillTooltip('critChance',   "Chance for an attack to crit and deal bonus damage")
end

----------------------------------------------------------------
-- g_game hooks / lifecycle
----------------------------------------------------------------

function init()
  connect(LocalPlayer, {
    onExperienceChange         = onExperienceChange,
    onLevelChange              = onLevelChange,
    onHealthChange             = onHealthChange,
    onManaChange               = onManaChange,
    onSoulChange               = onSoulChange,
    onFreeCapacityChange       = onFreeCapacityChange,
    onTotalCapacityChange      = onTotalCapacityChange,
    onStaminaChange            = onStaminaChange,
    onOfflineTrainingChange    = onOfflineTrainingChange,
    onRegenerationChange       = onRegenerationChange,
    onSpeedChange              = onSpeedChange,
    onBaseSpeedChange          = onBaseSpeedChange,
    onMagicLevelChange         = onMagicLevelChange,
    onBaseMagicLevelChange     = onBaseMagicLevelChange,
    onSkillChange              = onSkillChange,
    onBaseSkillChange          = onBaseSkillChange,
    onFlatDamageHealingChange  = onFlatDamageHealingChange,
    onAttackInfoChange         = onAttackInfoChange,
    onConvertedDamageChange    = onConvertedDamageChange,
    onImbuementsChange         = onImbuementsChange,
    onDefenseInfoChange        = onDefenseInfoChange,
    onCombatAbsorbValuesChange = onCombatAbsorbValuesChange,
    onForgeBonusesChange       = onForgeBonusesChange,
    onExperienceRateChange     = onExperienceRateChange
  })

  connect(g_game, {
    onGameStart               = online,
    onGameEnd                 = offline,

    -- ProtocolGame::parsePlayerStats() calls:
    -- g_lua.callGlobalField("g_game","onRegenerationRatesChange",
    --   condHpGain, condHpTicks, condMpGain, condMpTicks,
    --   itemHpGain, itemHpTicks, itemMpGain, itemMpTicks, critChance)
    onRegenerationRatesChange = onRegenerationRatesChange
  })

  skillsButton = modules.game_mainpanel.addToggleButton(
    'skillsButton',
    tr('Skills') .. ' (Alt+S)',
    '/images/options/button_skills',
    toggle,
    false,
    1
  )
  skillsButton:setOn(true)

  skillsWindow = g_ui.loadUI('skills')

  Keybind.new("Windows", "Show/hide skills windows", "Alt+S", "")
  Keybind.bind("Windows", "Show/hide skills windows", {
    { type = KEY_DOWN, callback = toggle, }
  })

  skillSettings = g_settings.getNode('skills-hide')
  if not skillSettings then
    skillSettings = {}
  end

  refresh()
  skillsWindow:setup()
  if g_game.isOnline() then
    skillsWindow:setupOnStart()
  end
end

function terminate()
  disconnect(LocalPlayer, {
    onExperienceChange         = onExperienceChange,
    onLevelChange              = onLevelChange,
    onHealthChange             = onHealthChange,
    onManaChange               = onManaChange,
    onSoulChange               = onSoulChange,
    onFreeCapacityChange       = onFreeCapacityChange,
    onTotalCapacityChange      = onTotalCapacityChange,
    onStaminaChange            = onStaminaChange,
    onOfflineTrainingChange    = onOfflineTrainingChange,
    onRegenerationChange       = onRegenerationChange,
    onSpeedChange              = onSpeedChange,
    onBaseSpeedChange          = onBaseSpeedChange,
    onMagicLevelChange         = onMagicLevelChange,
    onBaseMagicLevelChange     = onBaseMagicLevelChange,
    onSkillChange              = onSkillChange,
    onBaseSkillChange          = onBaseSkillChange,
    onFlatDamageHealingChange  = onFlatDamageHealingChange,
    onAttackInfoChange         = onAttackInfoChange,
    onConvertedDamageChange    = onConvertedDamageChange,
    onImbuementsChange         = onImbuementsChange,
    onDefenseInfoChange        = onDefenseInfoChange,
    onCombatAbsorbValuesChange = onCombatAbsorbValuesChange,
    onForgeBonusesChange       = onForgeBonusesChange,
    onExperienceRateChange     = onExperienceRateChange
  })

  disconnect(g_game, {
    onGameStart               = online,
    onGameEnd                 = offline,
    onRegenerationRatesChange = onRegenerationRatesChange
  })

  Keybind.delete("Windows", "Show/hide skills windows")
  skillsWindow:destroy()
  skillsButton:destroy()

  skillsWindow = nil
  skillsButton = nil
end

----------------------------------------------------------------
-- server push (regen + crit)
----------------------------------------------------------------
function g_game.onRegenerationRatesChange(
  condHpGain, condHpTicks,
  condMpGain, condMpTicks,
  itemHpGain, itemHpTicks,
  itemMpGain, itemMpTicks,
  critChance
)
  lastCondHpGain    = condHpGain    or 0
  lastCondHpTicks   = condHpTicks   or 0
  lastCondMpGain    = condMpGain    or 0
  lastCondMpTicks   = condMpTicks   or 0

  lastItemHpGain    = itemHpGain    or 0
  lastItemHpTicks   = itemHpTicks   or 0
  lastItemMpGain    = itemMpGain    or 0
  lastItemMpTicks   = itemMpTicks   or 0

  lastCritChance    = critChance or 0

  updateRegenDisplay()
end

----------------------------------------------------------------
-- refresh(): called on login / reopening window
-- seed the cached regen/crit from LocalPlayer getters so UI is not "0"
----------------------------------------------------------------
function refresh()
  local player = g_game.getLocalPlayer()
  if not player then return end

  if expSpeedEvent then
    expSpeedEvent:cancel()
  end
  expSpeedEvent = cycleEvent(checkExpSpeed, 30 * 1000)

  onExperienceChange(player, player:getExperience())
  onLevelChange(player, player:getLevel(), player:getLevelPercent())
  onHealthChange(player, player:getHealth(), player:getMaxHealth())
  onManaChange(player, player:getMana(), player:getMaxMana())
  onSoulChange(player, player:getSoul())
  onFreeCapacityChange(player, player:getFreeCapacity())
  onStaminaChange(player, player:getStamina())
  onMagicLevelChange(player, player:getMagicLevel(), player:getMagicLevelPercent())
  onOfflineTrainingChange(player, player:getOfflineTrainingTime())
  onRegenerationChange(player, player:getRegenerationTime())
  onSpeedChange(player, player:getSpeed())

  -- seed cache from LocalPlayer (requires the getters you added)
  if player.getCondHpGain then
    lastCondHpGain  = player:getCondHpGain()  or 0
    lastCondHpTicks = player:getCondHpTicks() or 0
    lastCondMpGain  = player:getCondMpGain()  or 0
    lastCondMpTicks = player:getCondMpTicks() or 0
  end
  if player.getItemHpGain then
    lastItemHpGain  = player:getItemHpGain()  or 0
    lastItemHpTicks = player:getItemHpTicks() or 0
    lastItemMpGain  = player:getItemMpGain()  or 0
    lastItemMpTicks = player:getItemMpTicks() or 0
  end
  if player.getCriticalChance then
    lastCritChance  = player:getCriticalChance() or 0
  end

  updateRegenDisplay()

  local hasAdditionalSkills = g_game.getFeature(GameAdditionalSkills)
  for i = Skill.Fist, Skill.Transcendence do
    onSkillChange(player, i, player:getSkillLevel(i), player:getSkillLevelPercent(i))

    if i > Skill.Fishing then
      local ativedAdditionalSkills = hasAdditionalSkills
      if ativedAdditionalSkills then
        if g_game.getClientVersion() >= 1281 then
          if i == Skill.LifeLeechAmount or i == Skill.ManaLeechAmount then
            ativedAdditionalSkills = false
          elseif g_game.getClientVersion() < 1332 and Skill.Transcendence then
            ativedAdditionalSkills = false
          elseif i >= Skill.Fatal and player:getSkillLevel(i) <= 0 then
            ativedAdditionalSkills = false
          end
        elseif g_game.getClientVersion() < 1281 and i >= Skill.Fatal then
          ativedAdditionalSkills = false
        end
      end
      toggleSkill('skillId' .. i, ativedAdditionalSkills)
    end
  end

  update()
  updateHeight()
end

----------------------------------------------------------------
-- other UI state helpers
----------------------------------------------------------------
function update()
  local offlineTraining = skillsWindow:recursiveGetChildById('offlineTraining')
  if not g_game.getFeature(GameOfflineTrainingTime) then
    offlineTraining:hide()
  else
    offlineTraining:show()
  end

  local regenerationTime = skillsWindow:recursiveGetChildById('regenerationTime')
  if not g_game.getFeature(GamePlayerRegenerationTime) then
    regenerationTime:hide()
  else
    regenerationTime:show()
  end

  local xpBoostButton = skillsWindow:recursiveGetChildById('xpBoostButton')
  local xpGainRate = skillsWindow:recursiveGetChildById('xpGainRate')
  if g_game.getFeature(GameExperienceBonus) then
    xpBoostButton:show()
    xpGainRate:show()
  else
    xpBoostButton:hide()
    xpGainRate:hide()
  end
end

function updateHeight()
  local maximumHeight = 8
  if g_game.isOnline() then
    local char = g_game.getCharacterName()

    if not skillSettings[char] then
      skillSettings[char] = {}
    end

    local skillsButtons = skillsWindow:recursiveGetChildById('experience'):getParent():getChildren()

    for _, skillButton in pairs(skillsButtons) do
      local percentBar = skillButton:getChildById('percent')
      if skillButton:isVisible() then
        if percentBar then
          showPercentBar(skillButton, skillSettings[char][skillButton:getId()] ~= 1)
        end
        maximumHeight = maximumHeight + skillButton:getHeight() + skillButton:getMarginBottom()
      end
    end
  else
    maximumHeight = 390
  end

  skillsWindow:setContentMinimumHeight(44)
  skillsWindow:setContentMaximumHeight(maximumHeight)
end

function online()
  skillsWindow:setupOnStart()
  refresh()
  if g_game.getFeature(GameEnterGameShowAppearance) then
    skillsWindow:recursiveGetChildById('regenerationTime'):getChildByIndex(1):setText('Food')
  end
end

function offline()
  skillsWindow:setParent(nil, true)
  if expSpeedEvent then
    expSpeedEvent:cancel()
    expSpeedEvent = nil
  end
  g_settings.setNode('skills-hide', skillSettings)
end

function toggle()
  if skillsButton:isOn() then
    skillsWindow:close()
    skillsButton:setOn(false)
  else
    if not skillsWindow:getParent() then
      local panel = modules.game_interface.findContentPanelAvailable(
        skillsWindow,
        skillsWindow:getMinimumHeight()
      )
      if not panel then return end
      panel:addChild(skillsWindow)
    end
    skillsWindow:open()
    skillsButton:setOn(true)
    updateHeight()
  end
end

----------------------------------------------------------------
-- misc UI interactions
----------------------------------------------------------------
function checkExpSpeed()
  local player = g_game.getLocalPlayer()
  if not player then return end

  local currentExp = player:getExperience()
  local currentTime = g_clock.seconds()
  if player.lastExps ~= nil then
    player.expSpeed = (currentExp - player.lastExps[1][1]) / (currentTime - player.lastExps[1][2])
    onLevelChange(player, player:getLevel(), player:getLevelPercent())
  else
    player.lastExps = {}
  end
  table.insert(player.lastExps, {currentExp, currentTime})
  if #player.lastExps > 30 then
    table.remove(player.lastExps, 1)
  end
end

function onMiniWindowOpen()
  skillsButton:setOn(true)
end

function onMiniWindowClose()
  skillsButton:setOn(false)
end

function onSkillButtonClick(button)
  local percentBar = button:getChildById('percent')
  local skillIcon = button:getChildById('icon')
  if percentBar and skillIcon then
    showPercentBar(button, not percentBar:isVisible())
    skillIcon:setVisible(skillIcon:isVisible())

    local char = g_game.getCharacterName()
    if percentBar:isVisible() then
      skillsWindow:modifyMaximumHeight(6)
      skillSettings[char][button:getId()] = 0
    else
      skillsWindow:modifyMaximumHeight(-6)
      skillSettings[char][button:getId()] = 1
    end
  end
end

function showPercentBar(button, show)
  local percentBar = button:getChildById('percent')
  local skillIcon = button:getChildById('icon')
  if not percentBar or not skillIcon then return end

  percentBar:setVisible(show)
  skillIcon:setVisible(show)
  if show then
    button:setHeight(21)
  else
    button:setHeight(21 - 6)
  end
end

----------------------------------------------------------------
-- stat change handlers
----------------------------------------------------------------
function onExperienceChange(localPlayer, value)
  setSkillValue('experience', comma_value(value))
end

function onLevelChange(localPlayer, value, percent)
  setSkillValue('level', comma_value(value))

  local text = tr('You have %s percent to go', 100 - percent) .. '\n' ..
               tr('%s of experience left',
               expToAdvance(localPlayer:getLevel(), localPlayer:getExperience()))

  if localPlayer.expSpeed ~= nil then
    local expPerHour = math.floor(localPlayer.expSpeed * 3600)
    if expPerHour > 0 then
      local nextLevelExp = expForLevel(localPlayer:getLevel() + 1)
      local hoursLeft = (nextLevelExp - localPlayer:getExperience()) / expPerHour
      local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft)) * 60)
      hoursLeft = math.floor(hoursLeft)
      text = text .. '\n' .. tr('%s of experience per hour', comma_value(expPerHour))
      text = text .. '\n' .. tr('Next level in %d hours and %d minutes', hoursLeft, minutesLeft)
    end
  end

  setSkillPercent('level', percent, text)
end

function onHealthChange(localPlayer, health, maxHealth)
  setSkillValue('health', comma_value(health))
  checkAlert('health', health, maxHealth, 30)
end

function onManaChange(localPlayer, mana, maxMana)
  setSkillValue('mana', comma_value(mana))
  checkAlert('mana', mana, maxMana, 30)
end

function onSoulChange(localPlayer, soul)
  setSkillValue('soul', soul)
end

function onFreeCapacityChange(localPlayer, freeCapacity)
  setSkillValue('capacity', comma_value(freeCapacity))
  checkAlert('capacity', freeCapacity, localPlayer:getTotalCapacity(), 20)
end

function onTotalCapacityChange(localPlayer, totalCapacity)
  checkAlert('capacity', localPlayer:getFreeCapacity(), totalCapacity, 20)
end

function onStaminaChange(localPlayer, stamina)
  local hours = math.floor(stamina / 60)
  local minutes = stamina % 60
  if minutes < 10 then minutes = '0' .. minutes end
  local percent = math.floor(100 * stamina / (42 * 60))

  setSkillValue('stamina', hours .. ':' .. minutes)

  if stamina > 2400 and g_game.getClientVersion() >= 1038 and localPlayer:isPremium() then
    local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
                 tr('Now you will gain 50%% more experience')
    setSkillPercent('stamina', percent, text, 'green')
  elseif stamina > 2400 and g_game.getClientVersion() >= 1038 and not localPlayer:isPremium() then
    local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
                 tr('You will not gain 50%% more experience because you aren\'t premium player, now you receive only 1x experience points')
    setSkillPercent('stamina', percent, text, '#89F013')
  elseif stamina >= 2400 and g_game.getClientVersion() < 1038 then
    local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
                 tr('If you are premium player, you will gain 50%% more experience')
    setSkillPercent('stamina', percent, text, 'green')
  elseif stamina < 2400 and stamina > 840 then
    setSkillPercent('stamina', percent,
      tr('You have %s hours and %s minutes left', hours, minutes), 'orange')
  elseif stamina <= 840 and stamina > 0 then
    local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
                 tr('You gain only 50%% experience and you don\'t may gain loot from monsters')
    setSkillPercent('stamina', percent, text, 'red')
  elseif stamina == 0 then
    local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
                 tr('You don\'t may receive experience and loot from monsters')
    setSkillPercent('stamina', percent, text, 'black')
  end
end

function onOfflineTrainingChange(localPlayer, offlineTrainingTime)
  if not g_game.getFeature(GameOfflineTrainingTime) then return end
  local hours = math.floor(offlineTrainingTime / 60)
  local minutes = offlineTrainingTime % 60
  if minutes < 10 then minutes = '0' .. minutes end
  local percent = 100 * offlineTrainingTime / (12 * 60)

  setSkillValue('offlineTraining', hours .. ':' .. minutes)
  setSkillPercent('offlineTraining', percent,
                  tr('You have %s percent', percent))
end

function onRegenerationChange(localPlayer, regenerationTime)
  if not g_game.getFeature(GamePlayerRegenerationTime) or regenerationTime < 0 then
    return
  end

  local hours = math.floor(regenerationTime / 3600)
  local minutes = math.floor(regenerationTime / 60)
  local seconds = regenerationTime % 60
  if seconds < 10 then seconds = '0' .. seconds end
  if minutes < 10 then minutes = '0' .. minutes end
  if hours < 10 then hours = '0' .. hours end

  local fmt = ""
  local alert = 300
  if g_game.getFeature(GameEnterGameShowAppearance) then
    fmt = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    alert = 0
  else
    fmt = string.format("%02d:%02d", minutes, seconds)
  end
  setSkillValue('regenerationTime', fmt)
  checkAlert('regenerationTime', regenerationTime, false, alert)

  if g_game.getFeature(GameEnterGameShowAppearance) then
    modules.game_interface.StatsBar.onHungryChange(regenerationTime, alert)
  end
end

function onSpeedChange(localPlayer, speed)
  setSkillValue('speed', comma_value(speed))
  onBaseSpeedChange(localPlayer, localPlayer:getBaseSpeed())
end

function onBaseSpeedChange(localPlayer, baseSpeed)
  setSkillBase('speed', localPlayer:getSpeed(), baseSpeed)
end

function onMagicLevelChange(localPlayer, magiclevel, percent)
  setSkillValue('magiclevel', magiclevel)
  setSkillPercent('magiclevel', percent,
                  tr('You have %s percent to go', 100 - percent))
  onBaseMagicLevelChange(localPlayer, localPlayer:getBaseMagicLevel())
end

function onBaseMagicLevelChange(localPlayer, baseMagicLevel)
  setSkillBase('magiclevel', localPlayer:getMagicLevel(), baseMagicLevel)
end

function onSkillChange(localPlayer, id, level, percent)
  setSkillValue('skillId' .. id, level)
  setSkillPercent('skillId' .. id, percent,
                  tr('You have %s percent to go', 100 - percent))

  onBaseSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))

  if id > Skill.ManaLeechAmount then
    toggleSkill('skillId' .. id, level > 0)
  end
end

function onBaseSkillChange(localPlayer, id, baseLevel)
  setSkillBase('skillId' .. id, localPlayer:getSkillLevel(id), baseLevel)
end

----------------------------------------------------------------
-- xp gain / exp rate stuff
----------------------------------------------------------------
local function updateExperienceRate(localPlayer)
  local baseRate = ExpRating[ExperienceRate.BASE] or 100
  local expRateTotal = baseRate

  for t, v in pairs(ExpRating) do
    if t ~= ExperienceRate.BASE and t ~= ExperienceRate.STAMINA_MULTIPLIER then
      expRateTotal = expRateTotal + (v or 0)
    end
  end

  local staminaMultiplier = ExpRating[ExperienceRate.STAMINA_MULTIPLIER] or 100
  expRateTotal = expRateTotal * staminaMultiplier / 100

  local xpgainrate = skillsWindow:recursiveGetChildById("xpGainRate")
  if not xpgainrate then return end

  local widget = xpgainrate:getChildById("value")
  if not widget then return end

  widget:setText(math.floor(expRateTotal) .. "%")

  local tooltip = string.format(
    "Your current XP gain rate amounts to %d%%.",
    math.floor(expRateTotal)
  )
  xpgainrate:setTooltip(tooltip)

  if expRateTotal == 0 then
    widget:setColor("#ff4a4a")
  elseif expRateTotal > 100 then
    widget:setColor("#00cc00")
  elseif expRateTotal < 100 then
    widget:setColor("#ff9429")
  else
    widget:setColor("#ffffff")
  end
end

function onExperienceRateChange(localPlayer, t, v)
  ExpRating[t] = v
  updateExperienceRate(localPlayer)
end

----------------------------------------------------------------
-- damage / defense / etc
----------------------------------------------------------------
local function setSkillValueWithTooltips(id, value, tooltip, showPercentage, color)
  local skill = skillsWindow:recursiveGetChildById(id)
  if not skill then return end

  if value and value ~= 0 then
    skill:show()
    local widget = skill:getChildById('value')
    if not widget then return end

    if color then
      widget:setColor(color)
    end

    if showPercentage then
      -- value is already in whole percent units (e.g. 20 == 20%)
      local percentValue = value or 0
      local sign = percentValue > 0 and "+ " or ""
      widget:setText(sign .. string.format("%.2f%%", percentValue))
      if percentValue < 0 then
        widget:setColor("#FF9854")
      end
    else
      widget:setText(tostring(value))
    end

    if tooltip then
      skill:setTooltip(tooltip)
    end
  else
    skill:hide()
  end
end

function onFlatDamageHealingChange(localPlayer, flatBonus)
  local tt = "This flat bonus is the main source of your character's power, " ..
             "added to most of the damage and healing values you cause."
  setSkillValueWithTooltips('damageHealing', flatBonus, tt, false)
end

function onAttackInfoChange(localPlayer, attackValue, attackElement)
  local tt = "This is your basic physical attack power (weapons/fists)."
  setSkillValueWithTooltips('attackValue', attackValue, tt, false)

  local skill = skillsWindow:recursiveGetChildById("attackValue")
  if skill then
    local element = clientCombat[attackElement]
    if element then
      skill:getChildById('icon'):setImageSource(element.path)
      skill:getChildById('icon'):setImageSize({width = 9, height = 9})
    end
  end
end

function onConvertedDamageChange(localPlayer, convertedDamage, convertedElement)
  setSkillValueWithTooltips('convertedDamage', convertedDamage, false, true)
  setSkillValueWithTooltips('convertedElement', convertedElement, false, true)
end

function onImbuementsChange(localPlayer, lifeLeech, manaLeech, critChanceVal, critDamage, onslaught)
  local ttOnslaught   = "Chance to trigger Onslaught (burst damage bonus)."
  local ttCritChance  = "Chance your hits become Critical Hits (bonus damage)."
  local ttCritDmg     = "Extra damage multiplier when a Critical Hit triggers."
  local ttManaLeech   = "Portion of dealt damage returned as mana."
  local ttLifeLeech   = "Portion of dealt damage returned as health."

  skillsWindow:recursiveGetChildById("criticalHit"):setVisible(true)

  setSkillValueWithTooltips('lifeLeech',           lifeLeech,     ttLifeLeech,  true)
  setSkillValueWithTooltips('manaLeech',           manaLeech,     ttManaLeech,  true)
  setSkillValueWithTooltips('criticalChance',      critChanceVal, ttCritChance, true)
  setSkillValueWithTooltips('criticalExtraDamage', critDamage,    ttCritDmg,    true)
  setSkillValueWithTooltips('onslaught',           onslaught,     ttOnslaught,  true)
end

local combatIdToWidgetId = {
  [0]  = "physicalResist",
  [1]  = "fireResist",
  [2]  = "earthResist",
  [3]  = "energyResist",
  [4]  = "IceResist",
  [5]  = "HolyResist",
  [6]  = "deathResist",
  [7]  = "HealingResist",
  [8]  = "drowResist",
  [9]  = "lifedrainResist",
  [10] = "manadRainResist"
}

function onCombatAbsorbValuesChange(localPlayer, absorbValues)
  for id, widgetId in pairs(combatIdToWidgetId) do
    local skill = skillsWindow:recursiveGetChildById(widgetId)
    if skill then
      local value = absorbValues[id]
      if value then
        setSkillValueWithTooltips(widgetId, value, false, true, "#44AD25")
      else
        skill:hide()
      end
    end
  end
end

function onDefenseInfoChange(localPlayer, defense, armor, mitigation, dodge, damageReflection)
  skillsWindow:recursiveGetChildById("separadorOnDefenseInfoChange"):setVisible(true)

  local ttDefense =
    "Chance to dodge melee/ranged hits completely."
  local ttArmor =
    "Your armor protection vs physical sources."
  local ttMitigation =
    "Overall % reduction of incoming physical damage."
  local ttDodge =
    "Chance to avoid incoming damage entirely."
  local ttReflect =
    "Percent of dealt damage reflected back."

  setSkillValueWithTooltips('defenceValue',      defense,          ttDefense,       false)
  setSkillValueWithTooltips('armorValue',        armor,            ttArmor,         false)
  setSkillValueWithTooltips('mitigation',        mitigation,       ttMitigation,    true)
  setSkillValueWithTooltips('dodge',             dodge,            ttDodge,         true)
  setSkillValueWithTooltips('damageReflection',  damageReflection, ttReflect,       true)
end

function onForgeBonusesChange(localPlayer, momentum, transcendence, amplification)
  skillsWindow:recursiveGetChildById("separadorOnForgeBonusesChange"):setVisible(true)

  local momentumTooltip =
    "Chance to trigger Momentum, reducing spell cooldowns briefly."
  local transcendenceTooltip =
    "Chance to enter avatar form (auto-crits + damage reduction)."
  local amplificationTooltip =
    "Percent bonus applied to tiered item effects."

  setSkillValueWithTooltips('momentum',        momentum,        momentumTooltip,        true)
  setSkillValueWithTooltips('transcendence',   transcendence,   transcendenceTooltip,   true)
  setSkillValueWithTooltips('amplification',   amplification,   amplificationTooltip,   true)
end

----------------------------------------------------------------
-- math helpers
----------------------------------------------------------------
function expForLevel(level)
  return math.floor(
    (50 * level * level * level) / 3
    - 100 * level * level
    + (850 * level) / 3
    - 200
  )
end

function expToAdvance(currentLevel, currentExp)
  return expForLevel(currentLevel + 1) - currentExp
end
