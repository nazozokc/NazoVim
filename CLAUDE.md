# Neovim Configuration

このディレクトリは nazozokc/NazoVim リポジトリの Neovim 設定です。  
自作プラグインマネージャー `nazoplug`（`apps/nazoplug/`）を使用しています。
`init.lua` は `NAZOVIM_PLUGIN_MANAGER=lazy` のときだけ lazy.nvim にフォールバックします。

---

## 特徴

- **軽量・高速・充実**: nazoplug による遅延読み込み
- **LSP 完備**: TypeScript, Lua, Ruby, Nix, HTML, C/C++ など標準サポート
- **モダンUI**: カスタムダッシュボード、ステータスライン、ファジーファインダー
- **Treesitter**: シンタックスハイライト・インデント・テキストオブジェクト
- **DAP統合**: JavaScript / TypeScript デバッグ機能
- **セッション管理**: NazoVim内蔵 `session.lua` による保存・復元
- **テンプレート**: 各種ファイルタイプ用テンプレート

---

## ディレクトリ構成

```text
.
├── apps/
│   ├── nvim/                 # Neovim configuration
│   │   ├── init.lua          # エントリーポイント・nazoplug bootstrap
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
│   ├── lua/
│   ├── md/
│   ├── project/
│   └── ts/
├── flake.nix                 # Nix flake (nix run / nix develop)
├── docs/
└── .github/
```

---

## プラグイン管理

`:NazoPlug` で操作します。設定は `apps/nvim/nazoplug-lock.json`、実行時データは
`stdpath("data")/site/pack/nazoplug/opt` と
`stdpath("data")/nazoplug-lock.json` です。
spec は lazy.nvim 互換で、`tag` / `pin` / `cond` / 関数形式の `enabled` に対応します。

```vim
:NazoPlug sync      " lock に合わせて導入・復元
:NazoPlug install   " 未導入プラグインを導入
:NazoPlug update    " 全プラグインを更新
:NazoPlug check     " 導入状態と lock の差分を確認
:NazoPlug status    " プラグイン状態と lock の差分を表示
:NazoPlug restore   " lock の commit に復元
:NazoPlug clean     " spec/lock から外れたプラグインを削除
:NazoPlug migrate   " 既存 lazy.nvim データを移行
:NazoPlug build     " build hook を実行
```

headless テスト:

```bash
for t in spec install loader commands init; do
  nvim --headless -u apps/nazoplug/tests/minimal_init.lua -l apps/nazoplug/tests/${t}_test.lua
done
```

---

## 内蔵機能への置き換え方針

- プラグイン置換コードは `apps/nvim/lua/nazovim/<category>/<feature>.lua` に1機能1ファイルで実装する。
  `nazovim/features.lua` がディレクトリを走査して自動登録するため、追加はファイルを置くだけでよい。
  初期パス以外で起動する機能だけ `features.lua` の `phases` に1行追加する。
  不要な機能はファイルを削除するか `vim.g.nazovim_disabled_features` で個別に止められる。
- 実装はNeovim APIを使って要件から新規に設計する。既存プラグインのソースコードを複写・翻案しない。
- 置換時は専用モジュール、機能登録、プラグインspecとlock、README・機能一覧を同じ変更で更新する。

## 主要プラグイン

### LSP / 補完

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | LSP管理（`lsp.lua`、`vim.lsp.config` / `vim.lsp.enable`、PATH上のサーバーのみ起動、`:NazoLspInfo`） |
| NazoVim 内蔵 | ファイルアイコン（`icons.lua`、`get_icon` / `get_icon_by_filetype` のdevicons互換API） |
| NazoVim 内蔵 | TypeScript / JavaScript LSP（`lsp.lua` の `ts_ls` = typescript-language-server。formatting と semantic tokens を無効化、`<leader>oi` / `<leader>ru`） |
| NazoVim 内蔵 | 補完（`completion.lua`、`vim.lsp.completion` + snippet/buffer/path、`<C-Space>` / `<Tab>` / `<S-Tab>` / `<CR>`） |
| NazoVim 内蔵 | コマンドライン補完（`cmdline_completion.lua`） |
| NazoVim 内蔵 | 独立snippet展開・placeholder移動（`snippets.lua`、VSCode JSON subset） |
| NazoVim 内蔵 | Neovim標準LSPコードアクション（`ga`） |
| NazoVim 内蔵 | LSPコードアクション差分プレビュー（`action_preview.lua`） |
| NazoVim 内蔵 | LSPリファクタリング操作（`refactor.lua`） |
| NazoVim 内蔵 | 外部 formatter（stylua / prettier / black / clang-format / nixfmt / RuboCop、`format.lua`） |
| NazoVim 内蔵 | 外部リンター（ESLint / RuboCop / Luacheck / Nix / markdownlint、`lint.lua`） |
| NazoVim 内蔵 | タスク実行と履歴（`tasks.lua`） |
| NazoVim 内蔵 | LSPプログレス表示 |
| NazoVim 内蔵 | インライン診断 |
| NazoVim 内蔵 | アイドルLSPクライアントの停止（5分後。ESLint / TypeScriptを除外） |
| NazoVim 内蔵 | Lua/Neovim API の型補完（`lsp.lua` が lua_ls の `workspace.library` に `$VIMRUNTIME` と nazoplug を渡す） |

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

