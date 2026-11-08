# 内蔵エディタ機能

<!-- cspell:words hlslens commentstring rgba -->

次の機能は `apps/nvim/lua/nazovim/` で管理します。
プラグイン未導入の初回起動でも動作します。LSP・Treesitter参照には
対応するサーバー／パーサーが必要です。

機能はカテゴリ別ディレクトリに1機能1ファイルで置きます。`features.lua` が
ファイルを走査して起動対象を自動登録するため、追加はファイルを置くだけ、
削除はファイルを消すだけで済みます。`init.lua` はディレクトリ名そのものの機能、
`lib/` 配下は共有ライブラリとして起動対象から除外されます。

初期パス以外（`VimEnter` / `CmdlineEnter` / `AfterPlugins`）で起動する機能だけは、
`features.lua` の `phases` に名前を1行追加します。

不要な機能は、たとえば次のように `nazovim.setup()` より前に名前で無効化できます。

```lua
vim.g.nazovim_disabled_features = { "todo", "ui.scrollbar", "terminal.commands" }
```

| 旧プラグイン | 内蔵モジュール | 動作 |
| --- | --- | --- |
| lualine.nvim | `statusline/init.lua` | モード、Gitブランチ・差分、ファイル、診断件数、文字コード、改行形式、位置 |
| nvim-hlslens | `search/init.lua` | 検索件数をカーソル行の末尾に表示 |
| template.nvim | `template/init.lua` | ファイルテンプレート挿入とプロジェクト生成 |
| tiny-inline-diagnostic.nvim | `lsp/diagnostics.lua` | 現在行の診断をその下に表示 |
| fidget.nvim | `lsp/progress.lua` | LSP進捗を右下に表示、入力中は非表示、完了後2秒で消去 |
| todo-comments.nvim | `todo/init.lua` | コメントのキーワード強調、プロジェクト内の検索 |
| vim-illuminate | `lsp/references.lua` | LSP優先、Treesitterのスコープ解析をフォールバックに使用 |
| nvim-highlight-colors | `colors/init.lua` | 色リテラルの背景色プレビュー |
| satellite.nvim / nvim-scrollbar | `ui/scrollbar.lua` | 現在位置・診断のスクロールバー |
| nvim-autopairs | `edit/pairs.lua` | 括弧・クォートの自動補完、ペア内Enter展開、空ペアのBS削除 |
| mini.surround | `edit/surround.lua` | `sa` / `sd` / `sr` による囲みの追加・削除・置換 |
| mini.comment | （Neovim標準） | `gc` / `gcc`。専用モジュールは不要 |
| mini.indentscope / hlchunk / indent-blankline | `edit/indent.lua` | インデントガイドとカーソル行が属するブロックの強調 |
| nvim-ufo | `edit/folding.lua` | Treesitter優先・インデントfallbackのフォールドと折り畳み表示 |
| which-key.nvim | `ui/whichkey.lua` | 保留中のキー候補と説明をフローティング表示 |
| dial.nvim | `edit/dial.lua` | 数値・真偽値・定数の `<C-a>` / `<C-x>` 拡張 |
| nvim-spider | `edit/motion.lua` | camelCase / snake_case を分割する `w` / `e` / `b` / `ge` |
| （Neovim標準） | `edit/motion.lua` | `f` / `F` / `t` / `T` の複数行検索と `;` / `,` の繰り返し |
| quick-scope | `edit/motion.lua` | `f` / `F` / `t` / `T` 入力前に一意な検索候補を下線表示 |
| flash.nvim | `edit/jump.lua` | `<CR>` で可視範囲の文字へ、`<S-CR>` でTreesitter葉ノードへラベルジャンプ |
| nvim-tmux-navigation | `terminal/tmux_navigation.lua` | `<C-h/j/k/l>` でNeovim分割とtmuxペインを移動 |
| dressing.nvim | `ui/input.lua` | `vim.ui.input()` を浮動ウィンドウで表示し、補完・履歴を提供 |
| ccc.nvim | `colors/picker.lua` / `colors/highlighter.lua` | 色パレットからカーソル位置へ挿入、`:CccHighlighterEnable/Disable` でプレビュー切替 |
| md-outline.nvim | `markdown/outline.lua` | `:MdOutline` で見出し一覧と選択位置のプレビュー |
| nvim-neoclip.lua | `search/clipboard_history.lua` | yank/delete履歴を検索・プレビューし、貼り付け・編集・削除。`:Neoclip` |
| nvim_context_vt | `edit/context_hint.lua` | Treesitterで現在の構文スコープを判定し、カーソル行末に見出しを表示。`:NazoContextToggle` |
| nvim-treesitter-context | `edit/scope_context.lua` | カーソルを含む外側スコープをウィンドウ上端に最大3行表示。`:NazoScopeContextToggle` |
| substitute.nvim | `edit/substitute.lua` | `s` + motion、`ss`、`S`、Visual `s` でレジスタ内容へ置換 |
| vim-repeat | `edit/repeat_action.lua` | 自作操作を`.`で再実行し、他の操作はNeovim標準の`.`へ委譲 |
| nvim-pnpm-catalog-lens | `tools/pnpm_catalog.lua` | package.jsonの`catalog:`をworkspace版に解決し、診断またはoverlay表示 |
| ts-error-translator.nvim | `tools/ts_error_hints.lua` | よく使うTypeScript診断コードの短い説明を行末に追加表示 |
| nvim-coverage | `test/coverage.lua` | LCOV行カバレッジをsign表示し、ファイル別・全体summaryを表示 |
| trouble.nvim | `ui/lists.lua` | quickfixでワークスペース／バッファ診断、ドキュメントシンボル、接続中LSPを一覧表示 |
| nvim-lint | `tools/lint.lua` | 保存時にfiletype別の外部リンターを実行し、結果をNeovim診断へ変換。`:NazoLint` / `<leader>ll` で手動実行 |
| hlargs.nvim | `edit/argument_highlights.lua` | 現在の関数の引数宣言とTreesitter localsで解決した参照を強調。`:NazoArgumentHighlightsToggle` で切替 |
| garbage-day.nvim | `lsp/idle.lua` | 未使用LSPクライアントを5分後に停止。ESLint / TypeScriptサーバーは除外。待機中の整理は `:NazoLspIdleCleanup` |
| lspsaga.nvim | `lsp/actions.lua` | `ga` でNeovim標準のLSPコードアクションを表示 |
| nvim-ts-autotag | `edit/autotag.lua` | HTML/JSX/Vue/Svelte/Astroの構文ノードを使って閉じタグを挿入し、対タグ名を同期。`:NazoAutotagToggle` で切替 |
| nvim-treesitter-textobjects | `edit/textobjects.lua` | 構文ノードで関数・クラス・条件・loop・block・引数を選択／移動し、隣接引数をswap |
| conform.nvim | `tools/format.lua` | 保存時と `<leader>f` で外部 formatter を実行し、ない場合は LSP formatting にfallback |
| actions-preview.nvim | `tools/action_preview.lua` | `<leader>ca` でLSPコードアクションのworkspace editをdiff表示して選択・適用 |
| overseer.nvim | `tools/tasks.lua` | `<leader>or` でtaskを実行、`<leader>ot` で状態一覧・出力・停止を操作 |
| dropbar.nvim | `ui/breadcrumb.lua` | ファイルパスとTreesitter構文階層をwinbarに表示。`<leader>;` / `:NazoBreadcrumbPick` で階層位置を選択 |
| translate.nvim | `ai/translate.lua` | `<leader>T` または `:NazoTranslate [language]` で行・選択範囲を翻訳し、結果をフロート表示。Translate Shell (`trans`) が必要 |
| aerial.nvim | `ui/outline.lua` | `<leader>so` または `:NazoOutlineToggle` でLSPシンボル、Treesitter構文、Markdown見出しのサイドバーを表示 |
| package-info.nvim | `tools/package_info.lua` | `package.json` の最新依存バージョンを表示し、追加・更新・削除・バージョン変更を実行。レジストリ照会に `npm`、操作にプロジェクトの package manager を使用 |
| nvim-web-devicons | `ui/icons.lua` | 拡張子・ファイル名・filetype からアイコンとハイライトを返すdevicons互換API（`get_icon` / `get_icon_by_filetype` / `get_icons` / `set_icon`）。tabline とファイルブラウザーが使用 |
| vim-fugitive | `git/init.lua` | `git` CLI を直接呼び、statusバッファ（`s` stage / `u` unstage / `d` diff / `R` refresh / `q` close）、`<leader>ga` / `<leader>gu` / `<leader>gl`、`:Git <args>`（`%` は現在ファイルに展開）、`:NazoGitBlame` を提供 |
| lazydev.nvim | `lsp/init.lua` | lua_ls の `workspace.library` に `$VIMRUNTIME`（Neovim API の型）と nazoplug のランタイムディレクトリ（`NazoSpec` 注釈）を登録 |
| mason.nvim / mason-lspconfig.nvim / nvim-lspconfig / zigtools-zls | `lsp/init.lua` | 言語サーバーを `vim.lsp.config` / `vim.lsp.enable` で直接設定し、PATH上に実行ファイルがあるものだけを起動（devShellが供給）。lua_ls / clangd / html / cssls / jsonls / emmet / nixd / taplo / yamlls / marksman / bashls / gopls / pyright / jdtls / rust_analyzer / ts_ls / solargraph / zls を定義し、`K` / `<leader>ls` / `<leader>ld` / `<leader>lf` をバッファマップする。hover と signature help は `vim.lsp.config("*")` で丸枠に統一。`:NazoLspInfo` で有効・接続中・不足サーバーを確認 |
| （Neovim標準） | `lsp/symbols.lua` | `grw` でワークスペースシンボルをquickfixに一覧、`<leader>gr` でカーソル下の参照をquickfix化、`gD` で宣言へジャンプ、`<leader>lT` で型階層（supertypes / subtypes）を選択 |
| （Neovim標準） | `lsp/calls.lua` | `<leader>lci` / `<leader>lco` でカーソル下シンボルの呼び出し階層を収集しquickfixにインデント付きで表示。深さ4・300ノードで打ち切る |
| （Neovim標準） | `lsp/display.lua` | `<leader>li` inlay hints、`<leader>lS` semantic tokens、`<leader>lh` code lens をバッファ単位でトグル |
| （Neovim標準） | `lsp/lifecycle.lua` | `<leader>lr` 再起動 / `<leader>lq` 停止 / `:NazoLspStart [name]` 起動。再起動は `Client:_restart()` を使い、利用できない場合は `vim.lsp.enable()` で再アタッチする |
| （Neovim標準） | `health.lua` | `:checkhealth nazovim` でLSPの有効／不足、稼働中クライアント、Treesitterパーサーを確認 |
| nvim-cmp / cmp-nvim-lsp / cmp-buffer / cmp-path / cmp-calc | `completion/init.lua` | Neovim標準の `vim.lsp.completion` を有効化（autotrigger + `completeopt=menu,menuone,noselect,popup`）。`<C-Space>` でLSP補完、LSPが無いバッファではsnippet・バッファ内単語・パスを独自候補として表示。`<CR>`確定、`<Tab>`/`<S-Tab>` で確定とsnippetプレースホルダ移動。ファイルパスは `/` を含む入力で補完 |
| cmp-cmdline | `cmdline/completion.lua` | Neovim標準のwildmenuとpopupでExコマンド・パス・検索入力を補完 |
| render-markdown.nvim | `markdown/render.lua` | Markdownバッファに見出し・コードブロック・箇条書き・checkbox・引用・表・リンクの装飾を追加。`<leader>um` / `:NazoMarkdownRenderToggle` で切替 |
| nvim-dap / nvim-dap-vscode-js / vscode-js-debug | `dap/init.lua` | Debug Adapter Protocol をstdio上で自前実装（`Content-Length` フレーミング、request/response/event、`initialize` → `launch` → `configurationDone`）。`js-debug` アダプタをTCPモードで起動し、`<F5>` / `<F10>` / `<F11>` / `<F12>` でcontinue・step over・step in・step out、`<leader>db` でbreakpoint切替、`<leader>dB` で一覧バッファ、`<leader>dl` で開始、`<leader>de` で式評価、`<leader>dq` で終了、`:NazoDapInfo` で状態確認。breakpointはパス単位で保持し、`setBreakpoints` を自動送信 |
| nvim-dap-virtual-text | `dap/virtual_text.lua` | Treesitter locals と DAP scope 値から変数定義行に値を表示し、例外停止理由を表示。`:NazoDapVirtualTextToggle` で切替 |
| nvim-dap-ui | `dap/ui.lua` | DAP scope・breakpoint・stack・watch式を右側パネルに表示。`<leader>du` / `:NazoDapUi` で開閉、値はEnterで展開、stack frame選択、`a` / `d` でwatch追加・削除 |
| opencode.nvim | `ai/opencode.lua` | `opencode` CLIをフローティングterminalで起動。`:OpenCode` / `:OC` で開き（引数はCLIへ渡す）、`:OpenCode --continue` などで会話を再開。`<leader>oa` で `@path` メンション、`<leader>ox` でコマンドパレット、`<C-.>` で開閉、`<C-q>` で閉じる。プラグイン固有の `go` / `goo` オペレータとセッションスクロールコマンドは提供しない |
| claudecode.nvim | `ai/claudecode.lua` | `claude` CLIをフローティングterminalで起動。`:ClaudeCode` で開き、`:ClaudeCodeToggle` / `:ClaudeCodeFocus` で開閉・フォーカス、`:ClaudeCode --resume` や `--continue` で会話を再開、`:ClaudeCodeAdd` / `:ClaudeCodeSend` で `@path` メンション、`:ClaudeCodeSelectModel` で `/model` を送信。`<C-q>` で閉じる。CLIは `npm install -g @anthropic-ai/claude-code` で導入 |
| avante.nvim | `ai/ask.lua` | `claude -p` / `codex exec` / `opencode run` を `vim.system` で非対話実行し、右分割パネルへストリーミング表示。`:NazoAI` / `<leader>aa` で質問、`<leader>ae` で回答のコードブロックをバッファへ適用、`<leader>at` でパネル開閉、`<leader>a?` でプロバイダ選択、`<leader>ac` / `<leader>aB` で文脈ファイル添付、`<leader>ah` で履歴。チャットUI・diffプレビュー・repomap は含まない |
| codex.nvim | `ai/codex.lua` | Codex CLIをフローティングterminalで起動。`:Codex` で開き、`:CodexToggle` でセッションを保持したまま開閉、`<C-q>` で閉じる。CLIは `npm install -g @openai/codex` で導入 |
| oil.nvim / neo-tree.nvim / yazi.nvim | `ui/file_browser.lua` | ディレクトリバッファ、Git状態、隠しファイル切替、preview、作成・再帰コピー・rename・再帰削除。`<leader>m` / `<leader>n` / `:NazoFiles` |
| Snacks Picker / Telescope (基本選択) | `search/picker.lua` | プロジェクトファイル・バッファ・最近使ったファイル・`rg`検索結果を独自fuzzy順位付けで選択。`<leader><leader>` / `<leader>b` / `<leader>r` / `<leader>/`。`grep(directory)` で任意ディレクトリを検索できる |
| snacks.nvim (Dashboard) | `startup/dashboard.lua` | 起動時に引数なしならヘッダー・最近使ったファイル・キーマップを表示。`e`新規、`f`ファイル検索、`.`ブラウズ、`r`最近使ったファイル、`z`プラグイン、`q`終了、`<CR>`で最近使ったファイルを開く。`:NazoDashboard` で再表示 |
| snacks.nvim (Statuscolumn) | `ui/statuscolumn.lua` | sign・fold・行番号を1列にまとめる`statuscolumn`式を設定。`number` / `relativenumber` に追従し、`:NazoStatuscolumn` で再適用、`:NazoStatuscolumn!` でリセット |
| snacks.nvim (Quickfile) | `search/quickfile.lua` | `BufWritePre` で親ディレクトリが無ければ `mkdir -p` してから書き込む。存在しない深いパスへ `:write` できる |
| snacks.nvim (Zen) | `ui/zen.lua` | 行番号・sign列・statusline・winbar・診断を隠す集中表示。`<leader>z` / `:NazoZen` でトグルし、終了時に元の設定へ戻す |
| noice.nvim | `cmdline/ui.lua` / `ui/notifications.lua` | コマンドラインpopup、通知フロートと履歴、`:NazoMessages`。検索件数は`search/init.lua`、LSP hover/signatureはNeovim標準APIを使用 |
| kanagawa.nvim | `colors/scheme.lua` / `colors/nazovim.lua` | 独自の青緑系暗色パレット、透明な通常背景、標準・Tree-sitter・診断highlightを設定 |
| Octo.nvim (Issue / PR一覧・表示・作成・編集、通知、検索) | `github/init.lua` | `gh` CLIでIssue/PR作成・タイトル/本文編集・コメント・close/reopen、通知、検索を操作。作成は`:NazoGitHubIssueCreate` / `:NazoGitHubPRCreate`、フォームは1行目がタイトル、2行目以降が本文で`<C-s>`送信 |
| Octo.nvim (Discussion create/edit/delete/reply/poll/answer/vote/reaction/category/subscription/close) | `github/discussions.lua` | `<leader>od`で一覧、`:NazoGitHubDiscussionCreate` / `<leader>oD`で作成。詳細は`c`返信、`e`編集、`d`削除、`p`poll投票、`a`accepted answer、`u`upvote、`r`reaction、`s`購読、`g`カテゴリ変更、`m`コメント管理、`x`close/reopen。GitHub GraphQLと認証が必要 |
| Octo.nvim (Issue / PR labels・assignees・milestones・project・reactions、PR reviewers) | `github/metadata.lua` | `:NazoGitHubMetadata` / `<leader>om` で対象を選び、ラベル・担当者・milestone・projectの追加/削除、8種のリアクション切替、PR reviewerの追加/削除を行う。GitHub CLI (`gh`) と認証が必要 |
| Octo.nvim (Issue pin / subscription / develop) | `github/issue_extras.lua` | `:NazoGitHubIssueExtras` / `<leader>oI` でIssueを選び、pin/unpin・通知購読状態の変更・`gh issue develop` によるリンクブランチ作成を行う。pin権限・購読可能状態を確認してからGitHub GraphQLを呼び出す |
| Octo.nvim (PR checks・merge・checkout・ready/draft・branch update) | `github/pr_actions.lua` | `:NazoGitHubPRActions` / `<leader>oA` からPRを選び、checksの一覧、branch checkout、merge方式選択、ready/draft切替、base branch更新を操作。merge・checkout・更新は確認後に実行 |
| Octo.nvim (PR diff・全体/行レビュー) | `github/review.lua` | `:NazoGitHubReview` / `<leader>oR` でopen PRを選び、独立diff bufferで変更を読む。diff上の`c`で行コメント、Visual選択中の`c`で複数行コメント、`t`で既存thread一覧。thread画面で`r`返信・`x`解決/再オープン。`r`からApprove / Comment / Request changesも送信 |
| Octo.nvim (PR commits / changes / runs) | `github/pr_details.lua` | `:NazoGitHubPRDetails` / `<leader>oC` でPRを選び、commits・変更ファイル・check runsを一覧。`<CR>`でcommit diffまたはファイルpatch、`gx`でGitHubを開く |
| Octo.nvim (Project board) | `github/projects.lua` | `:NazoGitHubProjects` / `<leader>oB` でプロジェクトを選び、item一覧・status変更・issue/PRの追加・archiveを行う。`gh` に `project` スコープが必要 |
| Octo.nvim (gist) | `github/gists.lua` | `:NazoGitHubGists` / `<leader>oG` で自分のgistを一覧。`<CR>`でブラウザ表示、`y`でURLをコピー。`gh api gists` を使用 |
| LuaSnip / denippet.vim / friendly-snippets | `completion/snippets.lua` | `snippets/` の独自JSON定義を補完候補として表示し、展開後はTab / Shift-Tabでplaceholderを移動。`:NazoSnippetExpand` / `:NazoSnippetReload` |
| nvim-java / spring-boot.nvim | `lsp/init.lua` | `jdtls`（jdt-language-server）を `vim.lsp.config` で定義。`cmd` を関数にしてプロジェクトルートごとに `-data` ワークスペースを作る。Lombok・テスト実行・DAP 連携は含まない |
| rustaceanvim | `lsp/init.lua` | `rust_analyzer`（rust-analyzer）を `vim.lsp.config` で定義し、`cargo.allFeatures` と `check.command = "clippy"` を設定。`<leader>rr` は `experimental/runnables` を引いて `vim.ui.select` で選び、terminal split で実行 |
| typescript-tools.nvim | `lsp/init.lua` | `ts_ls`（typescript-language-server）を `vim.lsp.config` で定義。formatting と semantic tokens を無効化し、`<leader>oi` organize imports / `<leader>ru` remove unused を code action で実行 |
| nvim-treesitter | `edit/treesitter.lua` | `vim.treesitter.start` で `FileType` ごとにハイライトを開始。grammar（`parser/<lang>.so` と `queries/<lang>/`）は Nix が `NAZOVIM_TREESITTER_DIR` で供給し、runtimepath に追加するだけ。`:NazoTreesitterInfo` で利用可能な言語を確認 |
| nvim-treesitter incremental selection | `edit/incremental_selection.lua` | `gnn` で開始、`grn` / `grm` で構文親ノードへ拡張・縮小、`grq` で終了。Neovim標準Tree-sitter APIを使用 |
| vim-bad-apple | `ui/animation.lua` | `:NazoAnimation [fps]` で独自生成の幾何学アニメーションを再生。任意のテキストフレームも `play(frames, fps)` で再生可能。`q` / `<Esc>` / `:NazoAnimationStop` で停止 |
| vim-kensaku | `search/romaji_search.lua` | `/` / `?` の入力確定時にローマ字をひらがな・カタカナ検索パターンへ変換。Migemo辞書による漢字展開はなし。`:NazoRomajiSearchToggle` で切替 |
| persistence.nvim | `tools/session.lua` | 作業ディレクトリ単位のセッション保存・復元。終了時に自動保存、`:NazoSessionSelect` で選択 |
| gitsigns.nvim | `git/signs.lua` | Git差分サイン、`]h` / `[h` のhunk移動、`<leader>gp` preview、`<leader>gt` blame |
| diffview.nvim | `git/review.lua` | `<leader>gd` 変更ファイル、`<leader>gh` / `<leader>gH` 履歴。conflict中は `<leader>co` / `ct` / `ca` / `dx` で選択、`<leader>gc` でビューを閉じる |
| lazygit.nvim | `git/lazygit.lua` | `<leader>gg` / `:LazyGit` でLazyGitを浮動terminalから起動。外部 `lazygit` が必要 |
| swagger-preview.nvim | `tools/swagger_preview.lua` | `:NazoSwaggerPreview [file]` でプレビュー、Stop/Toggleコマンドで管理。`swagger-ui-watcher` が必要 |
| neotest / Jest / Vitest / Playwright adapters | `test/runner.lua` | `<leader>tr` で現在テストの最寄りcase、`<leader>tf` でファイル、`<leader>tR` で全体を実行。`<leader>to` で最新出力、`:NazoTestStop` で停止 |
| refactoring.nvim | `lsp/refactor.lua` | `<leader>rR` / `:NazoRefactor` でLSPの `refactor` code actionを選択 |
| emmet-vim | `edit/abbreviations.lua` | Insertモードで `<C-e>,` を押すとHTML系略記を展開。CSSはmargin/padding/size/display/color等の基本略記に対応 |
| vim-svelte-inspector | `tools/svelte_inspector.lua` と `bin/nazovim-open-location` | Vite Inspectorから渡されたファイル・行・列をNeovimへ転送。開発サーバーはNazoVim内のterminalから起動 |
| kulala.nvim | `lib/http_client.lua` | `.http` / `.rest` のカーソル位置のリクエストまたは全リクエストを `curl` で送信し、レスポンスを分割ウィンドウに表示。`<leader>Rs` / `Ra` / `Rb` |
| marks.nvim | `edit/marks.lua` | マークのサイン表示、`:Marks` 一覧、`]m` / `[m` 移動 |
| spellsitter.nvim | `edit/spell.lua` | 散文ファイルタイプだけspellを有効化 |
| barbar.nvim | `ui/tabline.lua` | バッファタブ、クリック遷移、バッファ移動キー |

