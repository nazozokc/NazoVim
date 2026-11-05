local M = {}

local enabled = true
local syllables = {}
local rows = {
	k = { "か", "き", "く", "け", "こ" },
	g = { "が", "ぎ", "ぐ", "げ", "ご" },
	s = { "さ", "し", "す", "せ", "そ" },
	z = { "ざ", "じ", "ず", "ぜ", "ぞ" },
	t = { "た", "ち", "つ", "て", "と" },
	d = { "だ", "ぢ", "づ", "で", "ど" },
	n = { "な", "に", "ぬ", "ね", "の" },
	h = { "は", "ひ", "ふ", "へ", "ほ" },
	b = { "ば", "び", "ぶ", "べ", "ぼ" },
	p = { "ぱ", "ぴ", "ぷ", "ぺ", "ぽ" },
	m = { "ま", "み", "む", "め", "も" },
	r = { "ら", "り", "る", "れ", "ろ" },
	w = { "わ", "ゐ", "う", "ゑ", "を" },
	f = { "ふぁ", "ふぃ", "ふ", "ふぇ", "ふぉ" },
}
local vowels = { "a", "i", "u", "e", "o" }
for index, vowel in ipairs(vowels) do
	syllables[vowel] = ({ "あ", "い", "う", "え", "お" })[index]
end
local palatal = {
	k = "き",
	g = "ぎ",
	s = "し",
	z = "じ",
	j = "じ",
	c = "ち",
	t = "ち",
	d = "ぢ",
	n = "に",
	h = "ひ",
	b = "び",
	p = "ぴ",
	m = "み",
	r = "り",
}

for consonant, kana_row in pairs(rows) do
	for index, vowel in ipairs(vowels) do
		syllables[consonant .. vowel] = kana_row[index]
	end
end

for consonant, base in pairs(palatal) do
	for _, ending in ipairs({ "ya", "yu", "yo" }) do
		local small = ({ ya = "ゃ", yu = "ゅ", yo = "ょ" })[ending]
		syllables[consonant .. ending] = base .. small
	end
end

local extra = {
	shi = "し",
	si = "し",
	chi = "ち",
	ti = "ち",
	tsu = "つ",
	tu = "つ",
	di = "ぢ",
	du = "づ",
	ji = "じ",
	zi = "じ",
	fu = "ふ",
	wu = "う",
	wi = "ゐ",
	we = "ゑ",
	yi = "い",
	ye = "いぇ",
	va = "ゔぁ",
	vi = "ゔぃ",
	vu = "ゔ",
	ve = "ゔぇ",
	vo = "ゔぉ",
	kwa = "くぁ",
	kwi = "くぃ",
	kwe = "くぇ",
	kwo = "くぉ",
	gwa = "ぐぁ",
	she = "しぇ",
	je = "じぇ",
	che = "ちぇ",
	tsa = "つぁ",
	tsi = "つぃ",
	tse = "つぇ",
	tso = "つぉ",
	cha = "ちゃ",
	chu = "ちゅ",
	cho = "ちょ",
	sya = "しゃ",
	syu = "しゅ",
	syo = "しょ",
	zya = "じゃ",
	zyu = "じゅ",
	zyo = "じょ",
	jya = "じゃ",
	jyu = "じゅ",
	jyo = "じょ",
	lya = "ゃ",
	lyu = "ゅ",
	lyo = "ょ",
	xya = "ゃ",
	xyu = "ゅ",
	xyo = "ょ",
	la = "ぁ",
	li = "ぃ",
	lu = "ぅ",
	le = "ぇ",
	lo = "ぉ",
	xa = "ぁ",
	xi = "ぃ",
	xu = "ぅ",
	xe = "ぇ",
	xo = "ぉ",
	ltsu = "っ",
	xtsu = "っ",
	ltu = "っ",
	xtu = "っ",
	nn = "ん",
}

for spelling, kana in pairs(extra) do
	syllables[spelling] = kana
end
syllables.n = "ん"
local ordered_syllables = vim.tbl_keys(syllables)
table.sort(ordered_syllables, function(a, b)
	if #a ~= #b then
		return #a > #b
	end
	return a < b
end)

local function kana_class(character)
	local codepoint = vim.fn.char2nr(character)
	if codepoint >= 0x3041 and codepoint <= 0x3096 then
		local katakana = vim.fn.nr2char(codepoint + 0x60)
		return "[" .. character .. katakana .. "]"
	elseif codepoint >= 0x30A1 and codepoint <= 0x30F6 then
		return "[" .. vim.fn.nr2char(codepoint - 0x60) .. character .. "]"
	end
	return character
