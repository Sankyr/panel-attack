local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
local select_screen = require("select_screen")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local scene_manager = require("scenes.scene_manager")
local input = require("input2")

--@module MainMenu
local endless_menu = Scene("endless_menu")

local speed = GAME.config.endless_speed or 1
local difficulty = GAME.config.endless_difficulty or 1

local xPosition1 = 520
local xPosition2 = xPosition1 + 150
local yPosition = 270

local speed_slider = Slider({
    min = 1, 
    max = 99, 
    value = GAME.config.endless_speed or 1, 
    is_visible = false
})

local function startGame()
  print(config.endless_speed)
  print(speed_slider.value)
  if config.endless_speed ~= speed_slider.value or config.endless_difficulty ~= difficulty then
    config.endless_speed = speed_slider.value
    config.endless_difficulty = difficulty
    --gprint("saving settings...", unpack(main_menu_screen_pos))
    --wait()
    write_conf_file()
  end
  stop_the_music()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene(nil)
  
  func = main_endless_time_setup
  arg = {"endless", speed_slider.value, difficulty}
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end
  
local font = love.graphics.getFont()
local arrow = love.graphics.newText(font, ">")


local menu_options = {
  Label({text = love.graphics.newText(font, loc("speed")), is_visible = false}),
  Label({text = love.graphics.newText(font, loc("difficulty")), is_visible = false}),
  Button({text = love.graphics.newText(font, loc("go_")), onClick = startGame, is_visible = false}),
  Button({text = love.graphics.newText(font, loc("back")), onClick = exitMenu, is_visible = false}),
}

function endless_menu:setDifficulty(new_difficulty)
  self._difficulty_buttons[new_difficulty].color = {.5, .5, 1, .7}
  
  if new_difficulty ~= difficulty then
    difficulty = new_difficulty
    play_optional_sfx(themes[config.theme].sounds.menu_move)
    for i, buttons in ipairs(self._difficulty_buttons) do
      if i ~= difficulty then
        buttons.color = {.3, .3, .3, .7}
      end
    end
  end
end

local selected_id = 1
local time = 0

-- stack rise speed
local active_idx = 1
local startGameSet = false
local exitSet = false
local loc_difficulties = {loc("easy"), loc("normal"), loc("hard"), "EX Mode"} -- TODO: localize "EX Mode"

function endless_menu:init()
  self._difficulty_buttons = {
    Button({text = love.graphics.newText(font, loc("easy")), onClick = function() self:setDifficulty(1) end, is_visible = false}),
    Button({text = love.graphics.newText(font, loc("normal")), onClick = function() self:setDifficulty(2) end, is_visible = false}),
    Button({text = love.graphics.newText(font, loc("hard")), onClick = function() self:setDifficulty(3) end, is_visible = false}),
    -- TODO: localize "EX Mode"
    Button({text = love.graphics.newText(font, "EX Mode"), onClick = function() self:setDifficulty(4) end, is_visible = false}),
  }
  self:setDifficulty(difficulty)
  scene_manager:addScene(endless_menu)
end