Snacks の `words` と通知は無効化し、参照表示と通知はNazoVim内蔵機能に集約しています。

## エディタ操作

Snippet定義は `stdpath("config")/snippets/<filetype>.json` に置きます。VSCode形式の
`prefix`、`body`、`description`、`${1:name}`、`${2}`、`$0`、変数の基本subsetを
読み込みます。`:NazoSnippetExpand [prefix]` で展開し、補完候補の確定でも展開できます。
設定ディレクトリを変える場合は `vim.g.nazovim_snippet_dir` を指定してください。

- `sa` + motion + 文字: 囲みを追加（例: `saiw)`）。Visualモードでも可。
- `s` + motion: 選択範囲をレジスタ内容に置換。`ss` は行、`S` はカーソルから行末、Visual `s` は選択範囲。
- `sd` + 文字: カーソルを囲むペアを削除。
- `sr` + 文字 + 文字: 囲みを置換。
- `<C-a>` / `<C-x>`: カーソル下の数値・真偽値・`let`/`const`/`var` などを増減。Visualモードは選択範囲内のトークン（行選択なら行全体）。
- `w` / `e` / `b` / `ge`: camelCase と snake_case の境界で移動。
  operator-pending と Visual でも動作。
- `f` / `F` / `t` / `T`: 現在行の先も含めてバッファ内を文字検索。`;` は同方向、`,` は逆方向に直前の検索を繰り返します。
- `<CR>`: 表示範囲の行と文字にラベルを表示してジャンプ。`<S-CR>` はTreesitterが使える場合に構文葉ノードへジャンプします。
- `]m` / `[m`: 現在バッファの次／前のマークへ移動。`:Marks` でquickfix一覧。
- `<leader>?`: 保留中のキー候補を表示。通常は200ms待つと自動表示。
- `<C-PageDown>` / `<C-PageUp>`: 次／前のバッファ。タブをクリックしても移動。
- `<C-t>` / `<C-q>`: 新規バッファ／現在バッファを閉じる。
- `:SpellToggle`: 散文のスペルチェックを一括で切り替え。
- `zR` / `zM`: 全フォールドを開く／閉じる（Neovim標準）。

