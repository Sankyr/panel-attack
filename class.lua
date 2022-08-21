function class(init)
  local c,mt = {},{}
  c.__index = c
  mt.__call = function(class_tbl, ...)
    local obj = {}
    setmetatable(obj,c)
    init(obj,...)
    return obj
  end
  setmetatable(c, mt)
  return c
end

--@module class
local class = function(init, parent)
  local class_tbl = {}
  local metatable = {
    __index = parent,
    __call = function(_, ...)
      local self = parent and parent(...) or {}
      setmetatable(self, { __index = class_tbl })
      init(self, ...)
      return self
    end
  }
  setmetatable(class_tbl, metatable)
  return class_tbl
end

return class