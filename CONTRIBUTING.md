# Contributing to nazovim

まず興味を持ってくれてありがとうございます！  
nazovim は個人設定ベースのディストリビューションですが、外部からのコントリビューションも歓迎です。

---

## 🗂 Issue を使う

バグ報告・機能提案・プラグイン追加提案は、それぞれ専用のテンプレートを使ってください。

| テンプレート | 用途 |
| ----------- | ---- |
| 🐛 Bug Report | クラッシュ・動作不良などの不具合 |
| ✨ Feature Request | キーマップ追加・設定の改善提案 |
| 🔌 Plugin Proposal | 新プラグインの追加提案 |

質問・雑談は
[GitHub Discussions](https://github.com/nazozokc/nazozokc.nvim.config/discussions)
へどうぞ。

---

## 🛠 PR を送る前に

1. **既存の Issue / PR を確認する** — 重複を避けるため、先に検索してください
2. **対象ブランチは `main`** — 直接 `main` に向けて PR を出してください
3. **スコープを絞る** — 1 PR 1 変更を原則にしてください

---

## 📋 開発環境のセットアップ

```bash
# リポジトリをクローン
git clone https://github.com/nazozokc/nazozokc.nvim.config.git
cd nazozokc.nvim.config

# Nix 環境で起動（LSP / formatter 込み）
nix develop
nvim

# Nix なしの場合
git clone https://github.com/nazozokc/nazozokc.nvim.config.git ~/.config/nvim
nvim
```

---

## ✅ コードスタイル

- **Lua フォーマット**: [StyLua](https://github.com/JohnnyMorganz/StyLua) に準拠（CI で自動チェック）
- **インデント**: スペース 2 つ
- ローカルで確認したい場合:

```bash
nix shell nixpkgs#stylua --command stylua lua/ init.lua
```

---

## 🔌 プラグインを追加・変更するとき

- プラグイン設定は `lua/plugins/<カテゴリ>/` 以下に 1 ファイル 1 プラグインで追加
- lazy.nvim の仕様に従い、できる限り **遅延ロード** (`event`, `ft`, `cmd`, `keys`) を指定してください
- 既存プラグインと重複・競合がないか確認してください（特に LSP 系・フォーマッター系）

```text
lua/plugins/
├── ai/          # AI 統合
├── completion/  # 補完
├── dap/         # デバッグ
├── editor/      # 編集補助
├── finder/      # ファジーファインダー・ナビゲーション
├── git/         # Git 操作
├── lang/        # 言語別設定
├── lsp/         # LSP 関連
├── misc/        # その他ユーティリティ
├── test/        # テスト
├── treesitter/  # Treesitter
├── ui/          # UI・見た目
└── web/         # Web 開発向け
```

---

## 🤖 CI について

PR を出すと以下の CI が自動実行されます。

| ワークフロー | 内容 |
| ------------ | ---- |
| `nvim.yml` | Neovim のヘッドレス起動チェック（エラーが出ないか確認） |
| `nvim-lint.yml` | StyLua フォーマットチェック + luacheck |

CI が通らない PR はマージできません。ローカルで事前確認することを推奨します。

---

## 📄 ライセンス

コントリビューションは [MIT License](./LICENSE) のもとで公開されます。