自動補完はコメント・文字列内ではTreesitterがある場合に無効化されます。
パーサーがない場合は単純な文字判定にフォールバックします。
`sa` は `(` `[` `{` `<` `"` `'` `` ` `` に対応します。タグ囲みは未対応です。
インデントガイドは `tabstop == shiftwidth` を前提に `listchars.leadmultispace` を使います。
`listchars` の他の設定は保持されます。特殊バッファ（`buftype` が空でないもの）には
自動補完を適用しません。
折り畳みは `foldmethod=expr` と `foldexpr` を使うため、手動フォールドとは併用しません。

## 操作

- `n` / `N` / `*` / `#`: 従来どおり検索。カウント指定にも対応。
- `<leader>l`: 検索件数の表示切替。
- `<leader>h`: 検索ハイライトと件数表示の消去。
- `<M-n>` / `<M-p>`: 次／前の参照へ移動。
- `<M-i>`: Visual／Operator-pendingモードでカーソル下の参照を選択。
- `:TodoQuickFix`: プロジェクト内のTODO候補をquickfixに表示。
- `:TodoLocList`: 同じ検索結果を現在ウィンドウのlocation listに表示。
- `:TodoTelescope` / `:TodoTrouble`: 移行用の別名。quickfixに表示。

TODO検索には `rg` が必要です。Gitのignore設定を尊重します。

