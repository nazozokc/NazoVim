# NazoVim package definitions
#
# The Neovim config is extracted from apps/nvim/ (with the nazoplug runtime
# merged in), and wrapped as a fully isolated NVIM_APPNAME launcher.
#
# The root flake.nix wires these into `packages.default`, `packages.config`
# and `apps.default` for `nix run github:NazoVim-org/NazoVim`.

{
  pkgs,
  version,
  configSrc,
  nazoplugSrc,
}:

let
  # apps/nvim/ 以下の設定ファイルを Nix store にコピー
  nvimConfig = pkgs.stdenv.mkDerivation {
    pname = "nazovim";
    inherit version;
    src = pkgs.lib.cleanSource configSrc;
    installPhase = ''
      mkdir -p $out/lua/nazoplug
      cp -r . $out/
      cp -r ${nazoplugSrc}/. $out/lua/nazoplug/
    '';
  };

  # NVIM_APPNAME で完全隔離して起動する wrapped neovim
  neovim = pkgs.wrapNeovim pkgs.neovim-unwrapped { };

  nazovim = pkgs.writeShellApplication {
    name = "nvim";
    runtimeInputs = [
      neovim
      pkgs.git
      pkgs.gnumake
      pkgs.nodejs_latest
      pkgs.tree-sitter
      pkgs.clang-tools # clangd
      pkgs.jdt-language-server # jdtls
      pkgs.ruby
    ];
    text = ''
      APPNAME="nazovim"
      CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
      DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME"
      export NVIM_APPNAME="$APPNAME"

      # remove: 設定ディレクトリだけを削除する (plugins は data dir に残す)
      if [ "''${1:-}" = "remove" ]; then
        rm -rf "$CONFIG_DIR"
        echo "Removed $CONFIG_DIR"
        exit 0
      fi
      # `--` で nvim に渡す引数と排他する
      if [ "''${1:-}" = "--" ]; then
        shift
      fi

      # symlink なら既存チェック不要、存在すれば上書き
      if [ -L "$CONFIG_DIR" ]; then
        rm "$CONFIG_DIR"
      elif [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
      fi
      ln -s ${nvimConfig} "$CONFIG_DIR"
      # プラグインのデータディレクトリを事前に作成
      mkdir -p "$DATA_DIR"
      # 初回起動時に Nix store の lockfile を data dir にコピー
      if [ ! -f "$DATA_DIR/nazoplug-lock.json" ] && [ -f "$CONFIG_DIR/nazoplug-lock.json" ]; then
        cp "$CONFIG_DIR/nazoplug-lock.json" "$DATA_DIR/nazoplug-lock.json"
      fi
      # store の読み取り専用 mode を引き継がないようにする
      [ -f "$DATA_DIR/nazoplug-lock.json" ] && chmod u+w "$DATA_DIR/nazoplug-lock.json" || true
      exec nvim "$@"
    '';
  };
in
{
  inherit nvimConfig nazovim;
}