### Git

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | Git差分サイン・hunk移動・preview・blame（`git_signs.lua`） |
| NazoVim 内蔵 | Git変更一覧・履歴・conflict選択（`git_review.lua`） |
| NazoVim 内蔵 | LazyGit浮動terminal起動（`lazygit.lua`、外部 `lazygit` が必要） |
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
| NazoVim 内蔵 | Tree-sitter構文ノードの選択拡張・縮小（`incremental_selection.lua`） |
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
| NazoVim 内蔵 | フローティングターミナル |
| NazoVim 内蔵 | `.http` RESTクライアント（`http_client.lua`） |
| NazoVim 内蔵 | OpenAPI / Swagger preview（`swagger_preview.lua`、`swagger-ui-watcher` を使用） |
| NazoVim 内蔵 | セッション保存・復元（`session.lua`） |
| NazoVim 内蔵 | Svelte Vite Inspectorの場所をNeovimで開く（`svelte_inspector.lua`） |
| NazoVim 内蔵 | `.http` RESTリクエストの送信（`http_client.lua`、`curl` が必要） |

### AI統合

| プラグイン | 用途 |
| ---------- | ---- |
| NazoVim 内蔵 | Codex CLI統合（`codex.lua`、`:Codex` / `:CodexToggle`、`<C-q>`で閉じる） |
| NazoVim 内蔵 | 非対話AIクライアント（`ai_ask.lua`、`claude -p` / `codex exec` / `opencode run` を右分割パネルへストリーミング。`:NazoAI` / `<leader>aa` / `<leader>ae` / `<leader>at` / `<leader>a?`） |
| NazoVim 内蔵 | Claude Code CLI統合（`claudecode.lua`、`:ClaudeCode` / `:ClaudeCodeToggle` / `:ClaudeCodeFocus`、`<C-q>`で閉じる） |
| NazoVim 内蔵 | opencode CLI統合（`opencode.lua`、`:OpenCode` / `:OC`、`<C-.>`で開閉） |

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

## キーマップ

### Leader キー

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
| `gd` | 定義へ移動 (Lspsaga) |
| `ga` | コードアクション (Lspsaga) |
| `<Leader>ca` | コードアクション (preview) |
| `<Leader>ld` | 定義へ移動 (vim.lsp) |
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
| `<Leader>oI` | GitHub Issueのpin/unpin・通知購読設定・リンクブランチ作成 |
| `<Leader>oA` | GitHub PR checks・merge・checkout・ready/draft・branch更新 |
| `<Leader>oC` | GitHub PR commits・変更ファイル・check runsの一覧。`<CR>`でcommit diffまたはファイルpatch、`gx`でGitHubを開く |
| `<Leader>oB` | GitHub Projects。item一覧から`<CR>`でstatus変更・archive、issue/PRの追加も行う |
| `<Leader>oG` | gist一覧。`<CR>`でブラウザ表示、`y`でURLをコピー |
| `<Leader>on` | GitHub通知一覧 |
| `<Leader>os` | GitHub Issue / PR検索 |
| `<Leader>od` | GitHub Discussions一覧。詳細で`c`返信、`e`編集、`d`削除、`p`poll投票、`a`回答指定、`u`upvote、`r`reaction、`m`コメント管理、`g`カテゴリ、`s`購読、`x`close/reopen |
| `<Leader>oD` | GitHub Discussion作成 |

### セッション

| キー | 動作 |
| ---- | ---- |
| `<Leader>qs` | セッション復元 |
| `<Leader>qS` | セッション選択 |
| `<Leader>ql` | 最後のセッションを復元 |
| `<Leader>qd` | セッション保存を停止 |

### AI (NazoAI)

| キー | 動作 |
| ---- | ---- |
| `<Leader>aa` | 質問（文脈ファイルを添えてCLIへ） |
| `<Leader>an` | 文脈を捨てて新規質問 |
| `<Leader>ae` | 回答のコードブロックをバッファへ適用（visual対応） |
| `<Leader>at` | パネル開閉 |
| `<Leader>af` | パネルへフォーカス |
| `<Leader>aS` | 実行中のリクエストを停止 |
| `<Leader>ac` | 現在のバッファを文脈に追加 |
| `<Leader>aB` | 全バッファを文脈に追加 |
| `<Leader>aC` | 文脈ファイルをクリア |
| `<Leader>a?` | プロバイダ選択（claude / codex / opencode） |
| `<Leader>ah` | 履歴から選んで再表示 |

### AI (Claude Code)

| キー | 動作 |
| ---- | ---- |
| `<Leader>Cc` | Claude Code切替 |
| `<Leader>Cf` | Claudeフォーカス |
| `<Leader>Cr` | Claude Code再開（`claude --resume`） |
| `<Leader>CC` | Claude Code継続（`claude --continue`） |
| `<Leader>Cm` | モデル選択 |
| `<Leader>Cb` | 現在のバッファを追加 |
| `<Leader>Cs` | 現在のバッファを `@path` でメンション (Normal / Visual) |

### 診断・LSP一覧（quickfix）

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

- **lua_ls** — Lua（`lsp.lua` が `workspace.library` に `$VIMRUNTIME` と nazoplug を渡す）
- **ts_ls** — TypeScript / JavaScript（`lsp.lua`、typescript-language-server）
- **html** — HTML
- **solargraph** — Ruby
- **nixd** — Nix（devShell または手動インストール）
- **efm** — 汎用フォーマッター
- **clangd** — C / C++
- **jdtls** — Java（`lsp.lua`、プロジェクトごとに `-data` ワークスペースを分ける）
- **zls** — Zig（`lsp.lua` が定義、`zls` がPATHにあれば起動）
- **rust_analyzer** — Rust（`lsp.lua`、`<leader>rr` で runnables）

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
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/nazozokc/NazoVim.git ~/.config/nvim
cd ~/.config/nvim
git sparse-checkout set apps/nvim
mv apps/nvim/* . && rm -rf apps
```

または、直接このディレクトリを `~/.config/nvim` に配置してください。
