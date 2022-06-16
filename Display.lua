INF = 1e308
local legacy = ac.getPatchVersionCode() <= 1709
if legacy then ac.log('Running Legacy Mode!') end
local simObject = legacy and ac.getSimState() or ac.getSim();
local wheelstate = {discTemp = 0, brakeForce = 0}
local carstate = {
  page = _CFG.defaultPage, -- defines the first page upon loading
  gear = 0,
  geardelay = 0,
  maxstintfuel = 0,
  fuelPerLap = 0
}
local exec = {time = 0, firstrun = true, run = 0, distanceTravelledlastframe = 0}

ac.debug('page', carstate.page)
ac.debug('Popups', 0)

-- ################### UTIL FUNCTIONS #########################

function table.shallow_copy(t)
  local t2 = {}
  for k, v in pairs(t) do t2[k] = v end
  return t2
end

carstate.wheels = {}; -- [0] = FL, [1] = FR, [2] = RL, [3] = RR
for i = 0, 3 do table.insert(carstate.wheels, i, table.shallow_copy(wheelstate)) end

string.extend = function(input, lenght, char)
  local v = input
  if lenght == 0 then
    return input
  else
    for i = 1, lenght do v = v .. (char or string.sub(input, -1, -1)) end
  end
  return v
end

math.randomseed(os.time())
math.random()
math.random()
math.random()
math.random()
math.random()

local twodigits = function(input)
  return tonumber(input) < 10 and '0' .. tonumber(input) or (tonumber(input) >= 100 and '99' or tonumber(input))
end

local dec = function(input, decimals, seperator) -- have fun reading
  return
    string.len(math.floor(input * 10 ^ decimals) / 10 ^ decimals) - string.len(math.floor(input)) < decimals + 1 and
      string.gsub(math.floor(input * 10 ^ decimals) / 10 ^ decimals, '%.', seperator or '.') ..
      (string.len(math.floor(input * 10 ^ decimals) / 10 ^ decimals) - string.len(math.floor(input)) ~= decimals and
        (seperator or '.') or '') .. string.extend('0', decimals - 1 -
                                                     (string.len(math.floor(input * 10 ^ decimals) / 10 ^ decimals) -
                                                       string.len(math.floor(input)))) or
      string.gsub(math.floor(input * 10 ^ decimals) / 10 ^ decimals, '%.', seperator or '.')
end

local timeformat = function(input, seperator, millis, nullonempty) -- same for this one
  return input ~= 0 and (((tonumber(string.sub(tostring(input), 1, -4)) or 0) > 59 and
           math.floor((tonumber(string.sub(tostring(input), 1, -4)) or 0) / 60) or 0) .. (seperator[1] or ':') ..
           twodigits((tonumber(string.sub(tostring(input), 1, -4)) or 0) -
                       ((tonumber(string.sub(tostring(input), 1, -4)) or 0) > 59 and
                         math.floor((tonumber(string.sub(tostring(input), 1, -4)) or 0) / 60) or 0) * 60) ..
           (seperator[2] or ':') .. string.sub(tostring(input), -3, (millis or 2) - 4)) or
           ((nullonempty and '0' or '--') .. (seperator[1] or ':') .. (nullonempty and '00' or '--') ..
             (seperator[2] or ':') ..
             (nullonempty and string.sub('000', 1, (millis or 2) - 4) or string.sub('---', 1, (millis or 2) - 4)))
end

local mixcolors = function(factor, color1, color2)
  return rgbm(color1.rgb.r - math.min(math.max(factor, 0), 1) * (color1.rgb.r - color2.rgb.r),
              color1.rgb.g - math.min(math.max(factor, 0), 1) * (color1.rgb.g - color2.rgb.g),
              color1.rgb.b - math.min(math.max(factor, 0), 1) * (color1.rgb.b - color2.rgb.b), 1)
end

