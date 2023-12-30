require("class")
socket = require("socket")
GAME = require("Game")
require("match")
local RunTimeGraph = require("RunTimeGraph")
require("BattleRoom")
require("util")
local tableUtils = require("tableUtils")
local consts = require("consts")
require("FileUtil")
require("queue")
require("globals")
require("character_loader") -- after globals!
local CustomRun = require("CustomRun")
require("stage") -- after globals!
require("save")
require("engine.GarbageQueue")
require("engine.telegraph")
require("engine")
require("engine.checkMatches")
require("AttackEngine")
require("localization")
require("graphics")
GAME.input = require("input")
require("replay")
require("network")
require("Puzzle")
require("PuzzleSet")
require("puzzles")
require("mainloop")
require("sound")
require("timezones")
require("gen_panels")
require("panels")
require("Theme")
local utf8 = require("utf8Additions")
require("click_menu")
require("computerPlayers.computerPlayer")
require("rich_presence.RichPresence")

-- We override love.run with a function that refers to `pa_runInternal` for its gameloop function
-- so by overwriting that, the new runInternal will get used on the next iteration
love.pa_runInternal = CustomRun.innerRun
if GAME_UPDATER == nil then
  -- We don't have an autoupdater, so we need to override run.
  -- In the autoupdater case run will already have been overridden and be running
  love.run = CustomRun.run
end

local crashTrace = nil -- set to the trace of your thread before throwing an error if you use a coroutine

if PROFILING_ENABLED then
  GAME.profiler = require("profiler")
end

local logger = require("logger")
GAME.scores = require("scores")
GAME.rich_presence = RichPresence()


local last_x = 0
local last_y = 0
local input_delta = 0.0
local pointer_hidden = false
local mainloop = nil


-- local cpml = require "cpml"
-- local vertices = require "cube"

--[[local vertices = {
	--bottom              -- first 3 numbers is x , y, z for vertex
	                      -- second 2 are UV data to match the texture to the mesh
	                      -- 3 vertices to a triangle 2 triangles to a face of the cube
	{-1, 1, -1,  0,0},
	{1, 1, -1,   1,0},
	{-1, -1, -1, 0,1},

	{1, 1, -1,   1,0},
	{1, -1, -1,  1,1},
	{-1, -1, -1, 0,1},

	--top
	{-1, 1, 1,   0,0},
	{1, 1, 1,    1,0},
	{-1, -1, 1,  0,1},

	{1, 1, 1,    1,0},
	{1, -1, 1,   1,1},
	{-1, -1, 1,  0,1},

	--right side
	{1, 1, -1,   1,0},
	{1, 1, 1,    1,1},
	{1, -1, -1,  0,0},

	{1, 1, 1,    1,1},
	{1, -1, 1,   0,1},
	{1, -1, -1,  0,0},

	--left side
	{-1, 1, -1,  1,0},
	{-1, 1, 1,   1,1},
	{-1, -1, -1, 0,0},

	{-1, 1, 1,   1,1},
	{-1, -1, 1,  0,1},
	{-1, -1, -1, 0,0},

	--back side
	{-1, 1, 1,   0,1},
	{1, 1, 1,    1,1},
	{-1, 1, -1,  0,0},

	{1, 1, 1,    1,1},
	{1, 1, -1,   1,0},
	{-1, 1, -1,  0,0},

	--front side
	{-1, -1, 1,  0,1},
	{1, -1, 1,   1,1},
	{-1, -1, -1, 0,0},

	{1, -1, 1,   1,1},
	{1, -1, -1,  1,0},
	{-1, -1, -1, 0,0},

}--]]
local vertices = {
  {0, 0, 0,  0,0},
	{0, 1, 0,  0,1},
	{1, 1, 0,  1,1},
	
  {0, 0, 0,  0,0},
	{1, 0, 0,  1,0},
	{1, 1, 0,  1,1}}

local shader

--initial position and angle of Camera
--[[local cameraPos = cpml.vec3(0, 0, -15)
local angle     = cpml.vec2(0, 0)

--initial transforms for the cubes
local cube1 = cpml.mat4.identity()
cube1:translate(cube1, cpml.vec3(1,0,0))

local cube2 = cpml.mat4.identity()
cube2:translate(cube2, cpml.vec3(5,4,0))
--]]


--Custom vertex format add z to vertex position
local format = {
	{
		"VertexPosition",
		"float",
		3
	},
	{
		"VertexTexCoord",
		"float",
		2
	},
}

