local config = require("config")
local config_metadata = require("config_metadata")
local replay_browser = require("replay_browser")
local json = require("dkjson")
local tableUtils = require("tableUtils")
local inputManager = require("inputManager")
local fileUtils = require("fileUtils")
local logger = require("logger")

-- @module save
-- the save.lua file contains the read/write functions
local save = {}

local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

-- writes to the "keys.txt" file
function write_key_file()
  pcall(
    function()
      local file = love.filesystem.newFile("keysV3.txt")
      file:open("w")
      file:write(json.encode(GAME.input.inputConfigurations))
      file:close()
    end
  )
end

-- reads the .txt file of the given path and filename
function save.read_txt_file(path_and_filename)
  local s
  pcall(
    function()
      local file = love.filesystem.newFile(path_and_filename)
      file:open("r")
      s = file:read(file:getSize())
      file:close()
    end
  )
  if not s then
    s = "Failed to read file" .. path_and_filename
  else
    s = s:gsub("\r\n?", "\n")
  end
  return s or "Failed to read file"
end

-- reads the "keys.txt" file
function save.read_key_file()
  local file = love.filesystem.newFile("keysV3.txt")
  local ok, err = file:open("r")
  local migrateInputs = false
  
  if not ok then
    file = love.filesystem.newFile("keysV2.txt")
    ok, err = file:open("r")
    migrateInputs = true
  end
  
  if not ok then
    return GAME.input.inputConfigurations
  end
  
  local jsonInputConfig = file:read(file:getSize())
  file:close()
  
  local inputConfigs = json.decode(jsonInputConfig)
  
  if migrateInputs then
    -- migrate old input configs
    inputConfigs = inputManager:migrateInputConfigs(inputConfigs)
  end
  
  return inputConfigs
end

-- reads the .txt file of the given path and filename
function save.read_txt_file(path_and_filename)
  local s
  pcall(
    function()
      local file = love.filesystem.newFile(path_and_filename)
      file:open("r")
      s = file:read(file:getSize())
      file:close()
    end
  )
  if not s then
    s = "Failed to read file" .. path_and_filename
  else
    s = s:gsub("\r\n?", "\n")
  end
  return s or "Failed to read file"
end

-- writes to the "conf.json" file
function write_conf_file()
  pcall(
    function()
      local file = love.filesystem.newFile("conf.json")
      file:open("w")
      file:write(json.encode(GAME.config))
      file:close()
    end
  )
end

-- writes to the "conf.json" file
function save.write_conf_file()
  pcall(
    function()
      local file = love.filesystem.newFile("conf.json")
      file:open("w")
      file:write(json.encode(GAME.config))
      file:close()
    end
  )
end

-- reads the "conf.json" file
-- falls back to the default config
function save.readConfigFile()
  local file = love.filesystem.newFile("conf.json")
  local ok, err = file:open("r")
  
  if not ok then
    return config
  end
  
  local json_user_config = file:read(file:getSize())
  local user_config = json.decode(json_user_config)
  
  -- do stuff using read_data.version for retrocompatibility here
  -- language_code, panels, character and stage are patched later on by their own subsystems, we store their values in config for now!
  for key, value in pairs(config) do
    if user_config[key] ~= nil
        and type(user_config[key]) == type(config[key]) 
        and (not config_metadata.isValid[key] or config_metadata.isValid[key](user_config[key])) then
      if config_metadata.processValue[key] then
        user_config[key] = config_metadata.processValue[key](user_config[key])
      end
    else
      user_config[key] = value
    end
  end

  file:close()
  return user_config
end

-- writes to the "user_id.txt" file of the directory of the connected ip
function write_user_id_file()
  pcall(
    function()
      love.filesystem.createDirectory("servers/" .. GAME.connected_server_ip)
      local file = love.filesystem.newFile("servers/" .. GAME.connected_server_ip .. "/user_id.txt")
      file:open("w")
      file:write(tostring(my_user_id))
      file:close()
    end
  )
end

-- reads the "user_id.txt" file of the directory of the connected ip
function read_user_id_file()
  pcall(
    function()
      local file = love.filesystem.newFile("servers/" .. GAME.connected_server_ip .. "/user_id.txt")
      file:open("r")
      my_user_id = file:read()
      file:close()
      my_user_id = my_user_id:match("^%s*(.-)%s*$")
    end
  )
end

