local lrequire = require -- Remove before squishing
require = function(modname) return lrequire(_CFG.rootScriptDir .. modname) end -- Remove before squishing
-- Import Utils
Utils = require('modules/utils')
G = require('modules/globals')
local popup = require('modules/popup')
local eventListener = require('modules/eventListener')
--

INF = 1e308
Legacy = ac.getPatchVersionCode() <= 1709
if Legacy then ac.log('Running Legacy Mode!') end
local simObject = Legacy and ac.getSimState() or ac.getSim();
local wheelstate = {discTemp = 0, brakeForce = 0}
local carstate = {
  page = _CFG.defaultPage, -- defines the first page upon loading
  gear = 0,
  geardelay = 0,
  maxstintfuel = 0,
  fuelPerLap = 0
}
carstate.wheels = {}; -- [0] = FL, [1] = FR, [2] = RL, [3] = RR
for i = 0, 3 do table.insert(carstate.wheels, i, Utils.shallow_copy(wheelstate)) end

ac.debug('page', carstate.page)
ac.debug('Popups', 0)

math.randomseed(os.time())
math.random()
math.random()
math.random()
math.random()
math.random()

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

eventListener:new(function() return car.extraA; end, function(diff)
  if diff == 1 or Legacy then
    carstate.page = 1 + carstate.page;
    if carstate.page > 4 then carstate.page = 0 end
    ac.debug('page', carstate.page)
  end
end)

eventListener:new(function() return car.fuel; end, function(diff)
  pcall(function()
    if diff > 0 or (Legacy and (car.isInPitlane and car.speedKmh < 1) or car.isInPit) then
      carstate.maxstintfuel = car.fuel;
    end
  end)
end)

if _CFG.flashNatshift then
  eventListener:new(function() return car.gear; end, function()
    carstate.gear = 0;
    carstate.geardelay = carstate.geardelay - (carstate.geardelay % 3);
  end)
end

eventListener:new(function() return simObject.raceSessionType; end, function(_, newVal)
  if (newVal == 2) then
    carstate.page = 4;
    return;
  end
  carstate.page = 0;
end)

if Legacy then -- Calculating the fuelcons, because the old API does not calculate that value for us
  eventListener:new(function() return car.lapCount; end,
                    function(_, newVal) carstate.fuelPerLap = (carstate.maxstintfuel - car.fuel) / newVal; end)
end