local function createCylinderMesh()
  local mesh = {}
  local numSegments = 32
  for i = 0, numSegments - 1 do
    local pos = i / numSegments
    local nextPos = (i + 1) / numSegments
    table.insert(mesh, {math.cos(-2*math.pi*pos), -1, math.sin(-2*math.pi*pos),  pos,0})
    table.insert(mesh, {math.cos(-2*math.pi*pos), 1, math.sin(-2*math.pi*pos),  pos,1})
    table.insert(mesh, {math.cos(-2*math.pi*nextPos), 1, math.sin(-2*math.pi*nextPos),  nextPos,1})
    
    table.insert(mesh, {math.cos(-2*math.pi*pos), -1, math.sin(-2*math.pi*pos),  pos,0})
    table.insert(mesh, {math.cos(-2*math.pi*nextPos), -1, math.sin(-2*math.pi*nextPos),  nextPos,0})
    table.insert(mesh, {math.cos(-2*math.pi*nextPos), 1, math.sin(-2*math.pi*nextPos),  nextPos,1})
  end
  return mesh
end

local function setup3dMode()
	--load texture 

	--love.graphics.setBackgroundColor(.5,.5,.5)

	--Creates mesh using our format and vertices. It will be drawn as a set of triangles
	--We set the texture to our image and load our shader.
  --print(dump(createCylinderMesh()))
	mesh3d = love.graphics.newMesh(format, createCylinderMesh(), "triangles")
  --mesh3d = love.graphics.newMesh(format, vertices, "triangles")
	shader = love.graphics.newShader("basicRender.glsl")

	--Sets DepthMode. Prevents items being drawn out of order
  cursorPos = {0, 0}
end

-- Called at the beginning to load the game
function love.load()

  if PROFILING_ENABLED then
    GAME.profiler:start()
  end
  
  love.graphics.setDefaultFilter("linear", "linear")
  if config.maximizeOnStartup and not love.window.isMaximized() then
    love.window.maximize()
  end
  local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
  GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
  math.randomseed(os.time())
  for i = 1, 4 do
    math.random()
  end
  read_key_file()
  GAME.rich_presence:initialize("902897593049301004")
  mainloop = coroutine.create(fmainloop)

  GAME.globalCanvas = love.graphics.newCanvas(canvas_width, canvas_height, {dpiscale=GAME:newCanvasSnappedScale()})
  
  setup3dMode()
end

function love.focus(f)
  GAME.focused = f
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)

  if config.show_fps and config.debug_mode then
    if CustomRun.runTimeGraph == nil then
      CustomRun.runTimeGraph = RunTimeGraph()
    end
  else
    CustomRun.runTimeGraph = nil
  end

  if love.mouse.getX() == last_x and love.mouse.getY() == last_y then
    if not pointer_hidden then
      if input_delta > mouse_pointer_timeout then
        pointer_hidden = true
        love.mouse.setVisible(false)
      else
        input_delta = input_delta + dt
      end
    end
  else
    last_x = love.mouse.getX()
    last_y = love.mouse.getY()
    input_delta = 0.0
    if pointer_hidden then
      pointer_hidden = false
      love.mouse.setVisible(true)
    end
  end

  leftover_time = leftover_time + dt

  GAME:update(dt)
  
  if GAME.backgroundImage then
    GAME.backgroundImage:update(dt)
  end

  local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
  if GAME.previousWindowWidth ~= newPixelWidth or GAME.previousWindowHeight ~= newPixelHeight then
    GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
    if GAME.match then
      GAME.needsAssetReload = true
    else
      GAME:refreshCanvasAndImagesForNewScale()
    end
    GAME.showGameScale = true
  end

  local status, errorString = coroutine.resume(mainloop)
  if not status then
    crashTrace = debug.traceback(mainloop)
    error(errorString)
  end
  if server_queue and server_queue:size() > 0 then
    logger.trace("Queue Size: " .. server_queue:size() .. " Data:" .. server_queue:to_short_string())
  end
  this_frame_messages = {}

  update_music()
  GAME.rich_presence:runCallbacks()
end

