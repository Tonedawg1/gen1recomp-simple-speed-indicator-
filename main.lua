-- Speed Indicator
-- Flashes the current game-speed multiplier in the bottom-left
-- when speed changes. Works on Gen 1 (Red/Blue/Yellow) and Gen 2 (Gold/Silver).

return function(mod)
  local GameSpeed = require("src.core.GameSpeed")

  local FLASH_DURATION = 1.25
  local FADE_START     = 0.85
  local MARGIN         = 8

  local state = {
    label   = nil,
    until_t = 0,
    last    = nil,
  }

  local function now()
    return (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
  end

  -- Resolve the active multiplier for either generation.
  local function currentSpeed(game)
    if not game then return 1 end

    -- Gen 2: single options.speed
    local opts = game.options or (game.save and game.save.options)
    if opts and opts.speed ~= nil then
      return GameSpeed.clamp(opts.speed)
    end

    -- Gen 1: try the live method if present
    if type(game.logicSpeed) == "function" then
      local ok, mult = pcall(game.logicSpeed, game)
      if ok and mult then return GameSpeed.clamp(mult) end
    end

    -- Gen 1 fallback: per-category keys (use overworld as default)
    if opts then
      local v = opts.speedOverworld or opts.speedBattle or opts.speedMenu
      if v then return GameSpeed.clamp(v) end
    end

    return 1
  end

  -- Still wrap Gen 1's hook when it exists (more precise timing there)
  mod.hooks:wrap("core.logic_speed", function(next, game)
    local mult = next(game)
    if state.last ~= nil and mult ~= state.last then
      state.label   = GameSpeed.levelLabel(mult)
      state.until_t = now() + FLASH_DURATION
    end
    state.last = mult
    return mult
  end)

  -- Poll on every drawn frame — this is what makes Gen 2 work
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    next(game, viewport)

    local mult = currentSpeed(game)
    if state.last ~= nil and mult ~= state.last then
      state.label   = GameSpeed.levelLabel(mult)
      state.until_t = now() + FLASH_DURATION
    end
    state.last = mult

    if not state.label then return end
    local t = now()
    if t >= state.until_t then
      state.label = nil
      return
    end

    local remaining = state.until_t - t
    local progress  = 1 - (remaining / FLASH_DURATION)
    local alpha = 1
    if progress > FADE_START then
      alpha = 1 - (progress - FADE_START) / (1 - FADE_START)
    end
    if alpha <= 0 then return end

    local lg = love and love.graphics
    if not (lg and lg.print) then return end

    local scale = 1
    if viewport and viewport.scale and viewport.scale >= 2 then
      scale = math.max(1, math.floor(viewport.scale * 0.75 + 0.5))
    end

    local text = state.label
    local x = MARGIN
    local y = (lg.getHeight and lg.getHeight() or 144) - MARGIN
              - (lg.getFont and lg.getFont():getHeight() or 16) * scale

    lg.setColor(0, 0, 0, 0.75 * alpha)
    lg.print(text, x + 1 * scale, y + 1 * scale, 0, scale, scale)
    lg.setColor(1, 1, 1, alpha)
    lg.print(text, x, y, 0, scale, scale)
    lg.setColor(1, 1, 1, 1)
  end)
end