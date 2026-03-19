return {
	"matsui54/denops-signature_help",
	-- denops プラグインは DenopsReady イベントで発火させる
	-- lazy = true と event = "VeryLazy" のままだと DenopsReady が発生しない
	lazy = false,
}