PNPM catalog表示は `vim.g.pnpm_catalog_display = "diagnostics"` または `"overlay"` で選べます。
`:PnpmCatalogLensEnable` / `:PnpmCatalogLensDisable` で切り替えます。

TypeScript診断の補助説明は `:NazoTypeHintsEnable` / `:NazoTypeHintsDisable` で切り替えます。
対応する診断コードだけに短い説明を追加し、元の診断メッセージはそのまま残します。

CoverageはLCOV (`DA:`) の行カバレッジに対応します。`:CoverageLoad [path]`、
`:CoverageSummary`、`:CoverageToggle`、`:CoverageHide` を使います。
一覧検索はテキスト検索なので文字列内の候補も含みます。
バッファの強調表示はTreesitter、syntax、`commentstring`の順で
コメントを判定します。パーサーのない場合の複数行コメントには制限があります。

## テンプレート

```vim
" 選択UIから挿入
:Template
" 現在のファイルに挿入（Tab補完対応）
:Template lua/module.lua
" 新しいファイルを開いて挿入
:Template sample.ts typescript/api.ts
" 新しいディレクトリにプロジェクトを生成
:TemplateProject minimal ./my-project
```

空バッファでは内容を置換し、それ以外では現在行の後ろに挿入します。
ファイルは自動保存しません。プロジェクト生成は既存ディレクトリを拒否し、
テンプレート内の相対ファイル名をそのまま使います。

