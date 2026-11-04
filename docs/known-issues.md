# Known Issues

## DAP は JavaScript / TypeScript のみ対応

`dap.lua` が持つアダプタ定義は `pwa-node` と `pwa-chrome` だけです。他の言語を
デバッグするときは `dap.lua` の `M.adapters` と `M.configurations` にアダプタと
起動構成を追加してください。`js-debug` は devShell が供給します。

## `:CopilotChat` / `:Copilot` は提供しない

GitHub Copilot のクライアントは外部プラグイン依存だったため削除しました。
AI 支援は `ai_ask.lua`（`claude` / `codex` / `opencode` CLI）と、`codex.lua` /
`claudecode.lua` / `opencode.lua` の CLI 統合を使ってください。

## AI CLI が PATH に必要

`ai_ask.lua` は `claude` / `codex` / `opencode` のいずれかが PATH に無いと動作しません。
`:NazoAI` はその場合にエラーを通知します。