-- POPUPS --
eventListener:new(function() return car.tractionControlMode; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/tex.zip::Popup_TCR.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    Utils.displayText(newVal, 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)

eventListener:new(function() return car.absMode; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/tex.zip::Popup_ABS.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    Utils.displayText(newVal, 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)

eventListener:new(function() return car.tractionControl2; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/tex.zip::Popup_TCC.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    Utils.displayText(newVal, 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)

eventListener:new(function() return math.floor((car.brakeBias * 100 + 0.1) * 2) / 2; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/tex.zip::Popup_BB.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    Utils.displayText(Utils.dec(newVal, 2, '.'), 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)

eventListener:new(function() return car.fuelMap; end, function(_, newVal)
  popup:new(3, function()
    display.image({image = 'Display/tex.zip::Popup_Map.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    Utils.displayText(Utils.dec(newVal, 2, '.'), 240, 580, 1.6, '488', {1, 1, 1}, 'center')
  end)
end)
--

function update(dt)
  eventListener:update();
  G.time = G.time + dt;
  G.run = G.run + 1;
  if _CFG.flashNatshift then carstate.geardelay = carstate.geardelay + 1; end
  simObject = Legacy and ac.getSimState() or ac.getSim();
  ac.debug('simTime', G.time);
  ac.debug('run', G.run);
  ac.debug('SessionType', simObject.raceSessionType);

  if G.firstrun then
    carstate.maxstintfuel = car.fuel;
    for i = 0, 3 do carstate.wheels[i].discTemp = simObject.ambientTemperature end
  end

  carstate.wheels[0].brakeForce = math.floor(car.brake * car.brakeBias * 100) / 10
  carstate.wheels[2].brakeForce = math.floor(car.brake * (1 - car.brakeBias) * 100) / 10
  carstate.wheels[1].brakeForce = carstate.wheels[0].brakeForce
  carstate.wheels[3].brakeForce = carstate.wheels[2].brakeForce
  -- assuming a weight of 9kg of the disc, and that it is made from cast iron (which is not the case irl)
  calculateBrakeTemps(0, dt)
  calculateBrakeTemps(1, dt)
  calculateBrakeTemps(2, dt)
  calculateBrakeTemps(3, dt)

  if G.firstrun and simObject.raceSessionType == 2 then carstate.page = 4 end
  if carstate.page == 0 then
    display.image({image = 'Display/tex.zip::R1N.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      Utils.displayText(Utils.dec(car.oilTemperature, 1, '.'), 328, 193, 1.1, '488', {1, 1, 1}, 'center')
      Utils.displayText(Utils.dec(car.oilPressure, 1, '.'), 328, 291, 1.1, '488', {1, 1, 1}, 'center')
      Utils.displayText(Utils.dec(car.waterTemperature, 1, '.'), 328, 390, 1.1, '488', {1, 1, 1}, 'center')
      Utils.displayText(Utils.dec((car.waterTemperature - 20) ^ 0.3 * car.oilPressure / 5, 1, '.'), 328, 479, 1.1,
                        '488', {1, 1, 1}, 'center') -- Water Pressure

    end
  elseif carstate.page == 1 then
    display.image({image = 'Display/tex.zip::R2.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      Utils.displayText(Utils.dec(carstate.maxstintfuel - car.fuel, 1, '.'), 328, 195, 1.1, '488', {1, 1, 1}, 'center');
      if Legacy then
        Utils.displayText(Utils.dec(carstate.fuelPerLap, 2, '.'), 328, 290, 1.1, '488', {1, 1, 1}, 'center');
      else
        Utils.displayText(car.fuelPerLap and Utils.dec(car.fuelPerLap, 2, '.') or '0.00', 328, 290, 1.1, '488',
                          {1, 1, 1}, 'center');
      end
      Utils.displayText('80.00', 328, 385, 1.1, '488', {1, 1, 1}, 'center');
      Utils.displayText(Utils.dec(car.fuel, 1, '.'), 328, 480, 1.1, '488', {1, 1, 1}, 'center');
    end
  elseif carstate.page == 2 then
    display.image({image = 'Display/tex.zip::R1.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      Utils.displayText(math.floor(car.oilTemperature), 330, 52, 1, '488', {1, 1, 1}, 'right');
      display.rect({
        pos = vec2(64, 123),
        size = vec2(math.clampN((car.oilTemperature - 20) / 130, 0, 1) * 332, 98),
        color = rgb(0.25, 0.2, 1)
      })

      Utils.displayText(math.floor(car.waterTemperature), 330, 238, 1, '488', {1, 1, 1}, 'right');
      display.rect({
        pos = vec2(64, 315),
        size = vec2(math.clampN((car.waterTemperature - 20) / 170, 0, 1) * 332, 98),
        color = rgb(0.25, 0.2, 1)
      })

      Utils.displayText(Utils.dec(car.batteryVoltage, 1, '.'), 908, 420, 1, '488', {1, 1, 1}, 'right');
      Utils.displayText(Utils.dec(simObject.ambientTemperature, 1, '.'), 908, 358, 1, '488', {1, 1, 1}, 'right');
      Utils.displayText(Utils.dec((simObject.ambientTemperature + 24) / 2, 1, '.'), 908, 296, 1, '488', {1, 1, 1},
                        'right');
      Utils.displayText('5.0', 908, 172, 1, '488', {1, 1, 1}, 'right');
      Utils.displayText('24.0', 908, 110, 1, '488', {1, 1, 1}, 'right');
      Utils.displayText(Utils.dec(car.fuel, 1, '.'), 908, 48, 1, '488', {1, 1, 1}, 'right');
    end

    Utils.displayText(Utils.dec(car.oilPressure, 1, '.'), 335, 435, 1, '488', {1, 1, 1}, 'right');
    Utils.displayText('7.3', 335, 535, 1, '488', {1, 1, 1}, 'right');
    Utils.displayText(Utils.dec((car.waterTemperature - 20) ^ 0.3 * car.oilPressure / 5, 1, '.'), 335, 635, 1, '488',
                      {1, 1, 1}, 'right'); -- Water Pressure
    Utils.displayText('8.0', 335, 735, 1, '488', {1, 1, 1}, 'right');

    Utils.displayText(Utils.dec(math.floor((car.brakeBias * 100 + 0.1) * 2) / 2, 2, '.'), 620, 599, 0.7, '488',
                      {1, 1, 1}, 'right');
    Utils.displayText(Utils.dec(carstate.wheels[0].brakeForce, 1, '.'), 610, 656, 0.7, '488', {1, 1, 1}, 'right');
    Utils.displayText(Utils.dec(carstate.wheels[2].brakeForce, 1, '.'), 610, 713, 0.7, '488', {1, 1, 1}, 'right');
    Utils.displayText('1.0', 610, 770, 0.7, '488', {1, 1, 1}, 'right');

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
    display.image({image = 'Display/tex.zip::B1.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      Utils.displayText(math.floor(carstate.wheels[0].discTemp), 385, 195, 1.1, '488', {1, 1, 1}, 'right');
      Utils.displayText(math.floor(carstate.wheels[1].discTemp), 385, 290, 1.1, '488', {1, 1, 1}, 'right');
      Utils.displayText(math.floor(carstate.wheels[2].discTemp), 385, 385, 1.1, '488', {1, 1, 1}, 'right');
      Utils.displayText(math.floor(carstate.wheels[3].discTemp), 385, 480, 1.1, '488', {1, 1, 1}, 'right');
      Utils.displayText(Utils.dec(math.floor((car.brakeBias * 100 + 0.1) * 2) / 2, 2, ','), 650, 482, 1.2, '488',
                        {1, 1, 1}, 'left')
      Utils.displayText('100.0', 930, 482, 1.2, '488', {1, 1, 1}, 'right')
    end
    Utils.displayText(Utils.dec(carstate.wheels[0].brakeForce, 1, '.'), 385, 610, 1.1, '488', {1, 1, 1}, 'right');
    Utils.displayText(Utils.dec(carstate.wheels[2].brakeForce, 1, '.'), 385, 712, 1.1, '488', {1, 1, 1}, 'right');

  elseif carstate.page == 4 then -- QUALI
    display.image({image = 'Display/tex.zip::Q1.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
    if not car.isInPitlane then
      display.rect({
        pos = vec2(646 + 145, 362),
        size = vec2(145 * math.clampN(car.performanceMeter / 0.9, -1, 1), 193),
        color = rgb(1, 1, 1)
      })
      display.image({image = 'Display/tex.zip::Overlay.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
      Utils.displayText(Utils.timeformat(car.estimatedLapTimeMs, {':', '.'}, 2, true), 793, 250, 1.5, '488', {1, 1, 1},
                        'center')
      Utils.displayText(Utils.timeformat(car.lapTimeMs, {':', '.'}, 2, true), 243, 268, 1.4, '488', {1, 1, 1}, 'center')
      Utils.displayText(Utils.dec(car.fuel, 2, ','), 243, 448, 1.4, '488', {1, 1, 1}, 'center')
    end
  end
  if not (carstate.page == 2) then
    if not (carstate.page == 4) then
      if not (carstate.page == 3) then
        if not (car.isInPitlane) then
          if car.performanceMeter < 0 then
            display.image({
              image = 'Display/tex.zip::Diff.dds',
              pos = vec2(0, 0),
              size = vec2(1024, 1024),
              color = rgb(0.2, 1, 0.2)
            })
          end
          if car.performanceMeter > 0 then
            display.image({
              image = 'Display/tex.zip::Diff.dds',
              pos = vec2(0, 0),
              size = vec2(1024, 1024),
              color = rgb(1, 0.2, 0.2)
            })
          end
          Utils.displayText((car.performanceMeter == 0 and '  ' or (car.performanceMeter >= 0 and '+ ' or '- ')) ..
                              Utils.dec(math.abs(math.clampN(car.performanceMeter, -99, 99)), 2, '.'), 635, 482, 1.2,
                            '488', {1, 1, 1}, 'left')
          Utils.displayText(Utils.timeformat(car.estimatedLapTimeMs, {':', '.'}, 2, true), 955, 482, 1.2, '488',
                            {1, 1, 1}, 'right')
        end
      end
      if not car.isInPitlane then
        Utils.displayText(Utils.timeformat(car.lapTimeMs, {':', '.'}, 2, true), 793, 265, 1.5, '488', {1, 1, 1},
                          'center')
      end
    end
    if not (carstate.page == 3) then Utils.displayText(car.fuelMap, 197, 622, 1.0, '488', {1, 1, 1}, 'center'); end
    Utils.displayText(car.lapCount + 1, 805, 95, 1, '488', {1, 1, 1}, 'right');
    Utils.displayText(car.absMode, 378, 892, 0.8, '488', {1, 1, 1}, 'center');
    Utils.displayText(car.tractionControlMode, 869, 892, 0.8, '488', {1, 1, 1}, 'center');
    Utils.displayText(car.tractionControl2, 732, 892, 0.8, '488', {1, 1, 1}, 'center');

    Utils.displayText(Utils.dec(car.wheels[0].tyrePressure * 0.069, 2, ','), 424, 670, 1, '488', {1, 1, 1}, 'left');
    Utils.displayText(Utils.dec(car.wheels[2].tyrePressure * 0.069, 2, ','), 424, 743, 1, '488', {1, 1, 1}, 'left');
    Utils.displayText(Utils.dec(car.wheels[1].tyrePressure * 0.069, 2, ','), 600, 670, 1, '488', {1, 1, 1}, 'right');
    Utils.displayText(Utils.dec(car.wheels[3].tyrePressure * 0.069, 2, ','), 600, 743, 1, '488', {1, 1, 1}, 'right');
  end
  if not _CFG.flashNatshift then carstate.gear = car.gear; end
  Utils.displayText((carstate.gear < 1 and (carstate.gear == 0 and 'N' or 'R') or car.gear), 515, 225, 5, '488',
                    {1, 1, 0.1}, 'center')

  Utils.displayText(math.floor(car.speedKmh), 512, 55, 1.5, '488', {1, 1, 1}, 'center')

  popup:update();

  if car.isInPitlane then
    if (car.speedKmh < 60) then
      display.image {image = 'Display/tex.zip::R1_PIT_U.dds', pos = vec2(0, 0), size = vec2(1024, 1024)}
    elseif (car.speedKmh > 82) then
      display.image {image = 'Display/tex.zip::R1_PIT_O.dds', pos = vec2(0, 0), size = vec2(1024, 1024)}
    else
      display.image {image = 'Display/tex.zip::R1_PIT_N.dds', pos = vec2(0, 0), size = vec2(1024, 1024)}
    end
    if not _CFG.flashNatshift then carstate.gear = car.gear; end
    Utils.displayText((carstate.gear < 1 and (carstate.gear == 0 and 'N' or 'R') or car.gear), 790, 455, 1.5, '488',
                      {0, 0, 0}, 'center')
    Utils.displayText(math.floor(car.gas * 100), 790, 275, 1.5, '488', {0, 0, 0}, 'center')
    Utils.displayText(math.floor(car.speedKmh), 512, 325, 2.9, '488', {0, 0, 0}, 'center')
    Utils.displayText(math.floor(car.rpm), 512, 47, 1.5, '488', {1, 1, 1}, 'center')
    Utils.displayText(Utils.timeformat(car.lapTimeMs, {':', '.'}), 212, 430, 1.7, '488', {0, 0, 0}, 'center')
  else
    if carstate.page ~= 2 then
      if (simObject.rainWetness > 0.1 or simObject.rainIntensity > 0.4) then
        display.image({image = 'Display/tex.zip::Wet.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
      end
      if car.headlightsActive then
        display.image({
          image = 'Display/tex.zip::' .. (car.lowBeams and 'Lowbeams' or 'Highbeams') .. '.dds',
          pos = vec2(0, 0),
          size = vec2(1024, 1024)
        })
      end
    end
  end

  if car.fuel <= 5 then
    display.image({image = 'Display/tex.zip::R1_FUEL.dds', pos = vec2(0, 0), size = vec2(1024, 1024)})
  end

  if _CFG.flashNatshift then if carstate.geardelay % 3 == 0 then carstate.gear = car.gear; end end

  G.firstrun = false;
end