-- writes the stock puzzles
function write_puzzles()
  pcall(
    function()
      local currentPuzzles = fileUtils.getFilteredDirectoryItems("puzzles") or {}
      local customPuzzleExists = false
      for _, filename in pairs(currentPuzzles) do
        if love.filesystem.getInfo("puzzles/" .. filename) and filename ~= "stock (example).json" and filename ~= "README.txt" then
          customPuzzleExists = true
          break
        end
      end

      if customPuzzleExists == false then
        love.filesystem.createDirectory("puzzles")

        fileUtils.recursiveCopy("default_data/puzzles", "puzzles")
      end
    end
  )
end

-- reads the selected puzzle file
function read_puzzles()
  pcall(
    function()
      -- if type(replay.in_buf) == "table" then
      -- replay.in_buf=table.concat(replay.in_buf)
      -- end

      puzzle_packs = fileUtils.getFilteredDirectoryItems("puzzles") or {}
      logger.debug("loading custom puzzles...")
      for _, filename in pairs(puzzle_packs) do
        logger.trace(filename)
        if love.filesystem.getInfo("puzzles/" .. filename) and filename ~= "README.txt" then
          logger.debug("loading custom puzzle set: " .. (filename or "nil"))
          local current_set = {}
          local file = love.filesystem.newFile("puzzles/" .. filename)
          file:open("r")
          local teh_json = file:read(file:getSize())
          file:close()
          local current_json = json.decode(teh_json) or {}
          if current_json["Version"] == 2 then
            for _, puzzleSet in pairs(current_json["Puzzle Sets"]) do
              local puzzleSetName = puzzleSet["Set Name"]
              local puzzles = {}
              for _, puzzle in pairs(puzzleSet["Puzzles"]) do
                local puzzle = Puzzle(puzzle["Puzzle Type"], puzzle["Do Countdown"], puzzle["Moves"], puzzle["Stack"], puzzle["Stop"], puzzle["Shake"])
                puzzles[#puzzles + 1] = puzzle
              end

              local puzzleSet = PuzzleSet(puzzleSetName, puzzles)
              GAME.puzzleSets[puzzleSetName] = puzzleSet
            end
          else -- old file format compatibility
            for set_name, puzzle_set in pairs(current_json) do
              local puzzles = {}
              for _, puzzleData in pairs(puzzle_set) do
                local puzzle = Puzzle("moves", true, puzzleData[2], puzzleData[1])
                puzzles[#puzzles + 1] = puzzle
              end

              local puzzleSet = PuzzleSet(set_name, puzzles)
              GAME.puzzleSets[set_name] = puzzleSet
            end
          end

          logger.debug("loaded above set")
        end
      end
    end
  )
end

function save.read_attack_files(path)
  local lfs = love.filesystem
  local raw_dir_list = lfs.getDirectoryItems(path)
  for i, v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v, 0, string.len(prefix_of_ignored_dirs))
    if start_of_v ~= prefix_of_ignored_dirs then
      local current_path = path .. "/" .. v
      if lfs.getInfo(current_path) then
        if lfs.getInfo(current_path).type == "directory" then
          read_attack_files(current_path)
        elseif v ~= ".DS_Store" then
          local file = love.filesystem.newFile(current_path)
          file:open("r")
          local teh_json = file:read(file:getSize())
          local training_conf = {}
          for k, w in pairs(json.decode(teh_json)) do
            training_conf[k] = w
          end
          if not training_conf.name or not type(training_conf.name) == "string" then
            training_conf.name = v
          end
          trainings[#trainings+1] = training_conf
          file:close()
        end
      end
    end
  end
end

function read_attack_files(path)
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for i, v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v, 0, string.len(prefix_of_ignored_dirs))
    if start_of_v ~= prefix_of_ignored_dirs then
      local current_path = path .. "/" .. v
      if lfs.getInfo(current_path) then
        if lfs.getInfo(current_path).type == "directory" then
          read_attack_files(current_path)
        elseif v ~= ".DS_Store" then
          local file = love.filesystem.newFile(current_path)
          file:open("r")
          local teh_json = file:read(file:getSize())
          file:close()
          local training_conf = {}
          for k, w in pairs(json.decode(teh_json)) do
            training_conf[k] = w
          end
          if not training_conf.name or not type(training_conf.name) == "string" then
            training_conf.name = v
          end
          trainings[#trainings+1] = training_conf
        end
      end
    end
  end
end

function print_list(t)
  for i, v in ipairs(t) do
    print(v)
  end
end


return save