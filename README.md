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
[kanagawa](https://github.com/rebelot/kanagawa.nvim) カラースキームと、自作プラグインマネージャー `nazoplug` による高速な遅延ロードを基盤に、TypeScript・Lua・Nix・Rubyなどの開発に必要なすべてが揃っています。
<!-- markdownlint-enable MD013 -->

> Nixのflakeとして配布しているため、`nix run` 一発で隔離された状態から即起動できます。

---

## 🚀 Features

<!-- markdownlint-disable MD013 -->
- **⚡ Fast startup** — nazoplug によるアグレッシブな遅延ロード。起動を邪魔するものは VeryLazy 以降に追いやる
- **🔧 Full LSP** — TypeScript / Lua / Ruby / Nix / C / Java / Zig など多言語対応。mason + 手動 (nixd) の両刀
- **🎨 kanagawa** — `kanagawa-dragon` テーマ + 透明背景でターミナルと溶け込む
- **🧠 AI統合** — Claude Code (`claudecode.nvim`) と opencode (`opencode.nvim`) を両方サポート
- **🌊 snacks.nvim** — Dashboard・Picker・Zen mode・セッション管理をまとめて統一
- **🐛 DAP** — JavaScript / TypeScript のデバッグ環境を最小構成で内包
- **📦 Nix対応** — `nix run` で隔離起動 / `nix develop` でLSP完备のdevShell
- **🧪 テスト** — neotest + Jest / Vitest / Playwright アダプタ
- **🔍 Fuzzy finding** — snacks.nvim Picker (ivy layout) をメイン、Telescope をサブとして併用
- **📝 Treesitter textobjects** — 関数・クラス・引数単位の高精度テキストオブジェクト
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
| lazygit | LazyGit統合 |
| yazi | ファイルマネージャー統合 |
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
    ["kanagawa.nvim"] = "startup",
    ["snacks.nvim"] = "VeryLazy",
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

既定では `neo-tree.nvim` は `on_demand` で、キーやコマンドで
必要になったときに読み込みます。`plugins` を指定すると既定の一覧を置き換えます。

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
│   │       ├── plugins.lua   # プラグインカテゴリの import 定義
│   │       └── plugins/      # プラグイン設定
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
| nvim-lspconfig + mason | LSP管理 |
| typescript-tools.nvim | TypeScript専用LSP（高速化設定済み） |
| nvim-cmp | 補完エンジン |
| LuaSnip + denippet.vim | スニペット（VSCode互換） |
| lspsaga.nvim | LSP UI拡張 |
| actions-preview.nvim | コードアクションプレビュー |
| conform.nvim | フォーマッター（stylua / prettier等） |
| nvim-lint | rubocop等の追加診断 |
| NazoVim 内蔵 | LSPプログレス表示 |
| NazoVim 内蔵 | インライン診断 |
| lazydev.nvim | Lua/Neovim API の補完・型チェック強化 |

### Fuzzy Finder / ナビゲーション

| プラグイン | 用途 |
| ---------- | ---- |
| snacks.nvim | Picker / Dashboard / Zen / Words / Session |
| telescope.nvim | ファジーファインダー（サブ） |
| oil.nvim | バッファベースのファイルエクスプローラー |
| neo-tree.nvim | ツリー形式ファイルエクスプローラー |
| yazi.nvim | yaziファイルマネージャー統合 |
| dropbar.nvim | Winbar / パンくずリスト |
| flash.nvim | ジャンプ（`<CR>` でスマートジャンプ） |
| aerial.nvim | シンボルアウトライン |
| project.nvim | プロジェクトルート自動検出 |

### UI / 見た目

| プラグイン | 用途 |
| ---------- | ---- |
| kanagawa.nvim | カラースキーム（dragon + 透明） |
| NazoVim 内蔵 | ステータスライン |
| NazoVim 内蔵 | バッファタブ（クリック遷移対応） |
| NazoVim 内蔵 | インデントガイド / 現在ブロック強調 |
| noice.nvim | コマンドラインUI / 通知 |
| nvim-notify | 通知システム |
| NazoVim 内蔵 | スクロールバー |
| NazoVim 内蔵 | モード別の行番号色 |
| NazoVim 内蔵 | カーソル下シンボルのハイライト |
| NazoVim 内蔵 | フローティングファイル名 |
| NazoVim 内蔵 | TODO/FIXME等のハイライト |
| render-markdown.nvim | Markdownのリッチレンダリング |
| NazoVim 内蔵 | カラーコードのインラインプレビュー |

### Git (Plugins)

| プラグイン | 用途 |
| ---------- | ---- |
| gitsigns.nvim | Git差分サインカラム |
| diffview.nvim | 差分ビュー / ファイル履歴 |
| lazygit.nvim | LazyGit統合 |
| vim-fugitive | Git操作 |
| octo.nvim | GitHub Issue / PR / Notification 操作 |

### エディタ機能

| プラグイン | 用途 |
| ---------- | ---- |
| nvim-treesitter | シンタックスハイライト / インデント |
| nvim-treesitter-textobjects | 関数・クラス・引数単位のテキストオブジェクト |
| mini.jump | f/F/t/T の複数行拡張と `;` リピート |
| NazoVim 内蔵 | 括弧・クォート自動補完（`pairs.lua`） |
| NazoVim 内蔵 | Surround（`sa` / `sd` / `sr`） |
| NazoVim 内蔵 | camelCase/snake_case対応 `w` / `e` / `b` / `ge` |
| NazoVim 内蔵 | `<C-a>/<C-x>` の拡張インクリメント |
| NazoVim 内蔵 | キーマップヘルプ（`<leader>?`） |
| NazoVim 内蔵 | マークのサイン表示・`:Marks` 一覧 |
| NazoVim 内蔵 | 散文のスペルチェック（`:SpellToggle`） |
| NazoVim 内蔵 | Treesitterフォールド（`zR` / `zM`） |
| substitute.nvim | レジスタを使った置換 |
| NazoVim 内蔵 | フローティングターミナル（`:ToggleTerm`） |
| kulala.nvim | REST client (.http ファイル) |
| persistence.nvim | セッション管理 |

### AI統合

| プラグイン | 用途 |
| ---------- | ---- |
| claudecode.nvim | Claude Code統合 |
| opencode.nvim | opencode統合 |
| CopilotChat.nvim | GitHub Copilot Chat |
| copilot.lua | GitHub Copilot補完 |

### デバッグ / テスト

| プラグイン | 用途 |
| ---------- | ---- |
| nvim-dap + nvim-dap-ui | デバッガー |
| nvim-dap-vscode-js | JS/TS デバッグアダプタ |
| neotest | テストランナー |
| neotest-jest / vitest / playwright | テストアダプタ |
| nvim-coverage | カバレッジ表示 |

---

## ⌨️ Keymaps

`<Leader>` = `Space`

### 基本

| キー | 動作 |
| ---- | ---- |
| `<Leader><Leader>` | ファイル検索 (snacks Picker) |
| `<Leader>/` | Live Grep |
| `<Leader>b` | バッファ一覧 |
| `<Leader>r` | 最近使ったファイル |
| `<Leader>h` | 検索ハイライト解除 |
| `<Leader>z` | Zen mode |
| `<Leader>m` | Oil ファイルエクスプローラー |
| `<Leader>n` | Neo-tree |
| `<Leader>t` | フローティングターミナル |
| `<Leader>f` | フォーマット |

### LSP

| キー | 動作 |
| ---- | ---- |
| `K` | ホバー |
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
| `<Leader>gd` | DiffviewOpen |
| `<Leader>gh` | ファイル履歴 |
| `<Leader>gH` | ブランチ履歴 |
| `<Leader>gc` | Diffview Close |
| `<Leader>gp` | Hunkプレビュー |
| `<Leader>gt` | Blame toggle |

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
| `<Leader>ac` | Claude Code toggle |
| `<Leader>af` | Claude Code focus |
| `<Leader>ab` | 現在バッファを追加 |
| `<C-a>` | opencode ask |
| `<C-x>` | opencode select action |
| `<C-.>` | opencode toggle |

### DAP

| キー | 動作 |
| ---- | ---- |
| `<F5>` | 実行 / 継続 |
| `<F10>` | ステップオーバー |
| `<F11>` | ステップイン |
| `<F12>` | ステップアウト |
| `<Leader>db` | ブレークポイント切替 |
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

`lua/plugins/` 以下にLuaファイルを追加するだけで自動でロードされます。

<!-- markdownlint-disable MD013 -->
```lua
-- lua/plugins/my-config.lua

-- プラグイン追加
return {
  "folke/zen-mode.nvim",
  opts = {}
}
```
<!-- markdownlint-enable MD013 -->

既存プラグインの設定を上書きする場合も同じファイルに書けます。

```lua
return {
  "rebelot/kanagawa.nvim",
  opts = { transparent = false }
}
```

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

## 📄 License

MIT © [nazozokc](https://github.com/nazozokc)
