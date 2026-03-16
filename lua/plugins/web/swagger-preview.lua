return {
	"vinnymeller/swagger-preview.nvim",
	event = "InsertEnter",
	build = "npm install -g swagger-ui-watcher",
	config = true,
}
