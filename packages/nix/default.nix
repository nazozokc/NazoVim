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
      LEGACY_APPNAME="nvim-nazozokc"
      CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
      DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME"
      STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/$APPNAME"
      BIN_DIR="''${XDG_BIN_HOME:-$HOME/.local/bin}"
      LEGACY_CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/$LEGACY_APPNAME"
      LEGACY_DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/$LEGACY_APPNAME"
      LEGACY_STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/$LEGACY_APPNAME"
      export NVIM_APPNAME="$APPNAME"
      # 未導入のプラグインを起動時に自動インストールする
      export NAZOVIM_AUTO_INSTALL=1

      # remove: NazoVim が作った config / data / state / bin shim をすべて削除する
      if [ "''${1:-}" = "remove" ]; then
        rm -rf "$CONFIG_DIR" "$DATA_DIR" "$STATE_DIR" \
          "$LEGACY_CONFIG_DIR" "$LEGACY_DATA_DIR" "$LEGACY_STATE_DIR"
        rm -f "$BIN_DIR/nazovim"
        # nvim は NazoVim を指す symlink のときだけ消す (他ツールの nvim は残す)
        if [ -L "$BIN_DIR/nvim" ]; then
          case "$(readlink "$BIN_DIR/nvim")" in
            *nazovim*|*NazoVim*|*nvim-nazozokc*) rm -f "$BIN_DIR/nvim" ;;
          esac
        fi
        echo "Removed NazoVim config, data, state and bin shims"
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
      # 旧 APPNAME (nvim-nazozokc) のプラグインを初回起動時に引き継ぐ
      if [ ! -d "$DATA_DIR/site" ] && [ -d "$LEGACY_DATA_DIR/site" ]; then
        cp -a "$LEGACY_DATA_DIR/site" "$DATA_DIR/site"
      fi
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
