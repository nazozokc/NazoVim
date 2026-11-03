-- Kept as a plugin: mini.jump extends f/F/t/T across lines and owns `;`.
-- A built-in replacement is planned with the remaining motion work.
return {
	"echasnovski/mini.jump",
	version = false,
	event = "CursorMoved",
	config = function()
		require("mini.jump").setup({ mappings = { repeat_forward = ";", repeat_backward = "," } })
	end,
}