end

local function regex_literal(character)
	local magic = {
		["\\"] = true,
		["."] = true,
		["^"] = true,
		["$"] = true,
		["~"] = true,
		["["] = true,
		["]"] = true,
		["*"] = true,
	}
	if magic[character] then
		return "\\" .. character
	end
	return character
end

local function partial_pattern(tail)
	local alternatives, seen = {}, {}
	for _, spelling in ipairs(ordered_syllables) do
		if #spelling > #tail and spelling:sub(1, #tail) == tail then
			local kana = syllables[spelling]
			if not seen[kana] then
				seen[kana] = true
				local pattern = {}
				for _, character in ipairs(vim.fn.split(kana, "\\zs")) do
					pattern[#pattern + 1] = kana_class(character)
				end
				alternatives[#alternatives + 1] = table.concat(pattern)
			end
		end
	end
	table.sort(alternatives)
	if #alternatives == 0 then
		return nil
	end
	if #alternatives == 1 then
		return alternatives[1]
	end
	return "\\%(" .. table.concat(alternatives, "\\|") .. "\\)"
end

local function join_characters(characters, first, last)
	local result = {}
	for index = first, last or #characters do
		if characters[index] then
			result[#result + 1] = characters[index]
		end
	end
	return table.concat(result)
end

---Convert romanized Japanese input to a Vim pattern that matches hiragana and katakana.
function M.pattern(query)
	query = tostring(query or "")
	if query == "" then
		return query
	end
	for _, operator in ipairs({ "\\", ".", "*", "[", "]", "^", "$", "~", "+", "?", "(", ")", "|" }) do
		if query:find(operator, 1, true) then
			return query
		end
	end
	local characters = vim.fn.split(query, "\\zs")
	local output, index = {}, 1
	while index <= #characters do
		local character = characters[index]
		local lower = character:lower()
		local next_character = characters[index + 1] and characters[index + 1]:lower()
		local next_next = characters[index + 2] and characters[index + 2]:lower()
		if lower == "n" and next_character == "'" then
			output[#output + 1] = kana_class("ん")
			index = index + 2
		elseif lower == "n" and next_character == "n" then
			output[#output + 1] = kana_class("ん")
			if next_next and next_next:match("[aiueoy]") then
				index = index + 1
			else
				index = index + 2
			end
		elseif lower == "n" and next_character and not next_character:match("[aiueoy]") then
			output[#output + 1] = kana_class("ん")
			index = index + 1
		elseif #lower == 1 and lower:match("[bcdfghjklmpqrstvwxyz]") and lower == next_character then
			output[#output + 1] = kana_class("っ")
			index = index + 1
		else
			local matched = false
			for _, spelling in ipairs(ordered_syllables) do
				local candidate = join_characters(characters, index, index + #spelling - 1):lower()
				if candidate == spelling then
					for _, kana in ipairs(vim.fn.split(syllables[spelling], "\\zs")) do
						output[#output + 1] = kana_class(kana)
					end
					index = index + #spelling
					matched = true
					break
				end
			end
			if not matched then
				local tail = join_characters(characters, index):lower()
				local partial = tail:match("^[a-z]+$") and partial_pattern(tail) or nil
				if partial then
					output[#output + 1] = partial
					index = #characters + 1
				else
					output[#output + 1] = regex_literal(character)
					index = index + 1
				end
			end
		end
	end
	return "\\m" .. table.concat(output)
end

---Toggle automatic romaji-to-kana conversion when submitting `/` and `?` searches.
function M.toggle()
	enabled = not enabled
	vim.notify("Romaji kana search " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO, {
		title = "NazoVim",
	})
end

---Install Enter-time conversion for forward and backward search command lines.
function M.setup()
	enabled = vim.g.nazovim_romaji_search ~= false
	vim.keymap.set("c", "<CR>", function()
		local kind = vim.fn.getcmdtype()
		if enabled and (kind == "/" or kind == "?") then
			vim.fn.setcmdline(M.pattern(vim.fn.getcmdline()))
		end
		return "<CR>"
	end, { expr = true, desc = "Submit search with romaji-to-kana conversion" })
	vim.api.nvim_create_user_command("NazoRomajiSearchToggle", M.toggle, {
		desc = "Toggle romaji-to-kana search conversion",
	})
end

return M
