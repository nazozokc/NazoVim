# Neovim Configuration

このディレクトリは nazozokc/nazozokc.nvim.config リポジトリの Neovim 設定です。  
lazy.nvim をプラグインマネージャーとして使用しています。

---

## 特徴

- **軽量・高速・充実**: lazy.nvim による遅延読み込み
- **LSP 完備**: TypeScript, Lua, Ruby, Nix, HTML, C/C++ など標準サポート
- **モダンUI**: カスタムダッシュボード、ステータスライン、ファジーファインダー
- **Treesitter**: シンタックスハイライト・インデント・テキストオブジェクト
- **DAP統合**: JavaScript / TypeScript デバッグ機能
- **セッション管理**: persistence.nvim によるセッション保存・復元
- **テンプレート**: 各種ファイルタイプ用テンプレート

---

## ディレクトリ構成

```text
nvim/
├── init.lua              # エントリーポイント・キーマップ
├── lazy-lock.json        # プラグンバージョンロック
├── lua/
│   ├── plugins.lua       # プラグイン定義（空、plugins/ 以下を自動読み込み）
│   ├── vim-options.lua   # 基本設定
│   └── plugins/          # プラグイン設定（各ファイル）
└── template/             # ファイルテンプレート
    ├── js/
    ├── lua/
    ├── md/
    ├── project/
    └── ts/
```

---

## 主要プラグイン

### LSP / 補完

| プラグイン | 用途 |
| ---------- | ---- |
| nvim-lspconfig + mason | LSP管理 |
| typescript-tools.nvim | TypeScript専用LSP（高速化・semantic tokens無効化済み） |
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

### UI / 見た目

| プラグイン | 用途 |
| ---------- | ---- |
| kanagawa.nvim | カラースキーム（dragon + 透明背景） |
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

### Git

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

## キーマップ

### Leader キー

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
| `gd` | 定義へ移動 (Lspsaga) |
| `ga` | コードアクション (Lspsaga) |
| `<Leader>ca` | コードアクション (preview) |
| `<Leader>gd` | 定義へ移動 (vim.lsp) |
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

### Git (キーマップ)

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

### Trouble（診断一覧）

| キー | 動作 |
| ---- | ---- |
| `<Leader>xx` | 診断一覧 toggle |
| `<Leader>xX` | バッファの診断一覧 |
| `<Leader>cs` | シンボル一覧 |
| `<Leader>cl` | LSP一覧 |

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

### ウィンドウ移動

| キー | 動作 |
| ---- | ---- |
| `<C-h>` | 左へ移動 (tmux対応) |
| `<C-j>` | 下へ移動 (tmux対応) |
| `<C-k>` | 上へ移動 (tmux対応) |
| `<C-l>` | 右へ移動 (tmux対応) |

### バッファ

| キー | 動作 |
| ---- | ---- |
| `<C-PageDown>` | 次のバッファ |
| `<C-PageUp>` | 前のバッファ |
| `<C-t>` | 新規バッファ |
| `<C-q>` | バッファを閉じる |

---

## LSP サポート

以下の言語サーバーを設定済み：

- **lua_ls** — Lua（lazydev.nvim により Neovim API の補完強化済み）
- **ts_ls** / **typescript-tools.nvim** — TypeScript / JavaScript
- **html** — HTML
- **solargraph** — Ruby
- **nixd** — Nix（mason非対応、nix devShell または手動インストールが必要）
- **efm** — 汎用フォーマッター
- **clangd** — C / C++
- **jdtls** — Java（nvim-java が管理）
- **zls** — Zig

---

## テンプレート

`template/` ディレクトリに各種テンプレートを配置：

- `js/` — JavaScript
- `ts/` — TypeScript（api / controller / service）
- `lua/` — Lua モジュール
- `md/` — Markdown
- `project/` — プロジェクト雛形

---

## 設定値

- インデント: 2スペース
- 行番号: 表示 + 相対行番号
- Insertモード中は相対行番号を無効化
- Swapファイル: 無効
- Leader: `Space`

---

## 使用方法

このリポジトリをクローンし、`~/.config/nvim` にシンボリックリンクを貼って使用します。

```bash
git clone https://github.com/nazozokc/nazozokc.nvim.config.git ~/.config/nvim
```

または、直接このディレクトリを `~/.config/nvim` に配置してください。
