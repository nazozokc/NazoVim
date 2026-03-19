{
  description = "nazozokc's Neovim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, ... }:
        let
          # このリポジトリの設定ファイルを Nix store にコピー
          nvimConfig = pkgs.stdenv.mkDerivation {
            pname = "nazovim";
            version = "0.1.0";
            src = ./.;
            # .git は不要なので除外
            installPhase = ''
              mkdir -p $out
              cp -r . $out/
              rm -rf $out/.git
            '';
          };

          # NVIM_APPNAME で完全隔離して起動する wrapped neovim
          # nix run github:nazozokc/nazozokc.nvim.config で起動可能
          nvim-nazozokc = pkgs.writeShellApplication {
            name = "nvim";
            runtimeInputs = [
              pkgs.neovim
              pkgs.git # lazy.nvim の自己 bootstrap に必要
              pkgs.clang-tools # clangd
              pkgs.jdt-language-server # jdtls
              pkgs.ruby
            ];
            text = ''
              APPNAME="nvim-nazozokc"
              CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
              DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME"
              export NVIM_APPNAME="$APPNAME"
              # 毎回 config を削除して再作成
              echo "[nazozokc.nvim] Refreshing config at $CONFIG_DIR ..."
              if [ -d "$CONFIG_DIR" ]; then
                rm -rf "$CONFIG_DIR"
              fi
              mkdir -p "$CONFIG_DIR"
              cp -r ${nvimConfig}/. "$CONFIG_DIR/"
              chmod -R u+w "$CONFIG_DIR"
              # lazy.nvim のデータディレクトリを事前に作成
              mkdir -p "$DATA_DIR"
              exec nvim "$@"
            '';
          };

        in
        {
          packages = {
            # nix build → result/bin/nvim
            default = nvim-nazozokc;

            # nix build .#config → 設定ファイル一式
            config = nvimConfig;
          };

          apps.default = {
            type = "app";
            program = "${nvim-nazozokc}/bin/nvim";
          };

          # nix develop → LSP / formatter が揃った開発シェル
          # NVIM_APPNAME も自動でセットされるので nvim を叩くだけで隔離環境に入る
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              neovim
              git

              # LSP
              lua-language-server
              nixd
              nodePackages.typescript-language-server

              # Formatter
              stylua
              nixfmt-rfc-style
              nodePackages.prettier
            ];

            shellHook = ''
              export NVIM_APPNAME="nvim-nazozokc"

              CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/nvim-nazozokc"

              if [ ! -d "$CONFIG_DIR" ]; then
                echo "[nazozokc.nvim] Initializing config at $CONFIG_DIR ..."
                mkdir -p "$CONFIG_DIR"
                cp -r ${nvimConfig}/. "$CONFIG_DIR/"
                chmod -R u+w "$CONFIG_DIR"
              fi

              echo "nazozokc.nvim devShell"
              echo "  neovim : $(nvim --version | head -1)"
              echo "  lua-ls : $(lua-language-server --version 2>/dev/null || echo 'ok')"
              echo "  config : $CONFIG_DIR"
              echo "  NVIM_APPNAME=$NVIM_APPNAME (隔離済み)"
            '';
          };
        };
    };
}
