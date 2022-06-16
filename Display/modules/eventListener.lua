local eventListener = {
  clients = {},
  ---checks for changes
  ---@param self any
  update = function(self) for _, e in pairs(self.clients) do e:listen() end end,
  ---creates a new EventListener that executes the callback upon change of the value, and return the index of the new entry
  ---@param self any
  ---@param getter fun():any
  ---@param callback fun(diff:number, newVal:number, prevVal: number):nil
  ---@return number
  new = function(self, getter, callback)
    local o = {getter = getter, callback = callback, lastvalue = getter()};
    setmetatable(o, self);
    self.__index = self;
    table.insert(self.clients, o);
    return #self.clients; -- return the index of the new entry
  end,
  lastvalue = nil,
  getter = function() end,
  callback = function() end,
  listen = function(self)
    if (self.lastvalue ~= self.getter()) then
      pcall(function()
        self.callback(Utils.btn(self.getter()) - Utils.btn(self.lastvalue), self.getter(), self.lastvalue)
      end);
      self.lastvalue = self.getter();
    end
  end
}
return eventListener;
