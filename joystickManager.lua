local tableUtils = require("tableUtils")

--@module joystickManager
local joystickManager = {
  guidToName = {},
  
  -- list of {directions, axis} pairs for the 8 cardinal directions
  stickMap = { 
    {{"-", "x"}}, 
    {{"-", "x"}, {"-", "y"}}, 
    {{"-", "y"}}, 
    {{"+", "x"}, {"-", "y"}}, 
    {{"+", "x"}}, 
    {{"+", "x"}, {"+", "y"}}, 
    {{"+", "y"}}, 
    {{"-", "x"}, {"+", "y"}} 
  },
  
  -- TODO: Convert this into a list of sensitivities per player
  joystickSensitivity = .5,
}

-- mapping of GUID to map of joysticks under that GUID (GUIDs are unique per controller type)
-- the joystick map is a list of {joystickID: customJoystickID}
-- the custom joystick id is a number starting at 0 and increases by 1 for each new joystick of that type
-- this is to give each joystick an id that will remain consistant over multiple sessions (the joystick IDs can change per session)
local guidsToJoysticks = {}

function joystickManager:getJoystickButtonName(joystick, button) 
  if not guidsToJoysticks[joystick:getGUID()] then 
    guidsToJoysticks[joystick:getGUID()] = {} 
    self.guidToName[joystick:getGUID()] = joystick:getName() 
  end 
  if not guidsToJoysticks[joystick:getGUID()][joystick:getID()] then 
    guidsToJoysticks[joystick:getGUID()][joystick:getID()] = tableUtils.length(guidsToJoysticks[joystick:getGUID()]) 
  end 
  return string.format("%s:%s:%s", button, joystick:getGUID(), guidsToJoysticks[joystick:getGUID()][joystick:getID()]) 
end 

 -- maps joysticks to buttons by converting the {x, y} axis values to {direction, magnitude} pair
 -- this will give more even mapping along the diagonals when thresholded by a single value (joystickSensitivity)
function joystickManager:joystickToDPad(joystick, axis)
  local x = axis.."x" 
  local y = axis.."y"

  local dpadState = {
    [joystickManager:getJoystickButtonName(joystick, "+"..x)] = false,
    [joystickManager:getJoystickButtonName(joystick, "-"..x)] = false,
    [joystickManager:getJoystickButtonName(joystick, "+"..y)] = false,
    [joystickManager:getJoystickButtonName(joystick, "-"..y)] = false
  }
  
  -- not taking the square root to get the magnitude since it's it more expensive than squaring the joystickSensitivity
  local magSquared = joystick:getGamepadAxis(x) * joystick:getGamepadAxis(x) + joystick:getGamepadAxis(y) * joystick:getGamepadAxis(y)
  local dir = math.atan2(joystick:getGamepadAxis(y), joystick:getGamepadAxis(x)) * 180.0 / math.pi
  -- atan2 maps to [-180, 180] the quantizedDir equation prefers positive numbers (due to modulo) so mapping to [0, 360]
  dir = dir + 180
  -- number of segments we are quantizing the joystick values to
  local numDirSegments = #self.stickMap
  -- the minimum angle we care to detect
  local quantizationAngle = 360.0 / numDirSegments
  -- if we quantized the raw direction the direction wouldn't register until you are greater than the direction
  -- Ex: quantizedDir would be 0 (left) until you hit exactly 45deg before it changes to 1 (left, up) and would stay there until you are at 90deg
  -- adding this offset so the transition is equidistant from both sides of the direction
  -- Ex: quantizedDir is 1 (left, up) from the range [22.5, 67.5]
  local angleOffset = quantizationAngle / 2
  -- convert the continuous direction value into 8 quantized values which map to the stickMap indexes
  local quantizedDir = math.floor(((dir + angleOffset) / quantizationAngle) % numDirSegments) + 1 

  for _, button in ipairs(joystickManager.stickMap[quantizedDir]) do 
    local key = joystickManager:getJoystickButtonName(joystick, button[1]..axis..button[2])
    if magSquared > self.joystickSensitivity * self.joystickSensitivity then 
      dpadState[key] = true
    end
  end
  return dpadState
end 

return joystickManager