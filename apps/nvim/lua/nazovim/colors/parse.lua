local M = {}

local css_names = {
	green = 0x008000,
	gray = 0x808080,
	grey = 0x808080,
	maroon = 0x800000,
	purple = 0x800080,
	rebeccapurple = 0x663399,
}

local function byte(value)
	return math.floor(math.max(0, math.min(255, value)) + 0.5)
end

---Parse hex, CSS rgb()/hsl(), and named colors to an RGB integer.
function M.parse(value)
	value = vim.trim(value):lower()
	local hex = value:match("^#(%x+)$")
	if hex then
		if #hex == 3 or #hex == 4 then
			hex = hex:gsub(".", "%0%0")
		end
		if #hex ~= 6 and #hex ~= 8 then
			return
		end
		return tonumber(hex:sub(1, 6), 16)
	end
	local kind, body = value:match("^(%a+)%((.*)%)$")
	if kind then
		local parts = vim.split(body:gsub(",", " "):gsub("/", " "), "%s+", { trimempty = true })
		if #parts < 3 or #parts > 4 then
			return
		end
		if kind == "rgb" or kind == "rgba" then
			local rgb = {}
			for i = 1, 3 do
				local percent = parts[i]:sub(-1) == "%"
				local number = tonumber(percent and parts[i]:sub(1, -2) or parts[i])
				if not number then
					return
				end
				rgb[i] = byte(number * (percent and 2.55 or 1))
			end
			return rgb[1] * 65536 + rgb[2] * 256 + rgb[3]
		elseif kind == "hsl" or kind == "hsla" then
			local hue = tonumber((parts[1]:gsub("deg$", "")))
			local saturation = tonumber(parts[2]:match("^([%d.]+)%%$"))
			local lightness = tonumber(parts[3]:match("^([%d.]+)%%$"))
			if not hue or not saturation or not lightness then
				return
			end
			hue, saturation, lightness = (hue % 360) / 60, math.min(1, saturation / 100), math.min(1, lightness / 100)
			local c = (1 - math.abs(2 * lightness - 1)) * saturation
			local x, m = c * (1 - math.abs(hue % 2 - 1)), lightness - c / 2
			local values = { { c, x, 0 }, { x, c, 0 }, { 0, c, x }, { 0, x, c }, { x, 0, c }, { c, 0, x } }
			local rgb = values[math.floor(hue) + 1]
			return byte((rgb[1] + m) * 255) * 65536 + byte((rgb[2] + m) * 255) * 256 + byte((rgb[3] + m) * 255)
		end
		return
	end
	if css_names[value] then
		return css_names[value]
	end
	-- Neovim ships a color-name database; no plugin or runtime file scan is needed.
	if not value:match("^[a-z]+$") then
		return
	end
	local color = vim.api.nvim_get_color_by_name(value)
	return color >= 0 and color or nil
end

return M