利用できる置換は `{{_file_name_}}`（拡張子を除く名前）、
`{{_date_}}`、`{{_author_}}`、`{{_email_}}`、`{{_upper_file_}}`、
`{{_camel_case_file_}}`、`{{_cursor_}}` です。
未知の置換は文字列のまま残します。任意Luaの実行や変数入力プロンプトはありません。
同名テンプレートが複数ある場合は相対パスで指定してください。

設定例:

```lua
vim.g.nazovim_template_dir = "~/my-templates"
vim.g.nazovim_template_author = "Your Name"
vim.g.nazovim_template_email = "you@example.com"
```

既定では `stdpath("config")/template` を使い、リポジトリから実行する場合は
ルートの `template/` にフォールバックします。Nix配布物にも同梱します。
手動インストールでは `template/` も設定ディレクトリへコピーしてください。

## 表示と性能の方針

- ステータスラインの描画中に外部コマンドを実行しません。
  Gitブランチと差分件数を非同期取得します。
差分表示とblameにはGit実行ファイルが必要です。
- 色とTODOの強調は表示中の行を中心に処理し、4096バイトを超える行は省略します。
  イベントをまとめ、スクロール時にバッファ全体を走査しません。
- 色はhex（3/4/6/8桁）、`rgb()` / `rgba()`、`hsl()` / `hsla()`、
  Neovimの色名に対応。アルファ値は表示に反映せずRGBを表示します。
  同一バッファのCSS変数は5000行・200KB以下で解析します。
  CSSのカスケードや外部ファイルの変数解決、関数なしHSL値は対象外です。
  色のhighlightグループは最大512個です。
