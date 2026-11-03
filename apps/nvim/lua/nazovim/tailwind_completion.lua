local M = {}

local shades = {
	amber = "f59e0b",
	blue = "3b82f6",
	cool = "64748b",
	cyan = "06b6d4",
	emerald = "10b981",
	fuchsia = "d946ef",
	gray = "6b7280",
	green = "22c55e",
	indigo = "6366f1",
	lime = "84cc16",
	neutral = "737373",
	orange = "f97316",
	pink = "ec4899",
	purple = "a855f7",
	red = "ef4444",
	rose = "f43f5e",
	sky = "0ea5e9",
	slate = "64748b",
	stone = "78716c",
	teal = "14b8a6",
	violet = "8b5cf6",
	yellow = "eab308",
}

local properties = {
	"accent",
	"bg",
	"border",
	"caret",
	"decoration",
	"divide",
	"fill",
	"from",
	"outline",
	"ring",
	"shadow",
	"stroke",
	"text",
	"to",
	"via",
}

local known_groups = {}

local function hex_to_rgb(hex)
	hex = hex:gsub("^#", "")
	if #hex == 3 or #hex == 4 then
		hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
	elseif #hex == 8 then
		hex = hex:sub(1, 6)
	end
	if #hex ~= 6 or not hex:match("^%x+$") then
		return nil
	end
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function color_for(token)
	token = token:match("([^:]+)$") or token
	token = token:gsub("!", ""):gsub("/[%w%.%-]+$", "")
	for _, property in ipairs(properties) do
		local value = token:match("^" .. property .. "%-%[(.-)%]$")
		if value then
			if hex_to_rgb(value) then
				return value
			end
		end
		local name, shade = token:match("^" .. property .. "%-([%a]+)%-(%d%d%d)$")
		if name and shades[name] and tonumber(shade) then
			local base = shades[name]
			local red, green, blue = hex_to_rgb(base)
			local shade_number = tonumber(shade)
			local factor = ({ [50] = 0.9, [100] = 0.8, [200] = 0.6, [300] = 0.4, [400] = 0.2 })[shade_number]
			local target = 255
			if shade_number > 500 then
				factor = ({ [600] = 0.12, [700] = 0.25, [800] = 0.38, [900] = 0.52, [950] = 0.62 })[shade_number]
				target = 0
			end
			if shade_number == 500 then
				return base
			elseif factor then
				local function mix(channel)
					return math.floor(channel + (target - channel) * factor + 0.5)
				end
				return string.format("%02x%02x%02x", mix(red), mix(green), mix(blue))
			end
		end
		if token == property .. "-white" then
			return "ffffff"
		elseif token == property .. "-black" then
			return "000000"
		end
	end
end

local function completion_color(entry, item)
	if not item or type(item.abbr) ~= "string" then
		return nil
	end
	if entry and entry.source and entry.source.name ~= "nvim_lsp" then
		return nil
	end
	for token in item.abbr:gmatch("[%w_:%-/%[%]#%.!]+") do
		local color = color_for(token)
		if color then
			return color
		end
	end
	return nil
end

local function highlight_group(hex)
	local red, green, blue = hex_to_rgb(hex)
	if not red then
		return nil
	end
	local name = "NazoCmpColor" .. hex:gsub("#", ""):upper()
	if not known_groups[name] then
		vim.api.nvim_set_hl(0, name, {
			fg = string.format("#%02x%02x%02x", red, green, blue),
			bold = true,
		})
		known_groups[name] = true
	end
	return name
end

---Add a small colored marker to completion items containing Tailwind color classes.
---@param entry table
---@param item table
---@param enabled? boolean
---@return table
function M.format(entry, item, enabled)
	if enabled == false then
		return item
	end
	local color = completion_color(entry, item)
	if not color then
		return item
	end
	local group = highlight_group(color)
	if not group then
		return item
	end
	item.kind = "■ " .. (item.kind or "")
	item.kind_hl_group = group
	return item
end

---Initialize the independent completion color feature.
function M.setup()
	known_groups = {}
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("NazoVimTailwindCompletion", { clear = true }),
		callback = function()
			known_groups = {}
		end,
	})
end

return M
