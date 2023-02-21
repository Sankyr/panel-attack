local class = require("class")
local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local LevelSlider = require("ui.LevelSlider")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local save = require("save")
local GraphicsUtil = require("graphics_util")

--@module BasicMenu
local BasicMenu = class(
  function (self, name, options)
    self.name = name
    self.gameMode = options.gameMode
    self.gameScene = options.gameScene
  end,
  Scene
)

function BasicMenu:startGame()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  
  if config.endless_speed ~= self.speedSlider.value or config.endless_difficulty ~= self.difficultyButtons.value then
    config.endless_speed = self.speedSlider.value
    config.endless_difficulty = self.difficultyButtons.value
    --gprint("saving settings...", unpack(main_menu_screen_pos))
    --wait()
    write_conf_file()
  end
  
  GAME.match = Match(self.gameMode)

  current_stage = config.stage
  if current_stage == random_stage_special_value then
    current_stage = nil
  end

  if self.typeButtons.value == "Classic" then
    GAME.match.P1 = Stack{which=1, match=GAME.match, is_local=true, panels_dir=config.panels, speed=self.speedSlider.value, difficulty=self.difficultyButtons.value, character=config.character}
  else
    GAME.match.P1 = Stack{which=1, match=GAME.match, is_local=true, panels_dir=config.panels, level=self.levelSlider.value, character=config.character}
  end
  GAME.match.P1:wait_for_random_character()
  GAME.match.P1.do_countdown = config.ready_countdown_1P or false
  GAME.match.P2 = nil

  GAME.match.P1:starting_state()
  
  sceneManager:switchToScene(self.gameScene)
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("mainMenu")
end

function BasicMenu:init()
  sceneManager:addScene(self)
  
  self.speedSlider = Slider({
    min = 1, 
    max = 99, 
    value = GAME.config.endless_speed or 1, 
    isVisible = false
  })

  self.difficultyButtons = ButtonGroup(
      {
        buttons = {
          Button({label = "easy", width = 60, height = 25}),
          Button({label = "normal", width = 60, height = 25}),
          Button({label = "hard", width = 60, height = 25}),
          -- TODO: localize "EX Mode"
          Button({label = "EX Mode", translate = false}),
        },
        values = {1, 2, 3, 4},
        selectedIndex = GAME.config.endless_difficulty or 1,
        onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
      }
  )
  
  local tickLength = 16
  self.levelSlider = LevelSlider({
      tickLength = tickLength,
      onValueChange = function(s)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    })
  
  self.typeButtons = ButtonGroup(
    {
      buttons = {
        Button({label = "endless_classic", onClick = function()
              self.modernMenu:setVisibility(false)
              self.classicMenu:setVisibility(true)
              end, width = 60, height = 25}),
        Button({label = "endless_modern", onClick = function()
              self.classicMenu:setVisibility(false) 
              self.modernMenu:setVisibility(true)
              end, width = 60, height = 25}),
      },
      values = {"Classic", "Modern"},
      selectedIndex = 2,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  local modernMenuOptions = {
    {Label({label = "endless_type"}), self.typeButtons},
    {Label({label = "level"}), self.levelSlider},
    {Button({label = "go_", onClick = function() self:startGame() end})},
    {Button({label = "back", onClick = exitMenu})},
  }
  
  local classicMenuOptions = {
    modernMenuOptions[1],
    {Label({label = "speed", isVisible = false}), self.speedSlider},
    {Label({label = "difficulty", isVisible = false}), self.difficultyButtons},
    {Button({label = "go_", onClick = function() self:startGame() end})},
    {Button({label = "back", onClick = exitMenu})},
  }
  
  self.classicMenu = Menu({menuItems = classicMenuOptions})
  self.modernMenu = Menu({menuItems = modernMenuOptions})
  self.classicMenu:setVisibility(false)
  self.modernMenu:setVisibility(false)
end

function BasicMenu:load()
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  y = y + 100
  self.classicMenu.x = x
  self.classicMenu.y = y
  self.modernMenu.x = x
  self.modernMenu.y = y
  
  self.classicMenu:updateLabel()
  self.modernMenu:updateLabel()
  
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end

  for i, button in ipairs(self.difficultyButtons.buttons) do
    button.width = 60
    button.height = 25
  end
  
  if self.typeButtons.value == "Classic" then
    self.classicMenu:setVisibility(true)
  else
    self.modernMenu:setVisibility(true)
  end
end

function BasicMenu:drawBackground() 
  themes[config.theme].images.bg_main:draw() 
end

function BasicMenu:update()
  if self.typeButtons.value == "Classic" then
    local lastScore, record = unpack(self:getScores(self.difficultyButtons.value))
  
    local xPosition1 = 520
    local xPosition2 = xPosition1 + 150
    local yPosition = 270
  
    local lastScoreLabelQuads = {}
    local lastScoreQuads = {}
    local recordLabelQuads = {}
    local recordQuads = {}
    draw_pixel_font("last score", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition, 0.5, 1.0, nil, nil, lastScoreLabelQuads)
    draw_pixel_font(lastScore, themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition + 24, 0.5, 1.0, nil, nil, lastScoreQuads)
    draw_pixel_font("record", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition, 0.5, 1.0, nil, nil, recordLabelQuads)
    draw_pixel_font(record, themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition + 24, 0.5, 1.0, nil, nil, recordQuads)
  
    self.classicMenu:update()
    self.classicMenu:draw()
  else
    self.modernMenu:update()
    self.modernMenu:draw()
  end
  
end

function BasicMenu:unload() 
  if self.typeButtons.value == "Classic" then
    self.classicMenu:setVisibility(false)
  else
    self.modernMenu:setVisibility(false)
  end
  stop_the_music()
end

return BasicMenu