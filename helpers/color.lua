

local _color = {}



--- Try to guess if a color is dark or light.
--
-- @string color The color with hexadecimal HTML format `"#RRGGBB"`.
-- @treturn bool `true` if the color is dark, `false` if it is light.
function _color.is_dark(color)
    -- Try to determine if the color is dark or light
    local numeric_value = 0;
    for s in color:gmatch("[a-fA-F0-9][a-fA-F0-9]") do
        numeric_value = numeric_value + tonumber("0x"..s);
    end
    return (numeric_value < 383)
end


--- Lighten a color.
--
-- @string color The color to lighten with hexadecimal HTML format `"#RRGGBB"`.
-- @int[opt=26] amount How much light from 0 to 255. Default is around 10%.
-- @treturn string The lighter color
function _color.lighten(color, amount)
    amount = amount or 26
    local c = {
        r = tonumber("0x"..color:sub(2,3)),
        g = tonumber("0x"..color:sub(4,5)),
        b = tonumber("0x"..color:sub(6,7)),
    }

    c.r = c.r + amount
    c.r = c.r < 0 and 0 or c.r
    c.r = c.r > 255 and 255 or c.r
    c.g = c.g + amount
    c.g = c.g < 0 and 0 or c.g
    c.g = c.g > 255 and 255 or c.g
    c.b = c.b + amount
    c.b = c.b < 0 and 0 or c.b
    c.b = c.b > 255 and 255 or c.b

    return string.format('#%02x%02x%02x', c.r, c.g, c.b)
end

--- Darken a color.
--
-- @string color The color to darken with hexadecimal HTML format `"#RRGGBB"`.
-- @int[opt=26] amount How much dark from 0 to 255. Default is around 10%.
-- @treturn string The darker color
function _color.darken(color, amount)
    amount = amount or 26
    return _color.lighten(color, -amount)
end



return _color