function draw3dMode(player)
	love.graphics.push("all")
  love.graphics.setDepthMode("lequal", true)
	--centers the world on the screen
	local w, h = love.graphics.getDimensions()
	love.graphics.translate(w/2, h/2)

	--Sends the view and model transforms to shader
  local fov = math.pi * 30 / 180
  local far = 50
  local near = 1
  local boardRatio = 936/612
  shader:send("perspective", {
      {1/((w/h)*math.tan(fov/2)), 0, 0, 0},-- -3.5
      {0, 1/(math.tan(fov/2)), 0, 0},
      {0, 0, -((far+near)/(far-near)), -((2*far*near)/(far-near))},
      {0, 0, -1, 0}})
  --[[shader:send("perspective", {
      {1, 0, 0, 0},
      {0, 1, 0, 0},
      {0, 0, 1, 0},
      {0, 0, 0, 1}})--]]
	shader:send("view", {
      {1, 0, 0, 0},
      {0, 1, 0, 0},
      {0, 0, 1, 0},
      {0, 0, 0, 1}})
	shader:send("model_matrix", {
      {1, 0, 0, 0}, -- -1
      {0, boardRatio, 0, .25},
      {0, 0, 1, -8},
      {0, 0, 0, 1}})
  shader:send("rotation", cursorPos[player]/18)
  shader:send("playerSide", player * 2 - 3)

	--Sets the shader
	love.graphics.setShader(shader)

	--Draw mesh and clear shader.
	love.graphics.setColor(1,0,0)
	love.graphics.draw(mesh3d)
	love.graphics.setShader()
  love.graphics.setDepthMode("always", true)
	love.graphics.pop()

	love.graphics.print("FPS " .. love.timer.getFPS(), 20, 20*6)
end