local displayText = function(text, posx, posy, size, font, color, align)
  local lastx = posx

  local digitswidth = 22
  local symbolwidth = 14
  local alphabeticwidth = legacy and 32 or 22

  local alignmentoffset = (align == 'left' and 0 or
                            (select(2, string.gsub(text, '%d', '')) * digitswidth +
                              select(2, string.gsub(text, '%a', '')) * alphabeticwidth +
                              (string.len(text) - select(2, string.gsub(text, '%d', ''))) * 10) /
                            (align == 'center' and 2 or 1)) * size

  for i = 1, string.len(text) do
    local numeric = string.find(string.sub(text, i, i), '%d') and true or false
    local alphabetic = string.find(string.sub(text, i, i), '%a') and true or false

    display.text({
      text = string.sub(text, i, i),
      pos = vec2((numeric and lastx or
                   (alphabetic and lastx + (size ^ ((1 - size) / 8 + 1.15) * 10) - 5 or lastx + (legacy and 5 or 0) +
                     size ^ ((1 - size)))) - alignmentoffset,
                 numeric and posy or (alphabetic and posy or posy + size * 10)),
      letter = vec2(numeric and digitswidth * size or (alphabetic and (alphabeticwidth) * size or
                      (symbolwidth +
                        (legacy and ((string.sub(text, i, i) == '+' or string.sub(text, i, i) == '-') and 7 or -3) or 7)) *
                      size), numeric and 84 * size or (alphabetic and 84 * size or 112 / 1.5 * size)),
      color = rgbm(color[1], color[2], color[3], 1),
      font = font,
      width = 46,
      alignment = 0,
      spacing = -1
    })
    if numeric and string.find(string.sub(text, i + 1, i + 1), '%d') then
      lastx = lastx + size * digitswidth
    elseif alphabetic and string.find(string.sub(text, i + 1, i + 1), '%a') then
      lastx = lastx + size * alphabeticwidth
    else
      lastx = lastx + size * symbolwidth
    end
  end
end

local getArrayLength = function(list)
  local i = 0
  for _ in pairs(list) do i = math.max(i, _) end
  return i
end

math.interpolateTable = function(value, table)
  -- cases to skip immediately
  if value > getArrayLength(table) or value < 1 then return end
  if table[value] then return table[value] end
  local lowerVal
  local higherVal
  -- get next known values
  local i = 0
  while not lowerVal do
    lowerVal = table[math.floor(value) - i]
    i = i + 1
  end
  local a = 0
  while not higherVal do
    higherVal = table[math.ceil(value) + a]
    a = a + 1
  end
  -- doing the actual interpolation
  return math.lerp((value - (math.floor(value) - i) - 1) / ((a + i) - 1), lowerVal, higherVal)
end

local function btn(value)
  if not (select(1, pcall(function() return value > 1 end))) then return value and 1 or 0 end
  return value;
end

local popup = {
  clients = {},
  update = function(self)
    local tempTable = table.shallow_copy(self.clients);
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
  new = function(self, duration, displayCallback)
    local o = {startTime = exec.time, duration = duration, displayCallback = displayCallback};
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
    if ((self.startTime + self.duration) > exec.time) then
      self.displayCallback();
      return;
    end
    self.active = false;
  end
}

local eventListener = {
  clients = {},
  update = function(self) for _, e in pairs(self.clients) do e:listen() end end,
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
      pcall(function() self.callback(btn(self.getter()) - btn(self.lastvalue), self.getter(), self.lastvalue) end);
      self.lastvalue = self.getter();
    end
  end
}

local function calculateBrakeTemps(index, dt)
  carstate.wheels[index].discTemp = carstate.wheels[index].discTemp +
                                      (carstate.wheels[index].brakeForce * (car.speedKmh / 3.6) * dt * 6 *
                                        (math.random() + 0.75) * 0.85) / (9 * 0.46)
  carstate.wheels[index].discTemp = carstate.wheels[index].discTemp -
                                      (100 ^
                                        (1.3 *
                                          (dt * (carstate.wheels[index].discTemp - simObject.ambientTemperature) / 20) -
                                          0.7) - 0.0398107170553) * (math.max(car.speedKmh - 80, 0) / 200 + 0.7)