- 参照は120ms間隔で処理をまとめ、古いLSP応答を破棄します。
  5000行超ではTreesitterフォールバックを使いません。
  Treesitter解析は内蔵の `lib/locals.lua`（`locals` クエリベース）を利用します。
- スクロールバーは論理行数に対する概略位置です。
  折り返し・折り畳みを画面行数に換算するミニマップではありません。
  検索・Git差分マーカーとマウス操作はありません。
- 診断はNeovim標準の `virtual_lines` を使います。
  `vim.diagnostic.enable(false)` やZenモードと連動します。

プラグインの全API・全表示形式を互換実装するものではありません。
旧 `require("lualine")` などを使う個人設定や、
`NAZOVIM_STARTUP_CONFIG` にある削除済みプラグイン名は取り除いてください。
既存プラグインのディスク上のデータは自動削除しません。

SvelteのブラウザーInspector連携には、プロジェクト側でVite Inspectorを有効にし、
  開発サーバーをNazoVimのterminalから起動してください。
  NazoVimは独自launcherを `LAUNCH_EDITOR` に設定し、既存Neovim serverへ接続します。
  手動で場所を開く場合は `:NazoOpenLocation file:line:column` を使えます。

HTTPクライアントは `###` で区切られたリクエスト、ヘッダー、本文、`@name = value` 形式の変数を扱います。
  URL・ヘッダー・本文では `{{name}}` を展開し、未定義名は同名の環境変数を参照します。
  認証フロー、Cookie jar、応答アサーションなどの高機能RESTクライアントAPIは対象外です。

## 検証

```sh
nvim --headless -u NONE -l apps/nvim/tests/builtin_test.lua
nvim --headless -u NONE -l apps/nvim/tests/features_test.lua
nvim --headless -u NONE -l apps/nvim/tests/replacements_test.lua
```

テンプレートの上書き防止、色・コメント判定、診断、検索、
スクロールバーのウィンドウ再利用、LSP進捗の寿命、
UTF-16参照位置と古いLSP応答の破棄を検証します。
