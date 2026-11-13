# NazoVim

```text
█   █  ███  █████  ███  █   █ ███ █   █
██  █ █   █     █ █   █ █   █  █  ██ ██
█ █ █ █   █    █  █   █ █   █  █  █ █ █
█  ██ █████   █   █   █ █   █  █  █   █
█   █ █   █  █    █   █  █ █   █  █   █
█   █ █   █ █     █   █  █ █   █  █   █
█   █ █   █ █████  ███    █   ███ █   █
```

**A personal Neovim distribution by [nazozokc](https://github.com/nazozokc)**

[![CI](https://github.com/nazozokc/NazoVim/actions/workflows/nvim.yml/badge.svg)](https://github.com/nazozokc/NazoVim/actions/workflows/nvim.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-blueviolet?logo=neovim)
![Nix](https://img.shields.io/badge/Nix-flake-blue?logo=nixos)

> **注意:** CIはNix環境で実行されるため、Nixなしのcloneインストールは
> 自動テストされていません。Nixを使わない場合は `nvim --headless +q` で
> 手動確認することを推奨します。

---

## ✨ About

**nazovim** は、CLI・TUI中心のワークフローに特化したNeovimディストリビューションです。

<!-- markdownlint-disable MD013 -->
独自パレットの内蔵カラースキームと、自作プラグインマネージャー `nazoplug` による高速な遅延ロードを基盤に、TypeScript・Lua・Nix・Rubyなどの開発に必要なすべてが揃っています。
<!-- markdownlint-enable MD013 -->

> Nixのflakeとして配布しているため、`nix run` 一発で隔離された状態から即起動できます。

---

## 🚀 Features

<!-- markdownlint-disable MD013 -->
- **⚡ Fast startup** — nazoplug によるアグレッシブな遅延ロード。起動を邪魔するものは VeryLazy 以降に追いやる
- **🔧 Full LSP** — TypeScript / Lua / Ruby / Nix / C / Java / Zig など多言語対応。PATH上にある言語サーバーを自動で有効化（mason不要）
- **🎨 NazoVim theme** — 独自の青緑系暗色パレットと透明背景
- **🧠 AI統合** — Claude Code と opencode を内蔵terminal統合で両方サポート（`claudecode.lua` / `opencode.lua`）
- **🌊 Dashboard / Zen** — 起動ダッシュボードと集中表示をNazoVim内蔵で提供
- **🐛 DAP** — JavaScript / TypeScript のデバッグ環境を最小構成で内包
- **📦 Nix対応** — `nix run` で隔離起動 / `nix develop` でLSP完备のdevShell
- **🧪 テスト** — NazoVim内蔵ランナー（Jest / Vitest / Playwright CLIを利用）
- **🔍 Fuzzy finding** — NazoVim内蔵の独自pickerでファイル・バッファ・検索結果を選択
- **📝 Treesitter textobjects** — 自作の構文ノード選択・移動・引数入替
<!-- markdownlint-enable MD013 -->

---

## 📋 Requirements

| 必須 | バージョン |
| ---- | ---------- |
| Neovim | 0.10+（`nix run` では Nix が用意） |
| Git | any |
| [Nerd Font](https://www.nerdfonts.com/) | アイコン表示に必要 |

| 推奨 | 用途 |
| ---- | ---- |
| Nix (flakes対応) | `nix run` / `nix develop` での隔離起動 |
| Node.js | TypeScript LSP / prettier |
| NazoVim 内蔵 | LazyGit浮動terminal起動（`lazygit.lua`、外部 `lazygit` が必要） |
| ripgrep | Grep検索 |
| fd | ファイル検索 |

---

## 📦 Installation

### 方法1: `nix run`（まずは使ってみる人）

```bash
nix run github:nazozokc/NazoVim
```

<!-- markdownlint-disable MD013 -->
設定は `~/.config/nvim-nazozokc` に隔離して展開されるため、既存のNeovim設定を汚しません。
<!-- markdownlint-enable MD013 -->

最初の起動ではプラグインは自動ダウンロードされません。プラグインがない場合は
組み込みの案内画面から `o` でファイルを開き、`i` で編集、`Esc` の後に
`:w` で保存、`:q` で終了できます。追加機能が必要なら `p` または
`:NazoPlug install` でプラグインを導入し、再起動してください。
プラグインの取得にはネットワークと時間が必要です。

セッションの設定・プラグイン・キャッシュを終了時に破棄するには:

```bash
nix run github:nazozokc/NazoVim -- --temporary
```

一時セッションでは導入したプラグインも終了時に削除されます。編集したファイルは
保存先に残ります。通常の起動ではデータとキャッシュを再利用します。
Nix と flakes が必要で、初回は Nix 自体のダウンロードやビルドに時間がかかります。

内蔵UI・検索・テンプレートの操作と移行時の違いは
[内蔵機能ガイド](docs/builtin-features.md)を参照してください。

### 起動タイミングの設定

`NAZOVIM_STARTUP_CONFIG` に Lua ファイルのパスを指定すると、プラグインごとの
読み込みタイミングを変更できます。例えば `startup.lua` に次を書きます。

```lua
return {
  very_lazy_delay_ms = 200,
  plugins = {
    ["tokyonight.nvim"] = "VeryLazy",
  },
}
```

```bash
NAZOVIM_STARTUP_CONFIG="$HOME/startup.lua" nix run github:nazozokc/NazoVim
```

タイミングは `startup`、`on_demand`、`VeryLazy`、`InsertEnter` などの Neovim イベント、
または `User MyEvent` の形式です。`VeryLazy` は UI 表示後に実行され、
`very_lazy_delay_ms` で待ち時間をミリ秒単位で設定できます。指定がない場合は
100ms です。`NAZOVIM_VERY_LAZY_DELAY_MS=200` でも指定でき、
こちらが Lua ファイルの値より優先されます。

NazoVim は外部プラグインを同梱していないため、既定の `plugins` は空です。
プラグインを追加したら、この設定でキー・コマンド・イベントによる読み込みを指定できます。

コマンド・キー・ファイルタイプによる読み込みは残るため、指定イベントより早く
使われた場合はその時点で読み込まれます。他のプラグインが依存する場合も先に
読み込まれることがあります。`init` 関数は引き続き起動時に実行されます。
遅延はプラグインを使える時刻を遅らせるため、設定前後の体感を測って選んでください。

### 方法2: Clone（Nix 不要）

> **注意**: 既存の Neovim 設定を上書きします。バックアップを推奨します。

```bash
# Sparse checkout — `apps/nvim/` と `apps/nazoplug/` をダウンロード
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/nazozokc/NazoVim.git ~/.config/nvim
cd ~/.config/nvim
git sparse-checkout set apps/nvim apps/nazoplug
mv apps/nvim/* .
mkdir -p lua
cp -r apps/nazoplug/lua/nazoplug lua/
rm -rf apps
nvim
```

初回起動後に `:NazoPlug install` を実行すると、未導入のプラグインをインストールします。
既存の lazy.nvim 環境がある場合は `:NazoPlug migrate` でデータディレクトリを引き継げます。

> monorepo 構成のため、Neovim 設定は `apps/nvim/`、マネージャーは `apps/nazoplug/` にあります。
> 上記の sparse checkout で両方取得できます。

---

## 🗂️ Directory Structure

```text
.
├── apps/
│   ├── nvim/                 # 🎯 Neovim configuration (entry point)
│   │   ├── init.lua          # nazoplug bootstrap (lazy.nvim fallback)
│   │   ├── nazoplug-lock.json # プラグインバージョンロック
│   │   └── lua/
│   │       ├── config/       # options / keymaps / autocmds
│   │       └── plugins.lua   # 追加プラグインの import（既定は空）
│   └── nazoplug/             # 自作プラグインマネージャー
│       ├── lua/nazoplug/     # loader / installer / lock / git
│       └── tests/            # headless tests
├── packages/
│   └── nix/                  # Nix modules
├── template/                 # ファイルテンプレート
│   ├── js/
│   ├── ts/
│   ├── lua/
│   ├── md/
│   └── project/
├── docs/                     # ドキュメント
├── flake.nix                 # Nix flake (nix run / nix develop)
└── .github/                  # CI workflows / issue templates
```

---

## 🔌 Plugins

### LSP / 補完

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | LSP管理（`lsp.lua`、`vim.lsp.config` / `vim.lsp.enable`、PATH上のサーバーのみ起動、`:NazoLspInfo`） |
| NazoVim 内蔵 | ファイルアイコン（`icons.lua`、`get_icon` / `get_icon_by_filetype` のdevicons互換API） |
| NazoVim 内蔵 | TypeScript / JavaScript LSP（`lsp.lua` の `ts_ls` = typescript-language-server。formatting と semantic tokens を無効化、`<leader>oi` / `<leader>ru`） |
| NazoVim 内蔵 | Rust LSP（`lsp.lua` の `rust_analyzer` = rust-analyzer。`<leader>rr` で runnables を選択して実行） |
| NazoVim 内蔵 | Java LSP（`lsp.lua` の `jdtls` = jdt-language-server。プロジェクトごとに `-data` ワークスペースを分ける） |
| NazoVim 内蔵 | 補完（`completion.lua`、`vim.lsp.completion` + snippet/buffer/path、`<C-Space>` / `<Tab>` / `<S-Tab>` / `<CR>`） |
| NazoVim 内蔵 | コマンドライン補完（`cmdline_completion.lua`） |
| NazoVim 内蔵 | 独立snippet展開・placeholder移動（`snippets.lua`、VSCode JSON subset） |
| NazoVim 内蔵 | Tree-sitter構文ノードの選択拡張・縮小（`incremental_selection.lua`） |

Snippetは `snippets/<filetype>.json` に追加できます。
  補完候補の確定または `:NazoSnippetExpand [prefix]` で展開し、Tab / Shift-Tabで入力位置を移動します。
  構文選択は `gnn` で開始し、`grn` / `grm` で拡張・縮小します。
| NazoVim 内蔵 | Neovim標準LSPコードアクション（`lsp_actions.lua`） |
| NazoVim 内蔵 | LSPコードアクション差分プレビュー（`action_preview.lua`） |
| NazoVim 内蔵 | LSPリファクタリング操作（`refactor.lua`） |
| NazoVim 内蔵 | 外部 formatter（`format.lua`） |
| NazoVim 内蔵 | 外部リンター（`lint.lua`） |
| NazoVim 内蔵 | タスク実行と履歴（`tasks.lua`） |
| NazoVim 内蔵 | LSPプログレス表示 |
| NazoVim 内蔵 | インライン診断 |
| NazoVim 内蔵 | Lua/Neovim API の型補完（`lsp.lua` が lua_ls に `$VIMRUNTIME` を渡す） |

### Fuzzy Finder / ナビゲーション

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | 起動ダッシュボード（`dashboard.lua`、`:NazoDashboard`） |
| NazoVim 内蔵 | Zenモード（`zen.lua`、`<leader>z` / `:NazoZen`） |
| NazoVim 内蔵 | statuscolumn（sign・fold・行番号を1列に統合、`:NazoStatuscolumn`）と quickfile（書き込み時に親ディレクトリを自動作成、`quickfile.lua`） |
| NazoVim 内蔵 | ファイル・バッファ・最近使った項目・テキスト検索picker（`picker.lua`） |
| NazoVim 内蔵 | バッファベースのファイルブラウザー（`file_browser.lua`、`<leader>m` / `<leader>n`）。旧 oil / neo-tree / yazi を置換 |
| NazoVim 内蔵 | Winbar / パンくずリスト（`breadcrumb.lua`） |
| NazoVim 内蔵 | 翻訳コマンド（`translate.lua`、Translate Shellを使用） |
| NazoVim 内蔵 | package.json依存管理（`package_info.lua`） |
| NazoVim 内蔵 | `<CR>` の可視範囲ジャンプと `<S-CR>` のTreesitterノードジャンプ（`jump.lua`） |
| NazoVim 内蔵 | シンボルアウトライン（`outline.lua`） |
| project.nvim | プロジェクトルート自動検出 |

### UI / 見た目

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | 独自カラースキーム（青緑系暗色 + 透明背景、`colorscheme.lua`） |
| NazoVim 内蔵 | ステータスライン |
| NazoVim 内蔵 | バッファタブ（クリック遷移対応） |
| NazoVim 内蔵 | インデントガイド / 現在ブロック強調 |
| NazoVim 内蔵 | コマンドラインpopup・通知・メッセージ履歴（`cmdline_ui.lua` / `notifications.lua`） |
| NazoVim 内蔵 | スクロールバー |
| NazoVim 内蔵 | モード別の行番号色 |
| NazoVim 内蔵 | カーソル下シンボルのハイライト |
| NazoVim 内蔵 | フローティングファイル名 |
| NazoVim 内蔵 | TODO/FIXME等のハイライト |
| NazoVim 内蔵 | Markdown のリッチ表示（`markdown_render.lua`） |
| NazoVim 内蔵 | カラーコードのインラインプレビュー |

### Git (Plugins)

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | Git差分サイン・hunk移動・preview・blame（`git_signs.lua`） |
| NazoVim 内蔵 | Git変更一覧・履歴・conflict選択（`git_review.lua`） |
| NazoVim 内蔵 | LazyGit浮動terminal起動（`lazygit.lua`） |
| NazoVim 内蔵 | Git status・stage/unstage・diff・log・blame・任意の `git` サブコマンド（`git.lua`、`:Git` / `:NazoGitStatus` / `<leader>gs`） |
| NazoVim 内蔵 | GitHub Issue / PR一覧・詳細・作成・タイトル/本文編集・コメント・close/reopen（`github.lua`、`gh` CLIを使用） |
| NazoVim 内蔵 | GitHub通知・Issue/PR検索（`github.lua`）、Discussion作成・編集・削除・返信・コメント管理・poll投票・accepted answer・upvote・リアクション・カテゴリ・購読・close/reopen（`github_discussions.lua`） |
| NazoVim 内蔵 | Issue/PRのラベル・担当者・milestone・project・リアクション、PR reviewer管理（`github_metadata.lua`） |
| NazoVim 内蔵 | GitHub Issueのpin/unpin・通知購読・リンクブランチ作成（`github_issue_extras.lua`） |
| NazoVim 内蔵 | PR checks・merge・checkout・ready/draft・branch更新（`github_pr_actions.lua`） |
| NazoVim 内蔵 | PR diff・行コメント・thread返信/解決・全体レビュー（`github_review.lua`） |
| NazoVim 内蔵 | PR commits・変更ファイル・check runsの一覧と差分表示（`github_pr_details.lua`） |
| NazoVim 内蔵 | Project boardのitem一覧・status変更・issue/PR追加・archive（`github_projects.lua`） |
| NazoVim 内蔵 | gist一覧とブラウザ表示（`github_gists.lua`） |

### エディタ機能

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | Treesitter（`treesitter.lua`、`vim.treesitter.start`、grammarはNix供給、`:NazoTreesitterInfo`） |
| NazoVim 内蔵 | 関数・クラス・条件・loop・block・引数の選択と移動（`textobjects.lua`） |
| NazoVim 内蔵 | `f` / `F` / `t` / `T` の複数行検索と `;` / `,` の繰り返し |
| NazoVim 内蔵 | 括弧・クォート自動補完（`pairs.lua`） |
| NazoVim 内蔵 | Surround（`sa` / `sd` / `sr`） |
| NazoVim 内蔵 | 自作操作の`.`再実行（`repeat_action.lua`） |
| NazoVim 内蔵 | camelCase/snake_case対応 `w` / `e` / `b` / `ge` |
| NazoVim 内蔵 | HTML/CSS略記展開（`abbreviations.lua`、`<C-e>,`） |
| NazoVim 内蔵 | `<C-a>/<C-x>` の拡張インクリメント |
| NazoVim 内蔵 | キーマップヘルプ（`<leader>?`） |
| NazoVim 内蔵 | マークのサイン表示・`:Marks` 一覧 |
| NazoVim 内蔵 | 散文のスペルチェック（`:SpellToggle`） |
| NazoVim 内蔵 | Treesitterフォールド（`zR` / `zM`） |
| NazoVim 内蔵 | レジスタを使った置換（`substitute.lua`） |
| NazoVim 内蔵 | フローティングターミナル（`:ToggleTerm`） |
| NazoVim 内蔵 | `.http` リクエストを送信してレスポンス表示（`http_client.lua`） |
| NazoVim 内蔵 | OpenAPI / Swagger preview（`swagger_preview.lua`、`swagger-ui-watcher` を使用） |
| NazoVim 内蔵 | セッション保存・復元（`session.lua`） |
| NazoVim 内蔵 | Svelte Vite Inspectorの場所をNeovimで開く（`svelte_inspector.lua`、NazoVim terminalからdev serverを起動） |
| NazoVim 内蔵 | `.http` リクエストの送信とレスポンス表示（`http_client.lua`、`curl` が必要） |

### AI統合

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | Codex CLI統合（`codex.lua`、`:Codex` / `:CodexToggle`、`<C-q>`で閉じる） |
| NazoVim 内蔵 | Claude Code CLI統合（`claudecode.lua`、`:ClaudeCode` / `:ClaudeCodeToggle` / `:ClaudeCodeFocus`、`<C-q>`で閉じる） |
| NazoVim 内蔵 | opencode CLI統合（`opencode.lua`、`:OpenCode` / `:OC`、`<C-.>`で開閉） |
| NazoVim 内蔵 | 非対話AIクライアント（`ai_ask.lua`、`claude -p --tools "" --restricted --strict-mcp-config --safe-mode` / `codex exec --sandbox read-only --ephemeral --ignore-rules --ignore-user-config` / `opencode run --pure` を右分割パネルへストリーミング。`.env`・秘密鍵・認証情報を文脈から除外し、プロンプト内のトークン/パスワードを伏字化、文脈・プロンプト・出力・時間に上限。`:NazoAI` / `<leader>aa` / `<leader>ae` / `<leader>at` / `<leader>a?` / `:NazoAIDiff` / `:NazoAIQuickfix` / `:NazoAIExplain` / `:NazoAIFix` / `:NazoAIReview` / `:NazoAITest` / `:NazoAIDocs`） |

### デバッグ / テスト

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | DAPクライアント（`dap.lua`、stdioのDebug Adapter Protocol実装。`js-debug` アダプタを起動し、`<F5>` / `<F10>` / `<F11>` / `<F12>` で実行制御、`<leader>db` でbreakpoint、`<leader>dB` で一覧、`<leader>dl` で開始、`<leader>de` で式評価、`<leader>dq` で終了、`:NazoDapInfo` で状態確認） |
| NazoVim 内蔵 | DAP情報パネル（`dap_ui.lua`、scope展開・stack選択・watch操作） |
| NazoVim 内蔵 | JS/TS デバッグアダプタ起動（`dap.lua`、`js-debug` をTCPモードで起動。devShellが供給） |
| NazoVim 内蔵 | テスト実行と最新出力表示（`test_runner.lua`） |
| NazoVim 内蔵 | LCOVカバレッジ表示（`coverage.lua`） |
| NazoVim 内蔵 | DAP変数値・例外停止理由のインライン表示（`dap_virtual_text.lua`） |
| NazoVim 内蔵 | 独自生成の端末アニメーション（`animation.lua`） |

---

## ⌨️ Keymaps

`<Leader>` = `Space`

### 基本

| キー | 動作 |
| ---- | ---- |
| `<Leader><Leader>` | ファイル検索 (NazoVim内蔵 picker) |
| `<Leader>/` | Live Grep |
| `<Leader>b` | バッファ一覧 |
| `<Leader>r` | 最近使ったファイル |
| `<Leader>h` | 検索ハイライト解除 |
| `<Leader>z` | Zen mode |
| `<Leader>m` / `<Leader>n` | ファイルブラウザー |
| `<Leader>n` | Neo-tree |
| `<Leader>t` | フローティングターミナル |
| `<Leader>f` | フォーマット |

### LSP

| キー | 動作 |
| ---- | ---- |
| `K` | ホバー |
| `<Leader>ls` | Signature help |
| `gd` | 定義へ移動 |
| `ga` | コードアクション (Lspsaga) |
| `<Leader>ca` | コードアクション (preview) |
| `<Leader>gd` | 定義へ移動 |
| `<Leader>gr` | 参照一覧 |
| `<Leader>oi` | Import整理 (TS) |
| `<Leader>ru` | 未使用削除 (TS) |

### Treesitter Textobjects

| キー | 動作 |
| ---- | ---- |
| `af` / `if` | outer / inner 関数 |
| `ac` / `ic` | outer / inner クラス |
| `aa` / `ia` | outer / inner 引数 |
| `ai` / `ii` | outer / inner 条件分岐 |
| `al` / `il` | outer / inner ループ |
| `ab` / `ib` | outer / inner ブロック |
| `]f` / `[f` | 次/前の関数へジャンプ |
| `]c` / `[c` | 次/前のクラスへジャンプ |
| `]a` / `[a` | 次/前の引数へジャンプ |
| `<Leader>sn` | 次の引数と swap |
| `<Leader>sp` | 前の引数と swap |

### Git (Keymaps)

| キー | 動作 |
| ---- | ---- |
| `<Leader>gd` | 変更ファイルのdiff選択 |
| `<Leader>gh` | ファイル履歴 |
| `<Leader>gH` | ブランチ履歴 |
| `<Leader>gc` | Git diffビューを閉じる |
| `<Leader>gp` | Hunkプレビュー |
| `<Leader>gt` | Blame toggle |
| `<Leader>gg` | LazyGit |
| `<Leader>gi` | GitHub Issue一覧。詳細で`e`編集、`c`コメント、`x` close/reopen |
| `<Leader>op` | GitHub PR一覧。詳細で`e`編集、`c`コメント、`x` close/reopen |
| `<Leader>gI` | GitHub Issue作成フォーム |
| `<Leader>oP` | GitHub PR作成フォーム |
| `<Leader>oR` | GitHub PR diff・レビュー選択。diffで`c`行コメント（Visual複数行も可）、`t`thread一覧。thread画面で`r`返信、`x`解決/再オープン |
| `<Leader>om` | GitHub Issue / PRのラベル・担当者・リアクション管理 |
| `<Leader>oA` | GitHub PR checks・merge・checkout・ready/draft・branch更新 |
| `<Leader>oC` | GitHub PR commits・変更ファイル・check runsの一覧。`<CR>`でcommit diffまたはファイルpatch、`gx`でGitHubを開く |
| `<Leader>oB` | GitHub Projects。item一覧から`<CR>`でstatus変更・archive、issue/PRの追加も行う |
| `<Leader>oG` | gist一覧。`<CR>`でブラウザ表示、`y`でURLをコピー |
| `<Leader>on` | GitHub通知一覧 |
| `<Leader>os` | GitHub Issue / PR検索 |
| `<Leader>od` | GitHub Discussions一覧。詳細で`c`返信、`e`編集、`a`回答指定、`u`upvote、`x`close/reopen |
| `<Leader>oD` | GitHub Discussion作成 |

### セッション

| キー | 動作 |
| ---- | ---- |
| `<Leader>qs` | セッション復元 |
| `<Leader>qS` | セッション選択 |
| `<Leader>ql` | 最後のセッションを復元 |
| `<Leader>qd` | セッション保存を停止 |

### AI

| キー | 動作 |
| ---- | ---- |
| `<Leader>Cc` | Claude Code toggle |
| `<Leader>Cf` | Claude Code focus |
| `<Leader>aa` | NazoAI に質問（claude / codex / opencode CLI） |
| `<Leader>ae` | 回答のコードブロックをバッファへ適用（適用前に確認） |
| `<Leader>at` | NazoAI パネル開閉 |
| `<Leader>a?` | NazoAI プロバイダ選択 |
| `<Leader>ad` | git diff を文脈に追加 |
| `<Leader>aq` | quickfix を文脈に追加 |
| `<Leader>aE` | 現在のバッファ/選択範囲を説明 |
| `<Leader>aF` | 修正版を要求 |
| `<Leader>aR` | セキュリティを含めてレビュー |
| `<Leader>aT` | テストを要求 |
| `<Leader>aD` | ドキュメントを要求 |
| `<Leader>oa` | opencode ask（現在バッファを `@path` でメンション） |
| `<Leader>ox` | opencode command palette |
| `<C-.>` | opencode toggle |

<!-- markdownlint-disable MD013 -->
NazoAI は文脈を送る前に `.env`・秘密鍵・認証情報を拒否し、トークン・パスワード・URL 埋め込み資格情報を `[REDACTED]` に置換します。Claude はツールを無効化し `--restricted --strict-mcp-config --safe-mode` で settings/hooks/CLAUDE.md を遮断してプロンプトを stdin で渡し、Codex は `--sandbox read-only` に加えて shell tool を無効化して stdin で渡し、opencode は `--pure` と `OPENCODE_PERMISSION` の組み込みツール deny で実行します。シンボリックリンク・制御文字を含むパス・コードフェンス脱出も拒否または無害化します。回答の適用前には確認を挟みます（`g:nazovim_ai_apply_confirm = false` で無効化）。上限は `g:nazovim_ai_max_context_bytes` / `g:nazovim_ai_max_prompt_bytes` / `g:nazovim_ai_max_apply_bytes` / `g:nazovim_ai_max_output_bytes` / `g:nazovim_ai_timeout`（秒）/ `g:nazovim_ai_quickfix_items` で調整できます。
<!-- markdownlint-enable MD013 -->

### DAP

| キー | 動作 |
| ---- | ---- |
| `<F5>` | 実行 / 継続 |
| `<F10>` | ステップオーバー |
| `<F11>` | ステップイン |
| `<F12>` | ステップアウト |
| `<Leader>db` | ブレークポイント切替 |
| `<Leader>dB` | ブレークポイント一覧 |
| `<Leader>dl` | デバッグ開始 |
| `<Leader>de` | 式を評価 |
| `<Leader>dq` | セッション終了 |
| `<Leader>du` | DAP UI toggle |

### テスト

| キー | 動作 |
| ---- | ---- |
| `<leader>tr` | 最寄りのテスト実行 |
| `<leader>tR` | 全テスト実行 |
| `<leader>tf` | ファイルのテスト実行 |
| `<leader>to` | テスト出力 toggle |

### ウィンドウ / バッファ

| キー | 動作 |
| ---- | ---- |
| `<C-h/j/k/l>` | ウィンドウ移動 (tmux対応) |
| `<C-PageDown/Up>` | バッファ切替 |
| `<C-t>` | 新規バッファ |
| `<C-q>` | バッファを閉じる |

---

## 🛠️ Maintenance

### プラグイン更新

```vim
:NazoPlug sync      " lock に合わせて導入・復元
:NazoPlug update    " 全プラグインを最新へ更新
:NazoPlug install   " 未導入プラグインを導入
:NazoPlug restore   " lock の commit に復元
:NazoPlug check     " 導入状態と lock の差分を確認
:NazoPlug status    " プラグイン状態と lock の差分を表示
:NazoPlug clean     " spec/lock から外れたプラグインを削除
:NazoPlug migrate   " 既存 lazy.nvim データを移行
:NazoPlug build     " build hook を実行
```

### 設定リロード

```vim
:source %   " 現在のバッファを sourced
```

---

## 🔧 Customization

NazoVim は外部プラグインを同梱していません。追加するときは
`lua/plugins.lua` に import を1行足し、`lua/plugins/<group>/` に spec を置きます。

<!-- markdownlint-disable MD013 -->
```lua
-- lua/plugins.lua
return {
  { import = "plugins.my-group" },
}
```

```lua
-- lua/plugins/my-group/zen-mode.lua
return {
  "folke/zen-mode.nvim",
  opts = {},
}
```
<!-- markdownlint-enable MD013 -->

追加したプラグインは `:NazoPlug sync` で導入され、`nazoplug-lock.json` に記録されます。
読み込みタイミングは `lua/config/startup.lua` の `plugins` で指定できます。

> **Note**: Clone（方法3）でインストールした場合のみ有効です。

---

## 🏗️ Nix Integration

このディストリビューションはNix flakeとして完全に管理されています。

```bash
# 隔離起動（設定を汚さない）
nix run github:nazozokc/NazoVim

# LSP/formatter 完備の開発シェル
nix develop github:nazozokc/NazoVim

# 設定ファイルだけビルド
nix build github:nazozokc/NazoVim

# 対応プラットフォーム
# x86_64-linux / aarch64-linux / aarch64-darwin
```

---

## 🐛 Contributing

Issue・PRはお気軽にどうぞ。
<!-- markdownlint-disable MD013 -->
質問は [GitHub Discussions](https://github.com/nazozokc/NazoVim/discussions) へ。
<!-- markdownlint-enable MD013 -->

Issue templateが用意されています:

- 🐛 **Bug Report** — 再現手順・Neovimバージョン・エラーログ付きで
- ✨ **Feature Request** — 動機と提案内容を
- 🔌 **Plugin Proposal** — プラグイン名・URL・nazoplug の設定案を

---

## Special Thanks

NazoVim は多くの優れた Neovim プラグインに支えられています。以下のプロジェクトの作者・コントリビュータの皆様に感謝します。

- [AckslD/nvim-neoclip.lua](https://github.com/AckslD/nvim-neoclip.lua)
- [Bekaboo/dropbar.nvim](https://github.com/Bekaboo/dropbar.nvim)
- [L3MON4D3/LuaSnip](https://github.com/L3MON4D3/LuaSnip)
- [MeanderingProgrammer/render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)
- [MunifTanjim/eslint.nvim](https://github.com/MunifTanjim/eslint.nvim)
- [ThePrimeagen/refactoring.nvim](https://github.com/ThePrimeagen/refactoring.nvim)
- [alexghergh/nvim-tmux-navigation](https://github.com/alexghergh/nvim-tmux-navigation)
- [andersevenrud/nvim_context_vt](https://github.com/andersevenrud/nvim_context_vt)
- [andythigpen/nvim-coverage](https://github.com/andythigpen/nvim-coverage)
- [aznhe21/actions-preview.nvim](https://github.com/aznhe21/actions-preview.nvim)
- [chentoast/marks.nvim](https://github.com/chentoast/marks.nvim)
- [chrisgrieser/nvim-spider](https://github.com/chrisgrieser/nvim-spider)
- [coder/claudecode.nvim](https://github.com/coder/claudecode.nvim)
- [dmmulroy/ts-error-translator.nvim](https://github.com/dmmulroy/ts-error-translator.nvim)
- [echasnovski/mini.ai](https://github.com/echasnovski/mini.ai)
- [echasnovski/mini.comment](https://github.com/echasnovski/mini.comment)
- [echasnovski/mini.icons](https://github.com/echasnovski/mini.icons)
- [echasnovski/mini.indentscope](https://github.com/echasnovski/mini.indentscope)
- [echasnovski/mini.jump](https://github.com/echasnovski/mini.jump)
- [echasnovski/mini.nvim](https://github.com/echasnovski/mini.nvim)
- [echasnovski/mini.surround](https://github.com/echasnovski/mini.surround)
- [folke/flash.nvim](https://github.com/folke/flash.nvim)
- [folke/noice.nvim](https://github.com/folke/noice.nvim)
- [folke/persistence.nvim](https://github.com/folke/persistence.nvim)
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim)
- [folke/trouble.nvim](https://github.com/folke/trouble.nvim)
- [folke/which-key.nvim](https://github.com/folke/which-key.nvim)
- [gbprod/substitute.nvim](https://github.com/gbprod/substitute.nvim)
- [hrsh7th/cmp-buffer](https://github.com/hrsh7th/cmp-buffer)
- [hrsh7th/cmp-calc](https://github.com/hrsh7th/cmp-calc)
- [hrsh7th/cmp-cmdline](https://github.com/hrsh7th/cmp-cmdline)
- [hrsh7th/cmp-nvim-lsp](https://github.com/hrsh7th/cmp-nvim-lsp)
- [hrsh7th/cmp-path](https://github.com/hrsh7th/cmp-path)
- [hrsh7th/nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- [ibhagwan/fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [kdheepak/lazygit.nvim](https://github.com/kdheepak/lazygit.nvim)
- [kevinhwang91/nvim-ufo](https://github.com/kevinhwang91/nvim-ufo)
- [kevinhwang91/promise-async](https://github.com/kevinhwang91/promise-async)
- [kkrampis/codex.nvim](https://github.com/kkrampis/codex.nvim)
- [lambdalisue/kensaku-search.vim](https://github.com/lambdalisue/kensaku-search.vim)
- [lambdalisue/vim-kensaku](https://github.com/lambdalisue/vim-kensaku)
- [lewis6991/fileline.nvim](https://github.com/lewis6991/fileline.nvim)
- [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)
- [lewis6991/spellsitter.nvim](https://github.com/lewis6991/spellsitter.nvim)
- [lukas-reineke/indent-blankline.nvim](https://github.com/lukas-reineke/indent-blankline.nvim)
- [m-demare/hlargs.nvim](https://github.com/m-demare/hlargs.nvim)
- [marilari88/neotest-vitest](https://github.com/marilari88/neotest-vitest)
- [mattn/emmet-vim](https://github.com/mattn/emmet-vim)
- [mcauley-penney/visual-whitespace.nvim](https://github.com/mcauley-penney/visual-whitespace.nvim)
- [mfussenegger/nvim-lint](https://github.com/mfussenegger/nvim-lint)
- [mikavilpas/yazi.nvim](https://github.com/mikavilpas/yazi.nvim)
- [mistweaverco/kulala.nvim](https://github.com/mistweaverco/kulala.nvim)
- [monaqa/dial.nvim](https://github.com/monaqa/dial.nvim)
- [nickjvandyke/opencode.nvim](https://github.com/nickjvandyke/opencode.nvim)
- [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [nvim-neotest/neotest](https://github.com/nvim-neotest/neotest)
- [nvim-neotest/neotest-jest](https://github.com/nvim-neotest/neotest-jest)
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [nvimdev/lspsaga.nvim](https://github.com/nvimdev/lspsaga.nvim)
- [pwntester/octo.nvim](https://github.com/pwntester/octo.nvim)
- [rafamadriz/friendly-snippets](https://github.com/rafamadriz/friendly-snippets)
- [rcarriga/nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui)
- [rebelot/kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim)
- [refractalize/oil-git-status.nvim](https://github.com/refractalize/oil-git-status.nvim)
- [romgrk/barbar.nvim](https://github.com/romgrk/barbar.nvim)
- [roobert/tailwindcss-colorizer-cmp.nvim](https://github.com/roobert/tailwindcss-colorizer-cmp.nvim)
- [ryoppippi/denippet-autoimport-vscode](https://github.com/ryoppippi/denippet-autoimport-vscode)
- [ryoppippi/nvim-pnpm-catalog-lens](https://github.com/ryoppippi/nvim-pnpm-catalog-lens)
- [ryoppippi/vim-bad-apple](https://github.com/ryoppippi/vim-bad-apple)
- [ryoppippi/vim-svelte-inspector](https://github.com/ryoppippi/vim-svelte-inspector)
- [saadparwaiz1/cmp_luasnip](https://github.com/saadparwaiz1/cmp_luasnip)
- [shellRaining/hlchunk.nvim](https://github.com/shellRaining/hlchunk.nvim)
- [sindrets/diffview.nvim](https://github.com/sindrets/diffview.nvim)
- [stevearc/aerial.nvim](https://github.com/stevearc/aerial.nvim)
- [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim)
- [stevearc/dressing.nvim](https://github.com/stevearc/dressing.nvim)
- [stevearc/oil.nvim](https://github.com/stevearc/oil.nvim)
- [stevearc/overseer.nvim](https://github.com/stevearc/overseer.nvim)
- [theHamsta/nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text)
- [thenbe/neotest-playwright](https://github.com/thenbe/neotest-playwright)
- [tpope/vim-repeat](https://github.com/tpope/vim-repeat)
- [tttol/md-outline.nvim](https://github.com/tttol/md-outline.nvim)
- [uga-rosa/ccc.nvim](https://github.com/uga-rosa/ccc.nvim)
- [uga-rosa/cmp-denippet](https://github.com/uga-rosa/cmp-denippet)
- [uga-rosa/denippet.vim](https://github.com/uga-rosa/denippet.vim)
- [uga-rosa/translate.nvim](https://github.com/uga-rosa/translate.nvim)
- [unblevable/quick-scope](https://github.com/unblevable/quick-scope)
- [vim-denops/denops.vim](https://github.com/vim-denops/denops.vim)
- [vinnymeller/swagger-preview.nvim](https://github.com/vinnymeller/swagger-preview.nvim)
- [vuki656/package-info.nvim](https://github.com/vuki656/package-info.nvim)
- [willothy/flatten.nvim](https://github.com/willothy/flatten.nvim)
- [windwp/nvim-autopairs](https://github.com/windwp/nvim-autopairs)
- [windwp/nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag)
- [zeioth/garbage-day.nvim](https://github.com/zeioth/garbage-day.nvim)

（リストは `apps/nvim/nazoplug-lock.json` およびプラグイン仕様から自動生成）

---

## 📄 License

MIT © [nazozokc](https://github.com/nazozokc)

---
