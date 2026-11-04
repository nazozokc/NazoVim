{
  description = "nazozokc's Neovim configuration";

  # ============================================================
  # monorepo structure:
  #   apps/nvim/       — Neovim configuration (init.lua, lua/, nazoplug-lock.json)
  #   packages/nix/    — Nix package definitions (config derivation + launcher)
  #   template/        — File templates for new projects
  #   docs/            — Documentation
  # ============================================================

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
          # パッケージ定義は packages/nix/ へ委譲
          # version はここで管理 (release.yml が tag push 時に sed で更新)
          nixPackages = import ./packages/nix/default.nix {
            inherit pkgs;
            version = "2.1.0";
            configSrc = ./apps/nvim;
            templateSrc = ./template;
            nazoplugSrc = ./apps/nazoplug/lua/nazoplug;
          };

          nvim-nazozokc = nixPackages.nvim-nazozokc;
          nvimConfig = nixPackages.nvimConfig;
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
              (pkgs.wrapNeovim pkgs.neovim-unwrapped { })
              git
              ripgrep
              bun
              deno
              nodejs_latest
              pnpm
              gnumake
              tree-sitter

              # LSP (nazovim/lsp.lua enables the ones present on PATH)
              lua-language-server
              nixd
              typescript-language-server
              clang-tools
              solargraph
              zls
              vscode-langservers-extracted
              jdt-language-server

              # DAP (nazovim/dap.lua spawns the js-debug adapter)
              vscode-js-debug

              # Formatter
              stylua
              nixfmt-rfc-style
              prettier
            ];

            # Tree-sitter grammars and queries come from Nix, not from a plugin.
            NAZOVIM_TREESITTER_DIR = "${nixPackages.treeSitterGrammars}";

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
