# NazoVim package definitions
#
# The Neovim config is extracted from apps/nvim/ (with the nazoplug runtime
# merged in), and wrapped as a fully isolated NVIM_APPNAME launcher.
#
# The root flake.nix wires these into `packages.default`, `packages.config`
# and `apps.default` for `nix run github:nazozokc/NazoVim`.

{
  pkgs,
  version,
  configSrc,
  nazoplugSrc,
  templateSrc,
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
      mkdir -p $out/template
      cp -r ${templateSrc}/. $out/template/
    '';
  };

  # NVIM_APPNAME で完全隔離して起動する wrapped neovim
  neovim = pkgs.wrapNeovim pkgs.neovim-unwrapped { };

  nvim-nazozokc = pkgs.writeShellApplication {
    name = "nvim";
    runtimeInputs = [
      neovim
      pkgs.git
      pkgs.ripgrep
      pkgs.gnumake
      pkgs.nodejs_latest
      pkgs.tree-sitter
      pkgs.clang-tools # clangd
      pkgs.jdt-language-server # jdtls
      pkgs.ruby
    ];
    text = ''
      # An explicit ephemeral session keeps all NazoVim state in a private directory.
      TEMP_ROOT=""
      if [ "''${1:-}" = "--temporary" ]; then
        shift
        TEMP_ROOT="$(mktemp -d "''${TMPDIR:-/tmp}/nazovim.XXXXXXXX")"
        trap 'rm -rf -- "$TEMP_ROOT"' EXIT
        export XDG_CONFIG_HOME="$TEMP_ROOT/config"
        export XDG_DATA_HOME="$TEMP_ROOT/data"
        export XDG_CACHE_HOME="$TEMP_ROOT/cache"
        export XDG_STATE_HOME="$TEMP_ROOT/state"
      fi
      APPNAME="nvim-nazozokc"
      CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
      DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME"
      export NVIM_APPNAME="$APPNAME"
      # Keep the existing link on the common path; never delete user config.
      mkdir -p "''${XDG_CONFIG_HOME:-$HOME/.config}"
      if [ -L "$CONFIG_DIR" ]; then
        current_target="$(readlink "$CONFIG_DIR")"
        if [ "$current_target" != "${nvimConfig}" ]; then
          case "$current_target" in
            /nix/store/*-nazovim-*) ln -sfn ${nvimConfig} "$CONFIG_DIR" ;;
            *) echo "NazoVim: refusing to replace config symlink: $CONFIG_DIR" >&2; exit 1 ;;
          esac
        fi
      elif [ -e "$CONFIG_DIR" ]; then
        echo "NazoVim: refusing to replace existing config: $CONFIG_DIR" >&2
        exit 1
      else
        ln -s ${nvimConfig} "$CONFIG_DIR"
      fi
      # プラグインのデータディレクトリを事前に作成
      mkdir -p "$DATA_DIR"
      # 初回起動時に Nix store の lockfile を data dir にコピー
      if [ ! -f "$DATA_DIR/nazoplug-lock.json" ] && [ -f "$CONFIG_DIR/nazoplug-lock.json" ]; then
        cp "$CONFIG_DIR/nazoplug-lock.json" "$DATA_DIR/nazoplug-lock.json"
      fi
      if [ -n "$TEMP_ROOT" ]; then
        nvim "$@"
      else
        exec nvim "$@"
      fi
    '';
  };
in
{
  inherit nvimConfig nvim-nazozokc;
}
