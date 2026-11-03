# 内蔵エディタ機能

<!-- cspell:words hlslens commentstring rgba -->

次の機能は `apps/nvim/lua/nazovim/` で管理します。
プラグイン未導入の初回起動でも動作します。LSP・Treesitter参照には
対応するサーバー／パーサーが必要です。

| 旧プラグイン | 内蔵モジュール | 動作 |
| --- | --- | --- |
| lualine.nvim | `statusline.lua` | モード、Gitブランチ・差分、ファイル、診断件数、文字コード、改行形式、位置 |
| nvim-hlslens | `search.lua` | 検索件数をカーソル行の末尾に表示 |
| template.nvim | `template.lua` | ファイルテンプレート挿入とプロジェクト生成 |
| tiny-inline-diagnostic.nvim | `diagnostics.lua` | 現在行の診断をその下に表示 |
| fidget.nvim | `progress.lua` | LSP進捗を右下に表示、入力中は非表示、完了後2秒で消去 |
| todo-comments.nvim | `todo.lua` | コメントのキーワード強調、プロジェクト内の検索 |
| vim-illuminate | `references.lua` | LSP優先、Treesitterのスコープ解析をフォールバックに使用 |
| nvim-highlight-colors | `colors.lua` | 色リテラルの背景色プレビュー |
| satellite.nvim / nvim-scrollbar | `scrollbar.lua` | 現在位置・診断のスクロールバー |
| nvim-autopairs | `pairs.lua` | 括弧・クォートの自動補完、ペア内Enter展開、空ペアのBS削除 |
| mini.surround | `surround.lua` | `sa` / `sd` / `sr` による囲みの追加・削除・置換 |
| mini.comment | （Neovim標準） | `gc` / `gcc`。専用モジュールは不要 |
| mini.indentscope / hlchunk / indent-blankline | `indent.lua` | インデントガイドとカーソル行が属するブロックの強調 |
| nvim-ufo | `folding.lua` | Treesitter優先・インデントfallbackのフォールドと折り畳み表示 |
| which-key.nvim | `whichkey.lua` | 保留中のキー候補と説明をフローティング表示 |
| dial.nvim | `dial.lua` | 数値・真偽値・定数の `<C-a>` / `<C-x>` 拡張 |
| nvim-spider | `motion.lua` | camelCase / snake_case を分割する `w` / `e` / `b` / `ge` |
| （Neovim標準） | `motion.lua` | `f` / `F` / `t` / `T` の複数行検索と `;` / `,` の繰り返し |
| quick-scope | `motion.lua` | `f` / `F` / `t` / `T` 入力前に一意な検索候補を下線表示 |
| marks.nvim | `marks.lua` | マークのサイン表示、`:Marks` 一覧、`]m` / `[m` 移動 |
| spellsitter.nvim | `spell.lua` | 散文ファイルタイプだけspellを有効化 |
| barbar.nvim | `tabline.lua` | バッファタブ、クリック遷移、バッファ移動キー |

Snacks の `words`、Noice のLSP進捗と検索件数表示は無効化し、
同じ情報の二重表示を防いでいます。他のSnacks／Noice機能は引き続き使います。

## エディタ操作

- `sa` + motion + 文字: 囲みを追加（例: `saiw)`）。Visualモードでも可。
- `sd` + 文字: カーソルを囲むペアを削除。
- `sr` + 文字 + 文字: 囲みを置換。
- `<C-a>` / `<C-x>`: カーソル下の数値・真偽値・`let`/`const`/`var` などを増減。Visualモードは選択範囲内のトークン（行選択なら行全体）。
- `w` / `e` / `b` / `ge`: camelCase と snake_case の境界で移動。operator-pending と Visual でも動作。
- `f` / `F` / `t` / `T`: 現在行の先も含めてバッファ内を文字検索。`;` は同方向、`,` は逆方向に直前の検索を繰り返します。
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
  Gitブランチは非同期取得し、gitsignsの情報があれば利用します。
- 色とTODOの強調は表示中の行を中心に処理し、4096バイトを超える行は省略します。
  イベントをまとめ、スクロール時にバッファ全体を走査しません。
- 色はhex（3/4/6/8桁）、`rgb()` / `rgba()`、`hsl()` / `hsla()`、
  Neovimの色名に対応。アルファ値は表示に反映せずRGBを表示します。
  同一バッファのCSS変数は5000行・200KB以下で解析します。
  CSSのカスケードや外部ファイルの変数解決、関数なしHSL値は対象外です。
  色のhighlightグループは最大512個です。
- 参照は120ms間隔で処理をまとめ、古いLSP応答を破棄します。
  5000行超ではTreesitterフォールバックを使いません。
  Treesitter解析は引き続き `nvim-treesitter` のlocals APIを利用します。
- スクロールバーは論理行数に対する概略位置です。
  折り返し・折り畳みを画面行数に換算するミニマップではありません。
  検索・Git差分マーカーとマウス操作はありません。
- 診断はNeovim標準の `virtual_lines` を使います。
  `vim.diagnostic.enable(false)` やZenモードと連動します。

プラグインの全API・全表示形式を互換実装するものではありません。
旧 `require("lualine")` などを使う個人設定や、
`NAZOVIM_STARTUP_CONFIG` にある削除済みプラグイン名は取り除いてください。
既存プラグインのディスク上のデータは自動削除しません。

## 検証

```sh
nvim --headless -u NONE -l apps/nvim/tests/builtin_test.lua
nvim --headless -u NONE -l apps/nvim/tests/features_test.lua
nvim --headless -u NONE -l apps/nvim/tests/replacements_test.lua
```

テンプレートの上書き防止、色・コメント判定、診断、検索、
スクロールバーのウィンドウ再利用、LSP進捗の寿命、
UTF-16参照位置と古いLSP応答の破棄を検証します。