end

-- ###################################################

eventListener:new(function() return car.extraA; end, function(diff)
  if diff == 1 or legacy then
    carstate.page = 1 + carstate.page;
    if carstate.page > 4 then carstate.page = 0 end
    ac.debug('page', carstate.page)
    if not legacy then ac.setExtraSwitch(0, false) end
  end
end)

eventListener:new(function() return car.fuel; end, function(diff)
  pcall(function()
    if diff > 0 or (legacy and (car.isInPitlane and car.speedKmh < 1) or car.isInPit) then
      carstate.maxstintfuel = car.fuel;
    end
  end)
end)

eventListener:new(function() return car.gear; end, function()
  carstate.gear = 0;
  carstate.geardelay = carstate.geardelay - (carstate.geardelay % 3);
end)

eventListener:new(function() return simObject.raceSessionType; end, function(_, newVal)
  if (newVal == 2) then
    carstate.page = 4;
    return;
  end
  carstate.page = 0;
end)

if legacy then -- Calculating the fuelcons, because the old API does not calculate that value for us
  eventListener:new(function() return car.lapCount; end,
                    function(_, newVal) carstate.fuelPerLap = (carstate.maxstintfuel - car.fuel) / newVal; end)
end

-- POPUPS --

eventListener:new(function() return car.tractionControlMode; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/Popup_TCR.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    displayText(newVal, 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)

eventListener:new(function() return car.absMode; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/Popup_ABS.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    displayText(newVal, 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)

eventListener:new(function() return car.tractionControl2; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/Popup_TCC.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    displayText(newVal, 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)

eventListener:new(function() return math.floor((car.brakeBias * 100 + 0.1) * 2) / 2; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/Popup_BB.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    displayText(dec(newVal, 2, '.'), 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)

eventListener:new(function() return car.fuelMap; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/Popup_Map.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    displayText(dec(newVal, 2, '.'), 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)
--

function update(dt)
  eventListener:update();
  exec.time = exec.time + dt;
  exec.run = exec.run + 1;
  carstate.geardelay = carstate.geardelay + 1;
  simObject = legacy and ac.getSimState() or ac.getSim();
  ac.debug('simTime', exec.time);
  ac.debug('run', exec.run);
  ac.debug('SessionType', simObject.raceSessionType);

  if exec.firstrun then
    carstate.maxstintfuel = car.fuel;
    for i = 0, 3 do carstate.wheels[i].discTemp = simObject.ambientTemperature end
  end

  carstate.wheels[0].brakeForce = math.floor(car.brake * car.brakeBias * 100) / 10
  carstate.wheels[2].brakeForce = math.floor(car.brake * (1 - car.brakeBias) * 100) / 10
  carstate.wheels[1].brakeForce = carstate.wheels[0].brakeForce
  carstate.wheels[3].brakeForce = carstate.wheels[2].brakeForce
  -- assuming a weight of 9kg of the disc, and that it is made from cast iron (which is not the case irl)
  calculateBrakeTemps(0, dt)
  calculateBrakeTemps(2, dt)
  calculateBrakeTemps(1, dt)
  calculateBrakeTemps(3, dt)
  -- carstate.wheels[1].discTemp = carstate.wheels[0].discTemp
  -- carstate.wheels[3].discTemp = carstate.wheels[2].discTemp

  if exec.firstrun and simObject.raceSessionType == 2 then carstate.page = 4 end
  if carstate.page == 0 then
    display.image({image = 'Display/R1N.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      displayText(dec(car.oilTemperature, 2, '.'), 390, 193, 1.1, '488', {1, 1, 1}, 'right')
      displayText(dec(car.oilPressure, 2, '.'), 390, 291, 1.1, '488', {1, 1, 1}, 'right')
      displayText(dec(car.waterTemperature, 2, ','), 390, 390, 1.1, '488', {1, 1, 1}, 'right')
      displayText(dec((car.waterTemperature - 20) ^ 0.3 * car.oilPressure / 5, 2, '.'), 390, 479, 1.1, '488', {1, 1, 1},
                  'right') -- Water Pressure

    end
  elseif carstate.page == 1 then
    display.image({image = 'Display/R2.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      displayText(dec(carstate.maxstintfuel - car.fuel, 2, ','), 385, 195, 1.1, '488', {1, 1, 1}, 'right');
      if legacy then
        displayText(dec(carstate.fuelPerLap, 2, ','), 385, 290, 1.1, '488', {1, 1, 1}, 'right');
      else
        displayText(car.fuelPerLap and dec(car.fuelPerLap, 2, ',') or '0.00', 385, 290, 1.1, '488', {1, 1, 1}, 'right');
      end
      displayText('80.00', 385, 385, 1.1, '488', {1, 1, 1}, 'right');
      displayText(dec(car.fuel, 2, ','), 385, 480, 1.1, '488', {1, 1, 1}, 'right');
    end
  elseif carstate.page == 2 then
    display.image({image = 'Display/R1.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      displayText(math.floor(car.oilTemperature), 330, 52, 1, '488', {1, 1, 1}, 'right');
      display.rect({
        pos = vec2(64, 123),
        size = vec2(math.clampN((car.oilTemperature - 20) / 130, 0, 1) * 332, 98),
        color = rgb(0.25, 0.2, 1)
      })

      displayText(math.floor(car.waterTemperature), 330, 238, 1, '488', {1, 1, 1}, 'right');
      display.rect({
        pos = vec2(64, 315),
        size = vec2(math.clampN((car.waterTemperature - 20) / 170, 0, 1) * 332, 98),
        color = rgb(0.25, 0.2, 1)
      })

      displayText(dec(car.batteryVoltage, 1, '.'), 908, 420, 1, '488', {1, 1, 1}, 'right');
      displayText(dec(simObject.ambientTemperature, 1, '.'), 908, 358, 1, '488', {1, 1, 1}, 'right');
      displayText(dec((simObject.ambientTemperature + 24) / 2, 1, '.'), 908, 296, 1, '488', {1, 1, 1}, 'right');
      displayText('5.0', 908, 172, 1, '488', {1, 1, 1}, 'right');
      displayText('24.0', 908, 110, 1, '488', {1, 1, 1}, 'right');
      displayText(dec(car.fuel, 1, '.'), 908, 48, 1, '488', {1, 1, 1}, 'right');
    end

    displayText(dec(car.oilPressure, 1, '.'), 335, 435, 1, '488', {1, 1, 1}, 'right');
    displayText('7.3', 335, 535, 1, '488', {1, 1, 1}, 'right');
    displayText(dec((car.waterTemperature - 20) ^ 0.3 * car.oilPressure / 5, 1, '.'), 335, 635, 1, '488', {1, 1, 1},
                'right'); -- Water Pressure
    displayText('8.0', 335, 735, 1, '488', {1, 1, 1}, 'right');

    displayText(dec(math.floor((car.brakeBias * 100 + 0.1) * 2) / 2, 2, '.'), 620, 599, 0.7, '488', {1, 1, 1}, 'right');
    displayText(dec(carstate.wheels[0].brakeForce, 1, '.'), 610, 656, 0.7, '488', {1, 1, 1}, 'right');
    displayText(dec(carstate.wheels[2].brakeForce, 1, '.'), 610, 713, 0.7, '488', {1, 1, 1}, 'right');
    displayText('1.0', 610, 770, 0.7, '488', {1, 1, 1}, 'right');

    display.text({
      text = car.absMode,
      pos = vec2(326, 883),
      letter = vec2(20, 100),
      font = '488',
      color = rgb(1, 1, 1),
      alignment = 0.22,
      width = 200,
      spacing = -5
    })

    display.text({
      text = car.fuelMap,
      pos = vec2(460, 883),
      letter = vec2(20, 100),
      font = '488',
      color = rgb(1, 1, 1),
      alignment = 0.22,
      width = 200,
      spacing = -5
    })

    display.text({
      text = car.tractionControl2,
      pos = vec2(717, 882),
      letter = vec2(20, 100),
      font = '488',
      color = rgb(1, 1, 1),
      alignment = 0.22,
      width = 200,
      spacing = -5
    })

    display.text({
      text = car.tractionControlMode,
      pos = vec2(848, 882),
      letter = vec2(20, 100),
      font = '488',
      color = rgb(1, 1, 1),
      alignment = 0.22,
      width = 200,
      spacing = -5
    })
  elseif carstate.page == 3 then
    display.image({image = 'Display/B1.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      displayText(math.floor(carstate.wheels[0].discTemp), 385, 195, 1.1, '488', {1, 1, 1}, 'right');
      displayText(math.floor(carstate.wheels[1].discTemp), 385, 290, 1.1, '488', {1, 1, 1}, 'right');
      displayText(math.floor(carstate.wheels[2].discTemp), 385, 385, 1.1, '488', {1, 1, 1}, 'right');
      displayText(math.floor(carstate.wheels[3].discTemp), 385, 480, 1.1, '488', {1, 1, 1}, 'right');
      displayText(dec(math.floor((car.brakeBias * 100 + 0.1) * 2) / 2, 2, ','), 650, 470, 1.2, '488', {1, 1, 1}, 'left')
      displayText('100.0', 930, 470, 1.2, '488', {1, 1, 1}, 'right')
    end
    displayText(dec(carstate.wheels[0].brakeForce, 1, ','), 385, 610, 1.1, '488', {1, 1, 1}, 'right');
    displayText(dec(carstate.wheels[2].brakeForce, 1, ','), 385, 712, 1.1, '488', {1, 1, 1}, 'right');

  elseif carstate.page == 4 then -- QUALI
    display.image({image = 'Display/Q1.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      display.rect({
        pos = vec2(646 + 145, 362),
        size = vec2(145 * math.clampN(car.performanceMeter / 0.9, -1, 1), 193),
        color = rgb(1, 1, 1)
      })
      display.image({image = 'Display/Overlay.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
      displayText(timeformat(car.estimatedLapTimeMs, {':', '.'}, 2, true), 793, 250, 1.5, '488', {1, 1, 1}, 'center')
      displayText(timeformat(car.lapTimeMs, {':', '.'}, 2, true), 243, 268, 1.4, '488', {1, 1, 1}, 'center')
      displayText(dec(car.fuel, 2, ','), 243, 448, 1.4, '488', {1, 1, 1}, 'center')
    end
  end
  if not (carstate.page == 2) then
    if not (carstate.page == 4) then
      if not (carstate.page == 3) then
        if not (car.isInPitlane) then
          local gainorloss = math.clampN(car.performanceMeter * INF, -1, 1)
          displayText((car.performanceMeter >= 0 and '+ ' or '- ') ..
                        dec(math.abs(math.clampN(car.performanceMeter, -99, 99)), 2, '.'), 635, 470, 1.2, '488', {
            math.interpolateTable(gainorloss + 2, {0.3, 1, 1}), math.interpolateTable(gainorloss + 2, {1, 1, 0.3}),
            math.interpolateTable(gainorloss + 2, {0.3, 1, 0.1})
          }, 'left')
          displayText(timeformat(car.estimatedLapTimeMs, {':', '.'}, 2, true), 950, 470, 1.2, '488', {
            math.interpolateTable(gainorloss + 2, {0.3, 1, 1}), math.interpolateTable(gainorloss + 2, {1, 1, 0.3}),
            math.interpolateTable(gainorloss + 2, {0.3, 1, 0.1})
          }, 'right')
        end
      end
      if not car.isInPitlane then
        displayText(timeformat(car.lapTimeMs, {':', '.'}, 2, true), 793, 265, 1.5, '488', {1, 1, 1}, 'center')
      end
    end
    if not (carstate.page == 3) then displayText(car.fuelMap, 197, 622, 1.0, '488', {1, 1, 1}, 'center'); end
    displayText(car.lapCount + 1, 805, 95, 1, '488', {1, 1, 1}, 'right');
    displayText(car.absMode, 378, 892, 0.8, '488', {1, 1, 1}, 'center');
    displayText(car.tractionControlMode, 869, 892, 0.8, '488', {1, 1, 1}, 'center');
    displayText(car.tractionControl2, 732, 892, 0.8, '488', {1, 1, 1}, 'center');

    displayText(dec(car.wheels[0].tyrePressure * 0.069, 2, ','), 414, 660, 1.15, '488', {1, 1, 1}, 'left');
    displayText(dec(car.wheels[2].tyrePressure * 0.069, 2, ','), 414, 743, 1.15, '488', {1, 1, 1}, 'left');
    displayText(dec(car.wheels[1].tyrePressure * 0.069, 2, ','), 610, 660, 1.15, '488', {1, 1, 1}, 'right');
    displayText(dec(car.wheels[3].tyrePressure * 0.069, 2, ','), 610, 743, 1.15, '488', {1, 1, 1}, 'right');
  end
  displayText((carstate.gear < 1 and (carstate.gear == 0 and 'N' or 'R') or car.gear), 515, 225, 5, '488', {1, 1, 0.1},
              'center')

  displayText(math.floor(car.speedKmh), 512, 55, 1.5, '488', {1, 1, 1}, 'center')

  popup:update();

  if car.isInPitlane then
    if (car.speedKmh < 60) then
      display.image {image = 'Display/R1_PIT_U.dds', pos = vec2(0, 0), size = vec2(1024, 1024)}
    elseif (car.speedKmh > 82) then
      display.image {image = 'Display/R1_PIT_O.dds', pos = vec2(0, 0), size = vec2(1024, 1024)}
    else
      display.image {image = 'Display/R1_PIT_N.dds', pos = vec2(0, 0), size = vec2(1024, 1024)}
    end
    displayText((carstate.gear < 1 and (carstate.gear == 0 and 'N' or 'R') or car.gear), 790, 455, 1.5, '488',
                {0, 0, 0}, 'center')
    displayText(math.floor(car.gas * 100), 790, 275, 1.5, '488', {0, 0, 0}, 'center')
    displayText(math.floor(car.speedKmh), 512, 325, 2.9, '488', {0, 0, 0}, 'center')
    displayText(math.floor(car.rpm), 512, 47, 1.5, '488', {1, 1, 1}, 'center')
    displayText(timeformat(car.lapTimeMs, {':', '.'}), 212, 430, 1.7, '488', {0, 0, 0}, 'center')
  else
    if carstate.page ~= 2 then
      if (simObject.rainWetness > 0.1 or simObject.rainIntensity > 0.4) then
        display.image({image = 'Display/Wet.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
      end
      if car.headlightsActive then
        display.image({
          image = 'Display/' .. (car.lowBeams and 'Lowbeams' or 'Highbeams') .. '.dds',
          pos = vec2(0, 0),
          size = vec2(1024, 1024)
        })
      end
    end
  end

  if car.fuel <= 5 then display.image({image = 'Display/R1_FUEL.dds', pos = vec2(0, 0), size = vec2(1024, 1024)}) end

  if carstate.geardelay % 3 == 0 then carstate.gear = car.gear; end
  exec.firstrun = false;
end
