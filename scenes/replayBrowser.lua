local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local GraphicsUtil = require("graphics_util")
local fileUtils = require("fileUtils")
local Replay = require("replay")

--@module replayBrowser
local replayBrowser = Scene("replayBrowser")

local font = GraphicsUtil.getGlobalFont()
local selection = nil
local base_path = "replays"
local current_path = "/"
local path_contents = {}
local filename = nil
local state = "browser"

local menu_x = 400
local menu_y = 280
local menu_h = 14
local menu_cursor_offset = 16

local cursor_pos = 0

local replay_id_top = 0

local function replayMenu()
  if (replay_id_top == 0) then
    if current_path ~= "/" then
      gprint("< " .. loc("rp_browser_up") .. " >", menu_x, menu_y)
    else
      gprint("< " .. loc("rp_browser_root") .. " >", menu_x, menu_y)
    end
  else
    gprint("^ " .. loc("rp_browser_more") .. " ^", menu_x, menu_y)
  end

  for i, p in pairs(path_contents) do
    if (i > replay_id_top) and (i <= replay_id_top + 20) then
      gprint(p, menu_x, menu_y + (i - replay_id_top) * menu_h)
    end
  end

  if #path_contents > replay_id_top + 20 then
    gprint("v " .. loc("rp_browser_more") .. " v", menu_x, menu_y + 21 * menu_h)
  end

  gprint(">", menu_x - menu_cursor_offset + math.sin(love.timer.getTime() * 8) * 5, menu_y + (cursor_pos - replay_id_top) * menu_h)
end

local function moveCursor(dir)
  cursor_pos = wrap(0, cursor_pos + dir, #path_contents)
  if cursor_pos <= replay_id_top then
    replay_id_top = math.max(cursor_pos, 1) - 1
  end
  if replay_id_top < cursor_pos - 20 then
    replay_id_top = cursor_pos - 20
  end
end

local function updateBrowsingPath(new_path)
  if new_path then
    cursor_pos = 0
    replay_id_top = 0
    if new_path == "" then
      new_path = "/"
    end
    current_path = new_path
  end
  path_contents = fileUtils.getFilteredDirectoryItems(base_path .. current_path)
end
  
local function setPathToParentDir()
  updateBrowsingPath(current_path:gsub("(.*/).*/$", "%1"))
end

local function selectMenuItem()
  if cursor_pos == 0 then
    setPathToParentDir()
  else
    selection = base_path .. current_path .. path_contents[cursor_pos]
    local file_info = love.filesystem.getInfo(selection)
    if file_info then
      if file_info.type == "file" then
        filename = selection
        return Replay.loadFromPath(selection)
      elseif file_info.type == "directory" then
        updateBrowsingPath(current_path .. path_contents[cursor_pos] .. "/")
      else
        --print(loc("rp_browser_error_unknown_filetype", file_info.type, selection))
      end
    else
      --print(loc("rp_browser_error_file_not_found", selection))
    end
  end
end

function replayBrowser:init()
  sceneManager:addScene(self)
end

function replayBrowser:load()
  reset_filters()
  
  if Replay.lastPath then
    current_path = string.sub(Replay.lastPath, (string.len(base_path) + 1)) .. "/"
  end

  state = "browser"
  updateBrowsingPath()

  GAME.renderDuringPause = true
end

function replayBrowser:drawBackground()
  themes[config.theme].images.bg_main:draw()
end

function replayBrowser:update()
  local ret = nil

  if state == "browser" then
    gprint(loc("rp_browser_header"), menu_x + 170, menu_y - 40)
    gprint(loc("rp_browser_current_dir", base_path .. current_path), menu_x, menu_y - 40 + menu_h)
    replayMenu()

    if input.isDown["MenuEsc"] then
      sceneManager:switchToScene("mainMenu")
    end
    if input.isDown["MenuSelect"] then
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      if selectMenuItem() then
        state = "info"
      end
    end
    if input.isDown["MenuBack"] then
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      setPathToParentDir()
    end
    if input.isDown["MenuUp"] then
      play_optional_sfx(themes[config.theme].sounds.menu_move)
      moveCursor(-1)
    end
    if input.isDown["MenuDown"] then
      play_optional_sfx(themes[config.theme].sounds.menu_move)
      moveCursor(1)
    end
  elseif state == "info" then
    local next_func = nil
    if Replay.replayCanBeViewed(replay) == false then
      gprint(loc("rp_browser_wrong_version"), menu_x - 150, menu_y - 80 + menu_h)
    end
    
    gprint(loc("rp_browser_info_header"), menu_x + 170, menu_y - 40)
    gprint(filename, menu_x - 150, menu_y - 40 + menu_h)
    if replay.vs then
      -- This used to be calculated based on the length of "O", but that no longer always exists.
      -- "I" will always exist for two player vs
      local twoPlayerVs = replay.vs.I and string.len(replay.vs.I) > 0
      local modeText
      if twoPlayerVs then
        modeText = loc("rp_browser_info_2p_vs")
      else
        modeText = loc("rp_browser_info_1p_vs")
      end
      gprint(modeText, menu_x + 220, menu_y + 20)

      gprint(loc("rp_browser_info_1p"), menu_x, menu_y + 50)
      gprint(loc("rp_browser_info_name", replay.vs.P1_name), menu_x, menu_y + 65)
      gprint(loc("rp_browser_info_level", replay.vs.P1_level), menu_x, menu_y + 80)
      gprint(loc("rp_browser_info_character", replay.vs.P1_char), menu_x, menu_y + 95)

      if twoPlayerVs then
        gprint(loc("rp_browser_info_2p"), menu_x + 300, menu_y + 50)
        gprint(loc("rp_browser_info_name", replay.vs.P2_name), menu_x + 300, menu_y + 65)
        gprint(loc("rp_browser_info_level", replay.vs.P2_level), menu_x + 300, menu_y + 80)
        gprint(loc("rp_browser_info_character", replay.vs.P2_char), menu_x + 300, menu_y + 95)

        if replay.vs.ranked then
          gprint(loc("rp_browser_info_ranked"), menu_x + 200, menu_y + 120)
        end
      end
    elseif replay.endless or replay.time then
      if replay.time then
        gprint(loc("rp_browser_info_time"), menu_x + 220, menu_y + 20)
      else
        gprint(loc("rp_browser_info_endless"), menu_x + 220, menu_y + 20)
      end

      local replay = replay.endless or replay.time
      gprint(loc("rp_browser_info_speed", replay.speed), menu_x + 150, menu_y + 50)
      gprint(loc("rp_browser_info_difficulty", replay.difficulty), menu_x + 150, menu_y + 65)
    elseif replay.puzzle then
      gprint(loc("rp_browser_info_puzzle"), menu_x + 220, menu_y + 20)

      gprint(loc("rp_browser_no_info"), menu_x + 150, menu_y + 50)
    else
      gprint(loc("rp_browser_error_unknown_replay_type"), menu_x + 220, menu_y + 20)
    end
    if Replay.replayCanBeViewed(replay) then
      gprint(loc("rp_browser_watch"), menu_x + 75, menu_y + 150)
    end

    if input.isDown["MenuEsc"] or input.isDown["MenuBack"] then
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      state = "browser"
    end
    if input.isDown["MenuSelect"] and Replay.replayCanBeViewed(replay) then
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      sceneManager:switchToScene("replayGame", {})
    end
  end
end

function replayBrowser:unload()
  stop_the_music()
end

return replayBrowser