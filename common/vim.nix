{ pkgs, config, ... }:

{
  programs.nixvim =
    {
      enable = true;
      extraPackages = with pkgs; [ rust-analyzer ];
      options = {
        number = true;
        relativenumber = true;
        clipboard = "unnamedplus";
        undofile = true;
        undodir = config.nixvim.helpers.mkRaw ''vim.fn.stdpath("data") .. "/undo"'';
        guifont = "Jetbrains Mono:h14";
      };
      extraConfigLua = ''
        local rt = require("rust-tools")
        require("which-key").setup { }

        rt.setup({
          server = {
            on_attach = function(_, bufnr)
              -- Hover actions
              vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
              -- Code action groups
              vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
            end,
          },
        })
        require('gitsigns').setup()

        require("toggleterm").setup {
          open_mapping = [[<C-\>]],
          direction = "float"
        }
        local Terminal = require("toggleterm.terminal").Terminal
        local lazygit = Terminal:new({
                cmd = "lazygit",
                direction = "float",
                hidden = true
        })

        function _lazygit_toggle()
          lazygit:toggle()
        end

        function _select_lf()
          local tempfile = os.tmpname()
          local lf = Terminal:new({
            cmd = "lf -selection-path=" .. tempfile,
            direction = "float",
            hidden = true,
            on_close = function(term)
              local f = io.open(tempfile, "r")
              local selection = f:read("*all")
              f:close()
              os.remove(tempfile)
              vim.cmd("e " .. selection)
            end,
          })
          lf:toggle()
        end

        require("auto-session").setup {
          log_level = "error"
        }
      '';
      colorschemes.onedark.enable = true;
      plugins = {
        nix.enable = true;
        trouble.enable = true;
        treesitter = {
          enable = true;
          indent = true;
          ensureInstalled = [ ];
          nixGrammars = false;
          parserInstallDir = "/Users/lightquantum/.config/nvim/ts";
          incrementalSelection = {
            enable = true;
            keymaps = {
              initSelection = "¬";
              nodeDecremental = "˙";
              nodeIncremental = "¬";
            };
          };
        };
        nvim-cmp = {
          enable = true;
          completion = {
            completeopt = "menu,menuone,noselect";
            keyword_length = 2;
          };
          snippet.expand = ''
            function(args)
              require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
            end
          '';
          mapping = {
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = ''cmp.mapping(function(fallback)
                -- This little snippet will confirm with tab, and if no entry is selected, will confirm the first item
                if (cmp.visible() and vim.b._copilot.suggestions == nil) then
                  local entry = cmp.get_selected_entry()
                  if not entry then
                    cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
                  else
                    cmp.confirm()
                  end
                else
                  fallback()
                end
              end, {"i","s",}) '';
            "<Up>" = "cmp.mapping.select_prev_item()";
            "<Down>" = "cmp.mapping.select_next_item()";
          };
          sources = [
            { name = "nvim_lsp"; }
            { name = "nvim_lsp_document_symbol"; }
            { name = "nvim_lsp_signature_help"; }
            { name = "buffer"; }
            { name = "path"; }
            { name = "luasnip"; }
          ];
        };
        cmp_luasnip.enable = true;
        cmp-nvim-lsp.enable = true;
        cmp-nvim-lsp-document-symbol.enable = true;
        cmp-nvim-lsp-signature-help.enable = true;
        cmp-buffer.enable = true;
        cmp-path.enable = true;
        copilot.enable = true;
        telescope = {
          enable = true;
          extensions = {
            frecency.enable = true;
          };
          enabledExtensions = [ "file_browser" ];
        };
        lualine = {
          enable = true;
          sections = {
            lualine_c = [
              {
                name = "filename";
                extraConfig = {
                  path = 3;
                };
              }
              "lsp_progress"
            ];
          };
        };
        bufferline.enable = true;
        lsp = {
          enable = true;
          servers = {
            eslint.enable = true;
            pyright.enable = true;
            rnix-lsp.enable = true;
            # rust-analyzer.enable = true;
          };
        };
        nvim-tree.enable = true;
      };
      extraPlugins = with pkgs.vimPlugins; [
        quick-scope
        suda-vim
        vim-startuptime
        telescope-file-browser-nvim
        auto-session
        auto-save-nvim
        rust-tools-nvim
        gitsigns-nvim
        dressing-nvim
        lualine-lsp-progress
        toggleterm-nvim
        luasnip
        which-key-nvim
      ];
      globals = {
        mapleader = " ";
        macos_alt_is_meta = true;
        copilot_assume_mapped = true;
      };
      maps = {
        normal = {
          "H" = { action = "^"; };
          "L" = { action = "$"; };
          "ZA" = { action = "<cmd>w suda://%<Return>:q<CR>"; };
          "<C-w>" = { action = "<cmd>bd<CR>"; silent = true; };
          "<C-b>" = { action = "<cmd>BufferLinePick<CR>"; };
          "<C-Left>" = { action = "<cmd>BufferLineCyclePrev<CR>"; };
          "<C-Right>" = { action = "<cmd>BufferLineCycleNext<CR>"; };
          "<Leader>s" = { action = "<cmd>Telescope live_grep<CR>"; silent = true; };
          "<Leader>f" = { action = "<cmd>Telescope find_files<CR>"; silent = true; };
          "<Leader>b" = { action = "<cmd>Telescope file_browser<CR>"; silent = true; };
          "<Leader>d" = { action = "<cmd>TroubleToggle document_diagnostics<CR>"; silent = true; };
          "<Leader>l" = {
            action = "<cmd>lua vim.lsp.buf.format{async=true}<CR>";
            silent = true;
          };
          "<leader>g" = {
            action = "<cmd>lua _lazygit_toggle()<CR>";
            silent = true;
          };
          "<leader>hs" = { action = "<cmd>Gitsigns stage_hunk<CR>"; silent = true; };
          "<leader>hd" = { action = "<cmd>Gitsigns reset_hunk<CR>"; silent = true; };
          # "<leader>l" = { action = "<cmd>lua _select_lf()<CR>"; silent = true; };
        };
        visual = {
          "H" = { action = "^"; };
          "L" = { action = "$"; };
          "ih" = "<cmd><C-U>Gitsigns select_hunk<CR>";
        };
        operator = {
          "ih" = "<cmd><C-U>Gitsigns select_hunk<CR>";
        };
        insert = {
          "<S-CR>" = { action = "<Esc>"; };
          "<D-S-l>" = { action = "<cmd>lua vim.lsp.buf.format{async=true}<Return>"; };
        };
        command = {
          "e!!" = { action = "e suda://%"; };
          "r!!" = { action = "e suda://%"; };
          "w!!" = { action = "w suda://%"; };
        };
      };
    };
}
