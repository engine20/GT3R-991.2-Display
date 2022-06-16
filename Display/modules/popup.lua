local popup = {
  clients = {},
  --- updates all popups
  ---@param self any
  update = function(self)
    local tempTable = Utils.shallow_copy(self.clients);
    for k, e in pairs(self.clients) do
      if not e.active then
        table.remove(tempTable, k)
      else
        e:display();
      end
      self.clients = tempTable;
    end

    -- destroy oldest popups when maximum is exceeded
    if _CFG.maxpopups > 1 then
      if #self.clients > _CFG.maxpopups then
        for i = 1, #self.clients - _CFG.maxpopups, 1 do table.remove(self.clients, 1) end
      end
    else
      if #self.clients > 1 then table.remove(self.clients, 1) end
    end
    ac.debug('Popups', #self.clients)
  end,
  ---Creates a new popup
  ---@param self any
  ---@param duration number
  ---@param displayCallback fun():nil
  ---@return integer
  new = function(self, duration, displayCallback)
    local o = {startTime = G.time, duration = duration, displayCallback = displayCallback};
    setmetatable(o, self);
    self.__index = self;
    table.insert(self.clients, o);
    return #self.clients; -- return the index of the new entry
  end,
  duration = 0,
  startTime = 0,
  displayCallback = function() end,
  active = true,
  display = function(self)
    if ((self.startTime + self.duration) > G.time) then
      self.displayCallback();
      return;
    end
    self.active = false;
  end
}

return popup;
