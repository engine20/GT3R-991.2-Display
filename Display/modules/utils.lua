local M = {}

-- Blends two rgb colors
---@param factor number
---@param color1 rgbm
---@param color2 rgbm
M.mixcolors = function(factor, color1, color2)
  return rgbm(color1.rgb.r - math.min(math.max(factor, 0), 1) * (color1.rgb.r - color2.rgb.r),
              color1.rgb.g - math.min(math.max(factor, 0), 1) * (color1.rgb.g - color2.rgb.g),
              color1.rgb.b - math.min(math.max(factor, 0), 1) * (color1.rgb.b - color2.rgb.b), 1)
end

---Displays numbers with natural scaling for symbol, numbers and letters
---@param text string
---@param posx number
---@param posy number
---@param size number
---@param font string
---@param color table
---@param align string
---| 'right'
---| 'left'
---| 'center'
M.displayText = function(text, posx, posy, size, font, color, align)
  local lastx = posx

  local digitswidth = 22
  local symbolwidth = 14
  local alphabeticwidth = Legacy and 32 or 22

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
                   (alphabetic and lastx + (size ^ ((1 - size) / 8 + 1.15) * 10) - 5 or lastx + (Legacy and 5 or 0) +
                     size ^ ((1 - size)))) - alignmentoffset,
                 numeric and posy or (alphabetic and posy or posy + size * 10)),
      letter = vec2(numeric and digitswidth * size or (alphabetic and (alphabeticwidth) * size or
                      (symbolwidth +
                        (Legacy and ((string.sub(text, i, i) == '+' or string.sub(text, i, i) == '-') and 7 or -3) or 7)) *
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
---Extends a string with its last character or the given character
---@param input string
---@param length integer
---@param char? string
---@return string
M.extend = function(input, length, char)
  local v = input
  if length == 0 then
    return input
  else
    for i = 1, length do v = v .. (char or string.sub(input, -1, -1)) end
  end
  return v
end
---Forces two digits for a given number
---@param input number
---@return string
M.twodigits = function(input)
  return tonumber(input) < 10 and '0' .. tonumber(input) or (tonumber(input) >= 100 and '99' or tonumber(input))
end
---Formats a value with given parameters
---@param input number
---@param decimals integer
---@param seperator? string
---@return string
M.dec = function(input, decimals, seperator)
  return
    string.len(math.floor(input * 10 ^ decimals) / 10 ^ decimals) - string.len(math.floor(input)) < decimals + 1 and
      string.gsub(math.floor(input * 10 ^ decimals) / 10 ^ decimals, '%.', seperator or '.') ..
      (string.len(math.floor(input * 10 ^ decimals) / 10 ^ decimals) - string.len(math.floor(input)) ~= decimals and
        (seperator or '.') or '') .. M.extend('0', decimals - 1 -
                                                (string.len(math.floor(input * 10 ^ decimals) / 10 ^ decimals) -
                                                  string.len(math.floor(input)))) or
      string.gsub(math.floor(input * 10 ^ decimals) / 10 ^ decimals, '%.', seperator or '.')
end
---Formats milliseconds into a time string, ideally used for lap times
---@param input number
---@param seperator table
---@param millis? integer
---@param nullonempty? boolean
---@return string
M.timeformat = function(input, seperator, millis, nullonempty)
  return input ~= 0 and (((tonumber(string.sub(tostring(input), 1, -4)) or 0) > 59 and
           math.floor((tonumber(string.sub(tostring(input), 1, -4)) or 0) / 60) or 0) .. (seperator[1] or ':') ..
           M.twodigits((tonumber(string.sub(tostring(input), 1, -4)) or 0) -
                         ((tonumber(string.sub(tostring(input), 1, -4)) or 0) > 59 and
                           math.floor((tonumber(string.sub(tostring(input), 1, -4)) or 0) / 60) or 0) * 60) ..
           (seperator[2] or ':') .. string.sub(tostring(input), -3, (millis or 2) - 4)) or
           ((nullonempty and '0' or '--') .. (seperator[1] or ':') .. (nullonempty and '00' or '--') ..
             (seperator[2] or ':') ..
             (nullonempty and string.sub('000', 1, (millis or 2) - 4) or string.sub('---', 1, (millis or 2) - 4)))
end

---Return a shallow copy of a table
---@param t table
---@return table
M.shallow_copy = function(t)
  local t2 = {}
  for k, v in pairs(t) do t2[k] = v end
  return t2
end

---Max value in table T
---@param T table
---@return number
M.maxValueTable = function(T)
  local max_so_far = T[1];
  local i = 2;
  while T[i] do
    if T[i] > max_so_far then max_so_far = T[i]; end
    i = i + 1;
  end
  return max_so_far;
end

---Min value in table T
---@param T table
---@return number
M.minValueTable = function(T)
  local min_so_far = T[1];
  local i = 2;
  while T[i] do
    if T[i] < min_so_far then min_so_far = T[i]; end
    i = i + 1;
  end
  return min_so_far
end

---Table to string
---@param T table
---@return string
M.toStringTable = function(T)
  local elem_str = '';
  for i = 1, #T do elem_str = elem_str .. tostring(T[i]) .. ' '; end
  return '[ ' .. elem_str .. ']';
end

---Table remove first element
---@param T table
---@return table
M.remove1stElemTable = function(T)
  local newT = {};
  for i = 2, #T do newT[i - 1] = T[i]; end
  return newT;
end

---Table add element
---@param T table
---@param new_elem any
M.addElemToTable = function(T, new_elem)
  local N = #T;
  if N then T[N + 1] = new_elem; end
end

---Table trim
---@param T table
---@param N integer
M.trimTable = function(T, N)
  if N >= 1 then
    T[N + 1] = nil;
  else
    T = {};
  end
end

---Interpolates between given values in a table
---@param value number
---@param table table
---@return number
M.interpolateTable = function(value, table)
  -- cases to skip immediately
  ---@diagnostic disable-next-line: missing-return-value
  if value > #table or value < 1 then return end
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

---If given input is a boolean, return 0 or 1, if it is a number, return the number
---@param value any
---@return number
M.btn = function(value)
  if not (select(1, pcall(function() return value > 1 end))) then return value and 1 or 0 end
  return value;
end
return M;