-- Called whenever the game needs to draw.
function love.draw()
  if GAME then
    GAME.isDrawing = true
  end

  -- Clear the screen
  love.graphics.setCanvas({GAME.globalCanvas, depth=true})
  love.graphics.setBackgroundColor(unpack(global_background_color))
  love.graphics.clear()

  -- draw background and its overlay
  if GAME.backgroundImage then
    GAME.backgroundImage:draw()
  end
  if GAME.background_overlay then
    local scale = canvas_width / math.max(GAME.background_overlay:getWidth(), GAME.background_overlay:getHeight()) -- keep image ratio
    menu_drawf(GAME.background_overlay, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end

  for i = gfx_q.first, gfx_q.last do
    gfx_q[i][1](unpack(gfx_q[i][2]))
  end
  gfx_q:clear()
  
  --draw3dMode()

  if GAME.foreground_overlay then
    local scale = canvas_width / math.max(GAME.foreground_overlay:getWidth(), GAME.foreground_overlay:getHeight()) -- keep image ratio
    menu_drawf(GAME.foreground_overlay, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end
  
  -- Draw the FPS if enabled
  if config ~= nil and config.show_fps then
    if not CustomRun.runTimeGraph then
      gprintf("FPS: " .. love.timer.getFPS(), 1, 1)
    end
  end

  if STONER_MODE then 
    gprintf("Lag Mode On, S:" .. GAME.sendNetworkQueue:length() .. " R:" .. GAME.receiveNetworkQueue:length(), 1, 1 + (11 * 4))
  end

  love.graphics.setCanvas() -- render everything thats been added
  love.graphics.clear(love.graphics.getBackgroundColor()) -- clear in preperation for the next render
    
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(GAME.globalCanvas, GAME.canvasX, GAME.canvasY, 0, GAME.canvasXScale, GAME.canvasYScale)
  love.graphics.setBlendMode("alpha", "alphamultiply")

  if GAME.showGameScale or config.debug_mode then
    local scaleString = "Scale: " .. GAME.canvasXScale .. " (" .. canvas_width * GAME.canvasXScale .. " x " .. canvas_height * GAME.canvasYScale .. ")"
    local newPixelWidth = love.graphics.getWidth()
    local font = get_global_font()
    local fontAscent = "Font Ascent: " .. font:getAscent()
    local fontDescent = "Font Descent: " .. font:getDescent()
    local fontBaseLine = "Font Baseline: " .. font:getBaseline()
    local fontHeight = "Font Height: " .. font:getHeight()
    local fontLineHeight = "Font Line Height: " .. font:getLineHeight()

    if canvas_width * GAME.canvasXScale > newPixelWidth then
      scaleString = scaleString .. " Clipped "
    end
    local bigFont = get_global_font_with_size(30)
    love.graphics.printf(scaleString, bigFont, 5, 5, 2000, "left")
    love.graphics.printf(fontAscent, bigFont, 5, 35, 2000, "left")
    love.graphics.printf(fontDescent, bigFont, 5, 65, 2000, "left")
    love.graphics.printf(fontBaseLine, bigFont, 5, 95, 2000, "left")
    love.graphics.printf(fontHeight, bigFont, 5, 125, 2000, "left")
    love.graphics.printf(fontLineHeight, bigFont, 5, 155, 2000, "left")

  end

  if DEBUG_ENABLED and love.system.getOS() == "Android" then
    local saveDir = love.filesystem.getSaveDirectory()
    love.graphics.printf(saveDir, get_global_font_with_size(30), 5, 50, 2000, "left")
  end

  if GAME then
    GAME.isDrawing = false
  end
end

-- Handle a mouse or touch press
function love.mousepressed(x, y)
  for menu_name, menu in pairs(CLICK_MENUS) do
    menu:click_or_tap(GAME:transform_coordinates(x, y))
  end
end

-- Handle a touch press
-- Note we are specifically not implementing this because mousepressed above handles mouse and touch
-- function love.touchpressed(id, x, y, dx, dy, pressure)
-- local _x, _y = GAME:transform_coordinates(x, y)
-- click_or_tap(_x, _y, {id = id, x = _x, y = _y, dx = dx, dy = dy, pressure = pressure})
-- end

function love.errorhandler(msg)

  if not love.window or not love.graphics or not love.event then
    return
  end

  if not love.graphics.isCreated() or not love.window.isOpen() then
    local success, status = pcall(love.window.setMode, 800, 600)
    if not success or not status then
      return
    end
  end

  msg = tostring(msg)
  local sanitizedMessageLines = {}
  for char in msg:gmatch(utf8.charpattern) do
    table.insert(sanitizedMessageLines, char)
  end
  local sanitizedMessage = table.concat(sanitizedMessageLines)

  local trace = crashTrace or debug.traceback("", 4)
  local traceLines = {}
  for l in trace:gmatch("(.-)\n") do
    if not l:match("boot.lua") and not l:match("stack traceback:") then
      table.insert(traceLines, l)
    end
  end
  local sanitizedTrace = table.concat(traceLines, "\n")
  
  local errorData = Game.errorData(sanitizedMessage, sanitizedTrace)
  local detailedErrorLogString = Game.detailedErrorLogString(errorData)
  errorData.detailedErrorLogString = detailedErrorLogString
  if GAME_UPDATER_GAME_VERSION then
    send_error_report(errorData)
  end

  local errorLines = {}
  table.insert(errorLines, "Error\n")
  table.insert(errorLines, detailedErrorLogString)
  if #sanitizedMessage ~= #msg then
    table.insert(errorLines, "Invalid UTF-8 string in error message.")
  end
  table.insert(errorLines, "\n")

  local messageToDraw = table.concat(errorLines, "\n")
  messageToDraw = messageToDraw:gsub("\t", "    ")
  messageToDraw = messageToDraw:gsub("%[string \"(.-)\"%]", "%1")

  print(messageToDraw)

  -- Reset state.
  if love.mouse then
    love.mouse.setVisible(true)
    love.mouse.setGrabbed(false)
    love.mouse.setRelativeMode(false)
    if love.mouse.isCursorSupported() then
      love.mouse.setCursor()
    end
  end
  if love.joystick then
    -- Stop all joystick vibrations.
    for i, v in ipairs(love.joystick.getJoysticks()) do
      v:setVibration()
    end
  end
  if love.audio then
    love.audio.stop()
  end

  love.graphics.reset()
  love.graphics.setFont(get_font_delta(4))
  love.graphics.setColor(1, 1, 1)
  love.graphics.origin()

  local scale = 1
  if GAME then
    scale = GAME:newCanvasSnappedScale()
    love.graphics.scale(scale, scale)
  end

  local function draw()
    if not love.graphics.isActive() then
      return
    end

    love.graphics.clear(love.graphics.getBackgroundColor())
    local positionX = 40
    local positionY = positionX
    love.graphics.printf(messageToDraw, positionX, positionY, love.graphics.getWidth() - positionX)

    love.graphics.present()
  end

  local fullErrorText = messageToDraw
  local function copyToClipboard()
    if not love.system then
      return
    end
    love.system.setClipboardText(fullErrorText)
    messageToDraw = messageToDraw .. "\nCopied to clipboard!"
  end

  if love.system then
    messageToDraw = messageToDraw .. "\n\nPress Ctrl+C or tap to copy this error"
  end

  return function()
    love.event.pump()

    for e, a, b, c in love.event.poll() do
      if e == "quit" then
        return 1
      elseif e == "keypressed" and a == "escape" then
        return 1
      elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
        copyToClipboard()
      elseif e == "touchpressed" then
        local name = love.window.getTitle()
        if #name == 0 or name == "Untitled" then
          name = "Game"
        end
        local buttons = {"OK", "Cancel"}
        if love.system then
          buttons[3] = "Copy to clipboard"
        end
        local pressed = love.window.showMessageBox("Quit " .. name .. "?", "", buttons)
        if pressed == 1 then
          return 1
        elseif pressed == 3 then
          copyToClipboard()
        end
      end
    end

    draw()

    if love.timer then
      love.timer.sleep(0.1)
    end
  end

end
