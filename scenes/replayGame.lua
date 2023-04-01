local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local consts = require("consts")
local util = require("util")
local Replay = require("replay")

--@module replayGame
local replayGame = GameBase("replayGame", {})

function replayGame:customLoad(scene_params)
  self.frameAdvance = false
  self.playbackSpeed = 1
  self.maximumSpeed = 20

  Replay.loadFromFile(replay)
end

function replayGame:customRun()
  -- If we just finished a frame advance, pause again
  if self.frameAdvance then
    self.frameAdvance = false
    GAME.gameIsPaused = true
  end

  -- Advance one frame
  if input:isPressedWithRepeat("Swap1", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) and not self.frameAdvance then
    self.frameAdvance = true
    GAME.gameIsPaused = false
    if GAME.match.P1 then
      GAME.match.P1.max_runs_per_frame = 1
    end
    if GAME.match.P2 then
      GAME.match.P2.max_runs_per_frame = 1
    end
  elseif input:isPressedWithRepeat("Right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.playbackSpeed = util.bound(1, self.playbackSpeed + 1, self.maximumSpeed)
    if GAME.match.P1 then
      GAME.match.P1.max_runs_per_frame = self.playbackSpeed
    end
    if GAME.match.P2 then
      GAME.match.P2.max_runs_per_frame = self.playbackSpeed
    end
  elseif input:isPressedWithRepeat("Left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.playbackSpeed = util.bound(1, self.playbackSpeed - 1, self.maximumSpeed)
    if GAME.match.P1 then
      GAME.match.P1.max_runs_per_frame = self.playbackSpeed
    end
    if GAME.match.P2 then
      GAME.match.P2.max_runs_per_frame = self.playbackSpeed
    end
  end
end

function replayGame:abortGame()
  sceneManager:switchToScene("replayBrowser")
end

function replayGame:customGameOverSetup()
  self.nextScene = "replayBrowser"
  self.nextSceneParams = nil

  if GAME.match.P2 and GAME.match.battleRoom:matchOutcome() then
    local matchOutcome = GAME.match.battleRoom:matchOutcome()
    self.text = matchOutcome["end_text"]
    self.winner_SFX = matchOutcome["winSFX"]
  else
    self.winner_SFX = GAME.match.P1:pick_win_sfx()
  end
end

return replayGame