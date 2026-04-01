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

**A personal Neovim distribution by [nazozokc:NazoVim-org](https://github.com/nazozokc)**

[![CI](https://github.com/nazozokc/nazozokc.nvim.config/actions/workflows/nvim.yml/badge.svg)](https://github.com/nazozokc/nazozokc.nvim.config/actions/workflows/nvim.yml)
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
[kanagawa](https://github.com/rebelot/kanagawa.nvim) カラースキームと [lazy.nvim](https://github.com/folke/lazy.nvim) による高速な遅延ロードを基盤に、TypeScript・Lua・Nix・Rubyなどの開発に必要なすべてが揃っています。
<!-- markdownlint-enable MD013 -->

> Nixのflakeとして配布しているため、`nix run` 一発で隔離された状態から即起動できます。

---

## 🚀 Features

<!-- markdownlint-disable MD013 -->
- **⚡ Fast startup** — lazy.nvim によるアグレッシブな遅延ロード。起動を邪魔するものは VeryLazy 以降に追いやる
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
| Neovim | 0.10+ |
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
nix run github:nazozokc/nazozokc.nvim.config
```

<!-- markdownlint-disable MD013 -->
設定は `~/.config/nvim-nazozokc` に隔離して展開されるため、既存のNeovim設定を汚しません。
<!-- markdownlint-enable MD013 -->

### 方法2: Clone（Nix 不要）

> **注意**: 既存の Neovim 設定を上書きします。バックアップを推奨します。
>
> ```bash
> mv ~/.config/nvim ~/.config/nvim.backup  # バックアップ（任意）
> ```

```bash
git clone https://github.com/nazozokc/nazozokc.nvim.config.git ~/.config/nvim
nvim
```

初回起動時に lazy.nvim がすべてのプラグインを自動インストールします。

### 方法2でクローン後に削除しても良いファイル

- document/
- LICENSE
- SECURITY.md
- CONTRIBUTING.md

> `flake.nix` と `.github/` は CI に必要です。
> PRを送る予定がない場合は `.github/` のみ削除しても構いません。

---

## 🗂️ Directory Structure

```text
.
├── flake.nix             # Nix flake (nix run / nix develop)
├── init.lua              # エントリーポイント・キーマップ定義
├── lazy-lock.json        # プラグンバージョンロック
├── lua/
│   ├── vim-options.lua   # 基本vim設定
│   ├── plugins.lua       # lazy.nvim エントリ (空 = plugins/ 以下を自動読み込み)
│   └── plugins/          # プラグイン設定 (1ファイル1プラグイン)
├── template/             # ファイルテンプレート
│   ├── js/
│   ├── ts/
│   ├── lua/
│   ├── md/
│   └── project/
└── .github/
    ├── workflows/        # CI (nvim startup check / auto-merge)
    └── ISSUE_TEMPLATE/   # Bug report / Feature request / Plugin proposal
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
| none-ls.nvim | rubocop等の追加診断 |
| fidget.nvim | LSPプログレス表示 |
| tiny-inline-diagnostic.nvim | インライン診断 |
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
| lualine.nvim | ステータスライン |
| barbar.nvim | タブバー |
| noice.nvim | コマンドラインUI / 通知 |
| nvim-notify | 通知システム |
| nvim-scrollbar / satellite.nvim | スクロールバー |
| modes.nvim | モード別カーソル色変化 |
| nvim-illuminate | カーソル下シンボルのハイライト |
| incline.nvim | フローティングファイル名 |
| todo-comments.nvim | TODO/FIXME等のハイライト |
| render-markdown.nvim | Markdownのリッチレンダリング |
| nvim-highlight-colors | カラーコードのインラインプレビュー |

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
| nvim-autopairs | 括弧自動補完 |
| mini.ai / surround / comment | テキストオブジェクト・Surround・コメント |
| nvim-spider | CamelCase/snake_case対応 w/e/b |
| substitute.nvim | レジスタを使った置換 |
| dial.nvim | `<C-a>/<C-x>` の拡張インクリメント |
| which-key.nvim | キーマップヘルプ |
| toggleterm.nvim | フローティングターミナル |
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
:Lazy sync   " 全プラグインを更新
:Lazy clean  " 未使用プラグインを削除
:Lazy snapshot " 現在のバージョンをロック
```

### 設定リロード

```vim
:Lazy reload   " 設定を再読み込み
:source %      " 現在のバッファを sourced
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
nix run github:nazozokc/nazovim

# LSP/formatter 完备の開発シェル
nix develop github:nazozokc/nazovim

# 設定ファイルだけビルド
nix build github:nazozokc/nazovim

# 対応プラットフォーム
# x86_64-linux / aarch64-linux / aarch64-darwin
```

---

## 🐛 Contributing

Issue・PRはお気軽にどうぞ。
<!-- markdownlint-disable MD013 -->
質問は [GitHub Discussions](https://github.com/nazozokc/nazozokc.nvim.config/discussions) へ。
<!-- markdownlint-enable MD013 -->

Issue templateが用意されています:

- 🐛 **Bug Report** — 再現手順・Neovimバージョン・エラーログ付きで
- ✨ **Feature Request** — 動機と提案内容を
- 🔌 **Plugin Proposal** — プラグイン名・URL・lazy.nvimの設定案を

---

## 📄 License

MIT © [nazozokc](https://github.com/nazozokc)