local function main_select_speed_99(mode)
  

  local gameSettingsMenu

  local function goEscape()
    gameSettingsMenu:set_active_idx(#gameSettingsMenu.buttons)
  end

  local function exitSettings()
    exitSet = true
  end

  local function updateMenuSpeed()
    gameSettingsMenu:set_button_setting(1, speed)
  end

  local function updateMenuDifficulty()
    gameSettingsMenu:set_button_setting(2, loc_difficulties[difficulty])
  end

  local function increaseSpeed()
    speed = bound(1, speed + 1, 99)
    updateMenuSpeed()
  end

  local function increaseDifficulty()
    difficulty = bound(1, difficulty + 1, 4)
    updateMenuDifficulty()
  end

  local function decreaseSpeed()
    speed = bound(1, speed - 1, 99)
    updateMenuSpeed()
  end

  local function decreaseDifficulty()
    difficulty = bound(1, difficulty - 1, 4)
    updateMenuDifficulty()
  end

  

  local function nextMenu()
    gameSettingsMenu:selectNextIndex()
  end

  local menu_x, menu_y = unpack(main_menu_screen_pos)
  menu_y = menu_y + 70
  gameSettingsMenu = ClickMenu(menu_x, menu_y, nil, canvas_height - menu_y - 10, 1)
  
  updateMenuSpeed()
  updateMenuDifficulty()

  while true do
    -- Draw the current score and record
    local record = 0
    local lastScore = 0
    if mode == "time" then
      lastScore = GAME.scores:lastTimeAttack1PForLevel(difficulty)
      record = GAME.scores:recordTimeAttack1PForLevel(difficulty)
    elseif mode == "endless" then
      lastScore = GAME.scores:lastEndlessForLevel(difficulty)
      record = GAME.scores:recordEndlessForLevel(difficulty)
    end
    local xPosition1 = 520
    local xPosition2 = xPosition1 + 150
    local yPosition = 270

    lastScore = tostring(lastScore)
    record = tostring(record)
    draw_pixel_font("last score", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition, 0.5, 1.0)
    draw_pixel_font(lastScore, themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition + 24, 0.5, 1.0)
    draw_pixel_font("record", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition, 0.5, 1.0)
    draw_pixel_font(record, themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition + 24, 0.5, 1.0)

    gameSettingsMenu:draw()

    wait()
    variable_step(
      function()
        gameSettingsMenu:update()
      end
    )

    if startGameSet then
      gameSettingsMenu:remove_self()
      return main_endless_time_setup, {mode, speed, difficulty}
    elseif exitSet then
      gameSettingsMenu:remove_self()
      return main_select_mode, {}
    end
  end
end


function endless_menu:load()
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end

  local menu_x, menu_y = unpack(main_menu_screen_pos)
  menu_y = menu_y + 100
  speed_slider.x = menu_x + 110 + 25 + 20
  speed_slider.y = menu_y + 25 / 2 - 2.5
  speed_slider.is_visible = true
  for i, button in ipairs(menu_options) do
    button.x = menu_x + 25
    button.y = i > 1 and menu_options[i - 1].y + menu_options[i - 1].height + 5 or menu_y
    button.width = 110
    button.height = 25
    button.is_visible = true
  end
  
  for i, button in ipairs(self._difficulty_buttons) do
    button.x = menu_x + 80 + 65 * i
    button.y = menu_options[2].y
    button.width = 60
    button.height = 25
    button.is_visible = true
  end
end

function endless_menu:update()
  if input.isDown["down"] or (input.isPressed["down"] and input.isPressed["down"] > 100 and input.isPressed["down"] % 20 == 0) then
    selected_id = (selected_id % #menu_options) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  
  if input.isDown["up"] or (input.isPressed["up"] and input.isPressed["up"] > 100 and input.isPressed["up"] % 20 == 0) then
    selected_id = ((selected_id - 2) % #menu_options) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  
  if input.isDown["left"] or (input.isPressed["left"] and input.isPressed["left"] > 100 and input.isPressed["left"] % 20 == 0) then
    if selected_id == 2 and difficulty > 1 then
      self:setDifficulty(difficulty - 1)
    elseif selected_id == 1 then
      speed_slider:setValue(speed_slider.value - 1)
    end
  end

  if input.isDown["right"] or (input.isPressed["right"] and input.isPressed["right"] > 100 and input.isPressed["right"] % 20 == 0) then
    if selected_id == 2 and difficulty < 4 then
      self:setDifficulty(difficulty + 1)
    elseif selected_id == 1 then
      speed_slider:setValue(speed_slider.value + 1)
    end
  end
  
  if input.isDown["return"] and selected_id > 2 then
    menu_options[selected_id].onClick()
  end
  
  for i = 1, 2 do
    menu_options[i]:draw()
  end
  
  lastScore = tostring(GAME.scores:lastEndlessForLevel(difficulty))
  record = tostring(GAME.scores:recordEndlessForLevel(difficulty))
  draw_pixel_font("last score", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition, 0.5, 1.0)
  draw_pixel_font(lastScore, themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition + 24, 0.5, 1.0)
  draw_pixel_font("record", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition, 0.5, 1.0)
  draw_pixel_font(record, themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition + 24, 0.5, 1.0)
  
  local animationX = (math.cos(math.rad(time * .6)) * 5) - 9
  local arrowx = menu_options[selected_id].x - 10 + animationX
  local arrowy = menu_options[selected_id].y + menu_options[selected_id].height / 4
  GAME.gfx_q:push({love.graphics.draw, {arrow, arrowx, arrowy, 0, 1, 1, 0, 0}})
  
  if wait_game_update ~= nil then
    has_game_update = wait_game_update:pop()
    if has_game_update ~= nil and has_game_update then
      wait_game_update = nil
      GAME_UPDATER_GAME_VERSION = "NEW VERSION FOUND! RESTART THE GAME!"
    end
  end

  if GAME_UPDATER_GAME_VERSION then
    gprintf("version: " .. GAME_UPDATER_GAME_VERSION, -2, 705, canvas_width, "right")
    if has_game_update then
      menu_draw(panels[config.panels].images.classic[1][1], 1262, 685)
    end
  end
  time = time + 1
end

function endless_menu:unload()
  for i = 3, 4 do
    menu_options[i].is_visible = false
  end
  for i, button in ipairs(self._difficulty_buttons) do
    button.is_visible = false
  end
  speed_slider.is_visible = false
end

return endless_menu